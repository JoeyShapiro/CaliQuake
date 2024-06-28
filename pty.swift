import Foundation
import Darwin

// First, we need to import the necessary C functions
let forkpty = Darwin.forkpty
let execvp = Darwin.execvp

// Main function to demonstrate forkpty usage
func testForkpty() {
    var master: Int32 = 0
    var name = [CChar](repeating: 0, count: 1024)
    
    let pid = forkpty(&master, &name, nil, nil)
    var cmds = [ "exit" ]

    print("Name: \(String(cString: name))")
    
    if pid < 0 {
        print("Error: forkpty failed")
        return
    } else if pid == 0 {
        // Child process
        print("Child process started")
        
        // Run zsh with proper arguments
        let args = ["zsh"]
        let cargs = args.map { strdup($0) } + [nil]
        
        let p = execvp(args[0], cargs)
        let str = String(cString: strerror(errno))
        print("Error: execvpe returned \(p) \(errno) \(str)")
        
        // If execvpe fails, we'll reach here
        print("Error: execvpe failed")
        exit(1)
    } else {
        // Parent process
        print("Parent process: child PID is \(pid)")
        
        // Read output from child process
        let bufferSize = 1024
        var buffer = [CChar](repeating: 0, count: bufferSize)
        
        while true {
            let bytesRead = read(master, &buffer, bufferSize)
            if bytesRead <= 0 {
                break
            }
            let output = String(cString: buffer)
            print("Received from child: \(output)", terminator: "")

            // If we have no more commands to send, break
            if cmds.count == 0 {
                break
            }
            let cmd = cmds[0]
            let cmdLen = cmd.count
            let written = write(master, strdup(cmd), cmdLen)
            if written < 0 {
                print("Error writing to child process")
                break
            }

            // remove the command from the list
            cmds.removeFirst()
        }
        
        // Wait for child process to finish
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        print("Child process exited with status \(status)")
    }
}

// Run the test
testForkpty()