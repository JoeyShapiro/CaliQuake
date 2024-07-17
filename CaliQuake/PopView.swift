//
//  PopView.swift
//  CaliQuake
//
//  Created by Joey Shapiro on 6/21/24.
//

import SwiftUI

struct PopView: View {
    let pointSize: CGFloat
    @State public var popPos: CGPoint
    @State private var highlights: [CGRect]
    @State public var visible: Bool
    @State var popAC = AnsiChar()
    @Binding var grid: TerminalGrid
    let width: CGFloat
    let height: CGFloat
    
    init(grid: Binding<TerminalGrid>, pointSize: CGFloat, width: CGFloat, height: CGFloat) {
        self.popPos = CGPoint(x: -1.0, y: -1.0)
        self.visible = false
        self._grid = grid
        
        self.pointSize = pointSize
        
        self.width = width
        self.height = height
        self.highlights = []
    }
    
    var body: some View {
        // geometry will be useful later, so i will keep
        ZStack {
            ForEach(Array(highlights.enumerated()), id: \.offset) { index, rect in
                Rectangle()
                    .background(Color.accentColor.opacity(0.5))
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 10).onEnded { value in
                        self.highlights = self.grid.highlight(start: value.startLocation, end: value.location)
                    })
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                popPos = value.location
    #if DEBUG
                                if let ac = self.grid.ch(at: popPos) {
                                    popAC = ac
                                    visible = true
                                } else {
                                    visible = false
                                }
    #endif
                            }
                    )
            }
            .frame(width: self.width, height: self.height) // TODO can i pass this in with frame
            .popover(isPresented: $visible,  attachmentAnchor: .rect(.rect(CGRect(x: popPos.x, y: popPos.y, width: 0, height: 0)))) {
                let value = popAC.char.unicodeScalars.first?.value ?? UInt32(0.0)
                Text("char: \"\(popAC.char)\" (\(value))")
                Text("fg: \(popAC.fg)")
                Text("pos: (\(popAC.x), \(popAC.y))")
            }
        }
    }
}
