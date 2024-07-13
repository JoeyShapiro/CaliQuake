//
//  AnsiChar.swift
//  CaliQuake
//
//  Created by Joey Shapiro on 7/12/24.
//

import Foundation
import SwiftUI

struct AnsiChar {
    var char: Character
    var fg: NSColor // Color causes crash
    var bg: NSColor
    var font: FontStyle
    var x: Int
    var y: Int
    var width: Int // need this, but want \n to be at end of line
    var invert: Bool
    
    init() {
        self.char  = "�"
        self.fg    = .white
        self.bg    = .clear
        self.font  = .regular
        self.x     = -1
        self.y     = -1
        self.width = 0
        self.invert = false
    }
    
    init(x: Int, y: Int) {
        self.char  = "�"
        self.fg    = .white
        self.bg    = .clear
        self.font  = .regular
        self.x     = 0
        self.y     = 0
        self.width = 0
        self.invert = false
    }
}
