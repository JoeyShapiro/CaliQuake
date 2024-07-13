//
//  CaliMenuExtra.swift
//  CaliQuake
//
//  Created by Joey Shapiro on 6/7/24.
//

import SwiftUI
import Metal

struct CaliMenuExtra: View {
    @Binding var grid: TerminalGrid
    let size: CGSize
    
    init(grid: Binding<TerminalGrid>) {
        self._grid = grid
        let width = 7 * CGFloat(80)
        let height = 14 * CGFloat(24)
        self.size = CGSize(width: width, height: height)
    }
    
    var body: some View {
        Text("")
        Image(self.grid.makeImage(size: self.size, pointSize: 12)!, scale: 2.0, label: Text("test"))
    }
}
