import Cocoa
import CoreGraphics

// Generates a 1024x1024 PNG icon depicting a diff-style two-panel comparison.
// Usage: make_icon <output-path>

let outPath = CommandLine.arguments.dropFirst().first ?? "icon.png"

let s: CGFloat = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: Int(s),
    height: Int(s),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("Failed to create CGContext\n", stderr)
    exit(1)
}

// MARK: Background with gradient + rounded squircle clip

let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
let cornerRadius = s * 0.22
let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()

let gradient = CGGradient(
    colorsSpace: cs,
    colors: [
        CGColor(red: 0.12, green: 0.08, blue: 0.22, alpha: 1) as CFTypeRef,
        CGColor(red: 0.04, green: 0.03, blue: 0.12, alpha: 1) as CFTypeRef
    ] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: s),
    end: CGPoint(x: s, y: 0),
    options: []
)

// Subtle aurora glow
ctx.saveGState()
ctx.setBlendMode(.plusLighter)
let glowGradient = CGGradient(
    colorsSpace: cs,
    colors: [
        CGColor(red: 0.55, green: 0.36, blue: 0.96, alpha: 0.40) as CFTypeRef,
        CGColor(red: 0.55, green: 0.36, blue: 0.96, alpha: 0.0) as CFTypeRef
    ] as CFArray,
    locations: [0, 1]
)!
ctx.drawRadialGradient(
    glowGradient,
    startCenter: CGPoint(x: s * 0.20, y: s * 0.85),
    startRadius: 0,
    endCenter: CGPoint(x: s * 0.20, y: s * 0.85),
    endRadius: s * 0.60,
    options: []
)
let glowGradient2 = CGGradient(
    colorsSpace: cs,
    colors: [
        CGColor(red: 0.0, green: 0.85, blue: 0.85, alpha: 0.35) as CFTypeRef,
        CGColor(red: 0.0, green: 0.85, blue: 0.85, alpha: 0.0) as CFTypeRef
    ] as CFArray,
    locations: [0, 1]
)!
ctx.drawRadialGradient(
    glowGradient2,
    startCenter: CGPoint(x: s * 0.85, y: s * 0.15),
    startRadius: 0,
    endCenter: CGPoint(x: s * 0.85, y: s * 0.15),
    endRadius: s * 0.55,
    options: []
)
ctx.restoreGState()

ctx.restoreGState()

// MARK: Two diff panels

let panelInset: CGFloat = s * 0.16
let panelGap: CGFloat = s * 0.045
let panelTopMargin = s * 0.22
let panelBottomMargin = s * 0.20
let panelHeight = s - panelTopMargin - panelBottomMargin
let panelWidth = (s - panelInset * 2 - panelGap) / 2

let leftPanel = CGRect(
    x: panelInset,
    y: panelBottomMargin,
    width: panelWidth,
    height: panelHeight
)
let rightPanel = CGRect(
    x: panelInset + panelWidth + panelGap,
    y: panelBottomMargin,
    width: panelWidth,
    height: panelHeight
)

let panelRadius = s * 0.035

// Left panel — removed (red)
ctx.setFillColor(CGColor(red: 1.0, green: 0.28, blue: 0.42, alpha: 0.18))
ctx.addPath(CGPath(roundedRect: leftPanel, cornerWidth: panelRadius, cornerHeight: panelRadius, transform: nil))
ctx.fillPath()
ctx.setStrokeColor(CGColor(red: 1.0, green: 0.30, blue: 0.45, alpha: 0.55))
ctx.setLineWidth(s * 0.004)
ctx.addPath(CGPath(roundedRect: leftPanel, cornerWidth: panelRadius, cornerHeight: panelRadius, transform: nil))
ctx.strokePath()

// Right panel — added (green)
ctx.setFillColor(CGColor(red: 0.20, green: 0.92, blue: 0.50, alpha: 0.18))
ctx.addPath(CGPath(roundedRect: rightPanel, cornerWidth: panelRadius, cornerHeight: panelRadius, transform: nil))
ctx.fillPath()
ctx.setStrokeColor(CGColor(red: 0.20, green: 0.92, blue: 0.55, alpha: 0.55))
ctx.addPath(CGPath(roundedRect: rightPanel, cornerWidth: panelRadius, cornerHeight: panelRadius, transform: nil))
ctx.strokePath()

// MARK: Text-like lines inside each panel

func drawLines(in panel: CGRect, baseColor: CGColor, widthFactors: [CGFloat], alphas: [CGFloat]) {
    let linePadding = panel.width * 0.10
    let lineHeight = s * 0.035
    let lineSpacing = s * 0.058
    let count = min(widthFactors.count, alphas.count)
    let totalHeight = CGFloat(count) * lineSpacing
    var y = panel.maxY - (panel.height - totalHeight) / 2 - lineHeight

    for i in 0..<count {
        let width = (panel.width - linePadding * 2) * widthFactors[i]
        let rect = CGRect(x: panel.minX + linePadding, y: y, width: width, height: lineHeight)
        ctx.setFillColor(baseColor.copy(alpha: alphas[i])!)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: s * 0.008, cornerHeight: s * 0.008, transform: nil))
        ctx.fillPath()
        y -= lineSpacing
    }
}

let redBase = CGColor(red: 1.0, green: 0.50, blue: 0.58, alpha: 1)
let greenBase = CGColor(red: 0.40, green: 0.98, blue: 0.55, alpha: 1)

drawLines(
    in: leftPanel,
    baseColor: redBase,
    widthFactors: [1.0, 0.7, 0.92, 0.55, 0.85],
    alphas: [0.95, 0.65, 0.85, 0.50, 0.75]
)
drawLines(
    in: rightPanel,
    baseColor: greenBase,
    widthFactors: [1.0, 0.85, 0.6, 0.95, 0.7],
    alphas: [0.95, 0.85, 0.55, 0.80, 0.65]
)

// MARK: Connecting glyph in the gap — a stylized double-arrow

let gapCenter = CGPoint(x: panelInset + panelWidth + panelGap / 2, y: s * 0.50)
let arrowSize = panelGap * 0.85
ctx.saveGState()
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.85))
let arrowPath = CGMutablePath()
// Left arrow ◀
arrowPath.move(to: CGPoint(x: gapCenter.x - arrowSize * 0.5, y: gapCenter.y + arrowSize * 0.4))
arrowPath.addLine(to: CGPoint(x: gapCenter.x - arrowSize * 0.5, y: gapCenter.y - arrowSize * 0.4))
arrowPath.addLine(to: CGPoint(x: gapCenter.x - arrowSize, y: gapCenter.y))
arrowPath.closeSubpath()
// Right arrow ▶
arrowPath.move(to: CGPoint(x: gapCenter.x + arrowSize * 0.5, y: gapCenter.y + arrowSize * 0.4))
arrowPath.addLine(to: CGPoint(x: gapCenter.x + arrowSize * 0.5, y: gapCenter.y - arrowSize * 0.4))
arrowPath.addLine(to: CGPoint(x: gapCenter.x + arrowSize, y: gapCenter.y))
arrowPath.closeSubpath()
ctx.addPath(arrowPath)
ctx.fillPath()
ctx.restoreGState()

// MARK: Output PNG

guard let cgImage = ctx.makeImage() else {
    fputs("Failed to render image\n", stderr)
    exit(1)
}
let bitmap = NSBitmapImageRep(cgImage: cgImage)
guard let data = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}

do {
    try data.write(to: URL(fileURLWithPath: outPath))
    print("Icon written: \(outPath)")
} catch {
    fputs("Failed to write icon: \(error)\n", stderr)
    exit(1)
}
