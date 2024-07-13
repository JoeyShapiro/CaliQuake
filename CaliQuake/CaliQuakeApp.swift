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
    
    @State public var grid: TerminalGrid
    @State public var command = ""
    @FocusState private var focused: Bool
    @State private var pty: PseudoTerminal? = nil
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let font = NSFont.monospacedSystemFont(ofSize: 11, weight: NSFont.Weight(rawValue: 0.0))
    @State var size = 500.0
    @State var isDebug = true
    let rows = 24
    let cols = 80
    @State var curChar = AnsiChar(x: 0, y: 0)
    let width: CGFloat
    let height: CGFloat
    let fontWidth: CGFloat
    let fontHeight: CGFloat
    @State private var symbol = "water.waves"
    
    init() {
        self.fontWidth = 7
        self.fontHeight = 14
        self.width = (self.fontWidth * CGFloat(self.cols) )
        self.height = (self.fontHeight * CGFloat(self.rows))
        
        self.grid = TerminalGrid(cols: self.cols, rows: self.rows)
    }
    
    var body: some Scene {
        WindowGroup {
            // TODO best i can do for now
            Button("symbol", systemImage: symbol) {
                symbol = symbol == "water.waves" ? "water.waves.slash" : "water.waves"
//                    .symbolEffect(.bounce.up.byLayer, value: effect)
            }
            ZStack {
                MetalView(grid: $grid, pointSize: self.font.pointSize, debug: $isDebug, rows: self.rows, cols: self.cols)
                    .frame(width: (7 * CGFloat(self.cols) ), height: (14 * CGFloat(self.rows)))
                    .padding(5)
                    .background(Color.black)
//                    .frame(width: (font.pointSize * CGFloat(self.cols) / fontRatio ), height: (font.pointSize * fontHuh * CGFloat(self.rows)))
                    .onAppear() {
                        if pty == nil {
                            startTTY()
                        }
                    }
                // getting the location causes a re-init
                PopView(grid: $grid, pointSize: font.pointSize, debug: $isDebug, width: self.width, height: self.height)
                //                .alert("Important message", isPresented: $show) {
                //                    Button("OK") { }
                //                }
            }
        }
        .modelContainer(sharedModelContainer)
        MenuBarExtra {
                    CaliMenuExtra(grid: $grid)
                        .frame(width: (7 * CGFloat(self.cols) ), height: (14 * CGFloat(self.rows)))
                        .padding(5)
                        .background(Color.black)
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
                            /*
                             16 - command (meta)
                             8  - option
                             4  - control
                             2  - shift
                             1  - caps lock (enabled)
                             */
                            if keyPress.modifiers.contains(.control) && keyPress.characters == "l" {
                                // ?
                                grid.clear()
                                command += "\n"
                                let _ = pty!.write(command: command)
                                command = ""
                                return .handled
                            }
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
        } label: {
            Image(systemName: symbol)
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
            grid.append(data)
            
            do {
                (data, n) = try await pty!.read()
            } catch {
                
            }
            print("read \(n)")
        }
    }
}

extension NSColor {
    static let debugMagenta = NSColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 1.0)
}
