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
    private var grid: TerminalGrid
    private var texture: MTLTexture?
    private var textureCursor: MTLTexture?
    private var isDirty = true
    let width: CGFloat
    let height: CGFloat
    var mtime: Float = 0.0
    var lastUpdateTime: TimeInterval = Date().timeIntervalSince1970
    let rows: Int
    let cols: Int
    let pointSize: CGFloat
    var times = [TimeInterval]()
    var resolution: simd_float2

    init(device: MTLDevice, pointSize: CGFloat, cols: Int, rows: Int) {
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
        self.grid = TerminalGrid(cols: 0, rows: 0)
        self.pointSize = pointSize
        
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
        
        self.resolution = vector_float2()

        super.init()
    }

    func drawableSizeWillChange(size: CGSize) {
        // Handle size change if necessary
        self.resolution = vector_float2(Float(size.width), Float(size.height))
    }
    
    func update(grid: TerminalGrid) {
        self.grid = grid
        self.isDirty = true
    }

    func draw(in view: MTKView) {
        if isDirty {
            // NSFont.monospacedSystemFont(ofSize: 12, weight: NSFont.Weight(rawValue: 0.1))
//            guard let font = NSFont(name: "SFMono-Regular", size: 12) else {
//                fatalError("cannot find font")
//            }
            let size = CGSize(width: self.width, height: self.height)
            let imageData = convertCGImageToData(self.grid.makeImage(size: size, pointSize: self.pointSize)!)!
            let imageCursor = convertCGImageToData(self.grid.makeCursor(size: size)!)!
            
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
}
