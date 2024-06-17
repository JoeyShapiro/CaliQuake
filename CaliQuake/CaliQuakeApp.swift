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
    
    @State public var text: [AnsiChar] = []
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
                    //
                    // name
                    // ps info
                    // rows
                    // colors

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
            text += parse(data)
            (data, n) = pty!.read()
            print("read \(n)")
        }
    }
    
    func parse(_ stdout: Data) -> [AnsiChar] {
        var isEsc = false
        var isMeta = false
        var parsed: [AnsiChar] = []
        let esc = 0o33
        let bel = 0o7
        var row = 0
        var col = 0
        var curColor = NSColor.white
        
        for i in (0...stdout.count-1) {
            if stdout[i] == esc {
                isEsc = true
                // good enough, until i do real parsing on whole thing
                // esc [ 6 9 7 ;
                //   0 1 2 3 4 5
                isMeta = stdout[i+2] == 54 /* 6 */ &&
                    stdout[i+3] == 57 /* 9 */ &&
                    stdout[i+4] == 55 /* 7 */
            }
            
            if !isEsc {
                parsed.append(AnsiChar(char: Character(Unicode.Scalar(stdout[i])), fg: curColor, x: col, y: row))
                col += 1
                if stdout[i] == 0xa /* \n */ {
                    row += 1 // carriage return
                    col = 0  // line feed
                             // :P
                }
            }
            
            // its doing the auto complete, so i have to handle escapes now
            
            // shrug
            if isMeta && stdout[i] == bel {
                isEsc = false
                isMeta = false
            }
            if isEsc && !isMeta && (stdout[i] == 109 /* m */ || stdout[i] == 104 /* h */) {
                isEsc = false
            }
        }
        
        return parsed
    }
}
