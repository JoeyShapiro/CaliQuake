//
//  PsuedoTerminal.swift
//  CaliQuake
//
//  Created by Joey Shapiro on 6/14/24.
//

import Foundation
import Dispatch

class PseudoTerminal {
//    private var shell = "/usr/bin/login".withCString(strdup) // /opt/homebrew/bin/nu
    private var shell = "/bin/zsh".withCString(strdup)
    private var fileActions: posix_spawn_file_actions_t? = nil
    private var spawnAttr: posix_spawnattr_t? = nil
    private var master: Int32 = 0
    private var slave: Int32 = 0
    public var pid: pid_t
    
    init(rows: Int, cols: Int) {
        var winp: winsize = winsize()
        // TODO bad values
        winp.ws_row = UInt16(rows)
        winp.ws_col = UInt16(cols)
        
        var term: termios = termios()
        term.c_iflag = tcflag_t(ICRNL | IXON | IXANY | IMAXBEL | BRKINT | IUTF8)
        term.c_oflag = tcflag_t(OPOST | ONLCR)
        term.c_cflag = tcflag_t(CREAD | CS8 | HUPCL)
        term.c_lflag = tcflag_t(ICANON | ISIG | IEXTEN | ECHO | ECHOE | ECHOK | ECHOKE | ECHOCTL)
        tcgetattr(self.master, &term)
        tcsetattr(self.master, TCSAFLUSH, &term)
        
        var name = [CChar](repeating: 0, count: 1024)
        self.pid = openpty(&self.master, &self.slave, &name, &term, &winp)
        if self.pid == 0 {
            // child
            self.child()
            print("child done")
        }
        if self.pid == -1 {
            fatalError("Error creating pseudo-terminal: \(self.pid) \(errno)")
        }
        print("forked \(String(cString: name))")
    }
    
    func child() -> pid_t {
        print("started child")
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = getenv("PATH").flatMap { String(cString: $0) } ?? ""
        environment["TERM"] = "xterm-256color"
        environment["OS_ACTIVITY_MODE"] = "disable"
        environment["LANG"] = "en_US.UTF-8"
        
        posix_spawn_file_actions_init(&self.fileActions)
        
        posix_spawn_file_actions_adddup2(&self.fileActions, self.slave, STDIN_FILENO)
        posix_spawn_file_actions_adddup2(&self.fileActions, self.slave, STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&self.fileActions, self.slave, STDERR_FILENO)
        
        // MARK: actions
//        let fds: [Int32] = [ STDIN_FILENO, STDOUT_FILENO, STDERR_FILENO ]
//        for i in 0..<3 {
//            if fds[i] != i {
//                posix_spawn_file_actions_adddup2(&self.fileActions, fds[i], Int32(i))
//            } else {
//                posix_spawn_file_actions_addinherit_np(&self.fileActions, Int32(i))
//            }
//        }
        print("actions done")
        
        posix_spawn_file_actions_addclose(&self.fileActions, self.master)
        
        // MARK: attributes
        // Set up spawn attributes
        // fixes all my problems, even the orphan using >100% cpu
        posix_spawnattr_init(&self.spawnAttr)
        
        var flags: Int16 = 0;
        // Use spawn-sigdefault in attrs rather than inheriting parent's signal
        // actions (vis-a-vis caught vs default action)
//        flags |= Int16(POSIX_SPAWN_SETSIGDEF)
//        // Use spawn-sigmask of attrs for the initial signal mask.
//        flags |= Int16(POSIX_SPAWN_SETSIGMASK)
//        // Close all file descriptors except those created by file actions.
//        flags |= Int16(POSIX_SPAWN_CLOEXEC_DEFAULT)
//        flags |= Int16(POSIX_SPAWN_SETEXEC)
        flags |= Int16(POSIX_SPAWN_SETSID)
        let rc = posix_spawnattr_setflags(&self.spawnAttr, flags)
        if rc != 0 {
            print("attr failed")
        } else {
            print("attr done")
        }
        
        // Do not start the new process with signal handlers.
        var default_signals: sigset_t = sigset_t()
        sigfillset(&default_signals)
        for i in 0..<NSIG {
            sigdelset(&default_signals, i)
        }
        posix_spawnattr_setsigdefault(&self.spawnAttr, &default_signals)
        print("signals done")
        
        // Unblock all signals.
        var signals: sigset_t = sigset_t();
        sigemptyset(&signals)
        posix_spawnattr_setsigmask(&self.spawnAttr, &signals)
        print("unblock done")
        
        // Prepare the arguments array
        let arguments: [String] = []
//        let arguments = [ "-fp", "oniichan", "/bin/zsh", "-fc", "exec -a -zsh /bin/zsh" ]
        let args = [shell] + arguments.map { strdup($0) }
        defer { for arg in args { free(arg) } }
        let env = environment.map({ "\($0)=\($1)" }) 
        // this was wrong. need this whole proper nightmare
        //environment.keys.map { $0.withCString(strdup) }
        let env2 = env.map { strdup($0) }
        var ptrEnv = env2.map { UnsafeMutablePointer<CChar>($0) }
        ptrEnv.append(nil)
        
        // Create a null-terminated array of C string pointers
        var argsPtrs = args.map { UnsafeMutablePointer<CChar>($0) }
        argsPtrs.append(nil)
        print("args done")
        
        var cpid: pid_t = 0
        let spawnResult = posix_spawn(&self.pid, shell, &fileActions, &self.spawnAttr, argsPtrs, ptrEnv)
        
        print("spawn: \(spawnResult)")
        if spawnResult != 0 {
            fatalError("Error launching shell: \(spawnResult): \"\(String(cString: strerror(errno)))\"")
        }
        
        return cpid
    }
    
    // should go here, just in case
    // also makes sense, shouldnt rely on caller to close it
    deinit {
        self.close()
    }
    
    func write(command: String) -> Int {
        let buf = command.data(using: .utf8)!
        
        let n = buf.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            Darwin.write(self.master, ptr.baseAddress!, ptr.count)
        }
        
        return n
    }
    
    func read() async throws -> (Data, Int) {
        var data = Data()
        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var bytesRead = 0
        // TODO have to do it this way. but see if i can move this out
        // i did want pty to handle the threading though
        return try await withCheckedThrowingContinuation { continuation in
            let queue = DispatchQueue(label: "com.JoeyShapiro.PsuedoTerminal.read")
            let source = DispatchSource.makeReadSource(fileDescriptor: self.master, queue: queue)
            
            source.setEventHandler {
                bytesRead = Darwin.read(self.master, &buffer, bufferSize)
                
                if bytesRead > 0 {
                    data.append(buffer, count: bytesRead)
                    #if DEBUG
                    if let output = String(data: data, encoding: .utf8) {
                            print("\"", terminator: "")
                            for c in output {
                                let val = c.unicodeScalars.first?.value ?? 0
                                // is printable ascii character
                                if let ascii = c.asciiValue, ascii > 32 && ascii < 127 {
                                    print(c, terminator: "")
                                } else {
                                    print("\\u\(val)", terminator: "")
                                }
                            }
                            print("\"")
                        } else {
                            print("Error decoding output data")
                        }
                    #endif
                    
                    source.cancel()
                    continuation.resume(returning: (data, bytesRead))
                } else {
                    source.cancel()
                    if bytesRead == 0 {
                        continuation.resume(returning: (data, bytesRead))
                    } else {
                        continuation.resume(throwing: NSError(domain: "FileReaderError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Error reading file"]))
                    }
                }
            }
            
            source.resume()
        }
    }
    
    func close() {
        // Send the exit command to the shell
        let exitCommand = "exit\n"
        let exitCommandData = exitCommand.data(using: .utf8)!
        exitCommandData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            Darwin.write(self.master, ptr.baseAddress!, ptr.count)
        }
        
        // Wait for the child process to terminate
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        
        // Close the master file descriptor
        Darwin.close(self.master)
        
        // Destroy the posix_spawn_file_actions_t structure
        posix_spawn_file_actions_destroy(&self.fileActions)
        self.fileActions?.deallocate()
        
        posix_spawnattr_destroy(&self.spawnAttr)
        self.spawnAttr?.deallocate()
        
        #if DEBUG
            print("Closed")
        #endif // DEBUG
    }
}

import SwiftUI
struct AnsiChar {
    var char: Character
    var fg: NSColor // Color causes crash
    var font: FontStyle
    var x: Int
    var y: Int
    var width: Int // need this, but want \n to be at end of line
    
    init() {
        self.char  = "�"
        self.fg    = .white
        self.font  = .regular
        self.x     = -1
        self.y     = -1
        self.width = 0
    }
    
    init(x: Int, y: Int) {
        self.char  = "�"
        self.fg    = .white
        self.font  = .regular
        self.x     = 0
        self.y     = 0
        self.width = 0
    }
}

enum FontStyle {
    case regular
    case bold
    case italic
    case boldItalic
    
    func font(size: CGFloat) -> NSFont {
        switch self {
        case .regular:
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case .bold:
            return NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
        case .italic:
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular).withTraits(.italicFontMask)
        case .boldItalic:
            return NSFont.monospacedSystemFont(ofSize: size, weight: .bold).withTraits(.italicFontMask)
        }
    }
}

extension NSFont {
    func withTraits(_ traits: NSFontTraitMask) -> NSFont {
        guard let newFont = NSFontManager.shared.font(withFamily: familyName ?? "", traits: traits, weight: 0, size: pointSize) else {
            return self
        }
        return newFont
    }
}
