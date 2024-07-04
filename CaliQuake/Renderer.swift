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
    private var text: [AnsiChar]
    private var texture: MTLTexture?
    private var isDirty = true
    let font: NSFont
    private var debug: Bool
    let width: CGFloat
    let height: CGFloat

    init(device: MTLDevice, font: NSFont, debug: Bool, cols: Int, rows: Int) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()

        let defaultLibrary = device.makeDefaultLibrary()
        
        let fragmentProgram = defaultLibrary?.makeFunction(name: "fragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = defaultLibrary?.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = fragmentProgram
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        self.pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    
        self.texture = nil
        self.text = []
        
        self.font = font
        self.debug = debug
        
        // all of these numbers must match
        self.width = 7 * CGFloat(cols)
        self.height = 14 * CGFloat(rows)

        super.init()
    }

    func drawableSizeWillChange(size: CGSize) {
        // Handle size change if necessary
    }
    
    func update(text: [AnsiChar], debug: Bool) {
        self.text = text
        self.debug = debug
        self.isDirty = true
    }

    func draw(in view: MTKView) {
        if isDirty {
            // NSFont.monospacedSystemFont(ofSize: 12, weight: NSFont.Weight(rawValue: 0.1))
//            guard let font = NSFont(name: "SFMono-Regular", size: 12) else {
//                fatalError("cannot find font")
//            }
            let imageData = convertCGImageToData(makeImage(text: self.text, font: self.font, size: CGSize(width: self.width, height: self.height))!)!
            
            let textureLoader = MTKTextureLoader(device: view.device!)
            
            let textureOptions: [MTKTextureLoader.Option : Any] = [
                .SRGB : false,
                .generateMipmaps : true
            ]
            self.texture = try? textureLoader.newTexture(data: imageData, options: textureOptions)
            
            isDirty = false
        }
        
        guard let texture = self.texture else {
            return
        }
        
        guard let commandBuffer = view.device?.makeCommandQueue()?.makeCommandBuffer(),
              let descriptor = view.currentRenderPassDescriptor,
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        
        encoder.setRenderPipelineState(pipelineState!)
        var resolution = vector_float2(Float(view.drawableSize.width), Float(view.drawableSize.height))
        encoder.setFragmentBytes(&resolution, length: MemoryLayout<vector_float2>.size, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
//        encoder.setFragmentTexture(texture, index: 1)
        
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
    
    private func makeImage(text: [AnsiChar], font: NSFont, size: CGSize) -> CGImage? {
        // Create a bitmap context
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        let width = Int(size.width * scale)
        let height = Int(size.height * scale)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 4 * width, space: colorSpace, bitmapInfo: bitmapInfo) else { return nil }
        
        context.scaleBy(x: scale, y: scale)
//        context.setShouldAntialias(true)
//        context.setAllowsAntialiasing(true)
//        context.setShouldSmoothFonts(true)
//        context.setAllowsFontSmoothing(true)
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        
        // Draw the text
        let paragraphStyle = NSMutableParagraphStyle()
        let style: FontStyle = .regular
        paragraphStyle.alignment = .center
        paragraphStyle.lineHeightMultiple = 0.9
        var attributes: [NSAttributedString.Key: Any] = [
            .font: style.font(size: self.font.pointSize),
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor.white, // if the data is not the right type, it will crash
        ]
        
        for ac in text {
            attributes[.foregroundColor] = ac.fg
            attributes[.font] = ac.font.font(size: self.font.pointSize)
            
            let pos = CGPoint(x: (CGFloat(ac.x) * 7), y: CGFloat(size.height-14)-(CGFloat(ac.y) * 14))
            let rect = CGRect(origin: pos, size: CGSize(width: (7 * CGFloat(ac.width)), height: 14))
            String(ac.char).draw(in: rect, withAttributes: attributes)
            
            #if DEBUG
            if self.debug {
                context.setStrokeColor(NSColor.red.cgColor)  // Set border color
                context.setLineWidth(0.2)  // Set border width
                context.stroke(rect)
            }
            #endif
        }
        
        // TODO test
        let last_x = text.last?.x ?? 0
        let last_y = text.last?.y ?? 0
        let pos = CGPoint(x: (CGFloat(last_x+1) * 7), y: CGFloat(size.height-14)-(CGFloat(last_y) * 14))
        let rect = CGRect(origin: pos, size: CGSize(width: 7, height: 14))
        context.setFillColor(NSColor.white.cgColor)
        context.fill(rect)
        
        NSGraphicsContext.restoreGraphicsState()
        
        // Create a texture from the bitmap context
        guard let image = context.makeImage() else { return nil }
        
        return image
    }
}
