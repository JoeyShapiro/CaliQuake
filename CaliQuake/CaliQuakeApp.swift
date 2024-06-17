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
        var sequence = Data()
        var curChar = AnsiChar(char: "a", fg: .white, x: col, y: row)
        
        var i = 0
        while i < stdout.count-1 {
            if stdout[i] == esc {
                isEsc = true
                // good enough, until i do real parsing on whole thing
                // esc [ 6 9 7 ;
                //   0 1 2 3 4 5
                i += 1 // "["
                isMeta = stdout[i+1] == 54 /* 6 */ && stdout[i+2] == 57 /* 9 */ && stdout[i+3] == 55 /* 7 */
                if isMeta {
                    i += 3
                }
                i += 1
            }
            
            if !isEsc {
                curChar.char = Character(Unicode.Scalar(stdout[i]))
                curChar.x = col
                curChar.y = row
                parsed.append(curChar)
                col += 1
                if stdout[i] == 0xa /* \n */ {
                    row += 1 // carriage return
                    col = 0  // line feed
                             // :P
                }
            } else {
                sequence.append(stdout[i])
            }
            
            // its doing the auto complete, so i have to handle escapes now
            
            // shrug
            if isMeta && stdout[i] == bel {
                isEsc = false
                isMeta = false
                sequence.removeAll()
            }
            if isEsc && !isMeta && (stdout[i] == 109 /* m */ || stdout[i] == 104 /* h */) {
                // parse sequence now
                if sequence.removeLast() == 109 {
                    let numbers = sequence.split(separator: 59 /* ; */)
                    for number in numbers {
                        if let str = Int(String(data: number, encoding: .utf8) ?? "-1") {
                            print("new color:", str)
                            switch str {
                            case -1:
                                print("bad")
                            case 30:
                                curChar.fg = .black
                            case 31:
                                curChar.fg = .red
                            case 32:
                                curChar.fg = .green
                            case 33:
                                curChar.fg = .yellow
                            case 34:
                                curChar.fg = .blue
                            case 35:
                                curChar.fg = .magenta
                            case 36:
                                curChar.fg = .cyan
                            case 37:
                                curChar.fg = .white
                            case 39:
                                curChar.fg = .white
                            default: // 0
                                curChar.fg = .white
                            }
                        }
                    }
                }
                isEsc = false
                sequence.removeAll()
            }
            
            i+=1
        }
        
        return parsed
    }
}
