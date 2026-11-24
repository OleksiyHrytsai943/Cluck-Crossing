// Cluck Crossing art generator (bright-day farm).
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

// MARK: - Cluck Crossing palette (bright-day farm)

let ink = Col(hex: 0x2B1A10)
let skyTop = Col(hex: 0x4FA8E8)
let skyLow = Col(hex: 0xC4E8FB)
let grass = Col(hex: 0x7CC04B)
let grassDark = Col(hex: 0x4E9A33)
let grassLight = Col(hex: 0xA7D96B)
let dirt = Col(hex: 0xB98A5B)
let dirtDark = Col(hex: 0x8C6440)
let dirtLight = Col(hex: 0xD3AA7A)
let gravelCol = Col(hex: 0xC9B79A)
let barnRed = Col(hex: 0xC8372D)
let barnRedDark = Col(hex: 0x922620)
let wood = Col(hex: 0xA8743F)
let woodDark = Col(hex: 0x6B4423)
let woodLight = Col(hex: 0xD6A86B)
let wheat = Col(hex: 0xF2C14E)
let hay = Col(hex: 0xE9C46A)
let cream = Col(hex: 0xFFF6E0)
let fenceWhite = Col(hex: 0xF7F3EA)
let water = Col(hex: 0x5BC0EB)
let chalkboard = Col(hex: 0x2E4A38)
let combRed = Col(hex: 0xE5243B)
let beak = Col(hex: 0xFFA31A)
let eggGold = wheat

let outlineW: CGFloat = 7

func noiseSpeckle(_ rect: CGRect, count: Int, seed: UInt64, light: Col, dark: Col, size: ClosedRange<CGFloat> = 1.5...4) {
    var g = Rng(s: seed)
    for _ in 0..<count {
        let p = CGPoint(x: g.r(rect.minX, rect.maxX), y: g.r(rect.minY, rect.maxY))
        let r = g.r(size.lowerBound, size.upperBound)
        fill(circle(p, r), g.next() > 0.5 ? light : dark)
    }
}

/// Painted sign lettering: fill with a dark outline (barn paint on wood).
func paintText(_ s: String, _ p: CGPoint, size: CGFloat, _ col: Col, outline: Col = ink) {
    for (dx, dy) in [(-3.0, 0.0), (3.0, 0.0), (0.0, -3.0), (0.0, 3.0), (3.0, 4.0)] {
        text(s, CGPoint(x: p.x + dx * size / 60, y: p.y + dy * size / 60), size: size, weight: .black, color: outline)
    }
    text(s, p, size: size, weight: .black, color: col)
}

/// Wooden plank texture inside a path.
func planks(_ path: CGPath, base: Col, horizontal: Bool = true, seed: UInt64 = 1, plank: CGFloat = 60) {
    let box = path.boundingBoxOfPath
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    fill(CGPath(rect: box, transform: nil), base)
    var g = Rng(s: seed)
    var v = horizontal ? box.minY : box.minX
    let end = horizontal ? box.maxY : box.maxX
    while v < end {
        let shade = base.mix(g.next() > 0.5 ? .white : ink, g.r(0.02, 0.12))
        let r = horizontal ? CGRect(x: box.minX, y: v, width: box.width, height: plank) : CGRect(x: v, y: box.minY, width: plank, height: box.height)
        fill(CGPath(rect: r, transform: nil), shade)
        // Grain lines.
        for _ in 0..<3 {
            let o = g.r(8, plank - 8)
            let line = horizontal ? poly([CGPoint(x: box.minX, y: v + o), CGPoint(x: box.maxX, y: v + o + g.r(-4, 4))]) : poly([CGPoint(x: v + o, y: box.minY), CGPoint(x: v + o + g.r(-4, 4), y: box.maxY)])
            stroke(line, ink.alpha(0.08), 2)
        }
        let seam = horizontal ? poly([CGPoint(x: box.minX, y: v), CGPoint(x: box.maxX, y: v)]) : poly([CGPoint(x: v, y: box.minY), CGPoint(x: v, y: box.maxY)])
        stroke(seam, ink.alpha(0.35), 3)
        v += plank
    }
    ctx.restoreGState()
}

func cloud(_ c: CGPoint, _ s: CGFloat) {
    let parts: [(CGFloat, CGFloat, CGFloat)] = [(-60, 10, 46), (-15, -14, 60), (40, 0, 50), (80, 18, 34), (-95, 26, 28)]
    let shape = CGMutablePath()
    for (dx, dy, r) in parts { shape.addPath(circle(CGPoint(x: c.x + dx * s, y: c.y + dy * s), r * s)) }
    shape.addPath(rr(CGRect(x: c.x - 110 * s, y: c.y + 10 * s, width: 210 * s, height: 44 * s), 22 * s))
    fill(shape, Col(hex: 0xDCEEFA))
    ctx.saveGState(); ctx.translateBy(x: 0, y: -8 * s); fill(shape, .white); ctx.restoreGState()
}

// MARK: - Road rows (1125 x 225 px = 375 x 75 pt, one row of 5 cells)

let rowW = 1125, rowH = 225

func dirtBase(_ seed: UInt64, tint: Col) {
    let r = CGRect(x: 0, y: 0, width: CGFloat(rowW), height: CGFloat(rowH))
    linearFill(CGPath(rect: r, transform: nil), [tint.lighter(0.06), tint, tint.darker(0.08)], .zero, CGPoint(x: 0, y: r.height))
    noiseSpeckle(r, count: 700, seed: seed, light: Col(1, 1, 1, 0.12), dark: ink.alpha(0.12), size: 1.5...5)
    // Tyre ruts.
    for y in [r.height * 0.33, r.height * 0.67] {
        let p = CGMutablePath(); p.move(to: CGPoint(x: 0, y: y))
        var x: CGFloat = 0
        var g = Rng(s: seed &+ UInt64(y))
        while x < r.width { x += 90; p.addLine(to: CGPoint(x: x, y: y + g.r(-4, 4))) }
        stroke(p, tint.darker(0.18).alpha(0.55), 16)
        stroke(p, tint.lighter(0.1).alpha(0.3), 4)
    }
}

func laneRow(_ name: String, seed: UInt64, tint: Col, hot: Bool) {
    begin(rowW, rowH)
    dirtBase(seed, tint: tint)
    if hot {
        // Sunbaked gravel: pebbles and heat shimmer.
        noiseSpeckle(CGRect(x: 0, y: 0, width: CGFloat(rowW), height: CGFloat(rowH)), count: 260, seed: seed &+ 3, light: Col(hex: 0xEDE2CC), dark: Col(hex: 0x9C8A70), size: 4...9)
        for i in 0..<3 {
            let y = CGFloat(50 + i * 60)
            let p = CGMutablePath(); p.move(to: CGPoint(x: 0, y: y))
            var x: CGFloat = 0
            while x < CGFloat(rowW) { p.addQuadCurve(to: CGPoint(x: x + 70, y: y), control: CGPoint(x: x + 35, y: y - 12)); x += 70 }
            stroke(p, Col(hex: 0xFF8A3D, 0.22), 6)
        }
    }
    // Grass tufts along the top edge separate the lanes.
    var g = Rng(s: seed &+ 9)
    fill(CGPath(rect: CGRect(x: 0, y: 0, width: CGFloat(rowW), height: 8), transform: nil), grassDark.alpha(0.55))
    for _ in 0..<26 {
        let x = g.r(0, CGFloat(rowW))
        for k in 0..<3 { stroke(poly([CGPoint(x: x + CGFloat(k) * 6, y: 10), CGPoint(x: x + CGFloat(k) * 6 + g.r(-6, 6), y: g.r(-4, 4))]), grassDark, 4) }
    }
    finish(name)
}

func grassField(_ r: CGRect, seed: UInt64) {
    linearFill(CGPath(rect: r, transform: nil), [grassLight, grass, grassDark.mix(grass, 0.5)], CGPoint(x: 0, y: r.minY), CGPoint(x: 0, y: r.maxY))
    var g = Rng(s: seed)
    for _ in 0..<Int(r.width * r.height / 900) {
        let x = g.r(r.minX, r.maxX), y = g.r(r.minY + 6, r.maxY)
        stroke(poly([CGPoint(x: x, y: y), CGPoint(x: x + g.r(-6, 6), y: y - g.r(8, 18))]), grassDark.alpha(0.6), 3)
    }
}

func daisy(_ c: CGPoint, _ s: CGFloat, petals: Col = .white) {
    for i in 0..<6 {
        let a = CGFloat(i) * .pi / 3
        fill(circle(CGPoint(x: c.x + cos(a) * 8 * s, y: c.y + sin(a) * 8 * s), 6 * s), petals)
    }
    fill(circle(c, 5 * s), wheat)
}

func curbRow(_ name: String, seed: UInt64, finishLine: Bool) {
    begin(rowW, rowH)
    let r = CGRect(x: 0, y: 0, width: CGFloat(rowW), height: CGFloat(rowH))
    if finishLine {
        // Coop yard: straw with a painted HOME banner and eggs.
        fill(CGPath(rect: r, transform: nil), hay)
        var g = Rng(s: seed)
        for _ in 0..<500 {
            let x = g.r(0, r.width), y = g.r(0, r.height)
            stroke(poly([CGPoint(x: x, y: y), CGPoint(x: x + g.r(-24, 24), y: y + g.r(-6, 6))]), Col(hex: 0xC9A04A), 3)
        }
        let banner = rr(CGRect(x: 340, y: 60, width: 445, height: 100), 16)
        planks(banner, base: barnRed, horizontal: false, seed: 3, plank: 55)
        stroke(banner, fenceWhite, 8)
        stroke(banner, ink, 3)
        paintText("HOME", CGPoint(x: 562, y: 110), size: 64, cream)
        for x in [120.0, 230.0, 895.0, 1005.0] {
            let e = ellipse(CGRect(x: x - 24, y: 82, width: 48, height: 62))
            fill(e, cream); stroke(e, ink, 5)
        }
    } else {
        grassField(r, seed: seed)
        var g = Rng(s: seed &+ 1)
        for _ in 0..<22 { daisy(CGPoint(x: g.r(20, r.width - 20), y: g.r(30, r.height - 20)), g.r(0.7, 1.1), petals: g.next() > 0.7 ? Col(hex: 0xFFE27A) : .white) }
    }
    finish(name)
}

func hayBale(_ r: CGRect) {
    shadowed(5, 8, ink.alpha(0.35)) { fill(rr(r, 14), hay) }
    var g = Rng(s: UInt64(r.minX))
    ctx.saveGState(); ctx.addPath(rr(r, 14)); ctx.clip()
    for _ in 0..<60 {
        let x = g.r(r.minX, r.maxX), y = g.r(r.minY, r.maxY)
        stroke(poly([CGPoint(x: x, y: y), CGPoint(x: x + g.r(-20, 20), y: y + g.r(-5, 5))]), Col(hex: 0xC9A04A), 3)
    }
    ctx.restoreGState()
    for f in [0.3, 0.7] { stroke(poly([CGPoint(x: r.minX + r.width * CGFloat(f), y: r.minY), CGPoint(x: r.minX + r.width * CGFloat(f), y: r.maxY)]), barnRed, 5) }
    stroke(rr(r, 14), ink, 5)
}

func islandRow() {
    begin(rowW, rowH)
    let r = CGRect(x: 0, y: 0, width: CGFloat(rowW), height: CGFloat(rowH))
    dirtBase(91, tint: dirt)
    let strip = CGRect(x: 0, y: 22, width: r.width, height: r.height - 44)
    grassField(strip, seed: 92)
    var g = Rng(s: 93)
    for _ in 0..<14 { daisy(CGPoint(x: g.r(180, r.width - 180), y: g.r(strip.minY + 20, strip.maxY - 16)), 0.8) }
    hayBale(CGRect(x: 10, y: strip.minY + 18, width: 140, height: strip.height - 36))
    hayBale(CGRect(x: r.width - 150, y: strip.minY + 18, width: 140, height: strip.height - 36))
    stroke(poly([CGPoint(x: 0, y: strip.minY), CGPoint(x: r.width, y: strip.minY)]), grassDark, 5)
    stroke(poly([CGPoint(x: 0, y: strip.maxY), CGPoint(x: r.width, y: strip.maxY)]), grassDark, 5)
    finish("row_island")
}

// MARK: - Farm vehicles (top-down, facing right). Length ratio matches CarKind.length.

func vehicleCanvas(_ name: String, lengthCells: CGFloat, _ draw: (CGRect) -> Void) {
    let w = Int(lengthCells * 225), h = 170
    begin(w, h)
    draw(CGRect(x: 8, y: 14, width: CGFloat(w) - 16, height: CGFloat(h) - 28))
    finish(name)
}

func wheel(_ r: CGRect) { fill(rr(r, 8), ink); stroke(rr(r.insetBy(dx: 4, dy: 3), 5), Col(hex: 0x4A3A30), 3) }

func headlights(_ r: CGRect) {
    for y in [r.minY + 22, r.maxY - 22] {
        fill(rr(CGRect(x: r.maxX - 14, y: y - 9, width: 10, height: 18), 4), Col(hex: 0xFFF2B0))
        fill(rr(CGRect(x: r.minX + 2, y: y - 8, width: 8, height: 16), 3), combRed)
    }
}

func drawVehicles() {
    // Pickup: light body (tinted in the scene), cab at the front, open bed with a crate.
    vehicleCanvas("car_pickup", lengthCells: 1.15) { r in
        for x in [r.minX + r.width * 0.2, r.maxX - r.width * 0.2] { wheel(CGRect(x: x - 22, y: r.minY - 8, width: 44, height: 16)); wheel(CGRect(x: x - 22, y: r.maxY - 8, width: 44, height: 16)) }
        shadowed(6, 10, ink.alpha(0.45)) { fill(rr(r, 26), Col(hex: 0xF2EEE6)) }
        linearFill(rr(r, 26), [.white, Col(hex: 0xEDE7DC), Col(hex: 0xCFC6B8)], CGPoint(x: 0, y: r.minY), CGPoint(x: 0, y: r.maxY))
        let bed = CGRect(x: r.minX + 10, y: r.minY + 14, width: r.width * 0.5, height: r.height - 28)
        fill(rr(bed, 8), Col(hex: 0x8A8378)); stroke(rr(bed, 8), ink, 4)
        let crate = CGRect(x: bed.minX + 18, y: bed.midY - 26, width: 56, height: 52)
        planks(rr(crate, 4), base: woodLight, horizontal: true, seed: 2, plank: 17); stroke(rr(crate, 4), ink, 3)
        let cab = CGRect(x: r.minX + r.width * 0.6, y: r.minY + 16, width: r.width * 0.3, height: r.height - 32)
        fill(rr(cab, 14), Col(hex: 0xDAD3C6)); stroke(rr(cab, 14), ink.alpha(0.7), 3)
        fill(rr(CGRect(x: cab.maxX - 18, y: cab.minY + 6, width: 14, height: cab.height - 12), 6), water.alpha(0.85))
        stroke(rr(r, 26), ink, outlineW)
        headlights(r)
    }
    // Tractor: green, big rear wheels, small front wheels, exhaust stack and yellow seat.
    vehicleCanvas("car_tractor", lengthCells: 1.15) { r in
        let green = Col(hex: 0x3F9B3A)
        wheel(CGRect(x: r.minX + 6, y: r.minY - 12, width: 86, height: 30)); wheel(CGRect(x: r.minX + 6, y: r.maxY - 18, width: 86, height: 30))
        wheel(CGRect(x: r.maxX - 62, y: r.minY + 2, width: 44, height: 18)); wheel(CGRect(x: r.maxX - 62, y: r.maxY - 20, width: 44, height: 18))
        let body = CGRect(x: r.minX + 30, y: r.minY + 26, width: r.width - 40, height: r.height - 52)
        shadowed(6, 10, ink.alpha(0.45)) { fill(rr(body, 18), green) }
        linearFill(rr(body, 18), [green.lighter(0.25), green, green.darker(0.2)], CGPoint(x: 0, y: body.minY), CGPoint(x: 0, y: body.maxY))
        stroke(rr(body, 18), ink, outlineW)
        // Hood louvres.
        for i in 0..<4 { stroke(poly([CGPoint(x: body.maxX - 30 - CGFloat(i) * 14, y: body.minY + 14), CGPoint(x: body.maxX - 30 - CGFloat(i) * 14, y: body.maxY - 14)]), ink.alpha(0.4), 4) }
        fill(circle(CGPoint(x: body.minX + 40, y: body.midY), 22), wheat); stroke(circle(CGPoint(x: body.minX + 40, y: body.midY), 22), ink, 4)
        fill(circle(CGPoint(x: body.midX + 18, y: body.minY + 16), 10), Col(hex: 0x3A3A3A)); stroke(circle(CGPoint(x: body.midX + 18, y: body.minY + 16), 10), ink, 3)
        fill(rr(CGRect(x: body.maxX - 8, y: body.midY - 22, width: 12, height: 44), 4), Col(hex: 0xFFF2B0))
    }
    // Milk van: white with cow spots.
    vehicleCanvas("car_milkVan", lengthCells: 1.5) { r in
        for x in [r.minX + r.width * 0.18, r.maxX - r.width * 0.2] { wheel(CGRect(x: x - 22, y: r.minY - 8, width: 44, height: 16)); wheel(CGRect(x: x - 22, y: r.maxY - 8, width: 44, height: 16)) }
        shadowed(6, 10, ink.alpha(0.45)) { fill(rr(r, 26), .white) }
        ctx.saveGState(); ctx.addPath(rr(r, 26)); ctx.clip()
        var g = Rng(s: 41)
        for _ in 0..<7 {
            let c = CGPoint(x: g.r(r.minX + 20, r.maxX - 80), y: g.r(r.minY, r.maxY))
            let spot = CGMutablePath()
            for k in 0..<3 { spot.addPath(circle(CGPoint(x: c.x + CGFloat(k) * 12, y: c.y + g.r(-10, 10)), g.r(12, 22))) }
            fill(spot, ink)
        }
        ctx.restoreGState()
        let cab = CGRect(x: r.maxX - 70, y: r.minY + 14, width: 54, height: r.height - 28)
        fill(rr(cab, 12), Col(hex: 0x6FB7E8)); stroke(rr(cab, 12), ink, 4)
        stroke(rr(r, 26), ink, outlineW)
        headlights(r)
    }
    // Combine harvester: yellow body, red reel header at the front.
    vehicleCanvas("car_combine", lengthCells: 2.3) { r in
        let yellow = Col(hex: 0xF4C430)
        let header = CGRect(x: r.maxX - 70, y: r.minY - 8, width: 62, height: r.height + 16)
        let body = CGRect(x: r.minX + 10, y: r.minY + 14, width: r.width - 90, height: r.height - 28)
        wheel(CGRect(x: body.minX + 30, y: body.minY - 16, width: 90, height: 26)); wheel(CGRect(x: body.minX + 30, y: body.maxY - 10, width: 90, height: 26))
        shadowed(6, 10, ink.alpha(0.45)) { fill(rr(body, 18), yellow) }
        linearFill(rr(body, 18), [yellow.lighter(0.3), yellow, yellow.darker(0.2)], CGPoint(x: 0, y: body.minY), CGPoint(x: 0, y: body.maxY))
        stroke(rr(body, 18), ink, outlineW)
        let cab = CGRect(x: body.maxX - 110, y: body.midY - 34, width: 80, height: 68)
        fill(rr(cab, 12), water.alpha(0.8)); stroke(rr(cab, 12), ink, 4)
        fill(rr(CGRect(x: body.minX + 30, y: body.midY - 18, width: 140, height: 36), 10), Col(hex: 0xD9A80F)); stroke(rr(CGRect(x: body.minX + 30, y: body.midY - 18, width: 140, height: 36), 10), ink, 3)
        fill(rr(header, 10), barnRed); stroke(rr(header, 10), ink, 5)
        for i in 0..<7 { stroke(poly([CGPoint(x: header.minX + 6, y: header.minY + 10 + CGFloat(i) * 26), CGPoint(x: header.maxX - 6, y: header.minY + 20 + CGFloat(i) * 26)]), wheat, 5) }
    }
    // Corn truck: red cab + wooden flatbed piled with cobs.
    vehicleCanvas("car_cornTruck", lengthCells: 2.6) { r in
        for x in [r.minX + r.width * 0.15, r.minX + r.width * 0.5, r.maxX - r.width * 0.12] { wheel(CGRect(x: x - 24, y: r.minY - 8, width: 48, height: 16)); wheel(CGRect(x: x - 24, y: r.maxY - 8, width: 48, height: 16)) }
        let bed = CGRect(x: r.minX + 4, y: r.minY + 6, width: r.width * 0.7, height: r.height - 12)
        shadowed(6, 10, ink.alpha(0.45)) { fill(rr(bed, 10), wood) }
        planks(rr(bed, 10), base: wood, horizontal: false, seed: 5, plank: 46)
        stroke(rr(bed, 10), ink, 6)
        var g = Rng(s: 77)
        for _ in 0..<26 {
            let c = CGPoint(x: g.r(bed.minX + 28, bed.maxX - 28), y: g.r(bed.minY + 22, bed.maxY - 22))
            let cob = CGRect(x: c.x - 26, y: c.y - 11, width: 52, height: 22)
            ctx.saveGState(); ctx.translateBy(x: c.x, y: c.y); ctx.rotate(by: g.r(-0.6, 0.6)); ctx.translateBy(x: -c.x, y: -c.y)
            fill(rr(cob, 11), wheat); stroke(rr(cob, 11), Col(hex: 0xB07A10), 3)
            fill(rr(CGRect(x: cob.minX - 6, y: cob.minY + 2, width: 14, height: 18), 6), grass)
            ctx.restoreGState()
        }
        let cab = CGRect(x: bed.maxX + 10, y: r.minY + 12, width: r.maxX - bed.maxX - 16, height: r.height - 24)
        shadowed(6, 10, ink.alpha(0.45)) { fill(rr(cab, 18), barnRed) }
        linearFill(rr(cab, 18), [barnRed.lighter(0.2), barnRed, barnRedDark], CGPoint(x: 0, y: cab.minY), CGPoint(x: 0, y: cab.maxY))
        fill(rr(CGRect(x: cab.maxX - 30, y: cab.minY + 10, width: 18, height: cab.height - 20), 6), water.alpha(0.85))
        stroke(rr(cab, 18), ink, outlineW)
        headlights(CGRect(x: cab.minX, y: r.minY, width: cab.width, height: r.height))
    }
}

// MARK: - Hazards & pickups (300 x 300 = 100 pt)

func iconCanvas(_ name: String, _ size: Int = 300, _ draw: () -> Void) { begin(size, size); draw(); finish(name) }

func sprinklerHead(_ c: CGPoint, _ s: CGFloat, wet: CGFloat) {
    // Damp soil patch.
    fill(ellipse(CGRect(x: c.x - 100 * s, y: c.y - 50 * s, width: 200 * s, height: 110 * s)), dirtDark.mix(water, wet * 0.5).alpha(0.75))
    if wet > 0 {
        fill(ellipse(CGRect(x: c.x - 80 * s, y: c.y - 30 * s, width: 160 * s, height: 70 * s)), water.alpha(0.45 * wet))
        var g = Rng(s: 8)
        for _ in 0..<10 {
            let p = CGPoint(x: c.x + g.r(-90, 90) * s, y: c.y + g.r(-70, 10) * s)
            let drop = ellipse(CGRect(x: p.x - 7 * s, y: p.y - 10 * s, width: 14 * s, height: 20 * s))
            fill(drop, water); stroke(drop, ink.alpha(0.6), 2)
        }
    }
    // Brass riser + rotating head.
    let riser = rr(CGRect(x: c.x - 16 * s, y: c.y - 40 * s, width: 32 * s, height: 56 * s), 8 * s)
    linearFill(riser, [Col(hex: 0xF3D27A), Col(hex: 0xC9962E)], CGPoint(x: c.x - 16 * s, y: 0), CGPoint(x: c.x + 16 * s, y: 0))
    stroke(riser, ink, 5)
    let head = rr(CGRect(x: c.x - 46 * s, y: c.y - 58 * s, width: 92 * s, height: 26 * s), 12 * s)
    linearFill(head, [Col(hex: 0xF3D27A), Col(hex: 0xB9862A)], CGPoint(x: 0, y: c.y - 58 * s), CGPoint(x: 0, y: c.y - 32 * s))
    stroke(head, ink, 5)
    fill(circle(CGPoint(x: c.x + 40 * s, y: c.y - 45 * s), 7 * s), ink)
}

func drawHazards() {
    iconCanvas("sprinkler") { sprinklerHead(CGPoint(x: 150, y: 190), 1, wet: 0) }
    iconCanvas("sprinkler_gurgle") { sprinklerHead(CGPoint(x: 150, y: 190), 1, wet: 1) }
    // Spray: tall fan of water, drawn upward from the head (bottom of canvas).
    begin(300, 450)
    let base = CGPoint(x: 150, y: 400)
    for (i, (half, height, a)) in [(130.0, 390.0, 0.35), (95.0, 340.0, 0.55), (55.0, 280.0, 0.8)].enumerated() {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: base.x - 12, y: base.y))
        p.addCurve(to: CGPoint(x: base.x - half, y: base.y - height * 0.75), control1: CGPoint(x: base.x - half * 0.3, y: base.y - height * 0.6), control2: CGPoint(x: base.x - half * 0.8, y: base.y - height))
        p.addQuadCurve(to: CGPoint(x: base.x + half, y: base.y - height * 0.75), control: CGPoint(x: base.x, y: base.y - height * 1.15))
        p.addCurve(to: CGPoint(x: base.x + 12, y: base.y), control1: CGPoint(x: base.x + half * 0.8, y: base.y - height), control2: CGPoint(x: base.x + half * 0.3, y: base.y - height * 0.6))
        p.closeSubpath()
        fill(p, (i == 2 ? Col(hex: 0xE8F7FF) : water).alpha(CGFloat(a)))
        stroke(p, Col(hex: 0x2A86C2).alpha(0.6), 3)
    }
    var g = Rng(s: 12)
    for _ in 0..<24 {
        let p = CGPoint(x: g.r(20, 280), y: g.r(20, 300))
        fill(ellipse(CGRect(x: p.x - 6, y: p.y - 9, width: 12, height: 18)), Col(hex: 0xBFE9FF))
    }
    finish("spray")

    iconCanvas("kernel") {
        var g = Rng(s: 5)
        for _ in 0..<11 {
            let c = CGPoint(x: g.r(80, 220), y: g.r(120, 210))
            let k = CGMutablePath()
            k.move(to: CGPoint(x: c.x, y: c.y - 30))
            k.addQuadCurve(to: CGPoint(x: c.x + 22, y: c.y + 14), control: CGPoint(x: c.x + 26, y: c.y - 18))
            k.addQuadCurve(to: CGPoint(x: c.x - 22, y: c.y + 14), control: CGPoint(x: c.x, y: c.y + 30))
            k.addQuadCurve(to: CGPoint(x: c.x, y: c.y - 30), control: CGPoint(x: c.x - 26, y: c.y - 18))
            linearFill(k, [Col(hex: 0xFFF0A0), wheat, Col(hex: 0xE89A10)], CGPoint(x: c.x, y: c.y - 30), CGPoint(x: c.x, y: c.y + 24))
            stroke(k, ink, 5)
            fill(ellipse(CGRect(x: c.x - 6, y: c.y - 18, width: 10, height: 14)), Col(1, 1, 1, 0.7))
        }
    }
}

func featherShape() -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 150, y: 20))
    p.addCurve(to: CGPoint(x: 150, y: 250), control1: CGPoint(x: 245, y: 90), control2: CGPoint(x: 200, y: 210))
    p.addCurve(to: CGPoint(x: 150, y: 20), control1: CGPoint(x: 100, y: 210), control2: CGPoint(x: 55, y: 90))
    return p
}

func farmBell(_ c: CGPoint, _ s: CGFloat) {
    // Wooden yoke.
    let yoke = rr(CGRect(x: c.x - 110 * s, y: c.y - 120 * s, width: 220 * s, height: 34 * s), 10 * s)
    planks(yoke, base: wood, horizontal: true, seed: 4, plank: 17 * s); stroke(yoke, ink, 5)
    // Bell body.
    let bell = CGMutablePath()
    bell.move(to: CGPoint(x: c.x - 34 * s, y: c.y - 86 * s))
    bell.addCurve(to: CGPoint(x: c.x - 92 * s, y: c.y + 60 * s), control1: CGPoint(x: c.x - 60 * s, y: c.y - 70 * s), control2: CGPoint(x: c.x - 54 * s, y: c.y + 30 * s))
    bell.addLine(to: CGPoint(x: c.x + 92 * s, y: c.y + 60 * s))
    bell.addCurve(to: CGPoint(x: c.x + 34 * s, y: c.y - 86 * s), control1: CGPoint(x: c.x + 54 * s, y: c.y + 30 * s), control2: CGPoint(x: c.x + 60 * s, y: c.y - 70 * s))
    bell.closeSubpath()
    shadowed(6, 10, ink.alpha(0.45)) { fill(bell, Col(hex: 0xD8A23A)) }
    linearFill(bell, [Col(hex: 0xFFE7A0), Col(hex: 0xE2AE45), Col(hex: 0x9C6B12)], CGPoint(x: c.x - 90 * s, y: 0), CGPoint(x: c.x + 90 * s, y: 0), [0, 0.45, 1])
    stroke(bell, ink, outlineW)
    fill(rr(CGRect(x: c.x - 100 * s, y: c.y + 52 * s, width: 200 * s, height: 22 * s), 10 * s), Col(hex: 0xB9862A)); stroke(rr(CGRect(x: c.x - 100 * s, y: c.y + 52 * s, width: 200 * s, height: 22 * s), 10 * s), ink, 5)
    fill(circle(CGPoint(x: c.x, y: c.y + 88 * s), 18 * s), Col(hex: 0x8C6418)); stroke(circle(CGPoint(x: c.x, y: c.y + 88 * s), 18 * s), ink, 5)
}

func woodSign(_ r: CGRect, base: Col) {
    shadowed(6, 10, ink.alpha(0.45)) { fill(rr(r, 24), base) }
    planks(rr(r, 24), base: base, horizontal: true, seed: 6, plank: r.height / 3)
    stroke(rr(r, 24), ink, 7)
    for p in [CGPoint(x: r.minX + 22, y: r.minY + 22), CGPoint(x: r.maxX - 22, y: r.minY + 22), CGPoint(x: r.minX + 22, y: r.maxY - 22), CGPoint(x: r.maxX - 22, y: r.maxY - 22)] {
        fill(circle(p, 7), Col(hex: 0x5A5A5A)); stroke(circle(p, 7), ink, 2)
    }
}

func drawPickupsAndHUD() {
    iconCanvas("coin") {
        let c = CGPoint(x: 150, y: 150)
        shadowed(6, 10, ink.alpha(0.45)) { fill(circle(c, 120), Col(hex: 0xE0A21A)) }
        radialFill(circle(c, 120), [Col(hex: 0xFFE98A), wheat, Col(hex: 0xD88A10)], CGPoint(x: 115, y: 110), 170)
        stroke(circle(c, 120), ink, outlineW + 2)
        stroke(circle(c, 92), Col(hex: 0xB0700A), 6)
        let egg = ellipse(CGRect(x: 112, y: 92, width: 76, height: 104))
        fill(egg, Col(hex: 0xFFF3C0)); stroke(egg, Col(hex: 0xB0700A), 6)
    }
    iconCanvas("egg") {
        let egg = ellipse(CGRect(x: 80, y: 40, width: 140, height: 200))
        shadowed(8, 14, ink.alpha(0.4)) { fill(egg, cream) }
        radialFill(egg, [.white, cream, Col(hex: 0xE8C98E)], CGPoint(x: 125, y: 100), 170)
        stroke(egg, ink, outlineW + 1)
        fill(ellipse(CGRect(x: 110, y: 75, width: 30, height: 46)), Col(1, 1, 1, 0.8))
    }
    iconCanvas("feather") {
        ctx.saveGState(); ctx.translateBy(x: 150, y: 150); ctx.rotate(by: -0.6); ctx.translateBy(x: -150, y: -150)
        shadowed(6, 10, ink.alpha(0.4)) { fill(featherShape(), .white) }
        linearFill(featherShape(), [.white, Col(hex: 0xF3E6D0)], CGPoint(x: 120, y: 20), CGPoint(x: 180, y: 250))
        stroke(featherShape(), ink, outlineW)
        stroke(poly([CGPoint(x: 150, y: 40), CGPoint(x: 150, y: 285)]), ink, 7)
        for i in 0..<5 {
            let y = CGFloat(80 + i * 32)
            stroke(poly([CGPoint(x: 150, y: y), CGPoint(x: 115, y: y - 18)]), Col(hex: 0xCFC3AE), 4)
            stroke(poly([CGPoint(x: 150, y: y), CGPoint(x: 185, y: y - 18)]), Col(hex: 0xCFC3AE), 4)
        }
        ctx.restoreGState()
    }
    iconCanvas("feather_empty") {
        ctx.saveGState(); ctx.translateBy(x: 150, y: 150); ctx.rotate(by: -0.6); ctx.translateBy(x: -150, y: -150)
        fill(featherShape(), Col(1, 1, 1, 0.15))
        ctx.setLineDash(phase: 0, lengths: [14, 10]); stroke(featherShape(), Col(1, 1, 1, 0.55), 6); ctx.setLineDash(phase: 0, lengths: [])
        ctx.restoreGState()
    }
    iconCanvas("grain_token") { farmBell(CGPoint(x: 150, y: 160), 1.05) }
    iconCanvas("nest") {
        let bowl = CGMutablePath()
        bowl.move(to: CGPoint(x: 30, y: 150)); bowl.addQuadCurve(to: CGPoint(x: 270, y: 150), control: CGPoint(x: 150, y: 300)); bowl.closeSubpath()
        shadowed(6, 12, ink.alpha(0.45)) { fill(bowl, Col(hex: 0x8A5A2B)) }
        for (x, y) in [(110.0, 120.0), (150.0, 105.0), (190.0, 122.0)] {
            let e = ellipse(CGRect(x: x - 32, y: y - 44, width: 64, height: 86))
            radialFill(e, [.white, cream, Col(hex: 0xE8C98E)], CGPoint(x: x - 10, y: y - 20), 80); stroke(e, ink, 6)
        }
        fill(bowl, hay)
        var g = Rng(s: 3)
        for _ in 0..<26 {
            let a = CGPoint(x: g.r(40, 260), y: g.r(150, 220))
            stroke(poly([a, CGPoint(x: a.x + g.r(-60, 60), y: a.y + g.r(-14, 14))]), Col(hex: 0xC9A04A), 5)
        }
        stroke(bowl, ink, outlineW)
    }
    iconCanvas("thermometer") {
        let tube = rr(CGRect(x: 120, y: 30, width: 60, height: 190), 30)
        fill(tube, Col(1, 1, 1, 0.95)); stroke(tube, ink, outlineW)
        fill(rr(CGRect(x: 138, y: 90, width: 24, height: 150), 12), barnRed)
        fill(circle(CGPoint(x: 150, y: 235), 48), barnRed); stroke(circle(CGPoint(x: 150, y: 235), 48), ink, outlineW)
    }
    // Wooden multiplier signs (text drawn by the scene).
    iconCanvas("plaque", 360) { woodSign(CGRect(x: 26, y: 80, width: 308, height: 200), base: woodLight) }
    iconCanvas("plaque_hot", 360) { woodSign(CGRect(x: 26, y: 80, width: 308, height: 200), base: Col(hex: 0xF2B36B)) }
}

// MARK: - Upgrades (Feed Store goods, 300 x 300)

func drawUpgrades() {
    iconCanvas("upgrade_coolFeet") {
        // Mud socks: a pair of woolly socks dipped in cool mud.
        for (dx, rot) in [(-45.0, -0.15), (45.0, 0.15)] {
            ctx.saveGState(); ctx.translateBy(x: 150 + dx, y: 150); ctx.rotate(by: rot)
            let sock = CGMutablePath()
            sock.move(to: CGPoint(x: -30, y: -110)); sock.addLine(to: CGPoint(x: 30, y: -110)); sock.addLine(to: CGPoint(x: 30, y: 40))
            sock.addQuadCurve(to: CGPoint(x: -10, y: 110), control: CGPoint(x: 40, y: 110)); sock.addQuadCurve(to: CGPoint(x: -30, y: 40), control: CGPoint(x: -40, y: 90)); sock.closeSubpath()
            shadowed(5, 8, ink.alpha(0.4)) { fill(sock, cream) }
            ctx.saveGState(); ctx.addPath(sock); ctx.clip()
            for i in 0..<4 { fill(CGPath(rect: CGRect(x: -40, y: -110 + CGFloat(i) * 20, width: 80, height: 9), transform: nil), barnRed) }
            fill(CGPath(rect: CGRect(x: -50, y: 30, width: 120, height: 90), transform: nil), Col(hex: 0x6B4A2E))
            ctx.restoreGState()
            stroke(sock, ink, 6)
            ctx.restoreGState()
        }
        for (x, y) in [(70.0, 250.0), (225.0, 255.0), (150.0, 268.0)] { fill(ellipse(CGRect(x: x - 16, y: y - 8, width: 32, height: 16)), Col(hex: 0x6B4A2E)) }
    }
    iconCanvas("upgrade_bigBell") { farmBell(CGPoint(x: 150, y: 160), 1.1) }
    iconCanvas("upgrade_bigBasket") {
        let basket = poly([CGPoint(x: 50, y: 140), CGPoint(x: 250, y: 140), CGPoint(x: 220, y: 255), CGPoint(x: 80, y: 255)])
        for (x, y) in [(105.0, 115.0), (150.0, 100.0), (195.0, 118.0)] {
            let e = ellipse(CGRect(x: x - 30, y: y - 40, width: 60, height: 80))
            radialFill(e, [.white, cream, Col(hex: 0xE8C98E)], CGPoint(x: x - 10, y: y - 16), 70); stroke(e, ink, 5)
        }
        shadowed(6, 12, ink.alpha(0.45)) { fill(basket, Col(hex: 0xB9813F)) }
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
        shadowed(6, 12, ink.alpha(0.45)) { fill(featherShape(), Col(hex: 0xC97A3A)) }
        linearFill(featherShape(), [Col(hex: 0xF0B070), Col(hex: 0xB55A24)], CGPoint(x: 120, y: 20), CGPoint(x: 180, y: 250))
        stroke(featherShape(), ink, outlineW)
        stroke(poly([CGPoint(x: 150, y: 40), CGPoint(x: 150, y: 285)]), ink, 7)
        ctx.restoreGState()
        fill(circle(CGPoint(x: 232, y: 230), 40), grassDark); stroke(circle(CGPoint(x: 232, y: 230), 40), ink, 6)
        text("+1", CGPoint(x: 232, y: 230), size: 40, weight: .black, color: .white)
    }
    iconCanvas("upgrade_cornPouch") {
        // Burlap feed sack.
        let bag = CGMutablePath()
        bag.move(to: CGPoint(x: 80, y: 80))
        bag.addCurve(to: CGPoint(x: 70, y: 262), control1: CGPoint(x: 50, y: 140), control2: CGPoint(x: 40, y: 230))
        bag.addLine(to: CGPoint(x: 230, y: 262))
        bag.addCurve(to: CGPoint(x: 220, y: 80), control1: CGPoint(x: 260, y: 230), control2: CGPoint(x: 250, y: 140))
        bag.closeSubpath()
        shadowed(6, 12, ink.alpha(0.45)) { fill(bag, Col(hex: 0xD2B07E)) }
        linearFill(bag, [Col(hex: 0xE6CB9C), Col(hex: 0xB38F5C)], CGPoint(x: 80, y: 80), CGPoint(x: 220, y: 262))
        ctx.saveGState(); ctx.addPath(bag); ctx.clip()
        for i in 0..<20 { stroke(poly([CGPoint(x: 40 + CGFloat(i) * 12, y: 60), CGPoint(x: 40 + CGFloat(i) * 12, y: 280)]), ink.alpha(0.06), 3) }
        ctx.restoreGState()
        stroke(bag, ink, outlineW)
        stroke(poly([CGPoint(x: 86, y: 92), CGPoint(x: 214, y: 92)]), barnRed, 10)
        for (x, y) in [(125.0, 68.0), (152.0, 58.0), (180.0, 70.0)] { let k = ellipse(CGRect(x: x - 16, y: y - 20, width: 32, height: 40)); fill(k, wheat); stroke(k, ink, 4) }
        text("FEED", CGPoint(x: 150, y: 185), size: 50, weight: .black, color: barnRedDark)
    }
}

// MARK: - UI pieces

func drawUIPieces() {
    // Wooden finger sign for the signpost (900 x 210 = 300 x 70 pt), points right.
    begin(900, 210)
    let plank = poly([CGPoint(x: 10, y: 22), CGPoint(x: 790, y: 22), CGPoint(x: 885, y: 105), CGPoint(x: 790, y: 188), CGPoint(x: 10, y: 188)])
    shadowed(8, 12, ink.alpha(0.5)) { fill(plank, wood) }
    planks(plank, base: Col(hex: 0x9A6334), horizontal: true, seed: 7, plank: 56)
    stroke(plank, ink, 7)
    for p in [CGPoint(x: 40, y: 105), CGPoint(x: 740, y: 105)] { fill(circle(p, 9), Col(hex: 0x5A5A5A)); stroke(circle(p, 9), ink, 3) }
    finish("sign_plank")

    // Little wooden gate (back button), 240 x 300.
    begin(240, 300)
    for x in [30.0, 190.0] { let post = rr(CGRect(x: x, y: 20, width: 24, height: 260), 6); fill(post, woodDark); stroke(post, ink, 5) }
    for y in [70.0, 150.0, 230.0] { let rail = rr(CGRect(x: 40, y: y, width: 170, height: 24), 6); fill(rail, fenceWhite); stroke(rail, ink, 5) }
    stroke(poly([CGPoint(x: 52, y: 240), CGPoint(x: 200, y: 82)]), fenceWhite, 18); stroke(poly([CGPoint(x: 52, y: 240), CGPoint(x: 200, y: 82)]), ink, 3)
    finish("push_button")

    // GO sign: green round road sign with a walking hen.
    iconCanvas("signal_walk") {
        let c = CGPoint(x: 150, y: 150)
        shadowed(8, 12, ink.alpha(0.45)) { fill(circle(c, 124), fenceWhite) }
        stroke(circle(c, 124), ink, 7)
        fill(circle(c, 108), grassDark.mix(Col(hex: 0x2F7A3D), 0.5))
        let h = Col(hex: 0xFFFFFF)
        fill(ellipse(CGRect(x: 95, y: 130, width: 100, height: 70)), h)
        fill(circle(CGPoint(x: 190, y: 115), 26), h)
        fill(poly([CGPoint(x: 212, y: 110), CGPoint(x: 238, y: 118), CGPoint(x: 212, y: 126)]), wheat)
        fill(circle(CGPoint(x: 185, y: 88), 11), combRed)
        stroke(poly([CGPoint(x: 130, y: 195), CGPoint(x: 115, y: 232)]), h, 10)
        stroke(poly([CGPoint(x: 160, y: 195), CGPoint(x: 178, y: 232)]), h, 10)
        fill(poly([CGPoint(x: 100, y: 150), CGPoint(x: 66, y: 120), CGPoint(x: 92, y: 170)]), h)
    }
    // STOP sign: red octagon.
    iconCanvas("signal_stop") {
        let c = CGPoint(x: 150, y: 150)
        func octagon(_ r: CGFloat) -> CGPath { poly((0..<8).map { i in let a = CGFloat(i) * .pi / 4 + .pi / 8; return CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r) }) }
        shadowed(8, 12, ink.alpha(0.45)) { fill(octagon(132), fenceWhite) }
        stroke(octagon(132), ink, 7)
        fill(octagon(116), barnRed)
        text("STOP", c, size: 78, weight: .black, color: .white)
    }

    // County-fair rosettes: blue, red, gold, green, and a faded paper one for locked.
    let ribbonCols: [Col] = [Col(hex: 0x2F6FD6), barnRed, Col(hex: 0xE8B021), Col(hex: 0x3E9A43)]
    func rosette(_ name: String, _ col: Col, faded: Bool) {
        begin(300, 380)
        let c = CGPoint(x: 150, y: 140)
        let tailCol = faded ? Col(hex: 0xBDB4A6) : col.darker(0.1)
        for (dx, rot) in [(-40.0, 0.18), (40.0, -0.18)] {
            ctx.saveGState(); ctx.translateBy(x: c.x + dx, y: c.y + 80); ctx.rotate(by: rot)
            let tail = poly([CGPoint(x: -30, y: 0), CGPoint(x: 30, y: 0), CGPoint(x: 30, y: 190), CGPoint(x: 0, y: 160), CGPoint(x: -30, y: 190)])
            fill(tail, tailCol); stroke(tail, ink, 5)
            ctx.restoreGState()
        }
        // Pleated ring.
        let pleats = CGMutablePath()
        for i in 0..<24 {
            let a = CGFloat(i) / 24 * .pi * 2
            pleats.addPath(circle(CGPoint(x: c.x + cos(a) * 100, y: c.y + sin(a) * 100), 26))
        }
        fill(pleats, faded ? Col(hex: 0xD6CEC0) : col)
        stroke(circle(c, 124), ink, 5)
        fill(circle(c, 84), faded ? Col(hex: 0xEAE4D8) : cream); stroke(circle(c, 84), ink, 5)
        fill(circle(c, 66), faded ? Col(hex: 0xD6CEC0) : col.lighter(0.15)); stroke(circle(c, 66), ink, 4)
        if !faded {
            let s = star(c, 44, 20)
            fill(s, wheat); stroke(s, ink, 4)
        } else {
            text("?", c, size: 60, weight: .black, color: Col(hex: 0xA79E90))
        }
        finish(name)
    }
    for (i, col) in ribbonCols.enumerated() { rosette("ribbon_\(i)", col, faded: false) }
    rosette("ribbon_off", .white, faded: true)

    iconCanvas("star_on", 150) {
        let p = star(CGPoint(x: 75, y: 78), 62, 28)
        shadowed(3, 5, ink.alpha(0.4)) { fill(p, wheat) }
        stroke(p, ink, 6)
    }
    iconCanvas("star_off", 150) {
        let p = star(CGPoint(x: 75, y: 78), 62, 28)
        fill(p, Col(1, 1, 1, 0.25)); stroke(p, Col(1, 1, 1, 0.6), 5)
    }
    iconCanvas("lock", 150) {
        stroke(rr(CGRect(x: 45, y: 25, width: 60, height: 70), 30), Col(hex: 0x8A8378), 14)
        fill(rr(CGRect(x: 30, y: 65, width: 90, height: 70), 14), wood)
        stroke(rr(CGRect(x: 30, y: 65, width: 90, height: 70), 14), ink, 5)
        fill(circle(CGPoint(x: 75, y: 96), 10), ink)
    }
}

// MARK: - Farm backdrops (1170 x 2532 portrait, @3x of 390 x 844)

let bgW = 1170, bgH = 2532

func daySky(_ bottom: CGFloat) {
    linearFill(CGPath(rect: CGRect(x: 0, y: 0, width: CGFloat(bgW), height: bottom), transform: nil), [skyTop, skyLow], .zero, CGPoint(x: 0, y: bottom))
    glow(CGPoint(x: 960, y: 260), 300, Col(hex: 0xFFF6C8, 0.6))
    fill(circle(CGPoint(x: 960, y: 260), 90), Col(hex: 0xFFE680))
    cloud(CGPoint(x: 260, y: 300), 1.4)
    cloud(CGPoint(x: 760, y: 520), 1.0)
    cloud(CGPoint(x: 1080, y: 760), 0.8)
}

func hills(_ y: CGFloat, _ col: Col, seed: UInt64, amp: CGFloat) {
    var g = Rng(s: seed)
    let p = CGMutablePath(); p.move(to: CGPoint(x: 0, y: CGFloat(bgH)))
    p.addLine(to: CGPoint(x: 0, y: y))
    var x: CGFloat = 0
    while x < CGFloat(bgW) {
        let nx = x + g.r(260, 420)
        p.addQuadCurve(to: CGPoint(x: nx, y: y + g.r(-amp, amp) * 0.4), control: CGPoint(x: (x + nx) / 2, y: y - g.r(amp * 0.5, amp)))
        x = nx
    }
    p.addLine(to: CGPoint(x: CGFloat(bgW), y: CGFloat(bgH))); p.closeSubpath()
    fill(p, col)
}

func fieldStripes(_ y: CGFloat, _ h: CGFloat, cols: [Col]) {
    for i in 0..<12 {
        let r = CGRect(x: CGFloat(i) * 100 - 20, y: y, width: 100, height: h)
        fill(CGPath(rect: r, transform: nil), cols[i % cols.count])
    }
}

func barn(_ r: CGRect) {
    let body = CGMutablePath()
    body.move(to: CGPoint(x: r.minX, y: r.maxY)); body.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.35))
    body.addLine(to: CGPoint(x: r.minX + r.width * 0.2, y: r.minY + r.height * 0.08)); body.addLine(to: CGPoint(x: r.midX, y: r.minY))
    body.addLine(to: CGPoint(x: r.maxX - r.width * 0.2, y: r.minY + r.height * 0.08)); body.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.35))
    body.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); body.closeSubpath()
    shadowed(10, 18, ink.alpha(0.35)) { fill(body, barnRed) }
    planks(body, base: barnRed, horizontal: false, seed: 11, plank: 46)
    stroke(body, fenceWhite, 14); stroke(body, ink, 4)
    // Doors with white X.
    let door = CGRect(x: r.midX - r.width * 0.22, y: r.maxY - r.height * 0.45, width: r.width * 0.44, height: r.height * 0.45)
    fill(CGPath(rect: door, transform: nil), barnRedDark)
    stroke(CGPath(rect: door, transform: nil), fenceWhite, 12)
    stroke(poly([CGPoint(x: door.minX, y: door.minY), CGPoint(x: door.maxX, y: door.maxY)]), fenceWhite, 10)
    stroke(poly([CGPoint(x: door.maxX, y: door.minY), CGPoint(x: door.minX, y: door.maxY)]), fenceWhite, 10)
    stroke(poly([CGPoint(x: door.midX, y: door.minY), CGPoint(x: door.midX, y: door.maxY)]), fenceWhite, 8)
    // Hay loft window.
    let loft = CGRect(x: r.midX - 50, y: r.minY + r.height * 0.18, width: 100, height: 90)
    fill(CGPath(rect: loft, transform: nil), woodDark); stroke(CGPath(rect: loft, transform: nil), fenceWhite, 10)
    fill(CGPath(rect: loft.insetBy(dx: 12, dy: 40).offsetBy(dx: 0, dy: 26), transform: nil), hay)
}

func silo(_ x: CGFloat, _ top: CGFloat, _ bottom: CGFloat, _ w: CGFloat) {
    let body = CGRect(x: x, y: top + w / 2, width: w, height: bottom - top - w / 2)
    linearFill(CGPath(rect: body, transform: nil), [Col(hex: 0xD9D4CB), Col(hex: 0xA9A296)], CGPoint(x: x, y: 0), CGPoint(x: x + w, y: 0))
    for i in 0..<10 { stroke(poly([CGPoint(x: x, y: body.minY + CGFloat(i) * body.height / 10), CGPoint(x: x + w, y: body.minY + CGFloat(i) * body.height / 10)]), ink.alpha(0.2), 3) }
    stroke(CGPath(rect: body, transform: nil), ink, 5)
    let dome = CGMutablePath(); dome.addArc(center: CGPoint(x: x + w / 2, y: top + w / 2), radius: w / 2, startAngle: .pi, endAngle: 0, clockwise: false); dome.closeSubpath()
    fill(dome, Col(hex: 0x7A8A96)); stroke(dome, ink, 5)
}

func fence(_ y: CGFloat, from: CGFloat = 0, to: CGFloat = CGFloat(bgW)) {
    var x = from
    while x < to {
        let post = rr(CGRect(x: x, y: y - 70, width: 22, height: 100), 5)
        fill(post, fenceWhite); stroke(post, ink, 4)
        x += 110
    }
    for dy in [-50.0, -14.0] { let rail = CGRect(x: from, y: y + CGFloat(dy), width: to - from, height: 16); fill(CGPath(rect: rail, transform: nil), fenceWhite); stroke(CGPath(rect: rail, transform: nil), ink, 3) }
}

func sunflower(_ c: CGPoint, _ s: CGFloat) {
    stroke(poly([c, CGPoint(x: c.x, y: c.y + 140 * s)]), grassDark, 8 * s)
    fill(ellipse(CGRect(x: c.x, y: c.y + 60 * s, width: 40 * s, height: 20 * s)), grassDark)
    for i in 0..<14 {
        let a = CGFloat(i) / 14 * .pi * 2
        let p = CGPoint(x: c.x + cos(a) * 30 * s, y: c.y + sin(a) * 30 * s)
        fill(ellipse(CGRect(x: p.x - 13 * s, y: p.y - 13 * s, width: 26 * s, height: 26 * s)), Col(hex: 0xFFC83D))
    }
    fill(circle(c, 22 * s), Col(hex: 0x6B3E1E)); stroke(circle(c, 22 * s), ink, 3)
}

func drawBackdrops() {
    // Farmyard (home): sky, hills, barn and silo, fields, fence with sunflowers, dirt yard at the bottom.
    begin(bgW, bgH)
    daySky(1500)
    hills(1150, Col(hex: 0x9FD27A), seed: 1, amp: 160)
    hills(1300, Col(hex: 0x86C25C), seed: 2, amp: 120)
    fieldStripes(1360, 260, cols: [Col(hex: 0xE8C35A), Col(hex: 0xD9AE45), Col(hex: 0x8CC456)])
    silo(800, 700, 1500, 170)
    barn(CGRect(x: 420, y: 880, width: 420, height: 620))
    grassField(CGRect(x: 0, y: 1500, width: CGFloat(bgW), height: 600), seed: 3)
    fence(1640)
    var g = Rng(s: 4)
    for i in 0..<7 { sunflower(CGPoint(x: 120 + CGFloat(i) * 160 + g.r(-20, 20), y: 1520 + g.r(-20, 20)), 1.1) }
    // Dirt yard / road at the bottom.
    let yard = CGRect(x: 0, y: 2100, width: CGFloat(bgW), height: 432)
    fill(CGPath(rect: yard, transform: nil), dirt)
    noiseSpeckle(yard, count: 1500, seed: 5, light: Col(1, 1, 1, 0.15), dark: ink.alpha(0.12), size: 2...6)
    for y in [2230.0, 2380.0] { stroke(poly([CGPoint(x: 0, y: y), CGPoint(x: CGFloat(bgW), y: y + 10)]), dirtDark.alpha(0.5), 22) }
    finish("corner_backdrop")

    // Route board: open fields with a mailbox and a distant tractor.
    begin(bgW, bgH)
    daySky(1000)
    hills(820, Col(hex: 0x9FD27A), seed: 7, amp: 140)
    fieldStripes(900, 1632, cols: [Col(hex: 0x8CC456), Col(hex: 0x7CB64A), Col(hex: 0xE8C35A)])
    finish("timetable_backdrop")

    // Feed store: wooden wall with shelves of sacks.
    begin(bgW, bgH)
    planks(CGPath(rect: CGRect(x: 0, y: 0, width: CGFloat(bgW), height: CGFloat(bgH)), transform: nil), base: Col(hex: 0xC08A52), horizontal: false, seed: 9, plank: 130)
    for y in stride(from: 500.0, to: 2400.0, by: 520.0) {
        fill(CGPath(rect: CGRect(x: 0, y: y, width: CGFloat(bgW), height: 34), transform: nil), woodDark)
        for i in 0..<6 {
            let sack = rr(CGRect(x: 40 + CGFloat(i) * 190, y: y - 200, width: 150, height: 200), 40)
            fill(sack, Col(hex: 0xD8BC8C)); stroke(sack, ink.alpha(0.5), 5)
        }
    }
    fill(CGPath(rect: CGRect(x: 0, y: 0, width: CGFloat(bgW), height: CGFloat(bgH)), transform: nil), Col(1, 1, 1, 0.12))
    finish("vending_backdrop")

    // Henhouse: coop interior, plank walls, straw floor and a roof beam.
    begin(bgW, bgH)
    planks(CGPath(rect: CGRect(x: 0, y: 0, width: CGFloat(bgW), height: CGFloat(bgH)), transform: nil), base: Col(hex: 0xB07A45), horizontal: true, seed: 12, plank: 90)
    let beam = CGRect(x: 0, y: 330, width: CGFloat(bgW), height: 70)
    fill(CGPath(rect: beam, transform: nil), woodDark); stroke(CGPath(rect: beam, transform: nil), ink, 5)
    let floor = CGRect(x: 0, y: 2150, width: CGFloat(bgW), height: 382)
    fill(CGPath(rect: floor, transform: nil), hay)
    var gs = Rng(s: 13)
    for _ in 0..<800 { let x = gs.r(0, CGFloat(bgW)), y = gs.r(2150, CGFloat(bgH)); stroke(poly([CGPoint(x: x, y: y), CGPoint(x: x + gs.r(-30, 30), y: y + gs.r(-8, 8))]), Col(hex: 0xC9A04A), 4) }
    finish("henhouse_backdrop")

    // Barn wall: red vertical boards with white trim and an X brace.
    begin(bgW, bgH)
    planks(CGPath(rect: CGRect(x: 0, y: 0, width: CGFloat(bgW), height: CGFloat(bgH)), transform: nil), base: barnRed, horizontal: false, seed: 14, plank: 120)
    for y in [380.0, 2350.0] { fill(CGPath(rect: CGRect(x: 0, y: y, width: CGFloat(bgW), height: 40), transform: nil), fenceWhite) }
    stroke(poly([CGPoint(x: 0, y: 420), CGPoint(x: CGFloat(bgW), y: 2350)]), fenceWhite.alpha(0.6), 40)
    stroke(poly([CGPoint(x: CGFloat(bgW), y: 420), CGPoint(x: 0, y: 2350)]), fenceWhite.alpha(0.6), 40)
    finish("billboard_backdrop")
}

// MARK: - District postcards (900 x 540 = 300 x 180 pt)

func postcard(_ name: String, sky: [Col], ground: Col, _ extra: () -> Void) {
    begin(900, 540)
    linearFill(CGPath(rect: CGRect(x: 0, y: 0, width: 900, height: 330), transform: nil), sky, .zero, CGPoint(x: 0, y: 330))
    let hill = CGMutablePath(); hill.move(to: CGPoint(x: 0, y: 330)); hill.addQuadCurve(to: CGPoint(x: 900, y: 300), control: CGPoint(x: 450, y: 200)); hill.addLine(to: CGPoint(x: 900, y: 340)); hill.addLine(to: CGPoint(x: 0, y: 340)); hill.closeSubpath()
    fill(hill, ground)
    fill(CGPath(rect: CGRect(x: 0, y: 330, width: 900, height: 210), transform: nil), dirt)
    noiseSpeckle(CGRect(x: 0, y: 330, width: 900, height: 210), count: 400, seed: 2, light: Col(1, 1, 1, 0.15), dark: ink.alpha(0.12))
    for y in [400.0, 480.0] { stroke(poly([CGPoint(x: 0, y: y), CGPoint(x: 900, y: y)]), dirtDark.alpha(0.5), 14) }
    extra()
    stroke(rr(CGRect(x: 4, y: 4, width: 892, height: 532), 30), ink, 8)
    finish(name)
}

func miniTractor(_ x: CGFloat, _ y: CGFloat, _ col: Col, length: CGFloat = 130) {
    let r = CGRect(x: x, y: y, width: length, height: 60)
    fill(rr(r, 16), col); stroke(rr(r, 16), ink, 5)
    fill(circle(CGPoint(x: r.minX + 26, y: r.maxY), 22), ink); fill(circle(CGPoint(x: r.maxX - 22, y: r.maxY + 6), 14), ink)
    fill(rr(CGRect(x: r.minX + 20, y: r.minY - 30, width: 46, height: 36), 6), water.alpha(0.8)); stroke(rr(CGRect(x: r.minX + 20, y: r.minY - 30, width: 46, height: 36), 6), ink, 4)
}

func drawDistricts() {
    postcard("district_meadow", sky: [skyTop, skyLow], ground: grass) {
        cloud(CGPoint(x: 220, y: 110), 0.8)
        var g = Rng(s: 3)
        for _ in 0..<16 { daisy(CGPoint(x: g.r(20, 880), y: g.r(270, 325)), 0.9) }
        // Cow.
        fill(ellipse(CGRect(x: 610, y: 210, width: 150, height: 80)), .white); stroke(ellipse(CGRect(x: 610, y: 210, width: 150, height: 80)), ink, 5)
        fill(circle(CGPoint(x: 660, y: 240), 18), ink); fill(circle(CGPoint(x: 720, y: 255), 14), ink)
        fill(circle(CGPoint(x: 775, y: 222), 30), .white); stroke(circle(CGPoint(x: 775, y: 222), 30), ink, 5)
        miniTractor(200, 380, Col(hex: 0x3F9B3A))
    }
    postcard("district_harvest", sky: [skyTop, skyLow], ground: Col(hex: 0xE8C35A)) {
        for i in 0..<22 { let x = CGFloat(i) * 42; stroke(poly([CGPoint(x: x, y: 330), CGPoint(x: x + 6, y: 220)]), grassDark, 8); fill(ellipse(CGRect(x: x - 4, y: 230, width: 18, height: 40)), wheat) }
        let truck = CGRect(x: 280, y: 420, width: 300, height: 70)
        fill(rr(truck, 12), wood); stroke(rr(truck, 12), ink, 5)
        for i in 0..<7 { fill(rr(CGRect(x: 295 + CGFloat(i) * 38, y: 432, width: 34, height: 18), 8), wheat) }
        fill(rr(CGRect(x: 580, y: 410, width: 90, height: 90), 14), barnRed); stroke(rr(CGRect(x: 580, y: 410, width: 90, height: 90), 14), ink, 5)
    }
    postcard("district_orchard", sky: [skyTop, skyLow], ground: grass) {
        for x in [120.0, 360.0, 620.0, 820.0] {
            stroke(poly([CGPoint(x: x, y: 330), CGPoint(x: x, y: 250)]), woodDark, 16)
            fill(circle(CGPoint(x: x, y: 210), 70), grassDark); stroke(circle(CGPoint(x: x, y: 210), 70), ink, 5)
            for (dx, dy) in [(-30.0, -10.0), (20.0, -30.0), (30.0, 20.0), (-10.0, 30.0)] { fill(circle(CGPoint(x: x + dx, y: 210 + dy), 11), barnRed) }
        }
        sprinklerHead(CGPoint(x: 450, y: 470), 0.5, wet: 1)
        for i in 0..<12 { let a = CGFloat(i) / 12 * .pi; fill(ellipse(CGRect(x: 450 + cos(a + .pi) * 120 - 8, y: 420 - sin(a) * 100 - 10, width: 16, height: 22)), water) }
    }
    postcard("district_gravel", sky: [Col(hex: 0x6BB8F0), Col(hex: 0xFFE9B0)], ground: Col(hex: 0xD9B867)) {
        glow(CGPoint(x: 760, y: 90), 200, Col(hex: 0xFFE680, 0.8)); fill(circle(CGPoint(x: 760, y: 90), 60), Col(hex: 0xFFD54A))
        fill(CGPath(rect: CGRect(x: 0, y: 330, width: 900, height: 210), transform: nil), gravelCol.alpha(0.7))
        noiseSpeckle(CGRect(x: 0, y: 330, width: 900, height: 210), count: 300, seed: 6, light: Col(hex: 0xEDE2CC), dark: Col(hex: 0x9C8A70), size: 4...9)
        for i in 0..<3 {
            let p = CGMutablePath(); p.move(to: CGPoint(x: 0, y: 380 + CGFloat(i) * 50))
            var x: CGFloat = 0
            while x < 900 { p.addQuadCurve(to: CGPoint(x: x + 80, y: 380 + CGFloat(i) * 50), control: CGPoint(x: x + 40, y: 366 + CGFloat(i) * 50)); x += 80 }
            stroke(p, Col(hex: 0xFF8A3D, 0.35), 6)
        }
        miniTractor(520, 430, Col(hex: 0xC8372D))
    }
    postcard("district_fog", sky: [Col(hex: 0xBFD6E2), Col(hex: 0xE8EEF0)], ground: Col(hex: 0xA9C79A)) {
        miniTractor(240, 400, Col(hex: 0x3F9B3A))
        fill(CGPath(rect: CGRect(x: 0, y: 0, width: 900, height: 540), transform: nil), Col(1, 1, 1, 0.55))
        for (x, y) in [(380.0, 420.0), (700.0, 470.0)] { glow(CGPoint(x: x, y: y), 110, Col(hex: 0xFFE9A0, 0.9)); fill(circle(CGPoint(x: x, y: y), 12), .white) }
    }
}

// MARK: - Fair photo frame & logo

func drawPhotoAndLogo() {
    // County-fair photo pinned to a wooden board (1050 x 900 = 350 x 300 pt).
    begin(1050, 900)
    let board = rr(CGRect(x: 10, y: 10, width: 1030, height: 880), 30)
    planks(board, base: woodLight, horizontal: true, seed: 21, plank: 110)
    stroke(board, ink, 8)
    let photo = CGRect(x: 50, y: 50, width: 950, height: 640)
    shadowed(8, 14, ink.alpha(0.4)) { fill(CGPath(rect: photo.insetBy(dx: -20, dy: -20), transform: nil), .white) }
    ctx.saveGState(); ctx.addPath(CGPath(rect: photo, transform: nil)); ctx.clip()
    linearFill(CGPath(rect: photo, transform: nil), [skyTop, skyLow], CGPoint(x: 0, y: photo.minY), CGPoint(x: 0, y: photo.minY + 360))
    cloud(CGPoint(x: 260, y: 150), 0.9)
    fill(CGPath(rect: CGRect(x: 50, y: 360, width: 950, height: 140), transform: nil), grass)
    fill(CGPath(rect: CGRect(x: 50, y: 470, width: 950, height: 220), transform: nil), dirt)
    for y in [540.0, 620.0] { stroke(poly([CGPoint(x: 50, y: y), CGPoint(x: 1000, y: y)]), dirtDark.alpha(0.5), 16) }
    ctx.restoreGState()
    stroke(CGPath(rect: photo, transform: nil), ink, 4)
    // Thumbtacks.
    for p in [CGPoint(x: 70, y: 40), CGPoint(x: 980, y: 40)] { fill(circle(p, 16), barnRed); stroke(circle(p, 16), ink, 4) }
    // Caption strip (chalkboard).
    let strip = rr(CGRect(x: 50, y: 712, width: 950, height: 140), 16)
    fill(strip, chalkboard); stroke(strip, woodDark, 8)
    finish("photo_frame")

    // Wordmark on a painted wooden sign (1200 x 480 = 400 x 160 pt).
    begin(1200, 480)
    for x in [180.0, 990.0] { let post = rr(CGRect(x: x, y: 300, width: 30, height: 170), 6); fill(post, woodDark); stroke(post, ink, 5) }
    let sign = rr(CGRect(x: 30, y: 30, width: 1140, height: 380), 40)
    shadowed(10, 14, ink.alpha(0.45)) { fill(sign, wood) }
    planks(sign, base: Col(hex: 0x9A6334), horizontal: true, seed: 22, plank: 95)
    stroke(sign, ink, 10)
    stroke(rr(CGRect(x: 56, y: 56, width: 1088, height: 328), 28), fenceWhite.alpha(0.85), 6)
    paintText("CLUCK", CGPoint(x: 600, y: 150), size: 150, wheat)
    paintText("CROSSING", CGPoint(x: 600, y: 300), size: 112, fenceWhite)
    let egg = ellipse(CGRect(x: 120, y: 90, width: 60, height: 78))
    fill(egg, cream); stroke(egg, ink, 6)
    finish("logo_wordmark")
}

// MARK: - Almanac illustrations (720 x 420 = 240 x 140 pt)

func tutorialCanvas(_ name: String, _ draw: () -> Void) {
    begin(720, 420)
    fill(CGPath(rect: CGRect(x: 0, y: 0, width: 720, height: 420), transform: nil), dirt)
    noiseSpeckle(CGRect(x: 0, y: 0, width: 720, height: 420), count: 500, seed: 4, light: Col(1, 1, 1, 0.15), dark: ink.alpha(0.12))
    draw()
    stroke(rr(CGRect(x: 4, y: 4, width: 712, height: 412), 26), ink, 8)
    finish(name)
}

func laneTufts(_ ys: [CGFloat]) {
    for y in ys {
        fill(CGPath(rect: CGRect(x: 0, y: y, width: 720, height: 8), transform: nil), grassDark.alpha(0.6))
    }
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

func woodLabel(_ s: String, _ c: CGPoint, size: CGFloat, _ col: Col = wheat) {
    paintText(s, c, size: size, col)
}

func drawTutorials() {
    tutorialCanvas("tut_hop") {
        laneTufts([140, 280])
        miniTractor(40, 170, Col(hex: 0x3F9B3A))
        miniTractor(460, 310, Col(hex: 0xC8372D))
        miniHen(CGPoint(x: 360, y: 370), 0.9)
        for i in 0..<3 { stroke(poly([CGPoint(x: 340, y: 300 - CGFloat(i) * 70), CGPoint(x: 360, y: 270 - CGFloat(i) * 70), CGPoint(x: 380, y: 300 - CGFloat(i) * 70)]), .white, 12) }
    }
    tutorialCanvas("tut_roost") {
        grassField(CGRect(x: 0, y: 150, width: 720, height: 120), seed: 5)
        hayBale(CGRect(x: 20, y: 165, width: 110, height: 90))
        miniHen(CGPoint(x: 300, y: 220), 1.1)
        for (i, x) in [450.0, 510.0, 570.0].enumerated() {
            fill(ellipse(CGRect(x: x, y: 170 - CGFloat(i) * 10, width: 44, height: 60)), cream)
            stroke(ellipse(CGRect(x: x, y: 170 - CGFloat(i) * 10, width: 44, height: 60)), ink, 5)
        }
        woodSign(CGRect(x: 40, y: 30, width: 200, height: 100), base: woodLight)
        text("×1.4", CGPoint(x: 140, y: 80), size: 54, weight: .black, color: ink)
        woodLabel("ROOST!", CGPoint(x: 540, y: 360), size: 60)
    }
    tutorialCanvas("tut_bell") {
        laneTufts([140, 280])
        miniTractor(80, 170, Col(hex: 0x3F9B3A)); miniTractor(420, 310, Col(hex: 0xC8372D))
        fill(CGPath(rect: CGRect(x: 0, y: 150, width: 720, height: 260), transform: nil), Col(hex: 0x6CD6FF, 0.25))
        farmBell(CGPoint(x: 600, y: 120), 0.45)
        woodLabel("DING!", CGPoint(x: 330, y: 80), size: 66, fenceWhite)
    }
    tutorialCanvas("tut_truck") {
        laneTufts([150, 290])
        let r = CGRect(x: 60, y: 180, width: 420, height: 90)
        fill(rr(r, 16), wood); stroke(rr(r, 16), ink, 6)
        for i in 0..<9 { fill(rr(CGRect(x: 80 + CGFloat(i) * 34, y: 205, width: 40, height: 18), 8), wheat) }
        fill(rr(CGRect(x: 480, y: 175, width: 90, height: 100), 16), barnRed); stroke(rr(CGRect(x: 480, y: 175, width: 90, height: 100), 16), ink, 6)
        for i in 0..<4 { fill(ellipse(CGRect(x: 600 + CGFloat(i) * 26, y: 220 + CGFloat(i % 2) * 10, width: 22, height: 28)), wheat) }
        woodLabel("HONK!", CGPoint(x: 560, y: 90), size: 66, Col(hex: 0xF39C34))
    }
    tutorialCanvas("tut_sprinkler") {
        sprinklerHead(CGPoint(x: 210, y: 300), 0.9, wet: 0.6)
        sprinklerHead(CGPoint(x: 520, y: 300), 0.9, wet: 1)
        for i in 0..<14 { let a = CGFloat(i) / 14 * .pi; fill(ellipse(CGRect(x: 520 + cos(a + .pi) * 140 - 8, y: 230 - sin(a) * 140 - 10, width: 16, height: 22)), water) }
        woodLabel("GURGLE", CGPoint(x: 210, y: 70), size: 46, fenceWhite)
        woodLabel("SPLASH!", CGPoint(x: 520, y: 70), size: 46, water)
    }
    tutorialCanvas("tut_heat") {
        fill(CGPath(rect: CGRect(x: 0, y: 0, width: 720, height: 420), transform: nil), gravelCol.alpha(0.6))
        noiseSpeckle(CGRect(x: 0, y: 0, width: 720, height: 420), count: 200, seed: 6, light: Col(hex: 0xEDE2CC), dark: Col(hex: 0x9C8A70), size: 4...9)
        for i in 0..<5 {
            let p = CGMutablePath(); p.move(to: CGPoint(x: 0, y: 120 + CGFloat(i) * 50))
            var x: CGFloat = 0
            while x < 720 { p.addQuadCurve(to: CGPoint(x: x + 80, y: 120 + CGFloat(i) * 50), control: CGPoint(x: x + 40, y: 105 + CGFloat(i) * 50)); x += 80 }
            stroke(p, Col(hex: 0xFF7A3D, 0.35), 6)
        }
        miniHen(CGPoint(x: 330, y: 260), 1.1)
        let tube = rr(CGRect(x: 560, y: 80, width: 50, height: 230), 25)
        fill(tube, .white); stroke(tube, ink, 6)
        fill(rr(CGRect(x: 572, y: 110, width: 26, height: 190), 13), barnRed)
        glow(CGPoint(x: 120, y: 80), 90, Col(hex: 0xFFE680, 0.9)); fill(circle(CGPoint(x: 120, y: 80), 40), Col(hex: 0xFFD54A))
        woodLabel("HOT!", CGPoint(x: 330, y: 90), size: 64, Col(hex: 0xF39C34))
    }
}

// MARK: - App icon (1024 and 512, no alpha)

func drawIcon(size: Int) -> CGImage {
    begin(size, size)
    let s = CGFloat(size) / 1024
    ctx.scaleBy(x: s, y: s)
    linearFill(CGPath(rect: CGRect(x: 0, y: 0, width: 1024, height: 560), transform: nil), [skyTop, skyLow], .zero, CGPoint(x: 0, y: 560))
    cloud(CGPoint(x: 820, y: 130), 1.1)
    let hill = CGMutablePath(); hill.move(to: CGPoint(x: 0, y: 470)); hill.addQuadCurve(to: CGPoint(x: 1024, y: 430), control: CGPoint(x: 500, y: 330)); hill.addLine(to: CGPoint(x: 1024, y: 600)); hill.addLine(to: CGPoint(x: 0, y: 600)); hill.closeSubpath()
    fill(hill, Col(hex: 0x8CC456))
    fill(CGPath(rect: CGRect(x: 0, y: 520, width: 1024, height: 504), transform: nil), dirt)
    noiseSpeckle(CGRect(x: 0, y: 520, width: 1024, height: 504), count: 900, seed: 3, light: Col(1, 1, 1, 0.15), dark: ink.alpha(0.12), size: 3...8)
    for y in [700.0, 880.0] { stroke(poly([CGPoint(x: 0, y: y), CGPoint(x: 1024, y: y + 8)]), dirtDark.alpha(0.5), 30) }
    ctx.saveGState()
    ctx.translateBy(x: 170, y: 330)
    ctx.scaleBy(x: 2.3, y: 2.3)
    paintHenInPlace(HenLook(body: Col(hex: 0xF7F3EA), shade: Col(hex: 0xC9C0B0), wing: Col(hex: 0xE9E2D4), tail: Col(hex: 0xEDE6D8)))
    ctx.restoreGState()
    return ctx.makeImage()!
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
    flat.setFillColor(skyTop.cg); flat.fill(CGRect(x: 0, y: 0, width: w, height: h))
    flat.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, flat.makeImage()!, nil); CGImageDestinationFinalize(dest)
    print("icon \(url.path)")
}


// MARK: - Run

laneRow("row_lane", seed: 1, tint: dirt, hot: false)
laneRow("row_lane_b", seed: 2, tint: dirt.mix(dirtLight, 0.35), hot: false)
laneRow("row_lane_hot", seed: 3, tint: gravelCol, hot: true)
curbRow("row_curb", seed: 4, finishLine: false)
curbRow("row_finish", seed: 5, finishLine: true)
islandRow()
drawVehicles()
drawHazards()
drawPickupsAndHUD()
drawHens()
drawUpgrades()
drawUIPieces()
drawBackdrops()
drawDistricts()
drawPhotoAndLogo()
drawTutorials()

let iconDir = URL(fileURLWithPath: CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "./Icons")
try? fm.createDirectory(at: iconDir, withIntermediateDirectories: true)
writeIcon(drawIcon(size: 1024), iconDir.appendingPathComponent("CluckCrossing-1024.png"))
writeIcon(drawIcon(size: 512), iconDir.appendingPathComponent("CluckCrossing-512.png"))
print("done")
