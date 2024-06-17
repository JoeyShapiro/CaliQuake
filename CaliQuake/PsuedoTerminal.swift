//
//  PsuedoTerminal.swift
//  CaliQuake
//
//  Created by Joey Shapiro on 6/14/24.
//

import Foundation

class PseudoTerminal {
    private var shell = "/bin/zsh".withCString(strdup)
    private var fileActions: posix_spawn_file_actions_t? = nil
    private var master: Int32 = 0
    private var slave: Int32 = 0
    private var pid: pid_t
    
    init() {
        var environment: [String: String] = ProcessInfo.processInfo.environment
        environment["PATH"] = getenv("PATH").flatMap { String(cString: $0) } ?? ""
        
        posix_spawn_file_actions_init(&self.fileActions)
        
        var winp: winsize = winsize()
        winp.ws_row = 24
        winp.ws_col = 80
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
        
        #if DEBUG
            print("Closed")
        #endif // DEBUG
    }
}

import SwiftUI
struct AnsiChar {
    var char: Character
    var fg: NSColor // Color causes crash
    var x: Int
    var y: Int
}
