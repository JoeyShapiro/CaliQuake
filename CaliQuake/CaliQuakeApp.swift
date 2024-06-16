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
//                        text += keyPress.characters
                    } else if keyPress.characters == "\u{7f}" { // backspace
//                        command.removeLast()
                        command += keyPress.characters
//                        text.removeLast()
                    } else {
                        command += keyPress.characters
//                        text += keyPress.characters // the keys are duping or somthing
                    }
                    
                    // escape codes
                    // ls colors
                    //
                    // name

                    return .handled
                })
                .onAppear() {
                    if pty == nil {
                        startTTY()
                    }
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
    
    func startTTY() {
        pty = PseudoTerminal()
        Task {
            await keepWriting()
        }
        
        Task {
            await keepReading()
        }
        
//        Task {
//            await runThread2()
//        }
        
//        pty.close()
    }
    
    func keepWriting() async {
        var n = pty!.write(command: command)
        while n >= 0 {
            if command.isEmpty {
                continue
            }
            
            n = pty!.write(command: command)
            command = ""
            print("wrote \(n)")
        }
    }
    
    func keepReading() async {
        var (data, n) = pty!.read()
        while n > 0 {
            if let output = String(data: data, encoding: .utf8) {
                text += parse(output)
            }
            (data, n) = pty!.read()
            print("read \(n)")
        }
    }
    
    func parse(_ stdout: String) -> String {
        var isEscaped = false
        var parsed = ""
        let esc = Character(Unicode.Scalar(0o33))
        let bel = Character(Unicode.Scalar(0o7))
        
        for c in stdout {
            if c == esc {
                isEscaped = true
            }
            
            if !isEscaped {
                parsed.append(c)
            }
            
            // its doing the auto complete, so i have to handle escapes now
            
            // shrug
            if isEscaped && (c == bel || c == "m") {
                isEscaped = false
            }
        }
        
        return parsed
    }
}
