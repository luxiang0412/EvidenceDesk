// generate-app-icon.swift
//
// Renders the Evidence Desk app icon at every size macOS needs, straight into
// `EvidenceDesk/Resources/Assets.xcassets/AppIcon.appiconset`.
//
// Design intent (matches docs/DESIGN-SYSTEM.md — "Quiet Editorial"):
//   • deep ink-blue squircle: a desk at night, not a glass toy
//   • warm paper card: the evidence excerpt
//   • a single accent quote mark + rule: citation, not decoration
// Only three shapes, so the mark stays legible at 16 pt.
//
// Usage: swift scripts/generate-app-icon.swift
import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconSetDir = root
    .appendingPathComponent("EvidenceDesk/Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

try FileManager.default.createDirectory(at: iconSetDir, withIntermediateDirectories: true)

// MARK: - Palette

func rgb(_ hex: UInt32) -> CGColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255
    let g = CGFloat((hex >> 8) & 0xFF) / 255
    let b = CGFloat(hex & 0xFF) / 255
    return CGColor(red: r, green: g, blue: b, alpha: 1)
}

let inkTop = rgb(0x24486B)
let inkBottom = rgb(0x132940)
let paper = rgb(0xF7F3EA)
let paperEdge = rgb(0xE3DACA)
let accent = rgb(0x2F6FA8)
let inkText = rgb(0x33506B)

// MARK: - Drawing

/// Draws the icon into `size` × `size` points. Everything is expressed as a
/// fraction of the canvas so every size is compositionally identical.
func drawIcon(size: CGFloat) -> CGImage? {
    let px = Int(size)
    guard let ctx = CGContext(
        data: nil,
        width: px,
        height: px,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    let s = CGFloat(px)
    let canvas = CGRect(x: 0, y: 0, width: s, height: s)

    // macOS icon grid: the artwork occupies ~82% of the canvas, leaving the
    // system's optical margin.
    let inset = s * 0.09
    let body = canvas.insetBy(dx: inset, dy: inset)
    let corner = body.width * 0.225
    let squircle = CGPath(roundedRect: body, cornerWidth: corner, cornerHeight: corner, transform: nil)

    // Background: vertical ink gradient.
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    if let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [inkTop, inkBottom] as CFArray,
        locations: [0, 1]
    ) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: body.midX, y: body.maxY),
            end: CGPoint(x: body.midX, y: body.minY),
            options: []
        )
    }
    ctx.restoreGState()

    // Subtle inner edge so the shape reads on light desktops.
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.10))
    ctx.setLineWidth(max(1, s * 0.006))
    ctx.strokePath()
    ctx.restoreGState()

    // Paper card — slightly rotated for an "excerpt laid on a desk" feel.
    let cardW = body.width * 0.56
    let cardH = body.height * 0.64
    let card = CGRect(x: -cardW / 2, y: -cardH / 2, width: cardW, height: cardH)
    let cardCorner = cardW * 0.10

    ctx.saveGState()
    ctx.translateBy(x: body.midX + body.width * 0.015, y: body.midY - body.height * 0.01)
    ctx.rotate(by: -3.0 * .pi / 180)

    // Soft shadow under the card.
    ctx.setShadow(
        offset: CGSize(width: 0, height: -s * 0.012),
        blur: s * 0.035,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35)
    )
    ctx.setFillColor(paper)
    ctx.addPath(CGPath(roundedRect: card, cornerWidth: cardCorner, cornerHeight: cardCorner, transform: nil))
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    // Hairline edge.
    ctx.setStrokeColor(paperEdge)
    ctx.setLineWidth(max(0.6, s * 0.004))
    ctx.addPath(CGPath(roundedRect: card, cornerWidth: cardCorner, cornerHeight: cardCorner, transform: nil))
    ctx.strokePath()

    // Accent quote mark.
    let quoteSize = cardW * 0.42
    let quoteFont = NSFont.systemFont(ofSize: quoteSize, weight: .bold)
    let quote = NSAttributedString(string: "\u{201C}", attributes: [
        .font: quoteFont,
        .foregroundColor: NSColor(cgColor: accent) ?? .systemBlue
    ])
    let quoteRect = CGRect(
        x: card.minX + cardW * 0.10,
        y: card.maxY - cardH * 0.46,
        width: cardW * 0.5,
        height: cardH * 0.45
    )
    let previous = NSGraphicsContext.current
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    quote.draw(in: quoteRect)
    NSGraphicsContext.current = previous

    // Two text rules: body copy, the shorter one is the "citation".
    let ruleX = card.minX + cardW * 0.13
    let ruleW = cardW * 0.62
    let ruleH = max(1.2, cardH * 0.045)
    ctx.setFillColor(inkText)
    for (index, widthScale) in [1.0, 0.72].enumerated() {
        let y = card.minY + cardH * (0.34 - CGFloat(index) * 0.15)
        let rect = CGRect(x: ruleX, y: y, width: ruleW * widthScale, height: ruleH)
        ctx.addPath(CGPath(roundedRect: rect,
                           cornerWidth: ruleH / 2,
                           cornerHeight: ruleH / 2,
                           transform: nil))
        ctx.fillPath()
    }

    // Accent underline: the "source line".
    let underline = CGRect(x: ruleX, y: card.minY + cardH * 0.14,
                           width: ruleW * 0.34, height: ruleH * 1.15)
    ctx.setFillColor(accent)
    ctx.addPath(CGPath(roundedRect: underline,
                       cornerWidth: ruleH / 2,
                       cornerHeight: ruleH / 2,
                       transform: nil))
    ctx.fillPath()

    ctx.restoreGState()

    return ctx.makeImage()
}

func pngData(_ image: CGImage) -> Data? {
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: image.width, height: image.height)
    return rep.representation(using: .png, properties: [:])
}

// MARK: - Emit the asset catalog

struct Slot {
    let pointSize: Int
    let scale: Int
    var pixelSize: Int { pointSize * scale }
    var filename: String { "icon_\(pointSize)x\(pointSize)@\(scale)x.png" }
    var idiom: String { "mac" }
}

let slots: [Slot] = [
    Slot(pointSize: 16, scale: 1), Slot(pointSize: 16, scale: 2),
    Slot(pointSize: 32, scale: 1), Slot(pointSize: 32, scale: 2),
    Slot(pointSize: 128, scale: 1), Slot(pointSize: 128, scale: 2),
    Slot(pointSize: 256, scale: 1), Slot(pointSize: 256, scale: 2),
    Slot(pointSize: 512, scale: 1), Slot(pointSize: 512, scale: 2)
]

struct Entry: Codable {
    let filename: String
    let idiom: String
    let scale: String
    let size: String
}

var entries: [Entry] = []
var renderedPixels = Set<Int>()
var cachedData: [Int: Data] = [:]

for slot in slots {
    let data: Data
    if renderedPixels.contains(slot.pixelSize), let cached = cachedData[slot.pixelSize] {
        data = cached
    } else {
        guard let image = drawIcon(size: CGFloat(slot.pixelSize)), let png = pngData(image) else {
            fatalError("failed to render \(slot.pixelSize)px icon")
        }
        cachedData[slot.pixelSize] = png
        renderedPixels.insert(slot.pixelSize)
        data = png
    }
    try data.write(to: iconSetDir.appendingPathComponent(slot.filename))
    entries.append(Entry(
        filename: slot.filename,
        idiom: slot.idiom,
        scale: "\(slot.scale)x",
        size: "\(slot.pointSize)x\(slot.pointSize)"
    ))
}

let contents: [String: Any] = [
    "images": entries.map { ["filename": $0.filename, "idiom": $0.idiom, "scale": $0.scale, "size": $0.size] },
    "info": ["author": "xcode", "version": 1]
]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: iconSetDir.appendingPathComponent("Contents.json"))

// Top-level catalog metadata.
let catalogContents: [String: Any] = ["info": ["author": "xcode", "version": 1]]
let catalogJSON = try JSONSerialization.data(withJSONObject: catalogContents, options: [.prettyPrinted, .sortedKeys])
try catalogJSON.write(to: iconSetDir.deletingLastPathComponent().appendingPathComponent("Contents.json"))

print("Wrote \(entries.count) icon images to \(iconSetDir.path)")
