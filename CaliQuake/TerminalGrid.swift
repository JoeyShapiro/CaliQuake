//
//  TerminalGrid.swift
//  CaliQuake
//
//  Created by Joey Shapiro on 7/12/24.
//
//  not sure what to call this. but alacrity calls it something like this

import Foundation
import AppKit

// could be further abstracted with AnsiString
// but then i would need to handle location on a new pass
struct TerminalGrid: Sequence {
    private var text: [AnsiChar]
    private var curChar: AnsiChar
    private var cols: Int
    private var rows: Int
    public var top: Int
    
    init(cols: Int, rows: Int) {
        self.text = []
        self.curChar = AnsiChar()
        self.top = 0
        
        self.cols = cols
        self.rows = rows
    }
    
    func makeIterator() -> TextIterator {
        return TextIterator(self)
    }
    
    struct TextIterator: IteratorProtocol {
        var text: [AnsiChar]
        var i: Int
        
        init(_ sequence: TerminalGrid) {
            self.text = sequence.text
            self.i = 0
        }
        
        mutating func next() -> AnsiChar? {
            if self.i < self.text.count {
                defer { self.i += 1 }
                return self.text[self.i]
            } else {
                return nil
            }
        }
    }
    
    mutating func append(_ stdout: Data) {
        text += parse(stdout)
        text = format(text)
        
        self.top = topRow()
    }
    
    func ch(at: CGPoint) -> AnsiChar? {
        let x = Int(at.x / 7)
        let y = Int(at.y / 14)
        // last is better, it will show what is on top. but it should show all
        let ac = self.text.last(where: { ac in
            return ac.x == x && ac.y-top == y
        })
            
        return ac
    }
    
    func curx() -> Int {
        self.curChar.x
    }
    
    func cury() -> Int {
        self.curChar.y
    }
    
    mutating func topRow() -> Int {
        // get the row that should be at the top of the screen
        let lastRow = text.last?.y ?? 0
        // yes
        let row = lastRow > self.rows-1 ? lastRow-self.rows+1 : 0
        return row
    }
    
    mutating func clear() {
        text.removeAll()
        curChar = AnsiChar(x: 0, y: 0)
        
        self.top = topRow()
    }
    
    private mutating func parse(_ stdout: Data) -> [AnsiChar] {
        //y: (text.last?.y ?? 0), x: (text.last?.x ?? 0)
        //prev ?? AnsiChar(x: 0, y: 0)
        var isEsc = false
        var isMeta = false
        var parsed: [AnsiChar] = []
        let esc = 0o33
        let bel = 0o7
        var row = curChar.y
        var col = curChar.x
        var sequence = Data()
        var keypadMode = ""
        var csi = false // [
        var osc = false // ]
        var privates: [Int: Bool] = [:]
        
        var i = 0
        while i < stdout.count {
            if stdout[i] == esc {
                // reset sequence, just in case
                if !sequence.isEmpty {
                    print("leftover sequence:", sequence)
                    sequence.removeAll()
                }
                isEsc = true
                // good enough, until i do real parsing on whole thing
                // esc [ 6 9 7 ;
                //   0 1 2 3 4 5
                i += 1 // "["
                
                switch stdout[i] {
                case 91: /* [ */
                    csi = true
                case 93: /* ] */
                    osc = true
                default:
                    csi = false
                    osc = false
                }
                
                // string terminator
                if stdout[i] == 92 /* \ */ {
                    isEsc = false
                    csi = false
                    osc = false
                    i += 1
                    continue
                } else if stdout[i] == 62 /* > */ {
                    keypadMode = "app"
                    isEsc = false
                    csi = false
                    osc = false
                    i += 1
                    continue
                } else if stdout[i] == 61 /* = */ {
                    keypadMode = "num"
                    isEsc = false
                    csi = false
                    osc = false
                    i += 1
                    continue
                }
                
                if csi && stdout[i] == 72 /* H */ {
                    curChar = AnsiChar(x: 0, y: 0)
                    
                    isEsc = false
                    csi = false
                    i += 1
                    continue
                }
                
                if i+3 < stdout.count {
                    isMeta = stdout[i+1] == 54 /* 6 */ && stdout[i+2] == 57 /* 9 */ && stdout[i+3] == 55 /* 7 */
                }
                if isMeta {
                    i += 3
                }
                i += 1
            }
            
            if !isEsc {
                // read the unicode char
                // TODO can i use less u32
                // TODO can i do cleaner
                var unicode: UInt32 = 0
                if stdout[i] & 0b10000000 == 0 {
                    unicode = UInt32(stdout[i])
                } else if stdout[i] & 0b1110_0000 == 0b1100_0000 {
                    unicode = UInt32(stdout[i] & 0b0001_1111) << 6 | UInt32(stdout[i+1] & 0b0011_1111)
                    i += 1
                } else if stdout[i] & 0b1111_0000 == 0b1110_0000 {
                    unicode = UInt32(stdout[i] & 0b0000_1111) << 12 | UInt32(stdout[i+1] & 0b0011_1111) << 6 | UInt32(stdout[i+2] & 0b0011_1111)
                    i += 2
                } else if stdout[i] & 0b1111_1000 == 0b1111_0000 {
                    unicode = UInt32(stdout[i] & 0b0000_0111) << 18 | UInt32(stdout[i+1] & 0b0011_1111) << 12 | UInt32(stdout[i+2] & 0b0011_1111) << 6 | UInt32(stdout[i+3] & 0b0011_1111)
                    i += 3
                }
                
                
                
                // do action after placing it
                if stdout[i] == 0xd /* \r */ {
                    // this is what is happening. you just dont see it
                    col = 0
                    
                    // ¯\_(ツ)_/¯
                    if i+1 < stdout.count && stdout[i+1] == 0xa /* \n */ {
                        row += 1
                        i += 1
                    }
                    curChar.width = 0
                } else if stdout[i] == 0xa /* \n */ {
                    col = 0
                    row += 1
                    curChar.width = 0
                } else if stdout[i] == 0x8 /* BS */ {
                    let last = text.last(where: { $0.width > 0 })
                    col -= last?.width ?? 0
                    curChar.width = 0
                } else if stdout[i] == bel {
                    curChar.width = 0
                    //                    NSSound(named: "Beep")!.play()
                    NSSound.beep()
                } else {
                    curChar.width = 1
                }
                
                curChar.char = Character(UnicodeScalar(unicode)!)
                curChar.x = col
                curChar.y = row
                
                parsed.append(curChar)
                
                col += curChar.width
                curChar.x = col
                
                // handle window size
                if col > self.cols {
                    col = 0
                    row += 1
                }
            } else {
                sequence.append(stdout[i])
            }
            
            // its doing the auto complete, so i have to handle escapes now
            
            // shrug
            if (isMeta || osc) && stdout[i] == bel {
                isEsc = false
                isMeta = false
                csi = false
                osc = false
                sequence.removeAll()
            }
            
            /// cursor movement
            if isEsc && !isMeta && csi && (stdout[i] >= 65 /* A */ && stdout[i] <= 71 /* G */ ) {
                switch sequence.removeLast() {
                case 68: /* D */
                    if let d = Int(String(data: sequence, encoding: .utf8) ?? "0") {
                        curChar.x -= d
                        // clip it
                        //                        curChar.x = max(curChar.x, 0)
                    }
                case 67: /* C */
                    if let d = Int(String(data: sequence, encoding: .utf8) ?? "0") {
                        curChar.x += d
                        // clip it
                        //                        curChar.x = min(curChar.x, self.rows)
                    }
                default:
                    print("shrug", Unicode.Scalar(stdout[i]))
                }
                sequence.removeAll()
            } else if isEsc && !isMeta && csi && (stdout[i] == 109 /* m */ || stdout[i] == 104 /* h */) {
                // parse sequence now
                if sequence.removeLast() == 109 {
                    let numbers = sequence.split(separator: 59 /* ; */)
                    for number in numbers {
                        if let str = Int(String(data: number, encoding: .utf8) ?? "-1") {
                            switch str {
                            case -1:
                                print("bad")
                            case 0: // default
                                curChar.fg = .white
                                curChar.bg = .clear
                                curChar.font = .regular
                            case 1:
                                curChar.font = .bold
                            case 7: // TODO not sure if correct way, but makes sense
                                curChar.invert = true
                            case 27:
                                curChar.invert = false
                            case 30:
                                curChar.fg = .black
                            case 31:
                                curChar.fg = .red
                            case 32:
                                curChar.fg = .green
                            case 33:
                                curChar.fg = .yellow
                            case 34:
                                curChar.fg = .blue
                            case 35:
                                curChar.fg = .magenta
                            case 36:
                                curChar.fg = .cyan
                            case 37:
                                curChar.fg = .white
                            case 39:
                                curChar.fg = .white
                            case 40:
                                curChar.bg = .black
                            case 41:
                                curChar.bg = .red
                            case 42:
                                curChar.bg = .green
                            case 43:
                                curChar.bg = .yellow
                            case 44:
                                curChar.bg = .blue
                            case 45:
                                curChar.bg = .magenta
                            case 46:
                                curChar.bg = .cyan
                            case 47:
                                curChar.bg = .white
                            case 49:
                                curChar.bg = .clear
                            case 90: // "bright" black
                                curChar.fg = .systemGray // should really just be gray
                            default:
                                curChar.fg = .debugMagenta
                            }
                        }
                    }
                }
                isEsc = false
                csi = false
                sequence.removeAll()
            } else if isEsc && !isMeta && csi && stdout[i] == 63 /* ? */ {
                i += 1 // "?"
                var number = Data()
                // get the number
                while stdout[i] >= 48 && stdout[i] <= 57 {
                    number.append(stdout[i])
                    i += 1
                }
                // read what is there
                if let n = Int(String(data: number, encoding: .utf8)!) {
                    switch stdout[i] {
                    case 108: /* l */
                        // reset or disable
                        privates.removeValue(forKey: n)
                    case 104: /* h */
                        privates[n] = true
                    default:
                        print("unknown code:", Unicode.Scalar(stdout[i]), n)
                    }
                }
                
                isEsc = false
                csi = false
                sequence.removeAll()
            } else if isEsc && !isMeta && csi && stdout[i] == 74 /* J */ {
                sequence.removeLast()
                if let n = Int(String(data: sequence, encoding: .utf8)!){
                    switch n {
                    case 3: // clear scroll back
                        print("TODO")
                    case 2: // clear screen
                        text = []
                    default: // 0
                        print("default J")
                    }
                }
            }
            
            i+=1
        }
        
        return parsed
    }
    
    private func format(_ text: [AnsiChar]) -> [AnsiChar] {
        var posistions: [Int: [Int: Bool]] = [:]
        var formatted: [AnsiChar] = []
        for ac in text {
            if ac.char.asciiValue == 0x8 /* BS */ {
                if let last = formatted.popLast() {
                    posistions[last.y]?[last.x] = nil
                }
            } else {
                // seems super slow
                if ac.width > 0 && posistions[ac.y]?[ac.x] ?? false {
                    formatted.removeAll(where: { $0.x == ac.x && $0.y == ac.y })
                }
                
                if posistions[ac.y] == nil {
                    posistions[ac.y] = [:]
                }
                posistions[ac.y]?[ac.x] = true
                
                formatted.append(ac)
            }
        }
        
        return formatted
    }
    
    func makeCursor(size: CGSize) -> CGImage? {
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
        
        let y = CGFloat(size.height-14)-(CGFloat(self.cury()-self.top) * 14)
        
        // TODO test
        let pos = CGPoint(x: (CGFloat(self.curx()) * 7), y: y)
        let rect = CGRect(origin: pos, size: CGSize(width: 7, height: 14))
        context.setFillColor(NSColor.white.cgColor)
        context.fill(rect)
        
        NSGraphicsContext.restoreGraphicsState()
        
        // Create a texture from the bitmap context
        guard let image = context.makeImage() else { return nil }
        
        return image
    }
}

enum FontStyle {
    case regular
    case bold
    case italic
    case boldItalic
    
    func font(size: CGFloat) -> NSFont {
        switch self {
        case .regular:
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case .bold:
            return NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
        case .italic:
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular).withTraits(.italicFontMask)
        case .boldItalic:
            return NSFont.monospacedSystemFont(ofSize: size, weight: .bold).withTraits(.italicFontMask)
        }
    }
}

extension NSFont {
    func withTraits(_ traits: NSFontTraitMask) -> NSFont {
        guard let newFont = NSFontManager.shared.font(withFamily: familyName ?? "", traits: traits, weight: 0, size: pointSize) else {
            return self
        }
        return newFont
    }
}
