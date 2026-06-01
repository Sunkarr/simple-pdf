import AppKit
import CoreGraphics

func createIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    
    context.clear(CGRect(x: 0, y: 0, width: size, height: size))
    
    let scale = size / 512.0
    
    // Draw macOS App Icon Style Base (Squircle)
    let shadowPadding = 45.0 * scale
    let squircleRect = CGRect(
        x: shadowPadding,
        y: shadowPadding,
        width: size - (shadowPadding * 2),
        height: size - (shadowPadding * 2)
    )
    
    // Shadow
    context.saveGState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowOffset = NSSize(width: 0, height: -10.0 * scale)
    shadow.shadowBlurRadius = 15.0 * scale
    shadow.set()
    
    let cornerRadius = 90.0 * scale
    let squirclePath = NSBezierPath(roundedRect: squircleRect, xRadius: cornerRadius, yRadius: cornerRadius)
    
    // Red Gradient
    let colors = [
        NSColor(red: 0.95, green: 0.15, blue: 0.15, alpha: 1.0).cgColor,
        NSColor(red: 0.78, green: 0.05, blue: 0.05, alpha: 1.0).cgColor
    ]
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0]) else {
        image.unlockFocus()
        return image
    }
    
    squirclePath.addClip()
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: squircleRect.midX, y: squircleRect.maxY),
        end: CGPoint(x: squircleRect.midX, y: squircleRect.minY),
        options: []
    )
    context.restoreGState()
    
    // Subtle border
    context.saveGState()
    let borderPath = NSBezierPath(roundedRect: squircleRect, xRadius: cornerRadius, yRadius: cornerRadius)
    borderPath.lineWidth = 2.0 * scale
    NSColor.white.withAlphaComponent(0.15).setStroke()
    borderPath.stroke()
    context.restoreGState()
    
    // Draw stacked text ("simple" on top, "PDF" below)
    context.saveGState()
    
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    
    let simpleFont = NSFont.systemFont(ofSize: 56.0 * scale, weight: .medium)
    let simpleAttributes: [NSAttributedString.Key: Any] = [
        .font: simpleFont,
        .foregroundColor: NSColor.white.withAlphaComponent(0.9),
        .paragraphStyle: paragraphStyle
    ]
    
    let pdfFont = NSFont.systemFont(ofSize: 110.0 * scale, weight: .black)
    let pdfAttributes: [NSAttributedString.Key: Any] = [
        .font: pdfFont,
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraphStyle
    ]
    
    let simpleHeight = "simple".size(withAttributes: simpleAttributes).height
    let pdfHeight = "PDF".size(withAttributes: pdfAttributes).height
    let totalHeight = simpleHeight + pdfHeight + 8.0 * scale
    let startY = squircleRect.minY + (squircleRect.height - totalHeight) / 2
    
    // Draw "simple" (top)
    let simpleRect = CGRect(
        x: squircleRect.minX,
        y: startY + pdfHeight + 8.0 * scale,
        width: squircleRect.width,
        height: simpleHeight
    )
    "simple".draw(in: simpleRect, withAttributes: simpleAttributes)
    
    // Draw "PDF" (bottom)
    let pdfRect = CGRect(
        x: squircleRect.minX,
        y: startY,
        width: squircleRect.width,
        height: pdfHeight
    )
    "PDF".draw(in: pdfRect, withAttributes: pdfAttributes)
    
    context.restoreGState()
    
    image.unlockFocus()
    return image
}

func savePNG(image: NSImage, path: String) -> Bool {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        return false
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        return true
    } catch {
        print("Failed to write to \(path): \(error)")
        return false
    }
}

// Main execution
let iconsetDir = "SimplePDF.iconset"
let fileManager = FileManager.default

do {
    if fileManager.fileExists(atPath: iconsetDir) {
        try fileManager.removeItem(atPath: iconsetDir)
    }
    try fileManager.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true, attributes: nil)
} catch {
    print("Failed to create \(iconsetDir) directory: \(error)")
    exit(1)
}

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

print("Generating App Icon sizes...")
for (name, size) in sizes {
    let img = createIcon(size: size)
    let path = "\(iconsetDir)/\(name)"
    if savePNG(image: img, path: path) {
        print("Saved \(path)")
    } else {
        print("Failed to save \(path)")
        exit(1)
    }
}

print("App Icon set successfully generated.")
