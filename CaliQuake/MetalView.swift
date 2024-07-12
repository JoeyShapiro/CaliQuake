//
//  MetalView.swift
//  CaliQuake
//
//  Created by Joey Shapiro on 6/13/24.
//

import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {
    @Binding public var text: [AnsiChar]
    @Binding public var curChar: AnsiChar
    private var coordinator: Coordinator
    @Binding public var debug: Bool
    
    class Coordinator: NSObject, MTKViewDelegate {
        var renderer: Renderer
        
        init(device: MTLDevice, font: NSFont, debug: Bool, rows: Int, cols: Int) {
            self.renderer = Renderer(device: device, font: font, debug: debug, cols: cols, rows: rows)
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer.drawableSizeWillChange(size: size)
        }
        
        func draw(in view: MTKView) {
            renderer.draw(in: view)
        }
        
        func update(text: [AnsiChar], curChar: AnsiChar, debug: Bool) {
            // good idea to add debug, they both need to be updated together anyway
            renderer.update(text: text, curChar: curChar, debug: debug)
        }
    }
    
    init(textBinding: Binding<[AnsiChar]>, curChar: Binding<AnsiChar>, font: NSFont, debug: Binding<Bool>, rows: Int, cols: Int) {
        let device = MTLCreateSystemDefaultDevice()!
        self._text = textBinding
        self._curChar = curChar
        self._debug = debug
        
        self.coordinator = Coordinator(device: device, font: font, debug: false, rows: rows, cols: cols)
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
        self.coordinator.update(text: self.text, curChar: self.curChar, debug: self.debug)
    }
}

