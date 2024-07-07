//
//  CaliQuakeApp.swift
//  CaliQuake
//
//  Created by Joey Shapiro on 6/7/24.
//

import SwiftUI
import SwiftData
import AVFoundation

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
//    let fontRatio: CGFloat = 5/3
//    let fontHuh: CGFloat = 1.1
    let font = NSFont.monospacedSystemFont(ofSize: 11, weight: NSFont.Weight(rawValue: 0.0))
    @State var size = 500.0
    @State var isDebug = true
    let rows = 24
    let cols = 80
    @State var curChar = AnsiChar(x: 0, y: 0)
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                MetalView(textBinding: $text, curChar: $curChar, font: font, debug: $isDebug, rows: self.rows, cols: self.cols)
                    .frame(width: (7 * CGFloat(self.cols) ), height: (14 * CGFloat(self.rows)))
                    .padding(5)
                    .background(Color.black)
//                    .frame(width: (font.pointSize * CGFloat(self.cols) / fontRatio ), height: (font.pointSize * fontHuh * CGFloat(self.rows)))
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
                        if keyPress.modifiers.rawValue == 16 && keyPress.characters == "i" {
                            isDebug.toggle()
                            return .handled
                        }
                        
                        if keyPress.characters == "\r" || keyPress.characters == "\n" {
                            command += "\n"
                            // best i can think of
//                            text += parse("\n".data(using: .utf8)!, prev: text.last)
                            //                        text += keyPress.characters
                        } else if keyPress.characters == "\u{7f}" { // backspace
                            //                        command.removeLast()
                            command += keyPress.characters
                            //                        text.removeLast()
                        } else {
                            command += keyPress.characters
                            //                        text += keyPress.characters // the keys are duping or somthing
                        }
                        
                        // i think this makes more sense
                        // i know when to write
                        // unless its something special, but i can still handle that
                        if !command.isEmpty {
                            let n = pty!.write(command: command)
                            command = ""
                            print("wrote \(n)")
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
                // getting the location causes a re-init
                PopView(text: $text, pointSize: font.pointSize, debug: $isDebug, rows: self.rows, cols: self.cols)
                //                .alert("Important message", isPresented: $show) {
                //                    Button("OK") { }
                //                }
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
        // TODO best i can think of
        appDelegate.pty = PseudoTerminal(rows: self.rows, cols: self.cols)
        pty = appDelegate.pty
        
        // kill the prev
//        do {
//            if let state = try sharedModelContainer.mainContext.fetch(FetchDescriptor<AppState>()).first {
//                if state.childpty > 0 {
//                    _ = pty?.write(command: "kill \(state.childpty)\n")
//                }
//            }
//        } catch {
//            
//        }
        
        sharedModelContainer.mainContext.insert(AppState(child: pty?.pid ?? 0))
        do {
            try sharedModelContainer.mainContext.save()
        } catch {
            print("failed")
        }
        
        Task{
            await keepReading()
        }
    }
    
    func keepReading() async {
        var n = 0
        var data = Data()
        do {
            (data, n) = try await pty!.read()
        } catch {
            
        }
        while n > 0 {
            text += parse(data, prev: text.last)
            text = format(text)
            do {
                (data, n) = try await pty!.read()
            } catch {
                
            }
            print("read \(n)")
        }
    }
    
    func format(_ text: [AnsiChar]) -> [AnsiChar] {
        var formatted: [AnsiChar] = []
        for ac in text {
            if ac.char.asciiValue == 0x8 /* BS */ {
                let _ = formatted.popLast()
            } else {
                formatted.append(ac)
            }
        }
        
        return formatted
    }
    
    // using all of prev char could be useful
    func parse(_ stdout: Data, prev: AnsiChar?) -> [AnsiChar] {
        //y: (text.last?.y ?? 0), x: (text.last?.x ?? 0)
        //prev ?? AnsiChar(x: 0, y: 0)
        var isEsc = false
        var isMeta = false
        var parsed: [AnsiChar] = []
        let esc = 0o33
        let bel = 0o7
        var row = curChar.y
        var col = curChar.x
        var sequence = Data()
        // TODO need terminal state
        var keypadMode = ""
        var csi = false // [
        var osc = false // ]
        var privates: [Int: Bool] = [:]
        
        var i = 0
        while i < stdout.count {
            if stdout[i] == esc {
                // reset sequence, just in case
                if !sequence.isEmpty {
                    print("leftover sequence:", sequence)
                    sequence.removeAll()
                }
                isEsc = true
                // good enough, until i do real parsing on whole thing
                // esc [ 6 9 7 ;
                //   0 1 2 3 4 5
                i += 1 // "["
                
                switch stdout[i] {
                case 91: /* [ */
                    csi = true
                case 93: /* ] */
                    osc = true
                default:
                    csi = false
                    osc = false
                }
                
                // string terminator
                if stdout[i] == 92 /* \ */ {
                    isEsc = false
                    csi = false
                    osc = false
                    i += 1
                    continue
                } else if stdout[i] == 62 /* > */ {
                    keypadMode = "app"
                    isEsc = false
                    csi = false
                    osc = false
                    i += 1
                    continue
                } else if stdout[i] == 61 /* = */ {
                    keypadMode = "num"
                    isEsc = false
                    csi = false
                    osc = false
                    i += 1
                    continue
                }
                
                if i+3 < stdout.count {
                    isMeta = stdout[i+1] == 54 /* 6 */ && stdout[i+2] == 57 /* 9 */ && stdout[i+3] == 55 /* 7 */
                }
                if isMeta {
                    i += 3
                }
                i += 1
            }
            
            if !isEsc {
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
                
                
                
                // do action after placing it
                if stdout[i] == 0xd /* \r */ {
                    col = 0
                    row += 1
                    
                    // ¯\_(ツ)_/¯
                    if i+1 < stdout.count && stdout[i+1] == 0xa /* \n */ {
                        i += 1
                    }
                    curChar.width = 0
                } else if stdout[i] == 0xa /* \n */ {
                    col = 0
                    row += 1
                    curChar.width = 0
                } else if stdout[i] == 0x8 /* BS */ {
                    let last = text.last(where: { $0.width > 0 })
                    col -= last?.width ?? 0
                    curChar.width = 0
                } else if stdout[i] == bel {
                    curChar.width = 0
//                    NSSound(named: "Beep")!.play()
                    NSSound.beep()
                } else {
                    curChar.width = 1
                }
                
                curChar.char = Character(UnicodeScalar(unicode)!)
                curChar.x = col
                curChar.y = row
                
                parsed.append(curChar)
                
                col += curChar.width
                curChar.x = col
                
                // handle window size
                if col > self.cols {
                    col = 0
                    row += 1
                }
            } else {
                sequence.append(stdout[i])
            }
            
            // its doing the auto complete, so i have to handle escapes now
            
            // shrug
            if (isMeta || osc) && stdout[i] == bel {
                isEsc = false
                isMeta = false
                csi = false
                osc = false
                sequence.removeAll()
            }
            
            /// cursor movement
            if isEsc && !isMeta && csi && (stdout[i] >= 65 /* A */ && stdout[i] <= 71 /* G */ ) {
                switch sequence.removeLast() {
                case 68: /* D */
                    if let d = Int(String(data: sequence, encoding: .utf8) ?? "0") {
                        curChar.x -= d
                        // clip it
//                        curChar.x = max(curChar.x, 0)
                    }
                case 67: /* C */
                    if let d = Int(String(data: sequence, encoding: .utf8) ?? "0") {
                        curChar.x += d
                        // clip it
//                        curChar.x = min(curChar.x, self.rows)
                    }
                default:
                    print("shrug", Unicode.Scalar(stdout[i]))
                }
                sequence.removeAll()
            } else if isEsc && !isMeta && csi && (stdout[i] == 109 /* m */ || stdout[i] == 104 /* h */) {
                // parse sequence now
                if sequence.removeLast() == 109 {
                    let numbers = sequence.split(separator: 59 /* ; */)
                    for number in numbers {
                        if let str = Int(String(data: number, encoding: .utf8) ?? "-1") {
                            switch str {
                            case -1:
                                print("bad")
                            case 0: // default
                                curChar.fg = .white
                                curChar.bg = .clear
                                curChar.font = .regular
                            case 1:
                                curChar.font = .bold
                            case 7: // TODO not sure if correct way, but makes sense
                                curChar.invert = true
                            case 27:
                                curChar.invert = false
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
                            case 40:
                                curChar.bg = .black
                            case 41:
                                curChar.bg = .red
                            case 42:
                                curChar.bg = .green
                            case 43:
                                curChar.bg = .yellow
                            case 44:
                                curChar.bg = .blue
                            case 45:
                                curChar.bg = .magenta
                            case 46:
                                curChar.bg = .cyan
                            case 47:
                                curChar.bg = .white
                            case 49:
                                curChar.bg = .clear
                            default:
                                curChar.fg = .debugMagenta
                            }
                        }
                    }
                }
                isEsc = false
                csi = false
                sequence.removeAll()
            } else if isEsc && !isMeta && csi && stdout[i] == 63 /* ? */ {
                i += 1 // "?"
                var number = Data()
                // get the number
                while stdout[i] >= 48 && stdout[i] <= 57 {
                    number.append(stdout[i])
                    i += 1
                }
                // read what is there
                if let n = Int(String(data: number, encoding: .utf8)!) {
                    switch stdout[i] {
                    case 108: /* l */
                        // reset or disable
                        privates.removeValue(forKey: n)
                    default:
                        print("unknown code:", Unicode.Scalar(stdout[i]), n)
                    }
                }
                
                isEsc = false
                csi = false
                sequence.removeAll()
            }
            
            i+=1
        }
        
        return parsed
    }
}

extension NSColor {
    static let debugMagenta = NSColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 1.0)
}
