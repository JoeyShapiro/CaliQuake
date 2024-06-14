//
//  CaliQuakeApp.swift
//  CaliQuake
//
//  Created by Joey Shapiro on 6/7/24.
//

import SwiftUI
import SwiftData

@main
struct CaliQuakeApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    @State var input = ""
    
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
        
        return image
    }

    var body: some Scene {
        WindowGroup {
//            ContentView()
            MetalView()
                .frame(width: 100, height: 100)
            Image(nsImage: NSImage(cgImage: makeImage(text: "Hello, Metal!", font: NSFont.systemFont(ofSize: 12), size: CGSize(width: 512, height: 512))!, size: NSSize(width: 50.0, height: 50.0)))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
        }
        .modelContainer(sharedModelContainer)
        MenuBarExtra(
                    "App Menu Bar Extra", systemImage: "water.waves"
                    )
                {
                    CaliMenuExtra()
                }.menuBarExtraStyle(.window)
    }
}
