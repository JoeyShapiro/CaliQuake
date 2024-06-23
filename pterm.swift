import Darwin
import Foundation

func runBash() {
    let bashPath = "/bin/bash".withCString(strdup)
    
    var environment: [String: String] = ProcessInfo.processInfo.environment
    environment["PATH"] = getenv("PATH").flatMap { String(cString: $0) } ?? ""
    
    var fileActions: posix_spawn_file_actions_t? = nil
    posix_spawn_file_actions_init(&fileActions)

    var master: Int32 = 0
    var slave: Int32 = 0
    var winp: winsize = winsize()
    
    let result = openpty(&master, &slave, nil, nil, &winp)
    if result != 0 {
        fatalError("Error creating pseudo-terminal: \(result)")
    }
    
    var term: termios = termios()
    tcgetattr(master, &term)
    term.c_lflag &= ~UInt(ECHO | ECHOCTL)
    tcsetattr(master, TCSAFLUSH, &term)
    
    posix_spawn_file_actions_adddup2(&fileActions, slave, STDIN_FILENO)
    posix_spawn_file_actions_adddup2(&fileActions, slave, STDOUT_FILENO)
    posix_spawn_file_actions_adddup2(&fileActions, slave, STDERR_FILENO)
    posix_spawn_file_actions_addclose(&fileActions, master)
    
    defer {
        posix_spawn_file_actions_destroy(&fileActions)
        fileActions?.deallocate()
        close(master)
        close(slave)
    }
    
    var pid: pid_t = 0
    let spawnResult = posix_spawn(&pid, bashPath, &fileActions, nil, [bashPath], environment.keys.map { $0.withCString(strdup) })
    
    if spawnResult != 0 {
        fatalError("Error launching Bash: \(spawnResult)")
    }

    close(slave)

    // Read output from the spawned process
    var outputData = Data()
    let bufferSize = 1024
    var buffer = [UInt8](repeating: 0, count: bufferSize)
    
    var bytesRead = read(master, &buffer, bufferSize)
    print("--------- bytesRead: \(bytesRead)")
    if let output = String(data: outputData, encoding: .utf8) {
        print("Output from Bash:\n\(output)")
    } else {
        print("Error decoding output data")
    }

    // Write commands to the pseudo-terminal
    let command1 = "echo 'Hello, World!'\n"
    let command2 = "ls\n"
    let command3 = "exit\n"
    let command4 = "python3 -c 'import sys; print(sys.stdout.isatty())'\n"
    let command5 = "printf 'Colors: \\033[31mRed\\033[0m \\033[32mGreen\\033[0m \\033[34mBlue\\033[0m \\033[33mYellow\\033[0m \\033[35mMagenta\\033[0m \\033[36mCyan\\033[0m\n'"
    
    let commandData1 = command1.data(using: .utf8)!
    let commandData2 = command2.data(using: .utf8)!
    let commandData3 = command3.data(using: .utf8)!
    let commandData4 = command4.data(using: .utf8)!
    let commandData5 = command5.data(using: .utf8)!
    
    commandData1.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
        let n = write(master, ptr.baseAddress!, ptr.count)
        print("wrote \(n) bytes")
    }

    commandData2.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
        let n = write(master, ptr.baseAddress!, ptr.count)
        print("wrote \(n) bytes")
    }

    commandData4.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
        let n = write(master, ptr.baseAddress!, ptr.count)
        print("wrote \(n) bytes")
    }

    commandData5.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
        let n = write(master, ptr.baseAddress!, ptr.count)
        print("wrote \(n) bytes")
    }

    outputData.removeAll()
    bytesRead = read(master, &buffer, bufferSize)
    outputData.append(buffer, count: bytesRead)

    commandData3.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
        let n = write(master, ptr.baseAddress!, ptr.count)
        print("wrote \(n) bytes")
    }

    while bytesRead > 0 {
        outputData.removeAll()
        bytesRead = read(master, &buffer, bufferSize)
        outputData.append(buffer, count: bytesRead)
        print("-------- bytesRead: \(bytesRead)")

        // check if the buffer contains \033
        for i in 0..<bytesRead {
            if buffer[i] == 0x1b {
                print("buffer: \(buffer)")
                break
            }
        }

        if let output = String(data: outputData, encoding: .utf8) {
            print("Output from Bash:\n\(output)")
            if output.contains("exit") {
                print("exit command found")
                break
            }
        } else {
            print("Error decoding output data")
        }
    }
    
    var status: Int32 = 0
    waitpid(pid, &status, 0)
}

print("starting...")
runBash()
print("done")