import Cocoa
import MetalKit
import CoreImage.CIFilterBuiltins

import SwiftUI
import MetalKit
import AppKit
import Metal

struct Vertex {
    var position: vector_float4
    var texCoord: vector_float2
}

struct MetalView: NSViewRepresentable {

    static private let pixelFormat = MTLPixelFormat.bgra8Unorm_srgb
    static private let clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

    class Coordinator: NSObject, MTKViewDelegate {

        var device: MTLDevice

        private var commandQueue: MTLCommandQueue
        private var pipelineState: MTLRenderPipelineState
        private var vertexBuffer: MTLBuffer
        var texture: MTLTexture!
        var ciContext: CIContext!


        override init() {

            device = MTLCreateSystemDefaultDevice()!

            let library = device.makeDefaultLibrary()!
            let descriptor = MTLRenderPipelineDescriptor()
            let vertices = [
                Vertex(position: [-1.0,  1.0, 0.0, 1.0], texCoord: [0.0, 1.0]),
                Vertex(position: [-1.0, -1.0, 0.0, 1.0], texCoord: [0.0, 0.0]),
                Vertex(position: [ 1.0, -1.0, 0.0, 1.0], texCoord: [1.0, 0.0]),
                Vertex(position: [-1.0,  1.0, 0.0, 1.0], texCoord: [0.0, 1.0]),
                Vertex(position: [ 1.0, -1.0, 0.0, 1.0], texCoord: [1.0, 0.0]),
                Vertex(position: [ 1.0,  1.0, 0.0, 1.0], texCoord: [1.0, 1.0])
            ]
            vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.size, options: [])!


            descriptor.label = "Pixel Shader"
            descriptor.vertexFunction = library.makeFunction(name: "vertex_main")
            descriptor.fragmentFunction = library.makeFunction(name: "fragment_main")
            descriptor.colorAttachments[0].pixelFormat = MetalView.pixelFormat

            // Set up the vertex descriptor
            let vertexDescriptor = MTLVertexDescriptor()
            vertexDescriptor.attributes[0].format = .float4
            vertexDescriptor.attributes[0].offset = 0
            vertexDescriptor.attributes[0].bufferIndex = 0

            vertexDescriptor.attributes[1].format = .float2
            vertexDescriptor.attributes[1].offset = MemoryLayout<vector_float4>.size
            vertexDescriptor.attributes[1].bufferIndex = 0

            vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
            vertexDescriptor.layouts[0].stepRate = 1
            vertexDescriptor.layouts[0].stepFunction = .perVertex

            descriptor.vertexDescriptor = vertexDescriptor

            commandQueue = device.makeCommandQueue()!
            pipelineState = try! device.makeRenderPipelineState(descriptor: descriptor)

            super.init()
            
            ciContext = CIContext(mtlDevice: device)
            texture = createTexture(from: createFilteredImage())
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }

        func draw(in view: MTKView) {

            let buffer = commandQueue.makeCommandBuffer()!
            let descriptor = view.currentRenderPassDescriptor!
            let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor)!
            

            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBuffer(self.vertexBuffer, offset: 0, index: 0)
            encoder.setFragmentTexture(texture, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()

            buffer.present(view.currentDrawable!)
            buffer.commit()
        }
        
        private func createFilteredImage() -> CIImage {
            // Create a simple CIFilter (e.g., a sepia tone filter)
            let textImageGenerator = CIFilter.textImageGenerator()
            textImageGenerator.text = "Hello World!"
            // ...
            return textImageGenerator.outputImage!
        }

        private func createTexture(from image: CIImage) -> MTLTexture? {
            let width = Int(image.extent.width)
            let height = Int(image.extent.height)
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
            textureDescriptor.usage = [.shaderRead, .shaderWrite]
            guard let texture = device.makeTexture(descriptor: textureDescriptor) else { return nil }

            ciContext.render(image, to: texture, commandBuffer: nil, bounds: image.extent, colorSpace: CGColorSpaceCreateDeviceRGB())
            return texture
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
