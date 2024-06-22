//
//  PopView.swift
//  CaliQuake
//
//  Created by Joey Shapiro on 6/21/24.
//

import SwiftUI

struct PopView: View {
    let size = 500.0
    let fontRatio: CGFloat
    let fontHuh: CGFloat
    let pointSize: CGFloat
    @State public var popPos: CGPoint
    @State public var visible: Bool
    @State var popAC = AnsiChar(char: "?", fg: .clear, x: -1, y: -1)
    @Binding var text: [AnsiChar]
    
    init(fontHuh: CGFloat, fontRatio: CGFloat, text: Binding<[AnsiChar]>, pointSize: CGFloat) {
        self.popPos = CGPoint(x: -1.0, y: -1.0)
        self.visible = false
        self._text = text
        
        self.fontHuh = fontHuh
        self.fontRatio = fontRatio
        self.pointSize = pointSize
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
#endif
                        }
                )
        }
            .frame(width: size, height: size)
            .popover(isPresented: $visible,  attachmentAnchor: .rect(.rect(CGRect(x: popPos.x, y: popPos.y, width: 0, height: 0)))) {
                // TODO unknown value
                let value = popAC.char.unicodeScalars.first?.value ?? UInt32(0.0)
                Text("char: \"\(popAC.char)\" (\(value))")
                Text("fg: \(popAC.fg)")
                Text("pos: (\(popAC.x), \(popAC.y))")
            }
    }
}
