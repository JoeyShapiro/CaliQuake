//
//  CaliQuakeApp.swift
//  CaliQuake
//
//  Created by Joey Shapiro on 6/7/24.
//

import SwiftUI
import SwiftData

@main
struct CaliQuakeApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    @State public var text = ""
    @State public var command = ""
    @FocusState private var focused: Bool
    @State private var pty: PseudoTerminal? = nil

    var body: some Scene {
        WindowGroup {
            MetalView(textBinding: $text)
                .frame(width: 500, height: 500)
                .focusable()
                .focused($focused)
                .focusEffectDisabled()
                .onKeyPress(action: { keyPress in
                    print("""
                        New key event:
                        Key: \(keyPress.characters)
                        Modifiers: \(keyPress.modifiers)
                        Phase: \(keyPress.phase)
                        Debug description: \(keyPress.debugDescription)
                    """)
                    if keyPress.characters == "\r" || keyPress.characters == "\n" {
                        command += "\n"
                        text += keyPress.characters
                    } else if keyPress.characters == "\u{7f}" { // backspace
                        command.removeLast()
                        text.removeLast()
                    } else {
                        command += keyPress.characters
                        text += keyPress.characters
                    }
                    
                    // escape codes
                    // my escapes
                    // ls colors
                    // 
                    // read / write threads
                    // window size
                    // name
                    // write is one char at a time
                    // look at echo on

                    return .handled
                })
                Button("Start Threads") {
                    startThreads()
                }
        }
        .modelContainer(sharedModelContainer)
        MenuBarExtra(
                    "App Menu Bar Extra", systemImage: "water.waves"
                    )
                {
                    CaliMenuExtra()
                }.menuBarExtraStyle(.window)
    }
    
    func startThreads() {
        pty = PseudoTerminal()
        Task {
            await runThread1()
        }
        
//        Task {
//            await runThread2()
//        }
        
//        pty.close()
    }
    
    func runThread1() async {
        text += "Thread 2: \n"
//        command = "python3 -c 'import sys; print(sys.stdout.isatty())'\n"
//        text += command
        var (data, n2) = pty!.read()
        while n2 > 0 {
            if let output = String(data: data, encoding: .utf8) {
                text += output
                if output.contains("$") {
                    break
                }
            }
            (data, n2) = pty!.read()
            print("read \(n2)")
        }
        loop: while true {
            if !command.hasSuffix("\n") {
                continue
            }
            //            text += command
            let n = pty!.write(command: command)
            command = ""
            print("wrote \(n)")
            
            var (data, n2) = pty!.read()
            while n2 > 0 {
                if let output = String(data: data, encoding: .utf8) {
                    text += output
                    if output.contains("$") {
                        break
                    }
                    if output == "exit" {
                        break loop
                    }
                }
                (data, n2) = pty!.read()
                print("read \(n2)")
            }
        }
    }
    
    func runThread2() async {
        await MainActor.run {
            text += "Thread 2: \n"
            var (data, n) = pty!.read()
            print("read \(n)")
            if let output = String(data: data, encoding: .utf8) {
                text += output
            }
            while n > 0 {
                (data, n) = pty!.read()
            }
        }
    }
}
