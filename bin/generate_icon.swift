#!/usr/bin/env swift
import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
let tileRect = rect.insetBy(dx: 100, dy: 100)
let cornerRadius: CGFloat = 232

// Modern gradient background - blue to purple theme for inspection/analysis
let backgroundPath = NSBezierPath(roundedRect: tileRect, xRadius: cornerRadius, yRadius: cornerRadius)

let topColor = NSColor(calibratedRed: 59.0/255.0, green: 130.0/255.0, blue: 246.0/255.0, alpha: 1.0)     // Bright blue
let bottomColor = NSColor(calibratedRed: 139.0/255.0, green: 92.0/255.0, blue: 246.0/255.0, alpha: 1.0) // Purple

let gradient = NSGradient(starting: topColor, ending: bottomColor)!
gradient.draw(in: backgroundPath, angle: -45)

// Subtle highlight on top edge
let highlightPath = NSBezierPath(roundedRect: tileRect.insetBy(dx: 4, dy: 4), xRadius: cornerRadius - 4, yRadius: cornerRadius - 4)
NSColor.white.withAlphaComponent(0.2).setStroke()
highlightPath.lineWidth = 3
highlightPath.stroke()

// Deeper shadow for depth
let glyphShadow = NSShadow()
glyphShadow.shadowBlurRadius = 24
glyphShadow.shadowOffset = NSSize(width: 0, height: -6)
glyphShadow.shadowColor = NSColor.black.withAlphaComponent(0.35)

// Crisp white glyph
let glyphColor = NSColor(calibratedRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)

// Draw magnifying glass with document symbol - represents inspection/analysis
let symbolConfig = NSImage.SymbolConfiguration(pointSize: 520, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [glyphColor]))

if let symbol = NSImage(systemSymbolName: "doc.text.magnifyingglass", accessibilityDescription: nil)?
    .withSymbolConfiguration(symbolConfig) {
    
    let targetRect = tileRect.insetBy(dx: 120, dy: 120)
    let symbolSize = symbol.size
    let scale = min(targetRect.width / symbolSize.width, targetRect.height / symbolSize.height)
    let scaledSize = NSSize(width: symbolSize.width * scale, height: symbolSize.height * scale)
    let drawRect = NSRect(
        x: targetRect.midX - scaledSize.width / 2,
        y: targetRect.midY - scaledSize.height / 2,
        width: scaledSize.width,
        height: scaledSize.height
    )
    
    NSGraphicsContext.saveGraphicsState()
    glyphShadow.set()
    symbol.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()
}

// Add a subtle checkmark badge in bottom right to indicate validation
let badgeSize: CGFloat = 180
let badgeRect = NSRect(
    x: tileRect.maxX - badgeSize - 60,
    y: tileRect.minY + 60,
    width: badgeSize,
    height: badgeSize
)

// Badge background circle with shadow
let badgeShadow = NSShadow()
badgeShadow.shadowBlurRadius = 12
badgeShadow.shadowOffset = NSSize(width: 0, height: -3)
badgeShadow.shadowColor = NSColor.black.withAlphaComponent(0.3)

NSGraphicsContext.saveGraphicsState()
badgeShadow.set()

let badgePath = NSBezierPath(ovalIn: badgeRect)
NSColor(calibratedRed: 16.0/255.0, green: 185.0/255.0, blue: 129.0/255.0, alpha: 1.0).setFill() // Emerald green
badgePath.fill()

NSGraphicsContext.restoreGraphicsState()

// Checkmark in badge
let checkmarkConfig = NSImage.SymbolConfiguration(pointSize: 100, weight: .bold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor.white]))

if let checkmark = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)?
    .withSymbolConfiguration(checkmarkConfig) {
    
    let checkmarkSize = checkmark.size
    let checkmarkRect = NSRect(
        x: badgeRect.midX - checkmarkSize.width / 2,
        y: badgeRect.midY - checkmarkSize.height / 2 + 5,
        width: checkmarkSize.width,
        height: checkmarkSize.height
    )
    
    checkmark.draw(in: checkmarkRect, from: .zero, operation: .sourceOver, fraction: 1.0)
}

image.unlockFocus()

// Save as PNG
let pngData = image.tiffRepresentation.flatMap { NSBitmapImageRep(data: $0) }?.representation(using: .png, properties: [:])

if let data = pngData {
    let url = URL(fileURLWithPath: "Icon.png")
    try? data.write(to: url)
    print("Icon.png generated at \(url.path)")
} else {
    print("Failed to generate icon")
    exit(1)
}
