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
    
    // Red Gradient — same subtle gradient as original SimplePDF
    // Top: #EF2524 area (bright red), Bottom: slightly darker
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
    
    // Draw angular anvil in white
    context.saveGState()
    
    // Clip to squircle for safety
    let clipPath = NSBezierPath(roundedRect: squircleRect, xRadius: cornerRadius, yRadius: cornerRadius)
    clipPath.addClip()
    
    let anvilColor = NSColor.white
    anvilColor.setFill()
    
    // Anvil center (centered visually with sparks)
    let cx = squircleRect.midX
    let cy = squircleRect.midY - 10.0 * scale
    
    // Symmetrical Anvil Dimensions matching reference image exactly
    let hornWidth = 130.0 * scale // Distance from center to horn tip
    let hornTopY = cy + 40.0 * scale
    let hornTipThickness = 12.0 * scale
    let hornBottomY = hornTopY - hornTipThickness
    
    let waistWidth = 110.0 * scale // Middle vertical section
    let waistTopY = cy - 5.0 * scale
    let waistBottomY = cy - 25.0 * scale
    
    let baseWidth = 140.0 * scale // Flared bottom section
    let baseTopY = cy - 40.0 * scale
    let baseBottomY = cy - 55.0 * scale
    
    let archRadius = 28.0 * scale // Semicircular cutout
    
    let anvilPath = CGMutablePath()
    
    // Start at Top Right horn tip
    anvilPath.move(to: CGPoint(x: cx + hornWidth, y: hornTopY))
    
    // Straight across to Top Left horn tip
    anvilPath.addLine(to: CGPoint(x: cx - hornWidth, y: hornTopY))
    
    // Down to left horn bottom tip (blunt end)
    anvilPath.addLine(to: CGPoint(x: cx - hornWidth, y: hornBottomY))
    
    // In and down to left waist top
    anvilPath.addLine(to: CGPoint(x: cx - waistWidth/2, y: waistTopY))
    
    // Straight down to left waist bottom
    anvilPath.addLine(to: CGPoint(x: cx - waistWidth/2, y: waistBottomY))
    
    // Out and down to left base top
    anvilPath.addLine(to: CGPoint(x: cx - baseWidth/2, y: baseTopY))
    
    // Straight down to left base bottom
    anvilPath.addLine(to: CGPoint(x: cx - baseWidth/2, y: baseBottomY))
    
    // Line to start of arch (left side)
    anvilPath.addLine(to: CGPoint(x: cx - archRadius, y: baseBottomY))
    
    // Arch to right side (clockwise to draw the upper half)
    anvilPath.addArc(center: CGPoint(x: cx, y: baseBottomY), radius: archRadius, startAngle: .pi, endAngle: 0, clockwise: true)
    
    // Line to right base bottom
    anvilPath.addLine(to: CGPoint(x: cx + baseWidth/2, y: baseBottomY))
    
    // Straight up to right base top
    anvilPath.addLine(to: CGPoint(x: cx + baseWidth/2, y: baseTopY))
    
    // In and up to right waist bottom
    anvilPath.addLine(to: CGPoint(x: cx + waistWidth/2, y: waistBottomY))
    
    // Straight up to right waist top
    anvilPath.addLine(to: CGPoint(x: cx + waistWidth/2, y: waistTopY))
    
    // Out and up to right horn bottom tip
    anvilPath.addLine(to: CGPoint(x: cx + hornWidth, y: hornBottomY))
    
    // Close path (goes to top right horn tip)
    anvilPath.closeSubpath()
    
    context.addPath(anvilPath)
    context.fillPath()
    
    // --- SPARKS (dynamic streaks flying off) ---
    context.saveGState()
    
    // Re-clip to squircle
    let sparkClip = NSBezierPath(roundedRect: squircleRect, xRadius: cornerRadius, yRadius: cornerRadius)
    sparkClip.addClip()
    
    context.setLineCap(.round)
    
    // Sparks shoot outwards from the center of the anvil
    let strikeY = hornTopY + 5.0 * scale
    
    // Define sparks as (dx, dy) for start point and (dx, dy) for end point, plus line width
    let sparks: [(startX: CGFloat, startY: CGFloat, endX: CGFloat, endY: CGFloat, width: CGFloat, alpha: CGFloat)] = [
        // Central fast burst
        (-15.0, 20.0, -25.0, 50.0, 4.0, 1.0),
        (10.0, 25.0, 25.0, 65.0, 5.0, 0.9),
        (-5.0, 45.0, -10.0, 85.0, 3.0, 0.7),
        
        // Side spray
        (35.0, 15.0, 65.0, 35.0, 3.5, 0.8),
        (-35.0, 10.0, -65.0, 25.0, 3.0, 0.6),
        (45.0, 45.0, 75.0, 60.0, 2.5, 0.5),
        (-40.0, 50.0, -60.0, 75.0, 2.0, 0.5),
    ]
    
    for spark in sparks {
        context.setStrokeColor(NSColor.white.withAlphaComponent(spark.alpha).cgColor)
        context.setLineWidth(spark.width * scale)
        
        let path = CGMutablePath()
        path.move(to: CGPoint(x: cx + spark.startX * scale, y: strikeY + spark.startY * scale))
        path.addLine(to: CGPoint(x: cx + spark.endX * scale, y: strikeY + spark.endY * scale))
        
        context.addPath(path)
        context.strokePath()
    }
    
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

// Main execution — generate a preview at 512px
let previewPath = "sindri_icon_preview.png"
let previewImage = createIcon(size: 1024)
if savePNG(image: previewImage, path: previewPath) {
    print("Preview saved to \(previewPath)")
} else {
    print("Failed to save preview")
    exit(1)
}

// Also generate full iconset
let iconsetDir = "SindriPDF.iconset"
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

print("Generating SindriPDF App Icon sizes...")
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

print("SindriPDF App Icon set successfully generated.")
