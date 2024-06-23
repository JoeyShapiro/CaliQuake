//
//  PsuedoTerminal.swift
//  CaliQuake
//
//  Created by Joey Shapiro on 6/14/24.
//

import Foundation
import Dispatch

class PseudoTerminal {
    private var shell = "/bin/zsh".withCString(strdup)
    private var fileActions: posix_spawn_file_actions_t? = nil
    private var spawnAttr: posix_spawnattr_t? = nil
    private var master: Int32 = 0
    private var slave: Int32 = 0
    public var pid: pid_t
    
    init(rows: Int, cols: Int) {
        var environment: [String: String] = ProcessInfo.processInfo.environment
        environment["PATH"] = getenv("PATH").flatMap { String(cString: $0) } ?? ""
        
        posix_spawn_file_actions_init(&self.fileActions)
        
        var winp: winsize = winsize()
        // TODO bad values
        winp.ws_row = UInt16(rows)
        winp.ws_col = UInt16(cols)
        let result = openpty(&master, &slave, nil, nil, &winp)
        if result != 0 {
            fatalError("Error creating pseudo-terminal: \(result)")
        }
        
        var term: termios = termios()
        tcgetattr(self.master, &term)
//        term.c_lflag &= ~UInt(ECHO | ECHOCTL)
        tcsetattr(self.master, TCSAFLUSH, &term)
        
        posix_spawn_file_actions_adddup2(&self.fileActions, self.slave, STDIN_FILENO)
        posix_spawn_file_actions_adddup2(&self.fileActions, self.slave, STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&self.fileActions, self.slave, STDERR_FILENO)
        posix_spawn_file_actions_addclose(&self.fileActions, self.master)
        
        // Set up spawn attributes
        // fixes all my problems, even the orphan using >100% cpu
        posix_spawnattr_init(&self.spawnAttr)
        posix_spawnattr_setflags(&self.spawnAttr, Int16(POSIX_SPAWN_SETSID))
        
        self.pid = 0
        let spawnResult = posix_spawn(&self.pid, shell, &fileActions, &self.spawnAttr, [shell], environment.keys.map { $0.withCString(strdup) })
        
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
                                if !c.isWhitespace {
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
    var x: Int
    var y: Int
    var width: Int // need this, but want \n to be at end of line
}
