import Darwin
import Foundation

func runBash() {
    let bashPath = "/bin/bash".withCString(strdup)
    
    var environment: [String: String] = ProcessInfo.processInfo.environment
    environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
    
    var fileActions: posix_spawn_file_actions_t? = nil
    posix_spawn_file_actions_init(&fileActions)

    // Set up a pipe to communicate with the spawned process
    var pipeFDs: [Int32] = [0, 0]
    pipe(&pipeFDs)
    
    // Set up the file actions to map the write end of the pipe to the child's stdin
    posix_spawn_file_actions_adddup2(&fileActions, pipeFDs[1], STDIN_FILENO)
    
    defer {
        posix_spawn_file_actions_destroy(&fileActions)
        fileActions?.deallocate()
        close(pipeFDs[0]) // Close the read end of the pipe
        close(pipeFDs[1]) // Close the write end of the pipe
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
    
    let commandData1 = command1.data(using: .utf8)!
    let commandData2 = command2.data(using: .utf8)!
    
    _ = commandData1.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
        write(pipeFDs[1], ptr.baseAddress!, ptr.count)
    }
    
    _ = commandData2.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
        write(pipeFDs[1], ptr.baseAddress!, ptr.count)
    }
    
    var status: Int32 = 0
    waitpid(pid, &status, 0)
}

print("starting...")
runBash()
print("done")

