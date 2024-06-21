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
    
    class Coordinator: NSObject, MTKViewDelegate {
        var renderer: Renderer
        
        init(device: MTLDevice, font: NSFont) {
            self.renderer = Renderer(device: device, font: font)
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer.drawableSizeWillChange(size: size)
        }
        
        func draw(in view: MTKView) {
            renderer.draw(in: view)
        }
        
        func update(text: [AnsiChar]) {
            renderer.update(text: text)
        }
    }
    
    init(textBinding: Binding<[AnsiChar]>, font: NSFont) {
        let device = MTLCreateSystemDefaultDevice()!
        self.coordinator = Coordinator(device: device, font: font)
        self._text = textBinding
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
        self.coordinator.update(text: self.text)
    }
}

