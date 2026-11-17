// Contact sheet for reviewing generated art and screenshots.
// Usage: swift montage.swift <dir-with-pngs> <out.png> [columns] [cell]
import AppKit
let dir = CommandLine.arguments[1], out = CommandLine.arguments[2]
let cols = Int(CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "5")!
let cell = CGFloat(Int(CommandLine.arguments.count > 4 ? CommandLine.arguments[4] : "240")!)
let files = (try! FileManager.default.contentsOfDirectory(atPath: dir)).filter { $0.hasSuffix(".png") }.sorted()
let rows = (files.count + cols - 1) / cols
let W = Int(cell) * cols, H = Int(cell) * rows
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.setFillColor(CGColor(red: 0.85, green: 0.9, blue: 0.85, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
for (i, f) in files.enumerated() {
    guard let img = NSImage(contentsOfFile: dir + "/" + f), let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
    let r = i / cols, c = i % cols
    let aspect = CGFloat(cg.width) / CGFloat(cg.height)
    var w = cell - 10, h = (cell - 10) / aspect
    if h > cell - 10 { h = cell - 10; w = h * aspect }
    ctx.draw(cg, in: CGRect(x: CGFloat(c) * cell + (cell - w) / 2, y: CGFloat(H) - CGFloat(r + 1) * cell + (cell - h) / 2, width: w, height: h))
}
try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
