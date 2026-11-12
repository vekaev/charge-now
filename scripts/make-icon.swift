// Draws the Charge Now app icon: a graphite tile with one bold mark, a charging bolt.
// Run from the repo root: swift scripts/make-icon.swift
// Writes docs/icon.png (512, for the README) and App/AppIcon.icns (every size macOS asks for).
import AppKit

let size: CGFloat = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

func bitmap(_ pixels: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                     bytesPerRow: 0, bitsPerPixel: 0)!
}

func write(_ rep: NSBitmapImageRep, _ path: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let master = bitmap(Int(size))
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: master)
let ctx = NSGraphicsContext.current!.cgContext

// macOS icon grid: an 824 pt rounded square centered on a 1024 canvas.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: rgb(0, 0, 0, 0.28))
ctx.addPath(tilePath); ctx.setFillColor(rgb(26, 26, 28)); ctx.fillPath()
ctx.restoreGState()

/// The app's mark: a bolt, warm at the top and red at the tip, like a battery running out.
func drawMark() {
    // Points on a 100 × 100 sketch, y up, scaled into the tile.
    let sketch: [(CGFloat, CGFloat)] = [(60, 92), (26, 46), (47, 46), (40, 8), (74, 54), (53, 54)]
    let scale: CGFloat = 5.4
    let origin = CGPoint(x: size / 2 - 50 * scale, y: size / 2 - 50 * scale)
    let bolt = CGMutablePath()
    for (index, point) in sketch.enumerated() {
        let p = CGPoint(x: origin.x + point.0 * scale, y: origin.y + point.1 * scale)
        if index == 0 { bolt.move(to: p) } else { bolt.addLine(to: p) }
    }
    bolt.closeSubpath()
    // A round stroke of the same fill softens the corners.
    let soft = bolt.copy(strokingWithWidth: 34, lineCap: .round, lineJoin: .round, miterLimit: 1)
    let gradient = CGGradient(colorsSpace: space, colors: [rgb(255, 196, 64), rgb(240, 62, 80)] as CFArray,
                              locations: [0, 1])!
    // Two passes, the shape and its outline: clipping to both at once would cut the overlap out.
    for shape in [bolt, soft] {
        ctx.saveGState()
        ctx.addPath(shape); ctx.clip()
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: origin.y + 96 * scale),
                               end: CGPoint(x: 0, y: origin.y + 4 * scale), options: [])
        ctx.restoreGState()
    }
}
drawMark()

// Fine grain, like brushed paper.
ctx.saveGState()
ctx.addPath(tilePath); ctx.clip()
var seed: UInt64 = 42
func rnd() -> CGFloat {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return CGFloat(seed >> 33) / CGFloat(1 << 31)
}
for _ in 0..<22000 {
    ctx.setFillColor(rnd() > 0.5 ? rgb(255, 255, 255, 0.05) : rgb(0, 0, 0, 0.03))
    ctx.fill(CGRect(x: tile.minX + rnd() * tile.width, y: tile.minY + rnd() * tile.height, width: 2, height: 2))
}
ctx.restoreGState()
ctx.addPath(tilePath); ctx.setStrokeColor(rgb(58, 58, 62)); ctx.setLineWidth(3); ctx.strokePath()
NSGraphicsContext.restoreGraphicsState()

/// The master drawing scaled down to `pixels`.
func scaled(_ pixels: Int) -> NSBitmapImageRep {
    let rep = bitmap(pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current!.imageInterpolation = .high
    master.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let files = FileManager.default
try! files.createDirectory(atPath: "docs", withIntermediateDirectories: true)
write(scaled(512), "docs/icon.png")

let iconset = NSTemporaryDirectory() + "ChargeNow-\(ProcessInfo.processInfo.processIdentifier).iconset"
try! files.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    write(scaled(points), "\(iconset)/icon_\(points)x\(points).png")
    write(scaled(points * 2), "\(iconset)/icon_\(points)x\(points)@2x.png")
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset, "-o", "App/AppIcon.icns"]
try! iconutil.run()
iconutil.waitUntilExit()
try? files.removeItem(atPath: iconset)
print(iconutil.terminationStatus == 0 ? "Wrote docs/icon.png and App/AppIcon.icns" : "iconutil failed")
exit(iconutil.terminationStatus)
