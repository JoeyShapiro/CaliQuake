//
//  AppDelegate.swift
//  CaliQuake
//
//  Created by Joey Shapiro on 6/19/24.
//

import Foundation
import AppKit
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    var pty: PseudoTerminal?
    var statusItem: NSStatusItem?
    
    override init() {
        super.init()
        setupSignalHandlers()
        HotkeySolution.register(self)
    }
    
    func openMenu() {
        statusItem?.button?.performClick(nil)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        self.statusItem = NSApp.windows.first(where: { $0.title == "Item-0" })!.value(forKey: "statusItem") as? NSStatusItem
//        print(NSApp.windows.first(where: { $0.title }))
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("hello from delegate \(notification)")
        self.pty?.close()
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

extension String {
    /// This converts string to UInt as a fourCharCode
    public var fourCharCodeValue: Int {
        var result: Int = 0
        if let data = self.data(using: String.Encoding.macOSRoman) {
            data.withUnsafeBytes({ (rawBytes) in
                let bytes = rawBytes.bindMemory(to: UInt8.self)
                for i in 0 ..< data.count {
                    result = result << 8 + Int(bytes[i])
                }
            })
        }
        return result
    }
}

class HotkeySolution {
    static func register(_ appDelegate: AppDelegate) {
        var hotKeyRef: EventHotKeyRef?
        let modifierFlags = UInt32(cmdKey|shiftKey)
        
        let keyCode = kVK_Space
        var gMyHotKeyID = EventHotKeyID()
        
        gMyHotKeyID.id = UInt32(keyCode)
        
        // Not sure what "swat" vs "htk1" do.
        gMyHotKeyID.signature = OSType("swat".fourCharCodeValue)
        // gMyHotKeyID.signature = OSType("htk1".fourCharCodeValue)
        
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyReleased)
        
        // Install handler.
        InstallEventHandler(GetApplicationEventTarget(), {
            (nextHanlder, theEvent, userData) -> OSStatus in
            let passed = Unmanaged<AppDelegate>.fromOpaque(userData!).takeUnretainedValue()
            // var hkCom = EventHotKeyID()
            
            // GetEventParameter(theEvent,
            //                   EventParamName(kEventParamDirectObject),
            //                   EventParamType(typeEventHotKeyID),
            //                   nil,
            //                   MemoryLayout<EventHotKeyID>.size,
            //                   nil,
            //                   &hkCom)
            passed.openMenu()
            
            return noErr
            /// Check that hkCom in indeed your hotkey ID and handle it.
        }, 1, &eventType, Unmanaged.passUnretained(appDelegate).toOpaque(), nil)
        
        // Register hotkey.
        let status = RegisterEventHotKey(UInt32(keyCode),
                                         modifierFlags,
                                         gMyHotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &hotKeyRef)
        assert(status == noErr)
    }
}

