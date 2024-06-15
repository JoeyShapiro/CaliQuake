//
//  PsuedoTerminal.swift
//  CaliQuake
//
//  Created by Joey Shapiro on 6/14/24.
//

import Foundation

struct PseudoTerminal {
    private var shell = "/bin/sh".withCString(strdup)
    private var fileActions: posix_spawn_file_actions_t? = nil
    private var master: Int32 = 0
    private var slave: Int32 = 0
    private var pid: pid_t
    
    init() {
        var environment: [String: String] = ProcessInfo.processInfo.environment
        environment["PATH"] = getenv("PATH").flatMap { String(cString: $0) } ?? ""
        
        posix_spawn_file_actions_init(&self.fileActions)
        
        var amaster: Int32 = 0
        var aslave: Int32 = 0
        let result = openpty(&amaster, &aslave, nil, nil, nil)
        if result != 0 {
            fatalError("Error creating pseudo-terminal: \(result)")
        }
        self.master = amaster
        self.slave = aslave
        
        posix_spawn_file_actions_adddup2(&self.fileActions, self.slave, STDIN_FILENO)
        posix_spawn_file_actions_adddup2(&self.fileActions, self.slave, STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&self.fileActions, self.slave, STDERR_FILENO)
        posix_spawn_file_actions_addclose(&self.fileActions, self.master)
        
        self.pid = 0
        let spawnResult = posix_spawn(&self.pid, shell, &fileActions, nil, [shell], environment.keys.map { $0.withCString(strdup) })
        
        if spawnResult != 0 {
            fatalError("Error launching shell: \(spawnResult)")
        }
        
        Darwin.close(self.slave)
    }
    
    func write(command: String) -> Int {
        let buf = command.data(using: .utf8)!
        
        let n = buf.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            Darwin.write(self.master, ptr.baseAddress!, ptr.count)
        }
        
        return n
    }
    
    func read() -> (Data, Int) {
        var data = Data()
        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        
        let bytesRead = Darwin.read(self.master, &buffer, bufferSize)
        data.append(buffer, count: bytesRead)
        
        if let output = String(data: data, encoding: .utf8) {
            print("Output from shell:\n\(output)")
        } else {
            print("Error decoding output data")
        }
        
        return (data, bytesRead)
    }
    
    mutating func close() {
        posix_spawn_file_actions_destroy(&self.fileActions)
        self.fileActions?.deallocate()
        
        Darwin.close(self.master)
        
        var status: Int32 = 0
        waitpid(pid, &status, 0)
    }
}

struct Pipe {
    private var fds: [Int32] = [0, 0]
    public var r: Int32 {
        get { self.fds[0] }
    }
    public var w: Int32 {
        get { self.fds[1] }
    }
    
    init() {
        pipe(&fds)
    }
    
    public mutating func close() {
        Darwin.close(self.fds[0])
        Darwin.close(self.fds[1])
        
        self.fds[0] = 0
        self.fds[1] = 0
    }
}

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
    posix_spawn_file_actions_adddup2(&fileActions, pipeFDs[0], STDIN_FILENO)
    
    // Set up another pipe to capture the child's stdout and stderr
    var outPipeFDs: [Int32] = [0, 0]
    pipe(&outPipeFDs)
    // the program WRITES to stdout
    posix_spawn_file_actions_adddup2(&fileActions, outPipeFDs[1], STDOUT_FILENO)
    
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
        
        if let output = String(data: outputData, encoding: .utf8) {
            print("Output from Bash:\n\(output)")
        } else {
            print("Error decoding output data")
        }
    }
    
    var status: Int32 = 0
    waitpid(pid, &status, 0)
}
