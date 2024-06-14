//
//  MetalView.swift
//  CaliQuake
//
//  Created by Joey Shapiro on 6/13/24.
//

import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {
    @Binding public var text: String
    private var coordinator: Coordinator
    
    class Coordinator: NSObject, MTKViewDelegate {
        var renderer: Renderer
        
        init(device: MTLDevice) {
            self.renderer = Renderer(device: device)
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer.drawableSizeWillChange(size: size)
        }
        
        func draw(in view: MTKView) {
            renderer.draw(in: view)
        }
        
        func update(text: String) {
            renderer.update(text: text)
        }
    }
    
    init(textBinding: Binding<String>) {
        let device = MTLCreateSystemDefaultDevice()!
        self.coordinator = Coordinator(device: device)
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

