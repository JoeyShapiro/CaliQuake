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
    private var coordinator: Coordinator
    @Binding public var debug: Bool
    
    class Coordinator: NSObject, MTKViewDelegate {
        var renderer: Renderer
        
        init(device: MTLDevice, font: NSFont, debug: Bool) {
            self.renderer = Renderer(device: device, font: font, debug: debug)
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer.drawableSizeWillChange(size: size)
        }
        
        func draw(in view: MTKView) {
            renderer.draw(in: view)
        }
        
        func update(text: [AnsiChar], debug: Bool) {
            // good idea to add debug, they both need to be updated together anyway
            renderer.update(text: text, debug: debug)
        }
    }
    
    init(textBinding: Binding<[AnsiChar]>, font: NSFont, debug: Binding<Bool>) {
        let device = MTLCreateSystemDefaultDevice()!
        self._text = textBinding
        self._debug = debug
        
        self.coordinator = Coordinator(device: device, font: font, debug: false)
    }

    func makeCoordinator() -> Coordinator {
        return self.coordinator
    }
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.colorPixelFormat = .bgra8Unorm
        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        // Handle updates if necessary
        self.coordinator.update(text: self.text, debug: self.debug)
    }
}

