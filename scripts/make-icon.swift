// Génère l'icône de NewsFlux (initiales « NF » sur fond vert pastel).
// Usage : swift scripts/make-icon.swift <dossier.iconset>
import AppKit

let outputDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "build/AppIcon.iconset")
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Dessine l'icône sur un canevas carré de `size` pixels (gabarit macOS : forme de 824/1024).
func renderIcon(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(size) / 1024

    let inset = 100 * s
    let rect = NSRect(x: inset, y: inset, width: 824 * s, height: 824 * s)
    let shape = NSBezierPath(roundedRect: rect, xRadius: 185 * s, yRadius: 185 * s)

    // Ombre portée douce.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x000000, alpha: 0.22)
    shadow.shadowBlurRadius = 24 * s
    shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    shadow.set()
    color(0xA8E6C5).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Dégradé vert pastel, plus clair en haut.
    NSGradient(starting: color(0xC9F2DC), ending: color(0x8FD8B2))!.draw(in: shape, angle: -90)

    // Reflet léger sur la moitié supérieure.
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSGradient(starting: color(0xFFFFFF, alpha: 0.35), ending: color(0xFFFFFF, alpha: 0))!
        .draw(in: NSRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Initiales « NF ».
    let base = NSFont.systemFont(ofSize: 400 * s, weight: .heavy)
    let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 400 * s) } ?? base
    let textShadow = NSShadow()
    textShadow.shadowColor = color(0xFFFFFF, alpha: 0.5)
    textShadow.shadowBlurRadius = 0
    textShadow.shadowOffset = NSSize(width: 0, height: -4 * s)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color(0x1E6B4A),
        .kern: -12 * s,
        .shadow: textShadow,
    ]
    let text = NSAttributedString(string: "NF", attributes: attrs)
    let textSize = text.size()
    text.draw(at: NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2 + 8 * s))

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        let data = renderIcon(size: pixels).representation(using: .png, properties: [:])!
        try data.write(to: outputDir.appendingPathComponent(name))
    }
}
print("Icônes écrites dans \(outputDir.path)")
