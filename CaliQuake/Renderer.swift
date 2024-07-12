import Metal
import MetalKit
import CoreGraphics

struct Vertex {
    var position: vector_float4
    var texCoord: vector_float2
}

class Renderer: NSObject {
    var device: MTLDevice
    var pipelineState: MTLRenderPipelineState!
    var commandQueue: MTLCommandQueue!
    var vertexBuffer: MTLBuffer!
    var texCoordBuffer: MTLBuffer!
    private var text: [AnsiChar]
    private var curChar: AnsiChar
    private var texture: MTLTexture?
    private var textureCursor: MTLTexture?
    private var isDirty = true
    let font: NSFont
    private var debug: Bool
    let width: CGFloat
    let height: CGFloat
    var mtime: Float = 0.0
    var lastUpdateTime: TimeInterval = Date().timeIntervalSince1970
    let rows: Int
    let cols: Int
    let fps: Double
    var times = [TimeInterval]()
    var resolution: simd_float2

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
        self.curChar = AnsiChar(x: 0, y: 0)
        
        self.font = font
        self.debug = debug
        
        // all of these numbers must match
        self.width = 7 * CGFloat(cols)
        self.height = 14 * CGFloat(rows)
        
        self.rows = rows
        self.cols = cols
        
        let vertices: [Float] = [
            -1.0, -1.0,
             1.0, -1.0,
             -1.0,  1.0,
             1.0,  1.0
        ]
        self.vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: [])
        
        let texCoords: [Float] = [
            0.0, 1.0,
            1.0, 1.0,
            0.0, 0.0,
            1.0, 0.0
        ]
        self.texCoordBuffer = device.makeBuffer(bytes: texCoords, length: texCoords.count * MemoryLayout<Float>.size, options: [])
        
        self.fps = 60
        self.resolution = vector_float2()

        super.init()
    }

    func drawableSizeWillChange(size: CGSize) {
        // Handle size change if necessary
        self.resolution = vector_float2(Float(size.width), Float(size.height))
    }
    
    func update(text: [AnsiChar], curChar: AnsiChar, debug: Bool) {
        self.text = text
        self.curChar = curChar
        self.debug = debug
        self.isDirty = true
    }

    func draw(in view: MTKView) {
        if isDirty {
            // NSFont.monospacedSystemFont(ofSize: 12, weight: NSFont.Weight(rawValue: 0.1))
//            guard let font = NSFont(name: "SFMono-Regular", size: 12) else {
//                fatalError("cannot find font")
//            }
            let size = CGSize(width: self.width, height: self.height)
            let imageData = convertCGImageToData(makeImage(text: self.text, font: self.font, size: size)!)!
            let imageCursor = convertCGImageToData(makeCursor(size: size)!)!
            
            let textureLoader = MTKTextureLoader(device: view.device!)
            
            let textureOptions: [MTKTextureLoader.Option : Any] = [
                .SRGB : false,
                .generateMipmaps : true
            ]
            self.texture = try? textureLoader.newTexture(data: imageData, options: textureOptions)
            self.textureCursor = try? textureLoader.newTexture(data: imageCursor, options: textureOptions)
            
            isDirty = false
        }
        
        let currentTime = Date().timeIntervalSince1970
        let deltaTime = currentTime - lastUpdateTime
        self.mtime += Float(deltaTime * 1000) // Convert to milliseconds
        
        if deltaTime < 1.0/30.0 {
            return
        }
        
        // dont recreate the command queue every time
        guard let texture = self.texture,
              let commandBuffer = self.commandQueue.makeCommandBuffer(),
              let descriptor = view.currentRenderPassDescriptor,
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor),
              let drawable = view.currentDrawable else {
            return
        }
        
        lastUpdateTime = currentTime
        
        // Prevent timeInMilliseconds from growing too large
        self.mtime = fmodf(self.mtime, 1000000) // Reset every million milliseconds
        
        encoder.setRenderPipelineState(self.pipelineState!)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentTexture(self.textureCursor, index: 1)
        encoder.setFragmentBytes(&self.resolution, length: MemoryLayout<vector_float2>.size, index: 0)
        encoder.setFragmentBytes(&self.mtime, length: MemoryLayout<Float>.size, index: 1)
        
        encoder.setVertexBuffer(self.vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(self.texCoordBuffer, offset: 0, index: 1)
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

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
            .backgroundColor: NSColor.clear,
        ]
        
        // get the row that should be at the top of the screen
        let lastRow = text.last?.y ?? 0
        // yes
        let topRow = lastRow > self.rows-1 ? lastRow-self.rows+1 : 0
        
        for ac in text {
            // isVisible is prolly the best way. then i can handle scrolling
            if ac.y < topRow {
                continue
            }
            
            if ac.invert {
                attributes[.foregroundColor] = ac.bg == NSColor.clear ? NSColor.black : ac.bg
                attributes[.backgroundColor] = ac.fg
            } else {
                attributes[.foregroundColor] = ac.fg
                attributes[.backgroundColor] = ac.bg
            }
            
            attributes[.font] = ac.font.font(size: self.font.pointSize)
            
            let y = CGFloat(size.height-14)-(CGFloat(ac.y-topRow) * 14)
            let pos = CGPoint(x: (CGFloat(ac.x) * 7), y: y)
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
        
        NSGraphicsContext.restoreGraphicsState()
        
        // Create a texture from the bitmap context
        guard let image = context.makeImage() else { return nil }
        
        return image
    }
    
    private func makeCursor(size: CGSize) -> CGImage? {
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
        
        // get the row that should be at the top of the screen
        let lastRow = text.last?.y ?? 0
        // yes
        let topRow = lastRow > self.rows-1 ? lastRow-self.rows+1 : 0
        let y = CGFloat(size.height-14)-(CGFloat(curChar.y-topRow) * 14)
        
        // TODO test
        let pos = CGPoint(x: (CGFloat(curChar.x) * 7), y: y)
        let rect = CGRect(origin: pos, size: CGSize(width: 7, height: 14))
        context.setFillColor(NSColor.white.cgColor)
        context.fill(rect)
        
        NSGraphicsContext.restoreGraphicsState()
        
        // Create a texture from the bitmap context
        guard let image = context.makeImage() else { return nil }

        return image
    }
}
