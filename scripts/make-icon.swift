// Draws the app icon and writes Assets/AppIcon.png (1024×1024).
// Run: swift scripts/make-icon.swift  (then scripts/build-icon.sh makes the .icns)
import AppKit

let size: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// macOS icon grid: 824pt rounded square centred in 1024, with a soft drop shadow.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
ctx.addPath(tilePath)
ctx.setFillColor(NSColor(red: 0.12, green: 0.55, blue: 0.27, alpha: 1).cgColor)
ctx.fillPath()
ctx.restoreGState()

// Pitch: green gradient with mown stripes and a white centre circle.
ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()
let pitch = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
    NSColor(red: 0.20, green: 0.68, blue: 0.33, alpha: 1).cgColor,
    NSColor(red: 0.07, green: 0.42, blue: 0.20, alpha: 1).cgColor,
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(pitch, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
ctx.setFillColor(NSColor.white.withAlphaComponent(0.06).cgColor)
for i in stride(from: 0, to: 8, by: 2) {
    ctx.fill(CGRect(x: 100 + CGFloat(i) * 103, y: 100, width: 103, height: 824))
}
ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.55).cgColor)
ctx.setLineWidth(14)
ctx.move(to: CGPoint(x: 100, y: 512)); ctx.addLine(to: CGPoint(x: 924, y: 512)); ctx.strokePath()
ctx.strokeEllipse(in: CGRect(x: 512 - 300, y: 512 - 300, width: 600, height: 600))
ctx.restoreGState()

// Ball.
let centre = CGPoint(x: 492, y: 532)
let r: CGFloat = 255
let ballRect = CGRect(x: centre.x - r, y: centre.y - r, width: 2 * r, height: 2 * r)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 30, color: NSColor.black.withAlphaComponent(0.45).cgColor)
ctx.setFillColor(NSColor.white.cgColor)
ctx.fillEllipse(in: ballRect)
ctx.restoreGState()

func pentagon(_ c: CGPoint, _ radius: CGFloat, rotation: CGFloat) -> [CGPoint] {
    (0..<5).map { i in
        let a = rotation + CGFloat(i) * 2 * .pi / 5
        return CGPoint(x: c.x + radius * cos(a), y: c.y + radius * sin(a))
    }
}
let ink = NSColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1).cgColor
ctx.saveGState()
ctx.addEllipse(in: ballRect)
ctx.clip()
let up = CGFloat.pi / 2
let inner = pentagon(centre, r * 0.30, rotation: up)
ctx.setFillColor(ink)
ctx.addLines(between: inner); ctx.closePath(); ctx.fillPath()
ctx.setStrokeColor(ink)
ctx.setLineWidth(11)
ctx.setLineCap(.round)
for (i, v) in inner.enumerated() {
    let a = up + CGFloat(i) * 2 * .pi / 5
    let outerCentre = CGPoint(x: centre.x + r * 0.98 * cos(a), y: centre.y + r * 0.98 * sin(a))
    let outer = pentagon(outerCentre, r * 0.30, rotation: a + .pi)
    ctx.addLines(between: outer); ctx.closePath(); ctx.fillPath()
    // Seam from the centre patch to the outer patch.
    ctx.move(to: v); ctx.addLine(to: outer[0]); ctx.strokePath()
    // Seams running out to the rim between neighbouring outer patches.
    for side in [1, 4] {
        let p = outer[side]
        let dir = CGPoint(x: p.x - outerCentre.x, y: p.y - outerCentre.y)
        ctx.move(to: p); ctx.addLine(to: CGPoint(x: p.x + dir.x * 1.2, y: p.y + dir.y * 1.2)); ctx.strokePath()
    }
}
// Soft shading so the ball reads as a sphere.
let shade = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
    NSColor.white.withAlphaComponent(0).cgColor,
    NSColor.black.withAlphaComponent(0.22).cgColor,
] as CFArray, locations: [0.55, 1])!
ctx.drawRadialGradient(shade, startCenter: CGPoint(x: centre.x - 80, y: centre.y + 90), startRadius: 0,
                       endCenter: centre, endRadius: r, options: [])
ctx.restoreGState()
ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.25).cgColor)
ctx.setLineWidth(4)
ctx.strokeEllipse(in: ballRect)

// "?" badge: which player are ya?
let badge = CGRect(x: 640, y: 180, width: 230, height: 230)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: NSColor.black.withAlphaComponent(0.4).cgColor)
ctx.setFillColor(NSColor(red: 0.98, green: 0.77, blue: 0.16, alpha: 1).cgColor)
ctx.fillEllipse(in: badge)
ctx.restoreGState()
ctx.setStrokeColor(NSColor.white.cgColor)
ctx.setLineWidth(12)
ctx.strokeEllipse(in: badge.insetBy(dx: 6, dy: 6))
let mark = NSAttributedString(string: "?", attributes: [
    .font: NSFont.systemFont(ofSize: 170, weight: .black),
    .foregroundColor: NSColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1),
])
let markSize = mark.size()
mark.draw(at: CGPoint(x: badge.midX - markSize.width / 2, y: badge.midY - markSize.height / 2 + 4))

NSGraphicsContext.restoreGraphicsState()
let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Assets/AppIcon.png")
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("Wrote \(out.path)")
