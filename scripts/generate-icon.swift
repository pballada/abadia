import AppKit

// Original vector artwork: an illuminated abbey doorway, rendered by AppKit.
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/AppIcon.iconset")
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for density in [1, 2] {
        let pixels = size * density
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let scale = CGFloat(pixels) / 1024
        let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
        let tile = NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 208, yRadius: 208)
        NSColor(calibratedRed: 0.11, green: 0.17, blue: 0.15, alpha: 1).setFill(); tile.fill()
        let gradient = NSGradient(starting: NSColor(calibratedRed: 0.23, green: 0.30, blue: 0.25, alpha: 1), ending: NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.11, alpha: 1))!
        gradient.draw(in: tile, angle: -90)
        for i in 0..<3 {
            let inset = CGFloat(i) * 68
            let left = 252 + inset, right = 772 - inset, bottom: CGFloat = 222, peak = 820 - inset
            let path = NSBezierPath()
            path.move(to: NSPoint(x: left, y: bottom))
            path.line(to: NSPoint(x: left, y: peak - 210))
            path.curve(to: NSPoint(x: 512, y: peak), controlPoint1: NSPoint(x: left, y: peak - 100), controlPoint2: NSPoint(x: 455, y: peak - 30))
            path.curve(to: NSPoint(x: right, y: peak - 210), controlPoint1: NSPoint(x: 569, y: peak - 30), controlPoint2: NSPoint(x: right, y: peak - 100))
            path.line(to: NSPoint(x: right, y: bottom))
            NSColor(calibratedRed: 0.87, green: 0.75, blue: 0.49, alpha: 1).setStroke()
            path.lineWidth = 17; path.lineCapStyle = .round; path.stroke()
        }
        let light = NSBezierPath(roundedRect: NSRect(x: 489, y: 222, width: 46, height: 174), xRadius: 4, yRadius: 4)
        NSColor(calibratedRed: 0.98, green: 0.88, blue: 0.65, alpha: 1).setFill(); light.fill()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let name = "icon_\(size)x\(size)\(density == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent(name))
    }
}
// ICNS supports PNG payloads; write the container without extra tooling.
var chunks = Data()
for (type, name) in [("icp4", "icon_16x16.png"), ("icp5", "icon_32x32.png"), ("ic07", "icon_128x128.png"), ("ic08", "icon_256x256.png"), ("ic09", "icon_512x512.png"), ("ic10", "icon_512x512@2x.png")] {
    let png = try Data(contentsOf: root.appendingPathComponent(name))
    chunks.append(type.data(using: .ascii)!)
    var length = UInt32(png.count + 8).bigEndian
    withUnsafeBytes(of: &length) { chunks.append(contentsOf: $0) }
    chunks.append(png)
}
var icon = "icns".data(using: .ascii)!
var total = UInt32(chunks.count + 8).bigEndian
withUnsafeBytes(of: &total) { icon.append(contentsOf: $0) }
icon.append(chunks)
try icon.write(to: URL(fileURLWithPath: "Resources/AppIcon.icns"))
