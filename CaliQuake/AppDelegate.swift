//
//  AppDelegate.swift
//  CaliQuake
//
//  Created by Joey Shapiro on 6/19/24.
//

import Foundation
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var pty: PseudoTerminal?
    
    override init() {
        super.init()
        setupSignalHandlers()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("hello from delegate \(notification)")
    }
    
    func setupSignalHandlers() {
        signal(SIGTERM) { signal in
            print("Received signal: \(signal)")
            // Add your custom handling logic here
            exit(15)
        }
        signal(SIGINT) { signal in
            print("Received signal: \(signal)")
            // Add your custom handling logic here
            exit(15)
        }
    }
}
