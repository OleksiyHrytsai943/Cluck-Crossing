// Cluck Crossing art generator.
// Paints every bitmap the app uses (backgrounds, blocks, characters, items, tutorial
// illustrations, HUD parts) with CoreGraphics and writes them as image sets into an
// asset catalog folder. Deterministic: the same run always produces the same art.
//
// Usage: swift generate_assets.swift "<path>/Assets.xcassets/Generated" [preview-dir]

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputRoot = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./Generated")
let previewRoot: URL? = CommandLine.arguments.count > 2 ? URL(fileURLWithPath: CommandLine.arguments[2]) : nil
let fm = FileManager.default
try? fm.createDirectory(at: outputRoot, withIntermediateDirectories: true)
if let previewRoot { try? fm.createDirectory(at: previewRoot, withIntermediateDirectories: true) }
try! #"{"info":{"author":"xcode","version":1}}"#.write(to: outputRoot.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

// MARK: - Colour helpers

struct Col {
    var r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1
    init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    init(hex: UInt32, _ a: CGFloat = 1) {
        r = CGFloat((hex >> 16) & 0xFF) / 255; g = CGFloat((hex >> 8) & 0xFF) / 255; b = CGFloat(hex & 0xFF) / 255; self.a = a
    }
    var cg: CGColor { CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [r, g, b, a])! }
    func mix(_ o: Col, _ t: CGFloat) -> Col { Col(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t, a + (o.a - a) * t) }
    func alpha(_ v: CGFloat) -> Col { Col(r, g, b, v) }
    func lighter(_ t: CGFloat) -> Col { mix(.white, t) }
    func darker(_ t: CGFloat) -> Col { mix(Col(0.05, 0.06, 0.12), t) }
    static let white = Col(1, 1, 1)
    static let ink = Col(hex: 0x1B2340)
}

struct Rng {
    var s: UInt64
    mutating func next() -> CGFloat {
        s ^= s >> 12; s ^= s << 25; s ^= s >> 27
        return CGFloat(Double((s &* 2685821657736338717) >> 11) / Double(1 << 53))
    }
    mutating func r(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * next() }
}

// MARK: - Canvas (top-left origin)

var ctx: CGContext!
var canvasW: CGFloat = 0, canvasH: CGFloat = 0

func begin(_ w: Int, _ h: Int) {
    canvasW = CGFloat(w); canvasH = CGFloat(h)
    ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.interpolationQuality = .high
}

/// Writes the current canvas as `<name>.imageset` marked @3x so 3 px = 1 pt.
func finish(_ name: String) {
    let image = ctx.makeImage()!
    let dir = outputRoot.appendingPathComponent("\(name).imageset")
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("\(name).png")
    let dest = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil); CGImageDestinationFinalize(dest)
    let json = #"{"images":[{"idiom":"universal","scale":"1x"},{"idiom":"universal","scale":"2x"},{"filename":"\#(name).png","idiom":"universal","scale":"3x"}],"info":{"author":"xcode","version":1}}"#
    try! json.write(to: dir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    if let previewRoot { try? fm.removeItem(at: previewRoot.appendingPathComponent("\(name).png")); try? fm.copyItem(at: file, to: previewRoot.appendingPathComponent("\(name).png")) }
}

func gradient(_ cols: [Col], _ locs: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: cols.map(\.cg) as CFArray, locations: locs)!
}

func rr(_ r: CGRect, _ radius: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: min(radius, r.width / 2), cornerHeight: min(radius, r.height / 2), transform: nil) }
func ellipse(_ r: CGRect) -> CGPath { CGPath(ellipseIn: r, transform: nil) }
func circle(_ c: CGPoint, _ rad: CGFloat) -> CGPath { ellipse(CGRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2)) }
func poly(_ pts: [CGPoint]) -> CGPath { let p = CGMutablePath(); p.addLines(between: pts); p.closeSubpath(); return p }

func fill(_ path: CGPath, _ c: Col) { ctx.addPath(path); ctx.setFillColor(c.cg); ctx.fillPath() }
func stroke(_ path: CGPath, _ c: Col, _ w: CGFloat) { ctx.addPath(path); ctx.setStrokeColor(c.cg); ctx.setLineWidth(w); ctx.strokePath() }
func linearFill(_ path: CGPath, _ cols: [Col], _ from: CGPoint, _ to: CGPoint, _ locs: [CGFloat]? = nil) {
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    ctx.drawLinearGradient(gradient(cols, locs), start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}
func radialFill(_ path: CGPath, _ cols: [Col], _ c: CGPoint, _ radius: CGFloat, _ locs: [CGFloat]? = nil) {
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    ctx.drawRadialGradient(gradient(cols, locs), startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [.drawsAfterEndLocation])
    ctx.restoreGState()
}
func glow(_ c: CGPoint, _ radius: CGFloat, _ col: Col) {
    ctx.saveGState(); ctx.setBlendMode(.screen)
    ctx.drawRadialGradient(gradient([col, col.alpha(0)]), startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [])
    ctx.restoreGState()
}
func shadowed(_ offsetY: CGFloat, _ blur: CGFloat, _ col: Col = Col(0.05, 0.08, 0.2, 0.35), _ body: () -> Void) {
    ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: -offsetY), blur: blur, color: col.cg); ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    body()
    ctx.endTransparencyLayer(); ctx.restoreGState()
}
func text(_ s: String, _ p: CGPoint, size: CGFloat, weight: NSFont.Weight = .black, color: Col, center: Bool = true) {
    var font = NSFont.systemFont(ofSize: size, weight: weight)
    if let d = font.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: d, size: size) { font = f }
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(cgColor: color.cg)!]
    let str = NSAttributedString(string: s, attributes: attrs)
    let sz = str.size()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    str.draw(at: CGPoint(x: center ? p.x - sz.width / 2 : p.x, y: p.y - sz.height / 2))
    NSGraphicsContext.restoreGraphicsState()
}

// MARK: - Cluck Crossing palette (night city)

let ink = Col(hex: 0x0B0E17)
let graphite = Col(hex: 0x23262E)
let asphalt = Col(hex: 0x2B2E36)
let nightBlue = Col(hex: 0x101B36)
let deepNight = Col(hex: 0x080D1C)
let sodium = Col(hex: 0xFFB347)
let neonRed = Col(hex: 0xFF3B5C)
let neonTeal = Col(hex: 0x2EE6D6)
let neonPink = Col(hex: 0xFF5FD2)
let eggGold = Col(hex: 0xFFD54A)
let cream = Col(hex: 0xFFF4DC)
let concrete = Col(hex: 0x8E8C88)
let paint = Col(hex: 0xF4F1E6)
let combRed = Col(hex: 0xE5243B)
let beak = Col(hex: 0xFFA31A)

let outlineW: CGFloat = 7

/// Neon tube: soft coloured bloom + white-hot core.
func neon(_ path: CGPath, _ col: Col, _ w: CGFloat) {
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: w * 3.2, color: col.alpha(0.95).cg)
    stroke(path, col, w)
    ctx.restoreGState()
    stroke(path, col.lighter(0.55), w * 0.42)
}

func neonText(_ s: String, _ p: CGPoint, size: CGFloat, _ col: Col, weight: NSFont.Weight = .heavy) {
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: size * 0.35, color: col.cg)
    text(s, p, size: size, weight: weight, color: col)
    text(s, p, size: size, weight: weight, color: col)
    ctx.restoreGState()
    text(s, p, size: size, weight: weight, color: col.lighter(0.6).alpha(0.9))
}

func noiseSpeckle(_ rect: CGRect, count: Int, seed: UInt64, light: Col, dark: Col, size: ClosedRange<CGFloat> = 1.5...4) {
    var g = Rng(s: seed)
    for _ in 0..<count {
        let p = CGPoint(x: g.r(rect.minX, rect.maxX), y: g.r(rect.minY, rect.maxY))
        let r = g.r(size.lowerBound, size.upperBound)
        fill(circle(p, r), g.next() > 0.5 ? light : dark)
    }
}

// MARK: - Road rows (1125 x 225 px = 375 x 75 pt, one row of 5 cells)

let rowW = 1125, rowH = 225

func asphaltBase(_ seed: UInt64, tint: Col = asphalt) {
    let r = CGRect(x: 0, y: 0, width: CGFloat(rowW), height: CGFloat(rowH))
    linearFill(CGPath(rect: r, transform: nil), [tint.lighter(0.04), tint, tint.darker(0.12)], CGPoint(x: 0, y: 0), CGPoint(x: 0, y: r.height))
    noiseSpeckle(r, count: 900, seed: seed, light: Col(1, 1, 1, 0.05), dark: Col(0, 0, 0, 0.14))
    // Hairline cracks.
    var g = Rng(s: seed &+ 7)
    for _ in 0..<3 {
        let p = CGMutablePath()
        var pt = CGPoint(x: g.r(40, r.width - 40), y: g.r(30, r.height - 30))
        p.move(to: pt)
        for _ in 0..<5 { pt = CGPoint(x: pt.x + g.r(-30, 30), y: pt.y + g.r(-18, 18)); p.addLine(to: pt) }
        stroke(p, Col(0, 0, 0, 0.35), 2.5)
    }
}

func laneRow(_ name: String, seed: UInt64, hot: Bool) {
    begin(rowW, rowH)
    asphaltBase(seed, tint: hot ? Col(hex: 0x3A2B2C) : asphalt)
    if hot {
        // Heat shimmer bands.
        for i in 0..<4 {
            let y = CGFloat(40 + i * 45)
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: y))
            var x: CGFloat = 0
            while x < CGFloat(rowW) { p.addQuadCurve(to: CGPoint(x: x + 60, y: y), control: CGPoint(x: x + 30, y: y - 10)); x += 60 }
            stroke(p, Col(hex: 0xFF7A3D, 0.16), 6)
        }
    }
    // Dashed separator at the top edge (rows stack upwards).
    for i in 0..<9 {
        let x = CGFloat(i) * 135 + 20
        fill(rr(CGRect(x: x, y: 2, width: 80, height: 10), 4), paint.alpha(0.75))
    }
    finish(name)
}

func curbRow(_ name: String, seed: UInt64, finishLine: Bool) {
    begin(rowW, rowH)
    let r = CGRect(x: 0, y: 0, width: CGFloat(rowW), height: CGFloat(rowH))
    fill(CGPath(rect: r, transform: nil), Col(hex: 0x5D5B60))
    // Paver slabs.
    var g = Rng(s: seed)
    for row in 0..<3 {
        for col in 0..<9 {
            let w: CGFloat = 125, h: CGFloat = 62
            let x = CGFloat(col) * w + (row % 2 == 0 ? 0 : -w / 2)
            let rect = CGRect(x: x + 4, y: 18 + CGFloat(row) * (h + 4), width: w - 8, height: h)
            let shade = Col(hex: 0x77757A).mix(Col(hex: 0x8A8478), g.next() * 0.6)
            fill(rr(rect, 6), shade)
            stroke(rr(rect, 6), Col(0, 0, 0, 0.25), 3)
        }
    }
    // Granite curb edge (top and bottom).
    linearFill(CGPath(rect: CGRect(x: 0, y: 0, width: r.width, height: 18), transform: nil), [Col(hex: 0xB9B6AE), Col(hex: 0x6E6C68)], .zero, CGPoint(x: 0, y: 18))
    linearFill(CGPath(rect: CGRect(x: 0, y: r.height - 14, width: r.width, height: 14), transform: nil), [Col(hex: 0xB9B6AE), Col(hex: 0x6E6C68)], CGPoint(x: 0, y: r.height - 14), CGPoint(x: 0, y: r.height))
    if finishLine {
        // Golden "safe home" stripe with egg stencils.
        fill(CGPath(rect: CGRect(x: 0, y: 70, width: r.width, height: 80), transform: nil), eggGold.alpha(0.85))
        for i in 0..<5 {
            let c = CGPoint(x: CGFloat(i) * 225 + 112, y: 110)
            fill(ellipse(CGRect(x: c.x - 22, y: c.y - 28, width: 44, height: 56)), cream)
            stroke(ellipse(CGRect(x: c.x - 22, y: c.y - 28, width: 44, height: 56)), ink, 5)
        }
    }
    finish(name)
}

func islandRow() {
    begin(rowW, rowH)
    let r = CGRect(x: 0, y: 0, width: CGFloat(rowW), height: CGFloat(rowH))
    asphaltBase(91)
    let island = CGRect(x: 0, y: 26, width: r.width, height: r.height - 52)
    fill(rr(island, 30), Col(hex: 0xA19D93))
    linearFill(rr(island.insetBy(dx: 0, dy: 10), 24), [Col(hex: 0x3F6B3A), Col(hex: 0x2C4E2B)], CGPoint(x: 0, y: island.minY), CGPoint(x: 0, y: island.maxY))
    noiseSpeckle(island.insetBy(dx: 10, dy: 18), count: 500, seed: 92, light: Col(hex: 0x6FA35E, 0.7), dark: Col(hex: 0x1C3A1E, 0.6), size: 2...5)
    // Yellow-black hazard caps at both ends.
    for x in [CGFloat(0), r.width - 60] {
        let cap = CGRect(x: x, y: island.minY, width: 60, height: island.height)
        ctx.saveGState(); ctx.addPath(rr(cap, 20)); ctx.clip()
        fill(CGPath(rect: cap, transform: nil), eggGold)
        for i in -4..<6 {
            let y = cap.minY + CGFloat(i) * 30
            fill(poly([CGPoint(x: cap.minX, y: y), CGPoint(x: cap.maxX, y: y + 40), CGPoint(x: cap.maxX, y: y + 55), CGPoint(x: cap.minX, y: y + 15)]), ink)
        }
        ctx.restoreGState()
    }
    stroke(rr(island, 30), Col(hex: 0xD8D3C6), 6)
    finish("row_island")
}

// MARK: - Cars (top-down, facing right). Length ratio matches CarKind.length.

func carBody(_ name: String, lengthCells: CGFloat, body: Col, roof: Col, extra: (CGRect) -> Void = { _ in }) {
    let cell: CGFloat = 225
    let w = Int(lengthCells * cell), h = 170
    begin(w, h)
    let rect = CGRect(x: 8, y: 14, width: CGFloat(w) - 16, height: CGFloat(h) - 28)
    shadowed(8, 14, Col(0, 0, 0, 0.55)) {
        fill(rr(rect, 34), body)
    }
    linearFill(rr(rect, 34), [body.lighter(0.25), body, body.darker(0.25)], CGPoint(x: 0, y: rect.minY), CGPoint(x: 0, y: rect.maxY))
    stroke(rr(rect, 34), ink, outlineW)
    // Wheels peeking out.
    for x in [rect.minX + rect.width * 0.18, rect.maxX - rect.width * 0.22] {
        fill(rr(CGRect(x: x - 22, y: rect.minY - 10, width: 44, height: 14), 6), ink)
        fill(rr(CGRect(x: x - 22, y: rect.maxY - 4, width: 44, height: 14), 6), ink)
    }
    extra(rect)
    // Headlights (front = right) and taillights.
    for y in [rect.minY + 22, rect.maxY - 22] {
        glow(CGPoint(x: rect.maxX - 6, y: y), 34, Col(hex: 0xFFF2B0, 0.9))
        fill(rr(CGRect(x: rect.maxX - 16, y: y - 10, width: 12, height: 20), 5), Col(hex: 0xFFF8D8))
        fill(rr(CGRect(x: rect.minX + 2, y: y - 9, width: 10, height: 18), 4), neonRed)
    }
    _ = roof
    finish(name)
}

func cabin(_ rect: CGRect, from: CGFloat, to: CGFloat, roof: Col) {
    let cab = CGRect(x: rect.minX + rect.width * from, y: rect.minY + 18, width: rect.width * (to - from), height: rect.height - 36)
    fill(rr(cab, 22), roof)
    // Windshield (front) and rear glass.
    fill(rr(CGRect(x: cab.maxX - 28, y: cab.minY + 6, width: 22, height: cab.height - 12), 10), Col(hex: 0x9FD4FF, 0.85))
    fill(rr(CGRect(x: cab.minX + 6, y: cab.minY + 8, width: 16, height: cab.height - 16), 8), Col(hex: 0x6FA6D6, 0.8))
    stroke(rr(cab, 22), ink.alpha(0.8), 4)
}

func drawCars() {
    carBody("car_sedan", lengthCells: 1.15, body: Col(hex: 0xE9E6E0), roof: .white) { r in
        cabin(r, from: 0.28, to: 0.72, roof: Col(hex: 0xCFCBC3))
    }
    carBody("car_taxi", lengthCells: 1.15, body: Col(hex: 0xFFC629), roof: .white) { r in
        cabin(r, from: 0.28, to: 0.72, roof: Col(hex: 0xF0B000))
        let sign = CGRect(x: r.midX - 34, y: r.midY - 14, width: 68, height: 28)
        fill(rr(sign, 8), ink)
        text("TAXI", CGPoint(x: sign.midX, y: sign.midY), size: 20, weight: .heavy, color: eggGold)
        // Checker strip.
        for i in 0..<10 {
            fill(CGPath(rect: CGRect(x: r.minX + 20 + CGFloat(i) * 22, y: r.maxY - 16 - CGFloat(i % 2) * 8, width: 11, height: 8), transform: nil), ink)
        }
    }
    carBody("car_van", lengthCells: 1.5, body: Col(hex: 0x2FB7A8), roof: .white) { r in
        cabin(r, from: 0.62, to: 0.86, roof: Col(hex: 0x239485))
        let box = CGRect(x: r.minX + 18, y: r.minY + 16, width: r.width * 0.56, height: r.height - 32)
        fill(rr(box, 14), Col(hex: 0x37CDBD))
        stroke(rr(box, 14), ink.alpha(0.7), 4)
        for i in 1..<4 { stroke(poly([CGPoint(x: box.minX + box.width * CGFloat(i) / 4, y: box.minY + 8), CGPoint(x: box.minX + box.width * CGFloat(i) / 4, y: box.maxY - 8)]), ink.alpha(0.3), 3) }
    }
    carBody("car_bus", lengthCells: 2.3, body: Col(hex: 0x3F6FE0), roof: .white) { r in
        let roofRect = r.insetBy(dx: 26, dy: 20)
        fill(rr(roofRect, 18), Col(hex: 0x5684F0))
        for i in 0..<5 {
            let x = roofRect.minX + 24 + CGFloat(i) * (roofRect.width - 60) / 5
            fill(rr(CGRect(x: x, y: roofRect.minY + 14, width: 54, height: roofRect.height - 28), 8), Col(hex: 0x2B4FB0))
        }
        fill(rr(CGRect(x: r.maxX - 36, y: r.minY + 14, width: 20, height: r.height - 28), 8), Col(hex: 0x9FD4FF, 0.9))
        // Night-route stripe.
        fill(CGPath(rect: CGRect(x: r.minX + 12, y: r.maxY - 18, width: r.width - 40, height: 8), transform: nil), eggGold)
    }
    carBody("car_cornTruck", lengthCells: 2.6, body: Col(hex: 0xD8402F), roof: .white) { r in
        // Cab at the front.
        cabin(r, from: 0.74, to: 0.95, roof: Col(hex: 0xB72F22))
        // Flatbed piled with corn cobs.
        let bed = CGRect(x: r.minX + 14, y: r.minY + 12, width: r.width * 0.66, height: r.height - 24)
        fill(rr(bed, 12), Col(hex: 0x6B4A2E))
        stroke(rr(bed, 12), ink, 5)
        var g = Rng(s: 77)
        for _ in 0..<26 {
            let c = CGPoint(x: g.r(bed.minX + 24, bed.maxX - 24), y: g.r(bed.minY + 20, bed.maxY - 20))
            let cob = CGRect(x: c.x - 26, y: c.y - 11, width: 52, height: 22)
            ctx.saveGState(); ctx.translateBy(x: c.x, y: c.y); ctx.rotate(by: g.r(-0.6, 0.6)); ctx.translateBy(x: -c.x, y: -c.y)
            fill(rr(cob, 11), eggGold)
            stroke(rr(cob, 11), Col(hex: 0xB07A10), 3)
            fill(rr(CGRect(x: cob.minX - 6, y: cob.minY + 2, width: 14, height: 18), 6), Col(hex: 0x7FB04A))
            ctx.restoreGState()
        }
        // Warning beacon on the cab.
        glow(CGPoint(x: r.maxX - r.width * 0.16, y: r.midY), 40, Col(hex: 0xFFB347, 0.8))
        fill(circle(CGPoint(x: r.maxX - r.width * 0.16, y: r.midY), 10), sodium)
    }
}

// MARK: - Hazards & pickups (300 x 300 = 100 pt)

func iconCanvas(_ name: String, _ size: Int = 300, _ draw: () -> Void) { begin(size, size); draw(); finish(name) }

func manholeLid(_ c: CGPoint, _ rad: CGFloat, hot: CGFloat) {
    shadowed(4, 10, Col(0, 0, 0, 0.6)) { fill(circle(c, rad), Col(hex: 0x3A3836)) }
    radialFill(circle(c, rad), [Col(hex: 0x5A5652).mix(Col(hex: 0xFF7A1A), hot), Col(hex: 0x2E2C2A).mix(Col(hex: 0xC2410C), hot)], c, rad)
    stroke(circle(c, rad), ink, outlineW)
    stroke(circle(c, rad * 0.78), Col(0, 0, 0, 0.45), 4)
    // Grid pattern.
    ctx.saveGState(); ctx.addPath(circle(c, rad * 0.74)); ctx.clip()
    var y = c.y - rad
    while y < c.y + rad {
        fill(CGPath(rect: CGRect(x: c.x - rad, y: y, width: rad * 2, height: 6), transform: nil), Col(0, 0, 0, 0.35))
        y += 20
    }
    ctx.restoreGState()
    if hot > 0 {
        glow(c, rad * 1.6, Col(hex: 0xFF8A2A, 0.55 * hot))
        // Glowing slots.
        ctx.saveGState(); ctx.addPath(circle(c, rad * 0.74)); ctx.clip()
        var yy = c.y - rad + 4
        while yy < c.y + rad {
            fill(CGPath(rect: CGRect(x: c.x - rad, y: yy, width: rad * 2, height: 4), transform: nil), Col(hex: 0xFFC46B, 0.8 * hot))
            yy += 20
        }
        ctx.restoreGState()
    }
}

func drawHazards() {
    iconCanvas("manhole") { manholeLid(CGPoint(x: 150, y: 150), 110, hot: 0) }
    iconCanvas("manhole_glow") { manholeLid(CGPoint(x: 150, y: 150), 110, hot: 1) }
    // Flare: tall tongue of fire, drawn upward from the lid (bottom of canvas).
    begin(300, 450)
    let base = CGPoint(x: 150, y: 400)
    glow(CGPoint(x: 150, y: 260), 200, Col(hex: 0xFF6A00, 0.55))
    let layers: [(Col, CGFloat, CGFloat)] = [(Col(hex: 0xE5243B), 120, 380), (Col(hex: 0xFF7A1A), 90, 320), (eggGold, 58, 240), (cream, 28, 150)]
    for (col, half, height) in layers {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: base.x - half, y: base.y))
        p.addCurve(to: CGPoint(x: base.x - half * 0.15, y: base.y - height), control1: CGPoint(x: base.x - half * 1.1, y: base.y - height * 0.45), control2: CGPoint(x: base.x - half * 0.7, y: base.y - height * 0.7))
        p.addCurve(to: CGPoint(x: base.x + half * 0.25, y: base.y - height * 0.72), control1: CGPoint(x: base.x + half * 0.05, y: base.y - height * 0.88), control2: CGPoint(x: base.x + half * 0.1, y: base.y - height * 0.8))
        p.addCurve(to: CGPoint(x: base.x + half, y: base.y), control1: CGPoint(x: base.x + half * 0.9, y: base.y - height * 0.6), control2: CGPoint(x: base.x + half * 1.1, y: base.y - height * 0.3))
        p.closeSubpath()
        fill(p, col)
    }
    finish("flare")

    iconCanvas("kernel") {
        // A small pile of corn kernels.
        var g = Rng(s: 5)
        glow(CGPoint(x: 150, y: 170), 120, eggGold.alpha(0.35))
        for _ in 0..<11 {
            let c = CGPoint(x: g.r(80, 220), y: g.r(120, 210))
            let k = CGMutablePath()
            k.move(to: CGPoint(x: c.x, y: c.y - 30))
            k.addQuadCurve(to: CGPoint(x: c.x + 22, y: c.y + 14), control: CGPoint(x: c.x + 26, y: c.y - 18))
            k.addQuadCurve(to: CGPoint(x: c.x - 22, y: c.y + 14), control: CGPoint(x: c.x, y: c.y + 30))
            k.addQuadCurve(to: CGPoint(x: c.x, y: c.y - 30), control: CGPoint(x: c.x - 26, y: c.y - 18))
            linearFill(k, [Col(hex: 0xFFF0A0), eggGold, Col(hex: 0xE89A10)], CGPoint(x: c.x, y: c.y - 30), CGPoint(x: c.x, y: c.y + 24))
            stroke(k, ink, 5)
            fill(ellipse(CGRect(x: c.x - 6, y: c.y - 18, width: 10, height: 14)), Col(1, 1, 1, 0.7))
        }
    }
}

func drawPickupsAndHUD() {
    iconCanvas("coin") {
        let c = CGPoint(x: 150, y: 150)
        shadowed(6, 10, Col(0, 0, 0, 0.5)) { fill(circle(c, 120), Col(hex: 0xE0A21A)) }
        radialFill(circle(c, 120), [Col(hex: 0xFFE98A), eggGold, Col(hex: 0xD88A10)], CGPoint(x: 115, y: 110), 170)
        stroke(circle(c, 120), ink, outlineW + 2)
        stroke(circle(c, 92), Col(hex: 0xB0700A), 6)
        // Embossed egg.
        let egg = ellipse(CGRect(x: 112, y: 92, width: 76, height: 104))
        fill(egg, Col(hex: 0xFFF3C0))
        stroke(egg, Col(hex: 0xB0700A), 6)
    }
    iconCanvas("egg") {
        let egg = ellipse(CGRect(x: 80, y: 40, width: 140, height: 200))
        shadowed(8, 14, Col(0, 0, 0, 0.45)) { fill(egg, cream) }
        radialFill(egg, [.white, cream, Col(hex: 0xE8C98E)], CGPoint(x: 125, y: 100), 170)
        stroke(egg, ink, outlineW + 1)
        fill(ellipse(CGRect(x: 110, y: 75, width: 30, height: 46)), Col(1, 1, 1, 0.8))
    }
    iconCanvas("feather") {
        ctx.saveGState(); ctx.translateBy(x: 150, y: 150); ctx.rotate(by: -0.6); ctx.translateBy(x: -150, y: -150)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 150, y: 20))
        p.addCurve(to: CGPoint(x: 150, y: 250), control1: CGPoint(x: 245, y: 90), control2: CGPoint(x: 200, y: 210))
        p.addCurve(to: CGPoint(x: 150, y: 20), control1: CGPoint(x: 100, y: 210), control2: CGPoint(x: 55, y: 90))
        shadowed(6, 10, Col(0, 0, 0, 0.45)) { fill(p, .white) }
        linearFill(p, [.white, Col(hex: 0xF3E6D0)], CGPoint(x: 120, y: 20), CGPoint(x: 180, y: 250))
        stroke(p, ink, outlineW)
        stroke(poly([CGPoint(x: 150, y: 40), CGPoint(x: 150, y: 285)]), ink, 7)
        for i in 0..<5 {
            let y = CGFloat(80 + i * 32)
            stroke(poly([CGPoint(x: 150, y: y), CGPoint(x: 115, y: y - 18)]), Col(hex: 0xCFC3AE), 4)
            stroke(poly([CGPoint(x: 150, y: y), CGPoint(x: 185, y: y - 18)]), Col(hex: 0xCFC3AE), 4)
        }
        ctx.restoreGState()
        fill(circle(CGPoint(x: 235, y: 70), 26), combRed)
        stroke(circle(CGPoint(x: 235, y: 70), 26), ink, 5)
    }
    iconCanvas("feather_empty") {
        ctx.saveGState(); ctx.translateBy(x: 150, y: 150); ctx.rotate(by: -0.6); ctx.translateBy(x: -150, y: -150)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 150, y: 20))
        p.addCurve(to: CGPoint(x: 150, y: 250), control1: CGPoint(x: 245, y: 90), control2: CGPoint(x: 200, y: 210))
        p.addCurve(to: CGPoint(x: 150, y: 20), control1: CGPoint(x: 100, y: 210), control2: CGPoint(x: 55, y: 90))
        fill(p, Col(1, 1, 1, 0.12))
        ctx.setLineDash(phase: 0, lengths: [14, 10])
        stroke(p, Col(1, 1, 1, 0.45), 6)
        ctx.setLineDash(phase: 0, lengths: [])
        ctx.restoreGState()
    }
    iconCanvas("grain_token") {
        // Brass crossing-guard whistle.
        let c = CGPoint(x: 150, y: 160)
        shadowed(6, 12, Col(0, 0, 0, 0.5)) { fill(circle(c, 92), Col(hex: 0xC99A2E)) }
        radialFill(circle(c, 92), [Col(hex: 0xFFF0B0), Col(hex: 0xE6B840), Col(hex: 0x9C6B12)], CGPoint(x: 120, y: 120), 140)
        stroke(circle(c, 92), ink, outlineW)
        let mouth = rr(CGRect(x: 150, y: 70, width: 125, height: 62), 18)
        linearFill(mouth, [Col(hex: 0xFFF0B0), Col(hex: 0xC99A2E)], CGPoint(x: 0, y: 70), CGPoint(x: 0, y: 132))
        stroke(mouth, ink, outlineW)
        fill(rr(CGRect(x: 175, y: 92, width: 50, height: 20), 8), ink)
        fill(circle(CGPoint(x: 130, y: 170), 30), ink.alpha(0.85))
        // Lanyard ring.
        stroke(circle(CGPoint(x: 70, y: 105), 26), neonRed, 10)
    }
    iconCanvas("nest") {
        let bowl = CGMutablePath()
        bowl.move(to: CGPoint(x: 30, y: 150))
        bowl.addQuadCurve(to: CGPoint(x: 270, y: 150), control: CGPoint(x: 150, y: 300))
        bowl.closeSubpath()
        shadowed(6, 12, Col(0, 0, 0, 0.5)) { fill(bowl, Col(hex: 0x8A5A2B)) }
        // Eggs.
        for (x, y) in [(110.0, 120.0), (150.0, 105.0), (190.0, 122.0)] {
            let e = ellipse(CGRect(x: x - 32, y: y - 44, width: 64, height: 86))
            radialFill(e, [.white, cream, Col(hex: 0xE8C98E)], CGPoint(x: x - 10, y: y - 20), 80)
            stroke(e, ink, 6)
        }
        fill(bowl, Col(hex: 0x9C6A34))
        var g = Rng(s: 3)
        for _ in 0..<26 {
            let a = CGPoint(x: g.r(40, 260), y: g.r(150, 220))
            stroke(poly([a, CGPoint(x: a.x + g.r(-60, 60), y: a.y + g.r(-14, 14))]), Col(hex: 0xD9A15A), 5)
        }
        stroke(bowl, ink, outlineW)
    }
    iconCanvas("thermometer") {
        let tube = rr(CGRect(x: 120, y: 30, width: 60, height: 190), 30)
        fill(tube, Col(1, 1, 1, 0.9)); stroke(tube, ink, outlineW)
        fill(rr(CGRect(x: 138, y: 90, width: 24, height: 150), 12), neonRed)
        fill(circle(CGPoint(x: 150, y: 235), 48), neonRed)
        stroke(circle(CGPoint(x: 150, y: 235), 48), ink, outlineW)
        for i in 0..<5 { fill(CGPath(rect: CGRect(x: 182, y: 60 + CGFloat(i) * 30, width: 22, height: 6), transform: nil), paint) }
    }
    iconCanvas("plaque", 360) {
        // Neon multiplier plaque (text drawn by the scene).
        let r = CGRect(x: 20, y: 70, width: 320, height: 220)
        fill(rr(r, 40), Col(hex: 0x14112A, 0.92))
        neon(rr(r.insetBy(dx: 14, dy: 14), 30), neonPink, 9)
    }
    iconCanvas("plaque_hot", 360) {
        let r = CGRect(x: 20, y: 70, width: 320, height: 220)
        fill(rr(r, 40), Col(hex: 0x14112A, 0.92))
        neon(rr(r.insetBy(dx: 14, dy: 14), 30), eggGold, 9)
    }
}

// MARK: - Hens (300 x 300, 3/4 front view, standing)

struct HenLook {
    var body: Col
    var shade: Col
    var wing: Col
    var tail: Col
    var comb: Col = combRed
    var speckles: Col? = nil
    var crest = false
    var sheen: Col? = nil
    var bigComb = false
}

func drawHen(_ name: String, _ look: HenLook) {
    begin(300, 300)
    drawHenBody(look)
    finish(name)
}

func drawHenBody(_ look: HenLook) {
    // Ground shadow.
    fill(ellipse(CGRect(x: 70, y: 252, width: 160, height: 30)), Col(0, 0, 0, 0.35))
    // Legs.
    for x in [128.0, 170.0] {
        stroke(poly([CGPoint(x: x, y: 215), CGPoint(x: x, y: 262)]), beak.darker(0.1), 10)
        stroke(poly([CGPoint(x: x - 16, y: 266), CGPoint(x: x, y: 258), CGPoint(x: x + 16, y: 266)]), beak.darker(0.1), 8)
    }
    // Tail fan (behind body).
    let tail = CGMutablePath()
    tail.move(to: CGPoint(x: 90, y: 180))
    tail.addCurve(to: CGPoint(x: 52, y: 62), control1: CGPoint(x: 52, y: 160), control2: CGPoint(x: 30, y: 100))
    tail.addCurve(to: CGPoint(x: 120, y: 120), control1: CGPoint(x: 86, y: 70), control2: CGPoint(x: 110, y: 92))
    tail.closeSubpath()
    fill(tail, look.tail); stroke(tail, ink, outlineW)
    // Body.
    let body = CGMutablePath()
    body.move(to: CGPoint(x: 80, y: 170))
    body.addCurve(to: CGPoint(x: 150, y: 232), control1: CGPoint(x: 72, y: 215), control2: CGPoint(x: 110, y: 234))
    body.addCurve(to: CGPoint(x: 232, y: 160), control1: CGPoint(x: 200, y: 232), control2: CGPoint(x: 236, y: 205))
    body.addCurve(to: CGPoint(x: 200, y: 96), control1: CGPoint(x: 230, y: 125), control2: CGPoint(x: 214, y: 104))
    body.addCurve(to: CGPoint(x: 80, y: 170), control1: CGPoint(x: 150, y: 116), control2: CGPoint(x: 92, y: 120))
    body.closeSubpath()
    shadowed(4, 10, Col(0, 0, 0, 0.4)) { fill(body, look.body) }
    linearFill(body, [look.body.lighter(0.15), look.body, look.shade], CGPoint(x: 120, y: 100), CGPoint(x: 170, y: 232))
    if let sp = look.speckles {
        ctx.saveGState(); ctx.addPath(body); ctx.clip()
        var g = Rng(s: 11)
        for _ in 0..<40 { fill(ellipse(CGRect(x: g.r(80, 230), y: g.r(100, 230), width: 9, height: 6)), sp) }
        ctx.restoreGState()
    }
    if let sheen = look.sheen {
        ctx.saveGState(); ctx.addPath(body); ctx.clip()
        stroke(circle(CGPoint(x: 160, y: 200), 60), sheen.alpha(0.5), 10)
        ctx.restoreGState()
    }
    stroke(body, ink, outlineW)
    // Wing.
    let wing = CGMutablePath()
    wing.move(to: CGPoint(x: 112, y: 160))
    wing.addCurve(to: CGPoint(x: 190, y: 192), control1: CGPoint(x: 120, y: 205), control2: CGPoint(x: 170, y: 210))
    wing.addCurve(to: CGPoint(x: 112, y: 160), control1: CGPoint(x: 182, y: 160), control2: CGPoint(x: 140, y: 146))
    fill(wing, look.wing); stroke(wing, ink, 5)
    stroke(poly([CGPoint(x: 130, y: 178), CGPoint(x: 168, y: 192)]), ink.alpha(0.35), 4)
    // Head.
    let headC = CGPoint(x: 196, y: 84)
    // Comb.
    let combScale: CGFloat = look.bigComb ? 1.35 : 1
    for (dx, dy, r) in [(-20.0, -40.0, 16.0), (-2.0, -50.0, 18.0), (16.0, -42.0, 15.0)] {
        let p = circle(CGPoint(x: headC.x + dx * combScale, y: headC.y + dy * combScale + (combScale - 1) * 10), r * combScale)
        fill(p, look.comb)
    }
    for (dx, dy, r) in [(-20.0, -40.0, 16.0), (-2.0, -50.0, 18.0), (16.0, -42.0, 15.0)] {
        stroke(circle(CGPoint(x: headC.x + dx * combScale, y: headC.y + dy * combScale + (combScale - 1) * 10), r * combScale), ink, 5)
    }
    fill(circle(headC, 44), look.body)
    if look.crest {
        // Silkie pom-pom.
        var g = Rng(s: 21)
        for _ in 0..<14 { fill(circle(CGPoint(x: headC.x + g.r(-34, 30), y: headC.y + g.r(-56, -20)), g.r(14, 22)), look.body.lighter(0.1)) }
    }
    radialFill(circle(headC, 44), [look.body.lighter(0.2), look.body, look.shade], CGPoint(x: headC.x - 12, y: headC.y - 16), 70)
    stroke(circle(headC, 44), ink, outlineW)
    // Beak.
    let b = poly([CGPoint(x: headC.x + 30, y: headC.y - 4), CGPoint(x: headC.x + 66, y: headC.y + 8), CGPoint(x: headC.x + 30, y: headC.y + 20)])
    fill(b, beak); stroke(b, ink, 5)
    // Wattle.
    let wattle = ellipse(CGRect(x: headC.x + 18, y: headC.y + 20, width: 24, height: 34))
    fill(wattle, look.comb); stroke(wattle, ink, 4)
    // Eye with catchlight.
    fill(circle(CGPoint(x: headC.x + 12, y: headC.y - 6), 12), .white)
    stroke(circle(CGPoint(x: headC.x + 12, y: headC.y - 6), 12), ink, 3)
    fill(circle(CGPoint(x: headC.x + 15, y: headC.y - 5), 7), ink)
    fill(circle(CGPoint(x: headC.x + 17, y: headC.y - 8), 2.5), .white)
}

func drawHens() {
    drawHen("hen_pepper", HenLook(body: Col(hex: 0xF7F3EA), shade: Col(hex: 0xC9C0B0), wing: Col(hex: 0xE9E2D4), tail: Col(hex: 0xEDE6D8)))
    drawHen("hen_dot", HenLook(body: Col(hex: 0x8B4F2A), shade: Col(hex: 0x5A2F18), wing: Col(hex: 0x6E3C1F), tail: Col(hex: 0x2E2A2A), speckles: Col(hex: 0xFFF4DC)))
    drawHen("hen_sunny", HenLook(body: Col(hex: 0xF2B860), shade: Col(hex: 0xC27F2A), wing: Col(hex: 0xE09D44), tail: Col(hex: 0xD48B35)))
    drawHen("hen_comet", HenLook(body: Col(hex: 0xC2452D), shade: Col(hex: 0x7E2416), wing: Col(hex: 0xE38A2E), tail: Col(hex: 0x1F3A2E), sheen: Col(hex: 0x3CE0A0), bigComb: true))
    drawHen("hen_inkwell", HenLook(body: Col(hex: 0x2A2D38), shade: Col(hex: 0x111318), wing: Col(hex: 0x1C1F28), tail: Col(hex: 0x15171E), sheen: Col(hex: 0x3CE0A0)))
    drawHen("hen_duchess", HenLook(body: Col(hex: 0xFBF6FF), shade: Col(hex: 0xD6CBE6), wing: Col(hex: 0xF1E9FA), tail: Col(hex: 0xF4EEFB), comb: Col(hex: 0x6A2C4A), crest: true))
}

// MARK: - Upgrades (vending machine products, 300 x 300)

func drawUpgrades() {
    iconCanvas("upgrade_coolFeet") {
        // Tube of blue gel with a snowflake.
        let tube = poly([CGPoint(x: 70, y: 70), CGPoint(x: 230, y: 70), CGPoint(x: 210, y: 230), CGPoint(x: 90, y: 230)])
        shadowed(6, 12, Col(0, 0, 0, 0.5)) { fill(tube, Col(hex: 0x4FB8FF)) }
        linearFill(tube, [Col(hex: 0x9EDBFF), Col(hex: 0x4FB8FF), Col(hex: 0x2A78C8)], CGPoint(x: 70, y: 0), CGPoint(x: 230, y: 0))
        stroke(tube, ink, outlineW)
        fill(rr(CGRect(x: 120, y: 230, width: 60, height: 40), 8), Col(hex: 0xEDEDED)); stroke(rr(CGRect(x: 120, y: 230, width: 60, height: 40), 8), ink, 5)
        for a in stride(from: 0.0, to: Double.pi, by: Double.pi / 3) {
            let c = CGPoint(x: 150, y: 140)
            stroke(poly([CGPoint(x: c.x - 44 * cos(a), y: c.y - 44 * sin(a)), CGPoint(x: c.x + 44 * cos(a), y: c.y + 44 * sin(a))]), .white, 9)
        }
    }
    iconCanvas("upgrade_longWhistle") {
        let c = CGPoint(x: 140, y: 170)
        shadowed(6, 12, Col(0, 0, 0, 0.5)) { fill(circle(c, 80), Col(hex: 0xC99A2E)) }
        radialFill(circle(c, 80), [Col(hex: 0xFFF0B0), Col(hex: 0xE6B840), Col(hex: 0x9C6B12)], CGPoint(x: 110, y: 130), 130)
        stroke(circle(c, 80), ink, outlineW)
        let mouth = rr(CGRect(x: 140, y: 90, width: 120, height: 56), 16)
        linearFill(mouth, [Col(hex: 0xFFF0B0), Col(hex: 0xC99A2E)], CGPoint(x: 0, y: 90), CGPoint(x: 0, y: 146))
        stroke(mouth, ink, outlineW)
        for i in 0..<3 { neon(poly([CGPoint(x: 268, y: 90 + CGFloat(i) * 24), CGPoint(x: 290, y: 80 + CGFloat(i) * 30)]), neonTeal, 6) }
    }
    iconCanvas("upgrade_bigBasket") {
        let basket = poly([CGPoint(x: 50, y: 140), CGPoint(x: 250, y: 140), CGPoint(x: 220, y: 255), CGPoint(x: 80, y: 255)])
        for (x, y) in [(105.0, 115.0), (150.0, 100.0), (195.0, 118.0)] {
            let e = ellipse(CGRect(x: x - 30, y: y - 40, width: 60, height: 80))
            radialFill(e, [.white, cream, Col(hex: 0xE8C98E)], CGPoint(x: x - 10, y: y - 16), 70); stroke(e, ink, 5)
        }
        shadowed(6, 12, Col(0, 0, 0, 0.5)) { fill(basket, Col(hex: 0xB9813F)) }
        ctx.saveGState(); ctx.addPath(basket); ctx.clip()
        for i in 0..<8 { stroke(poly([CGPoint(x: 40 + CGFloat(i) * 30, y: 140), CGPoint(x: 60 + CGFloat(i) * 26, y: 260)]), Col(hex: 0x7E5224), 6) }
        for i in 0..<4 { stroke(poly([CGPoint(x: 40, y: 160 + CGFloat(i) * 26), CGPoint(x: 260, y: 160 + CGFloat(i) * 26)]), Col(hex: 0xE0AC66), 6) }
        ctx.restoreGState()
        stroke(basket, ink, outlineW)
        let handle = CGMutablePath(); handle.move(to: CGPoint(x: 70, y: 140)); handle.addQuadCurve(to: CGPoint(x: 230, y: 140), control: CGPoint(x: 150, y: 10))
        stroke(handle, ink, 16); stroke(handle, Col(hex: 0xB9813F), 9)
    }
    iconCanvas("upgrade_spareFeather") {
        ctx.saveGState(); ctx.translateBy(x: 150, y: 150); ctx.rotate(by: -0.5); ctx.translateBy(x: -150, y: -150)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 150, y: 20))
        p.addCurve(to: CGPoint(x: 150, y: 250), control1: CGPoint(x: 245, y: 90), control2: CGPoint(x: 200, y: 210))
        p.addCurve(to: CGPoint(x: 150, y: 20), control1: CGPoint(x: 100, y: 210), control2: CGPoint(x: 55, y: 90))
        shadowed(6, 12, Col(0, 0, 0, 0.5)) { fill(p, neonTeal.lighter(0.5)) }
        linearFill(p, [.white, neonTeal.lighter(0.3)], CGPoint(x: 120, y: 20), CGPoint(x: 180, y: 250))
        stroke(p, ink, outlineW)
        stroke(poly([CGPoint(x: 150, y: 40), CGPoint(x: 150, y: 285)]), ink, 7)
        ctx.restoreGState()
        // Plus badge.
        fill(circle(CGPoint(x: 232, y: 230), 40), neonRed); stroke(circle(CGPoint(x: 232, y: 230), 40), ink, 6)
        text("+1", CGPoint(x: 232, y: 230), size: 40, weight: .black, color: .white)
    }
    iconCanvas("upgrade_cornPouch") {
        let bag = CGMutablePath()
        bag.move(to: CGPoint(x: 100, y: 90))
        bag.addCurve(to: CGPoint(x: 150, y: 262), control1: CGPoint(x: 30, y: 150), control2: CGPoint(x: 50, y: 262))
        bag.addCurve(to: CGPoint(x: 200, y: 90), control1: CGPoint(x: 250, y: 262), control2: CGPoint(x: 270, y: 150))
        bag.closeSubpath()
        shadowed(6, 12, Col(0, 0, 0, 0.5)) { fill(bag, Col(hex: 0xC9A16B)) }
        linearFill(bag, [Col(hex: 0xE8C795), Col(hex: 0xA77B45)], CGPoint(x: 80, y: 90), CGPoint(x: 220, y: 262))
        stroke(bag, ink, outlineW)
        stroke(poly([CGPoint(x: 92, y: 98), CGPoint(x: 208, y: 98)]), neonRed, 10)
        // Kernels spilling out of the top.
        for (x, y) in [(130.0, 70.0), (160.0, 58.0), (186.0, 76.0), (148.0, 84.0)] {
            let k = ellipse(CGRect(x: x - 16, y: y - 20, width: 32, height: 40))
            fill(k, eggGold); stroke(k, ink, 4)
        }
        text("CORN", CGPoint(x: 150, y: 185), size: 40, weight: .black, color: Col(hex: 0x5A3A16))
    }
}

// MARK: - UI pieces

func drawUIPieces() {
    // Finger sign plank for the lamp post (900 x 210 = 300 x 70 pt), points right.
    begin(900, 210)
    let plank = poly([CGPoint(x: 10, y: 20), CGPoint(x: 800, y: 20), CGPoint(x: 885, y: 105), CGPoint(x: 800, y: 190), CGPoint(x: 10, y: 190)])
    shadowed(8, 14, Col(0, 0, 0, 0.6)) { fill(plank, Col(hex: 0x1D6B4A)) }
    linearFill(plank, [Col(hex: 0x2A8C62), Col(hex: 0x1D6B4A), Col(hex: 0x145238)], CGPoint(x: 0, y: 20), CGPoint(x: 0, y: 190))
    stroke(plank, .white, 10)
    stroke(plank, ink, 4)
    finish("sign_plank")

    // Crosswalk push-button box (back button), 240 x 300.
    begin(240, 300)
    let box = rr(CGRect(x: 20, y: 14, width: 200, height: 272), 30)
    shadowed(6, 12, Col(0, 0, 0, 0.6)) { fill(box, eggGold) }
    linearFill(box, [Col(hex: 0xFFE680), eggGold, Col(hex: 0xD9A510)], CGPoint(x: 0, y: 14), CGPoint(x: 0, y: 286))
    stroke(box, ink, outlineW)
    fill(rr(CGRect(x: 50, y: 40, width: 140, height: 70), 12), ink)
    // Little walking hen glyph.
    fill(circle(CGPoint(x: 120, y: 75), 22), .white)
    fill(poly([CGPoint(x: 140, y: 72), CGPoint(x: 158, y: 76), CGPoint(x: 140, y: 82)]), beak)
    fill(circle(CGPoint(x: 112, y: 52), 9), combRed)
    fill(circle(CGPoint(x: 120, y: 205), 54), Col(hex: 0x9A9A9A))
    radialFill(circle(CGPoint(x: 120, y: 205), 44), [Col(hex: 0xF0F0F0), Col(hex: 0xA0A0A0)], CGPoint(x: 105, y: 190), 70)
    stroke(circle(CGPoint(x: 120, y: 205), 54), ink, 6)
    finish("push_button")

    // Pedestrian signal heads (WALK / DON'T WALK) 300 x 300.
    iconCanvas("signal_walk") {
        let housing = rr(CGRect(x: 30, y: 30, width: 240, height: 240), 40)
        shadowed(8, 14, Col(0, 0, 0, 0.6)) { fill(housing, Col(hex: 0x1C1E24)) }
        stroke(housing, ink, outlineW)
        fill(rr(CGRect(x: 54, y: 54, width: 192, height: 192), 24), Col(hex: 0x05060A))
        glow(CGPoint(x: 150, y: 150), 130, Col(hex: 0x6CFFE8, 0.55))
        // Walking hen made of light.
        let c = Col(hex: 0xB5FFF4)
        fill(ellipse(CGRect(x: 95, y: 120, width: 100, height: 70)), c)
        fill(circle(CGPoint(x: 190, y: 105), 26), c)
        fill(poly([CGPoint(x: 212, y: 100), CGPoint(x: 238, y: 108), CGPoint(x: 212, y: 116)]), c)
        stroke(poly([CGPoint(x: 130, y: 185), CGPoint(x: 115, y: 225)]), c, 10)
        stroke(poly([CGPoint(x: 160, y: 185), CGPoint(x: 178, y: 225)]), c, 10)
        fill(poly([CGPoint(x: 100, y: 140), CGPoint(x: 66, y: 110), CGPoint(x: 92, y: 160)]), c)
    }
    iconCanvas("signal_stop") {
        let housing = rr(CGRect(x: 30, y: 30, width: 240, height: 240), 40)
        shadowed(8, 14, Col(0, 0, 0, 0.6)) { fill(housing, Col(hex: 0x1C1E24)) }
        stroke(housing, ink, outlineW)
        fill(rr(CGRect(x: 54, y: 54, width: 192, height: 192), 24), Col(hex: 0x05060A))
        glow(CGPoint(x: 150, y: 150), 130, Col(hex: 0xFF6A3A, 0.55))
        let c = Col(hex: 0xFF8A4A)
        // Raised hand.
        fill(rr(CGRect(x: 105, y: 130, width: 90, height: 90), 26), c)
        for i in 0..<4 { fill(rr(CGRect(x: 106 + CGFloat(i) * 23, y: 78 + (i == 0 || i == 3 ? 14 : 0), width: 19, height: 70), 9), c) }
        fill(rr(CGRect(x: 70, y: 140, width: 50, height: 22), 10), c)
    }

    // Neon achievement frames (420 x 260).
    for (i, col) in [neonPink, neonTeal, eggGold, neonRed].enumerated() {
        begin(420, 260)
        let r = CGRect(x: 30, y: 30, width: 360, height: 200)
        fill(rr(r, 36), Col(hex: 0x0E0B1E, 0.9))
        neon(rr(r.insetBy(dx: 12, dy: 12), 28), col, 10)
        finish("neon_on_\(i)")
    }
    begin(420, 260)
    let off = CGRect(x: 30, y: 30, width: 360, height: 200)
    fill(rr(off, 36), Col(hex: 0x0E0B1E, 0.9))
    stroke(rr(off.insetBy(dx: 12, dy: 12), 28), Col(hex: 0x3A3550), 10)
    stroke(rr(off.insetBy(dx: 12, dy: 12), 28), Col(hex: 0x575070), 3)
    finish("neon_off")

    // Stars for the timetable board.
    iconCanvas("star_on", 150) {
        let p = star(CGPoint(x: 75, y: 78), 62, 28)
        ctx.saveGState(); ctx.setShadow(offset: .zero, blur: 16, color: eggGold.cg); fill(p, eggGold); ctx.restoreGState()
        stroke(p, ink, 6)
    }
    iconCanvas("star_off", 150) {
        let p = star(CGPoint(x: 75, y: 78), 62, 28)
        fill(p, Col(1, 1, 1, 0.12)); stroke(p, Col(1, 1, 1, 0.35), 5)
    }
    iconCanvas("lock", 150) {
        stroke(rr(CGRect(x: 45, y: 25, width: 60, height: 70), 30), Col(hex: 0xB9B6AE), 14)
        fill(rr(CGRect(x: 30, y: 65, width: 90, height: 70), 14), Col(hex: 0xB9B6AE))
        stroke(rr(CGRect(x: 30, y: 65, width: 90, height: 70), 14), ink, 5)
        fill(circle(CGPoint(x: 75, y: 96), 10), ink)
    }
}

func star(_ c: CGPoint, _ outer: CGFloat, _ inner: CGFloat, points: Int = 5) -> CGPath {
    let p = CGMutablePath()
    for i in 0..<(points * 2) {
        let a = -CGFloat.pi / 2 + CGFloat(i) * .pi / CGFloat(points)
        let r = i % 2 == 0 ? outer : inner
        let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
    }
    p.closeSubpath()
    return p
}

// MARK: - City backdrops (1170 x 2532 portrait, @3x of 390 x 844)

let bgW = 1170, bgH = 2532

func nightSky(_ top: Col = deepNight, _ bottom: Col = nightBlue) {
    let r = CGRect(x: 0, y: 0, width: CGFloat(bgW), height: CGFloat(bgH))
    linearFill(CGPath(rect: r, transform: nil), [top, bottom, Col(hex: 0x2A1E45)], .zero, CGPoint(x: 0, y: r.height), [0, 0.6, 1])
    var g = Rng(s: 404)
    for _ in 0..<120 {
        let p = CGPoint(x: g.r(0, r.width), y: g.r(0, r.height * 0.45))
        fill(circle(p, g.r(1.5, 3.5)), Col(1, 1, 1, g.r(0.3, 0.9)))
    }
    // Moon.
    glow(CGPoint(x: 900, y: 300), 260, Col(hex: 0xFFF2C8, 0.25))
    fill(circle(CGPoint(x: 900, y: 300), 90), Col(hex: 0xFFF4D6))
    fill(circle(CGPoint(x: 940, y: 270), 80), top.alpha(0.0))
}

func skyline(_ baseY: CGFloat, _ col: Col, seed: UInt64, maxH: CGFloat, windows: Col?) {
    var g = Rng(s: seed)
    var x: CGFloat = -20
    while x < CGFloat(bgW) {
        let w = g.r(110, 220), h = g.r(maxH * 0.4, maxH)
        let r = CGRect(x: x, y: baseY - h, width: w, height: h + 4)
        fill(CGPath(rect: r, transform: nil), col)
        if let windows {
            var wy = r.minY + 30
            while wy < baseY - 30 {
                var wx = r.minX + 18
                while wx < r.maxX - 30 {
                    if g.next() > 0.55 { fill(CGPath(rect: CGRect(x: wx, y: wy, width: 22, height: 30), transform: nil), windows.alpha(g.r(0.5, 1))) }
                    wx += 40
                }
                wy += 52
            }
        }
        x += w + g.r(-10, 20)
    }
}

func streetLamp(_ x: CGFloat, _ baseY: CGFloat, height: CGFloat, glowSize: CGFloat = 340) {
    let top = baseY - height
    stroke(poly([CGPoint(x: x, y: baseY), CGPoint(x: x, y: top + 40)]), Col(hex: 0x1A1C22), 26)
    let arm = CGMutablePath(); arm.move(to: CGPoint(x: x, y: top + 60)); arm.addQuadCurve(to: CGPoint(x: x + 140, y: top + 30), control: CGPoint(x: x, y: top))
    stroke(arm, Col(hex: 0x1A1C22), 20)
    glow(CGPoint(x: x + 150, y: top + 60), glowSize, sodium.alpha(0.6))
    fill(rr(CGRect(x: x + 100, y: top + 22, width: 110, height: 34), 14), Col(hex: 0x1A1C22))
    fill(rr(CGRect(x: x + 110, y: top + 46, width: 90, height: 16), 8), Col(hex: 0xFFE2A0))
    // Light cone.
    ctx.saveGState(); ctx.setBlendMode(.screen)
    linearFill(poly([CGPoint(x: x + 120, y: top + 60), CGPoint(x: x + 190, y: top + 60), CGPoint(x: x + 420, y: baseY), CGPoint(x: x - 100, y: baseY)]), [sodium.alpha(0.28), sodium.alpha(0)], CGPoint(x: 0, y: top + 60), CGPoint(x: 0, y: baseY))
    ctx.restoreGState()
}

func roadStrip(_ y: CGFloat, _ h: CGFloat) {
    let r = CGRect(x: 0, y: y, width: CGFloat(bgW), height: h)
    fill(CGPath(rect: r, transform: nil), asphalt)
    noiseSpeckle(r, count: 1400, seed: 8, light: Col(1, 1, 1, 0.05), dark: Col(0, 0, 0, 0.18))
    // Zebra crossing.
    for i in 0..<8 {
        fill(CGPath(rect: CGRect(x: 380, y: y + 20 + CGFloat(i) * h / 8, width: 410, height: h / 16), transform: nil), paint.alpha(0.85))
    }
}

func drawBackdrops() {
    // Home: night street corner. Lower third is sidewalk where the UI sits.
    begin(bgW, bgH)
    nightSky()
    skyline(1300, Col(hex: 0x141A33), seed: 1, maxH: 700, windows: nil)
    skyline(1420, Col(hex: 0x1C2240), seed: 2, maxH: 560, windows: sodium)
    // Neon shop fronts.
    fill(CGPath(rect: CGRect(x: 0, y: 1420, width: CGFloat(bgW), height: 260), transform: nil), Col(hex: 0x181428))
    neon(rr(CGRect(x: 60, y: 1460, width: 300, height: 120), 20), neonTeal, 8)
    neonText("OPEN 24/7", CGPoint(x: 210, y: 1520), size: 58, neonTeal)
    neon(rr(CGRect(x: 760, y: 1450, width: 360, height: 140), 24), neonPink, 8)
    neonText("EGGS·DINER", CGPoint(x: 940, y: 1520), size: 54, neonPink)
    roadStrip(1680, 420)
    // Sidewalk.
    let side = CGRect(x: 0, y: 2100, width: CGFloat(bgW), height: 432)
    fill(CGPath(rect: side, transform: nil), Col(hex: 0x4D4B52))
    for row in 0..<4 { for col in 0..<6 {
        let r = CGRect(x: CGFloat(col) * 200 + (row % 2 == 0 ? 0 : -100) + 6, y: 2120 + CGFloat(row) * 104, width: 188, height: 96)
        fill(rr(r, 8), Col(hex: 0x5B5960)); stroke(rr(r, 8), Col(0, 0, 0, 0.3), 3)
    } }
    linearFill(CGPath(rect: CGRect(x: 0, y: 2092, width: CGFloat(bgW), height: 26), transform: nil), [Col(hex: 0xC9C5BA), Col(hex: 0x77746C)], CGPoint(x: 0, y: 2092), CGPoint(x: 0, y: 2118))
    streetLamp(80, 2200, height: 1100)
    finish("corner_backdrop")

    // Timetable: bus shelter wall at night.
    begin(bgW, bgH)
    nightSky(Col(hex: 0x07101E), Col(hex: 0x0E2236))
    skyline(1000, Col(hex: 0x111A2E), seed: 5, maxH: 600, windows: Col(hex: 0x9FD4FF))
    fill(CGPath(rect: CGRect(x: 0, y: 1000, width: CGFloat(bgW), height: 1532), transform: nil), Col(hex: 0x10151F))
    for i in 0..<6 { stroke(poly([CGPoint(x: CGFloat(i) * 234, y: 1000), CGPoint(x: CGFloat(i) * 234, y: CGFloat(bgH))]), Col(hex: 0x1E2636), 14) }
    glow(CGPoint(x: 585, y: 1100), 700, Col(hex: 0x2EE6D6, 0.12))
    finish("timetable_backdrop")

    // Vending: alley wall with brick and the glow of the machine.
    begin(bgW, bgH)
    fill(CGPath(rect: CGRect(x: 0, y: 0, width: CGFloat(bgW), height: CGFloat(bgH)), transform: nil), Col(hex: 0x1E1418))
    var g = Rng(s: 66)
    for row in 0..<60 {
        for col in 0..<9 {
            let r = CGRect(x: CGFloat(col) * 140 + (row % 2 == 0 ? 0 : -70), y: CGFloat(row) * 46, width: 132, height: 40)
            fill(rr(r, 4), Col(hex: 0x4A2A28).mix(Col(hex: 0x6B3A2E), g.next() * 0.6).darker(0.35))
        }
    }
    glow(CGPoint(x: 585, y: 1200), 900, Col(hex: 0xFF5FD2, 0.18))
    glow(CGPoint(x: 585, y: 1200), 500, Col(hex: 0x2EE6D6, 0.12))
    fill(CGPath(rect: CGRect(x: 0, y: 2200, width: CGFloat(bgW), height: 332), transform: nil), Col(hex: 0x2A2A30))
    finish("vending_backdrop")

    // Henhouse: apartment facade with lit windows (the screen overlays hens into the windows).
    begin(bgW, bgH)
    nightSky(Col(hex: 0x0A0C1E), Col(hex: 0x1A1640))
    let facade = CGRect(x: 60, y: 380, width: 1050, height: 2152)
    fill(CGPath(rect: facade, transform: nil), Col(hex: 0x6B3B32))
    var gb = Rng(s: 12)
    for row in 0..<48 { for col in 0..<8 {
        let r = CGRect(x: facade.minX + CGFloat(col) * 136 + (row % 2 == 0 ? 0 : -68), y: facade.minY + CGFloat(row) * 45, width: 130, height: 40)
        fill(CGPath(rect: r.intersection(facade), transform: nil), Col(hex: 0x7A4538).mix(Col(hex: 0x5E3229), gb.next()))
    } }
    stroke(CGPath(rect: facade, transform: nil), ink, 10)
    // Roof cornice.
    fill(CGPath(rect: CGRect(x: 30, y: 340, width: 1110, height: 60), transform: nil), Col(hex: 0x3A2420))
    // No sign here: the screen header sits on top of the roof line.
    finish("henhouse_backdrop")

    // Billboard: rooftop with water tower against the sky.
    begin(bgW, bgH)
    nightSky(Col(hex: 0x060814), Col(hex: 0x241446))
    skyline(1900, Col(hex: 0x120F26), seed: 9, maxH: 900, windows: neonPink.lighter(0.3))
    fill(CGPath(rect: CGRect(x: 0, y: 1900, width: CGFloat(bgW), height: 632), transform: nil), Col(hex: 0x1A1A22))
    // Water tower silhouette.
    fill(rr(CGRect(x: 820, y: 1500, width: 240, height: 250), 30), Col(hex: 0x0E0C18))
    fill(poly([CGPoint(x: 800, y: 1510), CGPoint(x: 940, y: 1400), CGPoint(x: 1080, y: 1510)]), Col(hex: 0x0E0C18))
    for x in [850.0, 1030.0] { stroke(poly([CGPoint(x: x, y: 1750), CGPoint(x: x, y: 1900)]), Col(hex: 0x0E0C18), 18) }
    finish("billboard_backdrop")
}

// MARK: - District postcards (900 x 540 = 300 x 180 pt)

func district(_ name: String, sky: [Col], lamp: Bool, accent: Col, _ extra: () -> Void) {
    begin(900, 540)
    linearFill(CGPath(rect: CGRect(x: 0, y: 0, width: 900, height: 540), transform: nil), sky, .zero, CGPoint(x: 0, y: 540))
    var g = Rng(s: UInt64(name.count * 31))
    var x: CGFloat = -10
    while x < 900 {
        let w = g.r(70, 150), h = g.r(120, 300)
        fill(CGPath(rect: CGRect(x: x, y: 330 - h, width: w, height: h), transform: nil), sky[0].darker(0.3))
        var wy = 330 - h + 16
        while wy < 310 { if g.next() > 0.5 { fill(CGPath(rect: CGRect(x: x + 12, y: wy, width: 14, height: 18), transform: nil), accent.alpha(0.8)) }; wy += 34 }
        x += w + 6
    }
    fill(CGPath(rect: CGRect(x: 0, y: 330, width: 900, height: 210), transform: nil), asphalt)
    for i in 0..<7 { fill(CGPath(rect: CGRect(x: CGFloat(i) * 140 + 10, y: 430, width: 80, height: 10), transform: nil), paint.alpha(0.7)) }
    if lamp { glow(CGPoint(x: 160, y: 330), 220, sodium.alpha(0.45)) }
    extra()
    stroke(rr(CGRect(x: 4, y: 4, width: 892, height: 532), 30), ink, 8)
    finish(name)
}

func smallCar(_ x: CGFloat, _ y: CGFloat, _ col: Col, length: CGFloat = 130) {
    let r = CGRect(x: x, y: y, width: length, height: 60)
    fill(rr(r, 18), col); stroke(rr(r, 18), ink, 5)
    fill(rr(CGRect(x: r.minX + length * 0.3, y: r.minY + 10, width: length * 0.4, height: 40), 10), col.darker(0.25))
    glow(CGPoint(x: r.maxX, y: r.midY), 50, Col(hex: 0xFFF2B0, 0.7))
}

func drawDistricts() {
    district("district_sleepy", sky: [Col(hex: 0x1B2A4E), Col(hex: 0x3A4A7A)], lamp: true, accent: sodium) {
        smallCar(520, 360, Col(hex: 0xE9E6E0))
    }
    district("district_market", sky: [Col(hex: 0x2A1838), Col(hex: 0x5A3050)], lamp: true, accent: eggGold) {
        smallCar(300, 450, Col(hex: 0xD8402F), length: 260)
        for i in 0..<6 { fill(ellipse(CGRect(x: 320 + CGFloat(i) * 30, y: 455, width: 22, height: 14)), eggGold) }
        neonText("MARKET", CGPoint(x: 700, y: 120), size: 60, eggGold)
    }
    district("district_steam", sky: [Col(hex: 0x1E2226), Col(hex: 0x3E3A36)], lamp: true, accent: Col(hex: 0xFF8A3A)) {
        manholeLid(CGPoint(x: 450, y: 440), 56, hot: 1)
        glow(CGPoint(x: 450, y: 400), 160, Col(hex: 0xFF6A00, 0.4))
        for i in 0..<4 { fill(circle(CGPoint(x: 430 + CGFloat(i) * 20, y: 350 - CGFloat(i) * 40), 40 - CGFloat(i) * 6), Col(1, 1, 1, 0.12)) }
    }
    district("district_neon", sky: [Col(hex: 0x1A0A30), Col(hex: 0x52206A)], lamp: false, accent: neonPink) {
        neonText("NEON BLVD", CGPoint(x: 450, y: 110), size: 70, neonPink)
        smallCar(120, 360, Col(hex: 0xFFC629)); smallCar(560, 460, Col(hex: 0x2FB7A8))
        for i in 0..<3 {
            let p = CGMutablePath(); p.move(to: CGPoint(x: 0, y: 380 + CGFloat(i) * 40))
            p.addQuadCurve(to: CGPoint(x: 900, y: 380 + CGFloat(i) * 40), control: CGPoint(x: 450, y: 370 + CGFloat(i) * 40))
            stroke(p, Col(hex: 0xFF7A3D, 0.2), 6)
        }
    }
    district("district_midnight", sky: [Col(hex: 0x02030A), Col(hex: 0x0A0E22)], lamp: false, accent: Col(hex: 0x30406A)) {
        fill(CGPath(rect: CGRect(x: 0, y: 330, width: 900, height: 210), transform: nil), Col(0, 0, 0, 0.5))
        for (x, y) in [(200.0, 390.0), (620.0, 480.0)] {
            glow(CGPoint(x: x, y: y), 120, Col(hex: 0xFFF2B0, 0.7))
            fill(circle(CGPoint(x: x, y: y - 12), 10), .white); fill(circle(CGPoint(x: x, y: y + 12), 10), .white)
        }
    }
}

// MARK: - Speed camera frame & logo

func drawCameraAndLogo() {
    // Speed camera photo frame (1050 x 900 = 350 x 300 pt): dark border with data strip area at the bottom.
    begin(1050, 900)
    let outer = rr(CGRect(x: 10, y: 10, width: 1030, height: 880), 30)
    fill(outer, Col(hex: 0xF4F1E6))
    stroke(outer, ink, 8)
    // Photo window.
    let photo = CGRect(x: 50, y: 50, width: 950, height: 640)
    fill(CGPath(rect: photo, transform: nil), Col(hex: 0x0A0C14))
    ctx.saveGState(); ctx.addPath(CGPath(rect: photo, transform: nil)); ctx.clip()
    // Road in the photo with flash bloom.
    fill(CGPath(rect: CGRect(x: 50, y: 420, width: 950, height: 270), transform: nil), asphalt)
    for i in 0..<6 { fill(CGPath(rect: CGRect(x: 60 + CGFloat(i) * 170, y: 540, width: 100, height: 12), transform: nil), paint.alpha(0.7)) }
    glow(CGPoint(x: 525, y: 380), 520, Col(1, 1, 1, 0.35))
    skyline(420, Col(hex: 0x161B30), seed: 3, maxH: 260, windows: sodium)
    ctx.restoreGState()
    // Crosshair corners.
    for (x, y, dx, dy) in [(70.0, 70.0, 1.0, 1.0), (980.0, 70.0, -1.0, 1.0), (70.0, 670.0, 1.0, -1.0), (980.0, 670.0, -1.0, -1.0)] {
        stroke(poly([CGPoint(x: x, y: y + dy * 60), CGPoint(x: x, y: y), CGPoint(x: x + dx * 60, y: y)]), neonRed, 8)
    }
    // Data strip.
    fill(CGPath(rect: CGRect(x: 50, y: 712, width: 950, height: 140), transform: nil), Col(hex: 0x111318))
    finish("camera_frame")

    // Neon wordmark (1200 x 480 = 400 x 160 pt).
    begin(1200, 480)
    let board = rr(CGRect(x: 30, y: 40, width: 1140, height: 400), 70)
    fill(board, Col(hex: 0x120E24, 0.88))
    stroke(board, Col(hex: 0x2C2450), 10)
    neon(rr(CGRect(x: 60, y: 70, width: 1080, height: 340), 54), neonTeal, 9)
    neonText("CLUCK", CGPoint(x: 600, y: 170), size: 150, eggGold, weight: .black)
    neonText("CROSSING", CGPoint(x: 600, y: 320), size: 116, neonPink, weight: .black)
    // Tiny egg dot over the C.
    fill(ellipse(CGRect(x: 150, y: 90, width: 46, height: 60)), cream)
    stroke(ellipse(CGRect(x: 150, y: 90, width: 46, height: 60)), ink, 5)
    finish("logo_wordmark")
}

// MARK: - Rulebook illustrations (720 x 420 = 240 x 140 pt)

func tutorialCanvas(_ name: String, _ draw: () -> Void) {
    begin(720, 420)
    fill(CGPath(rect: CGRect(x: 0, y: 0, width: 720, height: 420), transform: nil), asphalt)
    noiseSpeckle(CGRect(x: 0, y: 0, width: 720, height: 420), count: 500, seed: 4, light: Col(1, 1, 1, 0.05), dark: Col(0, 0, 0, 0.2))
    draw()
    stroke(rr(CGRect(x: 4, y: 4, width: 712, height: 412), 26), ink, 8)
    finish(name)
}

func laneLines(_ ys: [CGFloat]) {
    for y in ys { for i in 0..<6 { fill(CGPath(rect: CGRect(x: CGFloat(i) * 130 + 20, y: y, width: 70, height: 8), transform: nil), paint.alpha(0.7)) } }
}

func miniHen(_ c: CGPoint, _ s: CGFloat = 1) {
    fill(ellipse(CGRect(x: c.x - 40 * s, y: c.y - 24 * s, width: 80 * s, height: 56 * s)), .white)
    stroke(ellipse(CGRect(x: c.x - 40 * s, y: c.y - 24 * s, width: 80 * s, height: 56 * s)), ink, 5)
    fill(circle(CGPoint(x: c.x + 30 * s, y: c.y - 28 * s), 22 * s), .white)
    stroke(circle(CGPoint(x: c.x + 30 * s, y: c.y - 28 * s), 22 * s), ink, 5)
    fill(circle(CGPoint(x: c.x + 26 * s, y: c.y - 54 * s), 10 * s), combRed)
    fill(poly([CGPoint(x: c.x + 48 * s, y: c.y - 32 * s), CGPoint(x: c.x + 66 * s, y: c.y - 26 * s), CGPoint(x: c.x + 48 * s, y: c.y - 20 * s)]), beak)
    fill(circle(CGPoint(x: c.x + 36 * s, y: c.y - 32 * s), 4 * s), ink)
}

func drawTutorials() {
    tutorialCanvas("tut_hop") {
        laneLines([140, 280])
        smallCar(40, 170, Col(hex: 0xE9E6E0))
        smallCar(460, 310, Col(hex: 0xFFC629))
        miniHen(CGPoint(x: 360, y: 370), 0.9)
        for i in 0..<3 { stroke(poly([CGPoint(x: 340, y: 300 - CGFloat(i) * 70), CGPoint(x: 360, y: 270 - CGFloat(i) * 70), CGPoint(x: 380, y: 300 - CGFloat(i) * 70)]), neonTeal, 10) }
    }
    tutorialCanvas("tut_roost") {
        fill(rr(CGRect(x: 0, y: 150, width: 720, height: 120), 30), Col(hex: 0x3F6B3A))
        stroke(rr(CGRect(x: 0, y: 150, width: 720, height: 120), 30), Col(hex: 0xD8D3C6), 6)
        miniHen(CGPoint(x: 300, y: 220), 1.1)
        for (i, x) in [450.0, 510.0, 570.0].enumerated() {
            fill(ellipse(CGRect(x: x, y: 170 - CGFloat(i) * 10, width: 44, height: 60)), cream)
            stroke(ellipse(CGRect(x: x, y: 170 - CGFloat(i) * 10, width: 44, height: 60)), ink, 5)
        }
        neonText("×1.4", CGPoint(x: 140, y: 80), size: 70, neonPink)
        neonText("ROOST!", CGPoint(x: 520, y: 360), size: 64, eggGold)
    }
    tutorialCanvas("tut_whistle") {
        laneLines([140, 280])
        smallCar(80, 170, Col(hex: 0xE9E6E0)); smallCar(420, 310, Col(hex: 0x2FB7A8))
        fill(CGPath(rect: CGRect(x: 0, y: 150, width: 720, height: 260), transform: nil), Col(hex: 0x6CD6FF, 0.18))
        neonText("FREEZE", CGPoint(x: 360, y: 80), size: 70, neonTeal)
        miniHen(CGPoint(x: 600, y: 120), 0.8)
    }
    tutorialCanvas("tut_truck") {
        laneLines([150, 290])
        let r = CGRect(x: 60, y: 180, width: 420, height: 90)
        fill(rr(r, 20), Col(hex: 0xD8402F)); stroke(rr(r, 20), ink, 6)
        fill(rr(CGRect(x: 70, y: 190, width: 280, height: 70), 10), Col(hex: 0x6B4A2E))
        for i in 0..<8 { fill(rr(CGRect(x: 80 + CGFloat(i) * 32, y: 205, width: 40, height: 18), 8), eggGold) }
        for i in 0..<4 { fill(ellipse(CGRect(x: 520 + CGFloat(i) * 40, y: 220 + CGFloat(i % 2) * 10, width: 24, height: 30)), eggGold) }
        neonText("HONK!", CGPoint(x: 560, y: 90), size: 70, sodium)
    }
    tutorialCanvas("tut_manhole") {
        manholeLid(CGPoint(x: 220, y: 230), 90, hot: 0.6)
        manholeLid(CGPoint(x: 520, y: 230), 90, hot: 1)
        ctx.saveGState(); ctx.translateBy(x: 520, y: 150); ctx.scaleBy(x: 0.5, y: 0.5)
        ctx.restoreGState()
        glow(CGPoint(x: 520, y: 150), 180, Col(hex: 0xFF6A00, 0.7))
        neonText("GLOW", CGPoint(x: 220, y: 70), size: 54, sodium)
        neonText("FLARE", CGPoint(x: 520, y: 70), size: 54, neonRed)
    }
    tutorialCanvas("tut_heat") {
        fill(CGPath(rect: CGRect(x: 0, y: 0, width: 720, height: 420), transform: nil), Col(hex: 0x5A2A1A, 0.4))
        for i in 0..<5 {
            let p = CGMutablePath(); p.move(to: CGPoint(x: 0, y: 120 + CGFloat(i) * 50))
            var x: CGFloat = 0
            while x < 720 { p.addQuadCurve(to: CGPoint(x: x + 80, y: 120 + CGFloat(i) * 50), control: CGPoint(x: x + 40, y: 105 + CGFloat(i) * 50)); x += 80 }
            stroke(p, Col(hex: 0xFF7A3D, 0.35), 6)
        }
        miniHen(CGPoint(x: 330, y: 260), 1.1)
        let tube = rr(CGRect(x: 560, y: 80, width: 50, height: 230), 25)
        fill(tube, .white); stroke(tube, ink, 6)
        fill(rr(CGRect(x: 572, y: 110, width: 26, height: 190), 13), neonRed)
        neonText("OUCH!", CGPoint(x: 200, y: 90), size: 64, sodium)
    }
}

// MARK: - App icon (1024 and 512, no alpha)

func drawIcon(size: Int) -> CGImage {
    begin(size, size)
    let s = CGFloat(size) / 1024
    ctx.scaleBy(x: s, y: s)
    let full = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    linearFill(CGPath(rect: full, transform: nil), [deepNight, nightBlue, Col(hex: 0x3A1E50)], .zero, CGPoint(x: 0, y: 1024), [0, 0.55, 1])
    // Road with zebra stripes, seen from above.
    fill(CGPath(rect: CGRect(x: 0, y: 470, width: 1024, height: 554), transform: nil), asphalt)
    for i in 0..<6 { fill(CGPath(rect: CGRect(x: 60 + CGFloat(i) * 160, y: 740, width: 100, height: 16), transform: nil), paint.alpha(0.55)) }
    // Headlight glow coming from the left.
    glow(CGPoint(x: 40, y: 860), 420, Col(hex: 0xFFF2B0, 0.55))
    // Neon multiplier above.
    neon(rr(CGRect(x: 250, y: 90, width: 524, height: 250), 60), neonPink, 16)
    neonText("×2.4", CGPoint(x: 512, y: 215), size: 170, eggGold, weight: .black)
    // Hen (reuse the hen painter at large scale).
    ctx.saveGState()
    ctx.translateBy(x: 170, y: 330)
    ctx.scaleBy(x: 2.3, y: 2.3)
    paintHenInPlace(HenLook(body: Col(hex: 0xF7F3EA), shade: Col(hex: 0xC9C0B0), wing: Col(hex: 0xE9E2D4), tail: Col(hex: 0xEDE6D8)))
    ctx.restoreGState()
    return ctx.makeImage()!
}

/// Renders a hen on its own canvas and composites it into the current (icon) canvas.
func paintHenInPlace(_ look: HenLook) {
    let saved = ctx!
    let savedSize = (canvasW, canvasH)
    begin(300, 300)
    drawHenBody(look)
    let hen = ctx.makeImage()!
    ctx = saved
    canvasW = savedSize.0; canvasH = savedSize.1
    ctx.saveGState()
    ctx.translateBy(x: 0, y: 300); ctx.scaleBy(x: 1, y: -1)
    ctx.draw(hen, in: CGRect(x: 0, y: 0, width: 300, height: 300))
    ctx.restoreGState()
}

func writeIcon(_ image: CGImage, _ url: URL) {
    // Flatten onto opaque background (App Store icons must not have alpha).
    let w = image.width, h = image.height
    let flat = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    flat.setFillColor(deepNight.cg); flat.fill(CGRect(x: 0, y: 0, width: w, height: h))
    flat.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, flat.makeImage()!, nil); CGImageDestinationFinalize(dest)
    print("icon \(url.path)")
}

// MARK: - Run

laneRow("row_lane", seed: 1, hot: false)
laneRow("row_lane_b", seed: 2, hot: false)
laneRow("row_lane_hot", seed: 3, hot: true)
curbRow("row_curb", seed: 4, finishLine: false)
curbRow("row_finish", seed: 5, finishLine: true)
islandRow()
drawCars()
drawHazards()
drawPickupsAndHUD()
drawHens()
drawUpgrades()
drawUIPieces()
drawBackdrops()
drawDistricts()
drawCameraAndLogo()
drawTutorials()

// App icon: written next to the asset catalog and to the icon folder given as the 3rd argument.
let iconDir = URL(fileURLWithPath: CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "./Icons")
try? fm.createDirectory(at: iconDir, withIntermediateDirectories: true)
writeIcon(drawIcon(size: 1024), iconDir.appendingPathComponent("CluckCrossing-1024.png"))
writeIcon(drawIcon(size: 512), iconDir.appendingPathComponent("CluckCrossing-512.png"))
print("done")
