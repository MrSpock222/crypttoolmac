// Generates the CrypTool app icon (AppIcon.icns) with CoreGraphics.
// Usage: swift scripts/make-icon.swift <output-dir>
import AppKit

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = outDir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // macOS icon grid: 824/1024 rounded rect, radius ~185/1024
    let inset = s * 100 / 1024
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = CGPath(roundedRect: rect, cornerWidth: s * 185 / 1024, cornerHeight: s * 185 / 1024, transform: nil)

    // drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.03, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(path)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // background gradient (CT1 blue)
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let colors = [NSColor(calibratedRed: 0.10, green: 0.32, blue: 0.68, alpha: 1).cgColor,
                  NSColor(calibratedRed: 0.03, green: 0.12, blue: 0.33, alpha: 1).cgColor] as CFArray
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

    // faint hex digits in the background
    let digitFont = NSFont.monospacedSystemFont(ofSize: s * 0.075, weight: .medium)
    let attrs: [NSAttributedString.Key: Any] = [.font: digitFont, .foregroundColor: NSColor.white.withAlphaComponent(0.10)]
    let rows = ["3A F1 07 C9 5E", "B2 0D 9F 44 E8", "6C 1B A7 F0 23", "D5 88 2E 7B 90", "41 EC 36 05 BF", "9A 77 C2 1D 6E"]
    for (i, row) in rows.enumerated() {
        NSAttributedString(string: row, attributes: attrs)
            .draw(at: CGPoint(x: rect.minX + s * 0.04, y: rect.maxY - s * 0.13 - CGFloat(i) * s * 0.115))
    }
    ctx.restoreGState()

    // key symbol
    let config = NSImage.SymbolConfiguration(pointSize: s * 0.42, weight: .semibold)
    if let sym = NSImage(systemSymbolName: "key.horizontal.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let tinted = NSImage(size: sym.size, flipped: false) { r in
            sym.draw(in: r)
            NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.20, alpha: 1).set()
            r.fill(using: .sourceAtop)
            return true
        }
        let w = tinted.size.width, h = tinted.size.height
        tinted.draw(in: CGRect(x: (s - w) / 2, y: (s - h) / 2 + s * 0.06, width: w, height: h))
    }

    // "CT" label
    let labelFont = NSFont.systemFont(ofSize: s * 0.16, weight: .heavy)
    let label = NSAttributedString(string: "CT", attributes: [.font: labelFont, .foregroundColor: NSColor.white])
    let ls = label.size()
    label.draw(at: CGPoint(x: (s - ls.width) / 2, y: rect.minY + s * 0.07))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", outDir.appendingPathComponent("AppIcon.icns").path]
try p.run()
p.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print(p.terminationStatus == 0 ? "AppIcon.icns written" : "iconutil failed")
