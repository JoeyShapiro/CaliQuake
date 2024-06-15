//
//  PsuedoTerminal.swift
//  CaliQuake
//
//  Created by Joey Shapiro on 6/14/24.
//

import Foundation

struct PseudoTerminal {
    private var shell = "/bin/bash".withCString(strdup)
    private var fileActions: posix_spawn_file_actions_t? = nil
    private var master: Int32 = 0
    private var slave: Int32 = 0
    private var pid: pid_t
    
    init() {
        var environment: [String: String] = ProcessInfo.processInfo.environment
        environment["PATH"] = getenv("PATH").flatMap { String(cString: $0) } ?? ""
        
        posix_spawn_file_actions_init(&self.fileActions)
        
        var winp: winsize = winsize()
        let result = openpty(&master, &slave, nil, nil, &winp)
        if result != 0 {
            fatalError("Error creating pseudo-terminal: \(result)")
        }
        
        var term: termios = termios()
        tcgetattr(self.master, &term)
        term.c_lflag &= ~UInt(ECHO | ECHOCTL)
        tcsetattr(self.master, TCSAFLUSH, &term)
        
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

