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
    var text = "$ "

    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()

        let defaultLibrary = device.makeDefaultLibrary()
        
        let fragmentProgram = defaultLibrary?.makeFunction(name: "fragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = defaultLibrary?.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = fragmentProgram
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        self.pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)

        super.init()
    }

    func drawableSizeWillChange(size: CGSize) {
        // Handle size change if necessary
    }

    func draw(in view: MTKView) {
        // i changed the dimensions, removed verts, use tex coords, and changed the ordering
        guard let imageData = convertCGImageToData(makeImage(text: self.text, font: NSFont.monospacedSystemFont(ofSize: 12, weight: NSFont.Weight(rawValue: 0.1)), size: CGSize(width: 512, height: 512))!) else {
            fatalError("Could not load image file.")
        }
        
        let textureLoader = MTKTextureLoader(device: view.device!)
        
        let texture = try? textureLoader.newTexture(data: imageData, options: nil)
        
        guard let commandBuffer = view.device?.makeCommandQueue()?.makeCommandBuffer(),
              let descriptor = view.currentRenderPassDescriptor,
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        
        encoder.setRenderPipelineState(pipelineState!)
        encoder.setFragmentTexture(texture, index: 0)
        
        let vertices: [Float] = [
            -1.0, -1.0,
             1.0, -1.0,
             -1.0,  1.0,
             1.0,  1.0
        ]
        let vertexBuffer = view.device?.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: [])
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        let texCoords: [Float] = [
            0.0, 1.0,
            1.0, 1.0,
            0.0, 0.0,
            1.0, 0.0
        ]
        let texCoordBuffer = view.device?.makeBuffer(bytes: texCoords, length: texCoords.count * MemoryLayout<Float>.size, options: [])
        encoder.setVertexBuffer(texCoordBuffer, offset: 0, index: 1)
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        guard let drawable = view.currentDrawable else {
            return
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func convertCGImageToData(_ cgImage: CGImage, format: CFString = kUTTypePNG, quality: CGFloat = 1.0) -> Data? {
        let data = NSMutableData()
        
        guard let destination = CGImageDestinationCreateWithData(data, format, 1, nil) else {
            return nil
        }
        
        CGImageDestinationAddImage(destination, cgImage, [
            kCGImageDestinationLossyCompressionQuality: quality
        ] as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return data as Data
    }
    
    private func makeImage(text: String, font: NSFont, size: CGSize) -> CGImage? {
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
        paragraphStyle.alignment = .left
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
        
        return image
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

//        let region = MTLRegionMake2D(0, 0, width, height)
//        let bytesPerRow = 4 * width
//        let data = context.data!
//        texture.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: bytesPerRow)
        
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
