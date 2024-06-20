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
            AppState.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    /*
     "as your app might get killed on the real device as well without those triggers. IMO, it's a mistake to build code to handle this scenario into the app (more a design mistake)" - stack overflow guy
     grr
     nothing i can do
     */
    
    @State public var text: [AnsiChar] = []
    @State public var command = ""
    @FocusState private var focused: Bool
    @State private var pty: PseudoTerminal? = nil
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
                    // maybe do that somewhere else, but i kinda need it
                    // either pass in the info, or use modifiers

                    return .handled
                })
                .onAppear() {
                    if pty == nil {
                        startTTY()
                    }
                }
//                .alert("Important message", isPresented: $show) {
//                    Button("OK") { }
//                }
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
        // TODO best i can think of
        appDelegate.pty = PseudoTerminal()
        pty = appDelegate.pty
        
        // kill the prev
        do {
            if let state = try sharedModelContainer.mainContext.fetch(FetchDescriptor<AppState>()).first {
                if state.childpty > 0 {
                    _ = pty?.write(command: "kill \(state.childpty)\n")
                }
            }
        } catch {
            
        }
        
        sharedModelContainer.mainContext.insert(AppState(child: pty?.pid ?? 0))
        do {
            try sharedModelContainer.mainContext.save()
        } catch {
            print("failed")
        }
        
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
            text += parse(data, row: (text.last?.y ?? 0), col: (text.last?.x ?? 0))
            (data, n) = pty!.read()
            print("read \(n)")
        }
    }
    
    func parse(_ stdout: Data, row: Int, col: Int) -> [AnsiChar] {
        var isEsc = false
        var isMeta = false
        var parsed: [AnsiChar] = []
        let esc = 0o33
        let bel = 0o7
        var row = row
        var col = col
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
                // do it here to be cleaner and handle new lines
                col += 1
                if stdout[i] == 0xa /* \n */ || stdout[i] == 0xd /* \r */ {
                    col = 0  // carriage return
                    row += 1 // line feed
                             // :P
                }
                
                // read the unicode char
                // TODO can i use less u32
                // TODO can i do cleaner
                var unicode: UInt32 = 0
                if stdout[i] & 0b10000000 == 0 {
                    unicode = UInt32(stdout[i])
                } else if stdout[i] & 0b1110_0000 == 0b1100_0000 {
                    unicode = UInt32(stdout[i] & 0b0001_1111) << 6 | UInt32(stdout[i+1] & 0b0011_1111)
                    i += 1
                } else if stdout[i] & 0b1111_0000 == 0b1110_0000 {
                    unicode = UInt32(stdout[i] & 0b0000_1111) << 12 | UInt32(stdout[i+1] & 0b0011_1111) << 6 | UInt32(stdout[i+2] & 0b0011_1111)
                    i += 2
                } else if stdout[i] & 0b1111_1000 == 0b1111_0000 {
                    unicode = UInt32(stdout[i] & 0b0000_0111) << 18 | UInt32(stdout[i+1] & 0b0011_1111) << 12 | UInt32(stdout[i+2] & 0b0011_1111) << 6 | UInt32(stdout[i+3] & 0b0011_1111)
                    i += 3
                }
                
                curChar.char = Character(UnicodeScalar(unicode)!)
                curChar.x = col
                curChar.y = row
                parsed.append(curChar)
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
