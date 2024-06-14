import Metal
import MetalKit
import CoreGraphics

struct Vertex {
    var position: vector_float4
    var texCoord: vector_float2
}

class Renderer: NSObject {
    var device: MTLDevice!
    var pipelineState: MTLRenderPipelineState!
    var commandQueue: MTLCommandQueue!
    var vertexBuffer: MTLBuffer!
    var texture: MTLTexture!

    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()

        let defaultLibrary = device.makeDefaultLibrary()
        let vertexFunction = defaultLibrary?.makeFunction(name: "vertex_main")
        let fragmentFunction = defaultLibrary?.makeFunction(name: "fragment_main")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

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

        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        self.pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)

        // Quad vertices with positions and texture coordinates
        let vertices = [
            Vertex(position: [-1.0,  1.0, 0.0, 1.0], texCoord: [0.0, 1.0]),
            Vertex(position: [-1.0, -1.0, 0.0, 1.0], texCoord: [0.0, 0.0]),
            Vertex(position: [ 1.0, -1.0, 0.0, 1.0], texCoord: [1.0, 0.0]),
            Vertex(position: [-1.0,  1.0, 0.0, 1.0], texCoord: [0.0, 1.0]),
            Vertex(position: [ 1.0, -1.0, 0.0, 1.0], texCoord: [1.0, 0.0]),
            Vertex(position: [ 1.0,  1.0, 0.0, 1.0], texCoord: [1.0, 1.0])
        ]

        self.vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.size, options: [])

        super.init()
        
        self.texture = createTextTexture(text: "Hello, Metal!", font: NSFont.systemFont(ofSize: 12), size: CGSize(width: 512, height: 512))
    }

    func drawableSizeWillChange(size: CGSize) {
        // Handle size change if necessary
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor else { return }

        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        if let textTexture = createTextTexture(text: "Hello, Metal!", font: NSFont.systemFont(ofSize: 12), size: CGSize(width: 128, height: 128)) {
            renderEncoder.setFragmentTexture(textTexture, index: 0)
        }
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func createTextTexture(text: String, font: NSFont, size: CGSize) -> MTLTexture? {
        // Create a bitmap context
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        let width = Int(size.width * scale)
        let height = Int(size.height * scale)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 4 * width, space: colorSpace, bitmapInfo: bitmapInfo) else { return nil }
        
        context.scaleBy(x: scale, y: scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        
        // Draw the text
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor.white
        ]
        let rect = CGRect(origin: .zero, size: size)
        text.draw(in: rect, withAttributes: attributes)
        
        NSGraphicsContext.restoreGraphicsState()
        
        // Create a texture from the bitmap context
        guard let image = context.makeImage() else { return nil }
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else { return nil }

        let region = MTLRegionMake2D(0, 0, width, height)
        let bytesPerRow = 4 * width
        let data = context.data!
        texture.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: bytesPerRow)
        
        return createTexture(from: image)
    }
    
    private func createTexture(from image: CGImage) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: image.width, height: image.height, mipmapped: false)
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            fatalError("Failed to create texture")
        }
        
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * image.width
        let imageData = UnsafeMutableRawPointer.allocate(byteCount: bytesPerRow * image.height, alignment: 1)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(data: imageData, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
            fatalError("Failed to create CGContext")
        }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        
        let region = MTLRegionMake2D(0, 0, image.width, image.height)
        texture.replace(region: region, mipmapLevel: 0, withBytes: imageData, bytesPerRow: bytesPerRow)
        
        imageData.deallocate()
        
        return texture
    }

}
