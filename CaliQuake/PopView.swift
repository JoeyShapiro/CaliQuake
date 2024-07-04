//
//  PopView.swift
//  CaliQuake
//
//  Created by Joey Shapiro on 6/21/24.
//

import SwiftUI

struct PopView: View {
    let fontRatio: CGFloat
    let fontHuh: CGFloat
    let pointSize: CGFloat
    @State public var popPos: CGPoint
    @State public var visible: Bool
    @State var popAC = AnsiChar(char: "�", fg: .clear, font: .regular, x: -1, y: -1, width: 1)
    @Binding var text: [AnsiChar]
    @Binding var debug: Bool
    let rows: Int
    let cols: Int
    let width: CGFloat
    let height: CGFloat
    
    init(fontHuh: CGFloat, fontRatio: CGFloat, text: Binding<[AnsiChar]>, pointSize: CGFloat, debug: Binding<Bool>, rows: Int, cols: Int) {
        self.popPos = CGPoint(x: -1.0, y: -1.0)
        self.visible = false
        self._text = text
        
        self.fontHuh = fontHuh
        self.fontRatio = fontRatio
        self.pointSize = pointSize
        self._debug = debug
        
        self.rows = rows
        self.cols = cols
        
        self.width = (self.pointSize * CGFloat(self.cols) / self.fontRatio )
        self.height = (self.pointSize * self.fontHuh * CGFloat(self.rows))
    }
    
    var body: some View {
        // geometry will be useful later, so i will keep
        GeometryReader { geometry in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            popPos = value.location
#if DEBUG
                            if debug {
                                // TODO kinda want on drage and stuff, but that may lead back to start
                                let x = Int(popPos.x / self.pointSize * self.fontRatio)
                                let y = Int(popPos.y / self.pointSize / self.fontHuh)
                                if let ac = self.text.first(where: { ac in
                                    return ac.x == x && ac.y == y
                                }) {
                                    popAC = ac
                                    visible = true
                                } else {
                                    visible = false
                                }
                            }
#endif
                        }
                )
        }
        .frame(width: self.width, height: self.height)
            .popover(isPresented: $visible,  attachmentAnchor: .rect(.rect(CGRect(x: popPos.x, y: popPos.y, width: 0, height: 0)))) {
                // TODO unknown value
                let value = popAC.char.unicodeScalars.first?.value ?? UInt32(0.0)
                Text("char: \"\(popAC.char)\" (\(value))")
                Text("fg: \(popAC.fg)")
                Text("pos: (\(popAC.x), \(popAC.y))")
            }
    }
}
