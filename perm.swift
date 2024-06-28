import Foundation
import Dispatch

var shell = "/opt/homebrew/bin/nu".withCString(strdup)
var fileActions: posix_spawn_file_actions_t? = nil
var spawnAttr: posix_spawnattr_t? = nil
var master: Int32 = 0
var slave: Int32 = 0
var pid: pid_t

var environment: [String: String] = ProcessInfo.processInfo.environment
        environment["PATH"] = getenv("PATH").flatMap { String(cString: $0) } ?? ""
        
        posix_spawn_file_actions_init(&fileActions)
        
        var winp: winsize = winsize()
        // TODO bad values
        winp.ws_row = UInt16(80)
        winp.ws_col = UInt16(24)
        let result = openpty(&master, &slave, nil, nil, &winp)
        if result != 0 {
            fatalError("Error creating pseudo-terminal: \(result)")
        }
        
        var term: termios = termios()
        tcgetattr(master, &term)
//        term.c_lflag &= ~UInt(ECHO | ECHOCTL)
//        term.c_lflag &= ~UInt(ICANON | ECHO)
        tcsetattr(master, TCSAFLUSH, &term)
        
        posix_spawn_file_actions_adddup2(&fileActions, slave, STDIN_FILENO)
        posix_spawn_file_actions_adddup2(&fileActions, slave, STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&fileActions, slave, STDERR_FILENO)
        posix_spawn_file_actions_addclose(&fileActions, master)
        
        let res = login_tty(slave)
        print(String(cString: strerror(errno)))
        let res2 = ioctl(slave, TIOCSWINSZ, &winp)
        let res3 = ioctl(slave, TIOCSCTTY, 0)
        print(String(cString: strerror(errno)))

        // Set up spawn attributes
        // fixes all my problems, even the orphan using >100% cpu
        posix_spawnattr_init(&spawnAttr)
        posix_spawnattr_setflags(&spawnAttr, Int16(POSIX_SPAWN_SETSID))
        
        pid = 0
        let spawnResult = posix_spawn(&pid, shell, &fileActions, &spawnAttr, [shell], environment.keys.map { $0.withCString(strdup) })
        
        if spawnResult != 0 {
            fatalError("Error launching shell: \(spawnResult)")
        }
        
        Darwin.close(slave)