import Darwin
import Foundation

func runBash() {
    let bashPath = "/bin/bash".withCString(strdup)
    
    var environment: [String: String] = ProcessInfo.processInfo.environment
    environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
    
    var fileActions: posix_spawn_file_actions_t? = nil
    posix_spawn_file_actions_init(&fileActions)
    
    var pid: pid_t = 0
    let result = posix_spawn(&pid, bashPath, &fileActions, nil, [bashPath], environment.keys.map { $0.withCString(strdup) })
    
    if result != 0 {
        print("Error launching Bash: \(result)")
        return
    }
    
    var status: Int32 = 0
    waitpid(pid, &status, 0)
    
    posix_spawn_file_actions_destroy(&fileActions)
}

print("Hello, World!")
runBash()
print("done")

