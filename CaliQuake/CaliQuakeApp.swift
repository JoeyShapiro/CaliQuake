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
    
    @State public var input = "$ "
    @FocusState private var focused: Bool
    @State private var pty: PseudoTerminal? = nil

    var body: some Scene {
        WindowGroup {
            MetalView(textBinding: $input)
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
                    input += keyPress.characters
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
        
        Task {
            await runThread2()
        }
        
//        pty.close()
    }
    
    func runThread1() async {
        await MainActor.run {
            input += "echo hello\n"
            let n = pty!.write(command: "echo hello\n")
            print("wrote \(n)")
            
        }
    }
    
    func runThread2() async {
        await MainActor.run {
            input += "Thread 2: \n"
            var (data, n) = pty!.read()
            print("read \(n)")
            if let output = String(data: data, encoding: .utf8) {
                input += output
            }
            while n > 0 {
                (data, n) = pty!.read()
            }
        }
    }
}
