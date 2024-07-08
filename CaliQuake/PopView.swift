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
    @State public var visible: Bool
    @State var popAC = AnsiChar()
    @Binding var text: [AnsiChar]
    @Binding var debug: Bool
    let rows: Int
    let cols: Int
    let width: CGFloat
    let height: CGFloat
    
    init(text: Binding<[AnsiChar]>, pointSize: CGFloat, debug: Binding<Bool>, rows: Int, cols: Int) {
        self.popPos = CGPoint(x: -1.0, y: -1.0)
        self.visible = false
        self._text = text
        
        self.pointSize = pointSize
        self._debug = debug
        
        self.rows = rows
        self.cols = cols
        
        self.width = (7 * CGFloat(self.cols) )
        self.height = (14 * CGFloat(self.rows))
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
                                // get the row that should be at the top of the screen
                                let lastRow = text.last?.y ?? 0
                                // yes
                                let topRow = lastRow > self.rows-1 ? lastRow-self.rows+1 : 0
                                
                                // TODO kinda want on drage and stuff, but that may lead back to start
                                let x = Int(popPos.x / 7)
                                let y = Int(popPos.y / 14)
                                // last is better, it will show what is on top. but it should show all
                                if let ac = self.text.last(where: { ac in
                                    return ac.x == x && ac.y-topRow == y
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
