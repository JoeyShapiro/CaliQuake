import Darwin
import Foundation

func runBash() {
    let bashPath = "/bin/bash".withCString(strdup)
    
    var environment: [String: String] = ProcessInfo.processInfo.environment
    environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
    
    var fileActions: posix_spawn_file_actions_t? = nil
    posix_spawn_file_actions_init(&fileActions)

    // Set up a pipe to communicate with the spawned process
    var pipeFDs: [Int32] = [0, 0] // [read, write]
    pipe(&pipeFDs)
    
    // i got it!
    // Set up the file actions to map the write end of the pipe to the child's stdin
    // the program READS from strdin
    var s = posix_spawn_file_actions_adddup2(&fileActions, pipeFDs[0], STDIN_FILENO)
    print("posix_spawn_file_actions_adddup2: \(s)")

    // Set up another pipe to capture the child's stdout and stderr
    var outPipeFDs: [Int32] = [0, 0]
    pipe(&outPipeFDs)
    // the program WRITES to stdout
    s = posix_spawn_file_actions_adddup2(&fileActions, outPipeFDs[1], STDOUT_FILENO)
    print("posix_spawn_file_actions_adddup2: \(s)")
    // posix_spawn_file_actions_adddup2(&fileActions, outPipeFDs[1], STDERR_FILENO)
    
    defer {
        posix_spawn_file_actions_destroy(&fileActions)
        fileActions?.deallocate()
        close(pipeFDs[0])
        close(pipeFDs[1])
        close(outPipeFDs[0]) // Close the read end of the output pipe
    }
    
    var pid: pid_t = 0
    let result = posix_spawn(&pid, bashPath, &fileActions, nil, [bashPath], environment.keys.map { $0.withCString(strdup) })
    
    if result != 0 {
        print("Error launching Bash: \(result)")
        return
    }

    // Write commands to the pipe
    let command1 = "echo 'Hello, World!'\n"
    let command2 = "ls -l\n"
    let command3 = "exit\n"
    
    let commandData1 = command1.data(using: .utf8)!
    let commandData2 = command2.data(using: .utf8)!
    let commandData3 = command3.data(using: .utf8)!
    
    commandData1.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
        let n = write(pipeFDs[1], ptr.baseAddress!, ptr.count)
        print("wrote \(n) bytes")
    }
    
    commandData2.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
        let n = write(pipeFDs[1], ptr.baseAddress!, ptr.count)
        print("wrote \(n) bytes")
    }

    commandData3.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
        let n = write(pipeFDs[1], ptr.baseAddress!, ptr.count)
        print("wrote \(n) bytes")
    }

    close(outPipeFDs[1])
    
    // Read output from the spawned process
    var outputData = Data()
    let bufferSize = 1024
    var buffer = [UInt8](repeating: 0, count: bufferSize)
    
    var bytesRead = read(outPipeFDs[0], &buffer, bufferSize) // Use outPipeFDs[0] for reading
    print("bytesRead: \(bytesRead)")
    while bytesRead > 0 {
        outputData.append(buffer, count: bytesRead)
        bytesRead = read(outPipeFDs[0], &buffer, bufferSize) // Use outPipeFDs[0] for reading
        print("bytesRead: \(bytesRead)")
    }
    
    if let output = String(data: outputData, encoding: .utf8) {
        print("Output from Bash:\n\(output)")
    } else {
        print("Error decoding output data")
    }
    
    var status: Int32 = 0
    waitpid(pid, &status, 0)
}

print("starting...")
runBash()
print("done")