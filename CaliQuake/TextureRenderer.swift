import Cocoa
import MetalKit
import CoreImage.CIFilterBuiltins

import SwiftUI
import MetalKit
import AppKit

struct MetalView: NSViewRepresentable {

    static private let pixelFormat = MTLPixelFormat.bgra8Unorm_srgb
    static private let clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

    class Coordinator: NSObject, MTKViewDelegate {

        var device: MTLDevice

        private var commandQueue: MTLCommandQueue
        private var pipelineState: MTLRenderPipelineState
        private var vertexBuffer: MTLBuffer

        override init() {

            device = MTLCreateSystemDefaultDevice()!

            let library = device.makeDefaultLibrary()!
            let descriptor = MTLRenderPipelineDescriptor()
            let vertices: [simd_float2] = [[-1, +1],  [+1, +1],  [-1, -1],  [+1, -1]]
            let verticesLength = 4 * MemoryLayout<simd_float2>.stride

            descriptor.label = "Pixel Shader"
            descriptor.vertexFunction = library.makeFunction(name: "init")
            descriptor.fragmentFunction = library.makeFunction(name: "draw")
            descriptor.colorAttachments[0].pixelFormat = MetalView.pixelFormat

            commandQueue = device.makeCommandQueue()!
            pipelineState = try! device.makeRenderPipelineState(descriptor: descriptor)
            vertexBuffer = device.makeBuffer(bytes: vertices, length: verticesLength, options: [])!

            super.init()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }

        func draw(in view: MTKView) {

            let buffer = commandQueue.makeCommandBuffer()!
            let descriptor = view.currentRenderPassDescriptor!
            let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor)!

            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBuffer(self.vertexBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()

            buffer.present(view.currentDrawable!)
            buffer.commit()
        }
    }

    // finish by defining the three methods that are required by `NSViewRepresentable` conformance...

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: NSViewRepresentableContext<MetalView>) -> MTKView {

        let view = MTKView()

        view.delegate = context.coordinator
        view.device = context.coordinator.device
        view.colorPixelFormat = MetalView.pixelFormat
        view.clearColor = MetalView.clearColor
        view.drawableSize = view.frame.size
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.needsDisplay = true
        view.isPaused = false

        return view
    }

    func updateNSView(_ nsView: MTKView, context: NSViewRepresentableContext<MetalView>) { }
}

struct MetalController: NSViewControllerRepresentable {
    func makeNSViewController(context: Context) -> ViewController {
        let viewController = ViewController()
//        viewController.view = NSView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        return viewController
    }

    func updateNSViewController(_ nsView: ViewController, context: Context) {
        // No need to update the view in this example
    }
    
}

class ViewController: NSViewController {
    private let Device = MTLCreateSystemDefaultDevice()!
    private var CommandQue: MTLCommandQueue!, Pipeline: MTLRenderPipelineState!
    private var View: MTKView {
        return view as! MTKView
    }
    private var ciContext: CIContext!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print(type(of: view))
        View.delegate = self
        View.device = Device
        CommandQue = Device.makeCommandQueue()
        let PipelineDescriptor = MTLRenderPipelineDescriptor()
        let Library = Device.makeDefaultLibrary()!
        PipelineDescriptor.vertexFunction = Library.makeFunction(name: "V")
        PipelineDescriptor.fragmentFunction = Library.makeFunction(name: "T")
        Pipeline = try? Device.makeRenderPipelineState(descriptor: PipelineDescriptor)
        ciContext = CIContext()
    }
}
extension ViewController: MTKViewDelegate {
    func mtkView(_ _: MTKView, drawableSizeWillChange Size: CGSize) {
        View.draw()
    }
    func draw(in _: MTKView) {
        let CommandBuffer = CommandQue.makeCommandBuffer()!, CommandEncoder = CommandBuffer.makeRenderCommandEncoder(descriptor: View.currentRenderPassDescriptor!)!
        CommandEncoder.setRenderPipelineState(Pipeline!)
        
        // Render
        let textImageGenerator = CIFilter.textImageGenerator()
        textImageGenerator.text = "Hello World!"
        // ...
        let textImage = textImageGenerator.outputImage!
        // Note: create the CIContext once and re-use it
        ciContext.render(textImage, to: View.currentDrawable! as! MTLTexture, commandBuffer: CommandBuffer, bounds: textImage.extent, colorSpace: CGColorSpaceCreateDeviceRGB())
        
        CommandEncoder.endEncoding()
        CommandBuffer.present(View.currentDrawable!)
        CommandBuffer.commit()
    }
}
