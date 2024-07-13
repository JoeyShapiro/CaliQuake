//
//  MetalView.swift
//  CaliQuake
//
//  Created by Joey Shapiro on 6/13/24.
//

import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {
    @Binding public var grid: TerminalGrid
    private var coordinator: Coordinator
    @Binding public var debug: Bool
    
    class Coordinator: NSObject, MTKViewDelegate {
        var renderer: Renderer
        
        init(device: MTLDevice, pointSize: CGFloat, debug: Bool, rows: Int, cols: Int) {
            self.renderer = Renderer(device: device, pointSize: pointSize, debug: debug, cols: cols, rows: rows)
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer.drawableSizeWillChange(size: size)
        }
        
        func draw(in view: MTKView) {
            renderer.draw(in: view)
        }
        
        func update(grid: TerminalGrid, debug: Bool) {
            // good idea to add debug, they both need to be updated together anyway
            renderer.update(grid: grid, debug: debug)
        }
    }
    
    init(grid: Binding<TerminalGrid>, pointSize: CGFloat, debug: Binding<Bool>, rows: Int, cols: Int) {
        let device = MTLCreateSystemDefaultDevice()!
        self._grid = grid
        self._debug = debug
        
        self.coordinator = Coordinator(device: device, pointSize: pointSize, debug: false, rows: rows, cols: cols)
    }

    func makeCoordinator() -> Coordinator {
        return self.coordinator
    }
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.preferredFramesPerSecond = 30
        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        // Handle updates if necessary
        self.coordinator.update(grid: self.grid, debug: self.debug)
        self.grid.update(debug: self.debug)
    }
}

