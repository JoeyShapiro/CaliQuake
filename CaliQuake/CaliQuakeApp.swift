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
    @State var pty: PsuedoTerminal

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
        pty = PsuedoTerminal()
        Task {
            await MainActor.run {
                pty.write(command: "echo hello")
            }
        }
        
        Task {
            await MainActor.run {
                pty.read()
            }
        }
        
//        pty.close()
    }
    
    func runThread1() async {
        for i in 1...5 {
            await MainActor.run {
                input += "Thread 1: \(i)\n"
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
    
    func runThread2() async {
        for i in 1...5 {
            await MainActor.run {
                input += "Thread 2: \(i)\n"
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
}
