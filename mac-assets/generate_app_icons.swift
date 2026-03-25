import AppKit
import Foundation

enum IconVariant: String {
    case main
    case stop
}

struct Palette {
    let backgroundTop: NSColor
    let backgroundBottom: NSColor
    let rim: NSColor
    let accent: NSColor
    let accentSoft: NSColor
    let ticket: NSColor
    let ticketShadow: NSColor
    let badge: NSColor

    static let main = Palette(
        backgroundTop: NSColor(calibratedRed: 0.07, green: 0.11, blue: 0.23, alpha: 1.0),
        backgroundBottom: NSColor(calibratedRed: 0.13, green: 0.20, blue: 0.35, alpha: 1.0),
        rim: NSColor(calibratedRed: 0.51, green: 0.83, blue: 0.79, alpha: 0.22),
        accent: NSColor(calibratedRed: 0.95, green: 0.70, blue: 0.23, alpha: 1.0),
        accentSoft: NSColor(calibratedRed: 0.98, green: 0.87, blue: 0.59, alpha: 1.0),
        ticket: NSColor(calibratedRed: 0.99, green: 0.97, blue: 0.92, alpha: 1.0),
        ticketShadow: NSColor(calibratedRed: 0.02, green: 0.04, blue: 0.10, alpha: 0.18),
        badge: NSColor(calibratedRed: 0.12, green: 0.69, blue: 0.64, alpha: 1.0)
    )

    static let stop = Palette(
        backgroundTop: NSColor(calibratedRed: 0.12, green: 0.11, blue: 0.18, alpha: 1.0),
        backgroundBottom: NSColor(calibratedRed: 0.21, green: 0.16, blue: 0.24, alpha: 1.0),
        rim: NSColor(calibratedRed: 0.93, green: 0.41, blue: 0.35, alpha: 0.25),
        accent: NSColor(calibratedRed: 0.95, green: 0.70, blue: 0.23, alpha: 1.0),
        accentSoft: NSColor(calibratedRed: 0.98, green: 0.87, blue: 0.59, alpha: 1.0),
        ticket: NSColor(calibratedRed: 0.99, green: 0.97, blue: 0.92, alpha: 1.0),
        ticketShadow: NSColor(calibratedRed: 0.03, green: 0.03, blue: 0.06, alpha: 0.20),
        badge: NSColor(calibratedRed: 0.90, green: 0.28, blue: 0.24, alpha: 1.0)
    )
}

@main
struct IconRenderer {
    static func main() throws {
        guard CommandLine.arguments.count >= 3 else {
            fputs("Usage: generate_app_icons.swift <output.png> <main|stop>\n", stderr)
            exit(1)
        }

        let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
        guard let variant = IconVariant(rawValue: CommandLine.arguments[2]) else {
            fputs("Unknown icon variant.\n", stderr)
            exit(1)
        }

        let size = CGFloat(1024)
        let outputRect = NSRect(x: 0, y: 0, width: size, height: size)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size),
            pixelsHigh: Int(size),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            fputs("Failed to allocate bitmap.\n", stderr)
            exit(1)
        }

        bitmap.size = outputRect.size
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            fputs("Failed to create graphics context.\n", stderr)
            exit(1)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        drawIcon(in: outputRect, variant: variant)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            fputs("Failed to encode PNG.\n", stderr)
            exit(1)
        }

        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try pngData.write(to: outputURL)
    }

    static func drawIcon(in rect: NSRect, variant: IconVariant) {
        let palette = variant == .main ? Palette.main : Palette.stop

        let cornerRadius = rect.width * 0.22
        let basePath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        let baseGradient = NSGradient(starting: palette.backgroundTop, ending: palette.backgroundBottom)
        baseGradient?.draw(in: basePath, angle: 90)

        drawBackdrop(in: rect, palette: palette)
        drawTicket(in: rect, palette: palette)
        drawScanner(in: rect, palette: palette)
        drawCodeBars(in: rect, palette: palette)
        drawBottomBadge(in: rect, palette: palette)

        if variant == .stop {
            drawStopBadge(in: rect, palette: palette)
        }
    }

    static func drawBackdrop(in rect: NSRect, palette: Palette) {
        let haloRect = rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.08)
        let haloPath = NSBezierPath(ovalIn: haloRect)
        palette.rim.setFill()
        haloPath.fill()

        let upperGlowRect = NSRect(
            x: rect.minX + rect.width * 0.12,
            y: rect.minY + rect.height * 0.62,
            width: rect.width * 0.42,
            height: rect.height * 0.20
        )
        let glowPath = NSBezierPath(ovalIn: upperGlowRect)
        palette.accent.withAlphaComponent(0.14).setFill()
        glowPath.fill()

        let rimRect = rect.insetBy(dx: rect.width * 0.035, dy: rect.height * 0.035)
        let rimPath = NSBezierPath(roundedRect: rimRect, xRadius: rect.width * 0.19, yRadius: rect.height * 0.19)
        palette.rim.withAlphaComponent(0.65).setStroke()
        rimPath.lineWidth = rect.width * 0.012
        rimPath.stroke()
    }

    static func drawTicket(in rect: NSRect, palette: Palette) {
        let ticketRect = NSRect(
            x: rect.minX + rect.width * 0.22,
            y: rect.minY + rect.height * 0.30,
            width: rect.width * 0.56,
            height: rect.height * 0.40
        )

        let shadowRect = ticketRect.offsetBy(dx: 0, dy: -rect.height * 0.018)
        let shadowPath = NSBezierPath(roundedRect: shadowRect, xRadius: rect.width * 0.08, yRadius: rect.width * 0.08)
        palette.ticketShadow.setFill()
        shadowPath.fill()

        let ticketShape = NSBezierPath()
        ticketShape.windingRule = .evenOdd
        ticketShape.appendRoundedRect(ticketRect, xRadius: rect.width * 0.085, yRadius: rect.width * 0.085)

        let notchDiameter = rect.width * 0.11
        let notchY = ticketRect.midY - notchDiameter / 2
        ticketShape.appendOval(in: NSRect(x: ticketRect.minX - notchDiameter / 2, y: notchY, width: notchDiameter, height: notchDiameter))
        ticketShape.appendOval(in: NSRect(x: ticketRect.maxX - notchDiameter / 2, y: notchY, width: notchDiameter, height: notchDiameter))

        palette.ticket.setFill()
        ticketShape.fill()

        let topStrip = NSRect(
            x: ticketRect.minX + ticketRect.width * 0.08,
            y: ticketRect.maxY - ticketRect.height * 0.16,
            width: ticketRect.width * 0.42,
            height: ticketRect.height * 0.06
        )
        let topStripPath = NSBezierPath(roundedRect: topStrip, xRadius: topStrip.height / 2, yRadius: topStrip.height / 2)
        palette.accent.withAlphaComponent(0.16).setFill()
        topStripPath.fill()
    }

    static func drawScanner(in rect: NSRect, palette: Palette) {
        let scannerRect = NSRect(
            x: rect.minX + rect.width * 0.24,
            y: rect.minY + rect.height * 0.34,
            width: rect.width * 0.52,
            height: rect.height * 0.34
        )
        let length = rect.width * 0.075
        let lineWidth = rect.width * 0.018
        let bracketColor = palette.accentSoft
        bracketColor.setStroke()

        func strokeBracket(from start: NSPoint, horizontal: CGFloat, vertical: CGFloat) {
            let path = NSBezierPath()
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            path.move(to: start)
            path.line(to: NSPoint(x: start.x + horizontal, y: start.y))
            path.move(to: start)
            path.line(to: NSPoint(x: start.x, y: start.y + vertical))
            path.stroke()
        }

        strokeBracket(from: NSPoint(x: scannerRect.minX, y: scannerRect.maxY), horizontal: length, vertical: -length)
        strokeBracket(from: NSPoint(x: scannerRect.maxX, y: scannerRect.maxY), horizontal: -length, vertical: -length)
        strokeBracket(from: NSPoint(x: scannerRect.minX, y: scannerRect.minY), horizontal: length, vertical: length)
        strokeBracket(from: NSPoint(x: scannerRect.maxX, y: scannerRect.minY), horizontal: -length, vertical: length)

        let scanLineRect = NSRect(
            x: scannerRect.minX + rect.width * 0.05,
            y: scannerRect.midY - rect.height * 0.009,
            width: scannerRect.width - rect.width * 0.10,
            height: rect.height * 0.018
        )
        let scanLinePath = NSBezierPath(roundedRect: scanLineRect, xRadius: scanLineRect.height / 2, yRadius: scanLineRect.height / 2)
        palette.badge.withAlphaComponent(0.92).setFill()
        scanLinePath.fill()
    }

    static func drawCodeBars(in rect: NSRect, palette: Palette) {
        let groupRect = NSRect(
            x: rect.minX + rect.width * 0.32,
            y: rect.minY + rect.height * 0.43,
            width: rect.width * 0.36,
            height: rect.height * 0.08
        )

        let barCount = 5
        let gap = groupRect.width * 0.04
        let barWidth = (groupRect.width - gap * CGFloat(barCount - 1)) / CGFloat(barCount)
        let heights: [CGFloat] = [0.62, 0.92, 0.74, 0.88, 0.56]

        for index in 0..<barCount {
            let barHeight = groupRect.height * heights[index]
            let x = groupRect.minX + CGFloat(index) * (barWidth + gap)
            let y = groupRect.midY - barHeight / 2
            let barRect = NSRect(x: x, y: y, width: barWidth, height: barHeight)
            let barPath = NSBezierPath(roundedRect: barRect, xRadius: barWidth / 2, yRadius: barWidth / 2)
            palette.accent.setFill()
            barPath.fill()
        }
    }

    static func drawBottomBadge(in rect: NSRect, palette: Palette) {
        let badgeRect = NSRect(
            x: rect.minX + rect.width * 0.32,
            y: rect.minY + rect.height * 0.20,
            width: rect.width * 0.36,
            height: rect.height * 0.10
        )
        let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: badgeRect.height / 2, yRadius: badgeRect.height / 2)
        palette.badge.setFill()
        badgePath.fill()

        let dotSize = rect.width * 0.04
        let dotY = badgeRect.midY - dotSize / 2
        let dotXs = [0.16, 0.50, 0.84].map { badgeRect.minX + badgeRect.width * CGFloat($0) - dotSize / 2 }
        palette.ticket.setFill()
        for x in dotXs {
            NSBezierPath(ovalIn: NSRect(x: x, y: dotY, width: dotSize, height: dotSize)).fill()
        }
    }

    static func drawStopBadge(in rect: NSRect, palette: Palette) {
        let badgeDiameter = rect.width * 0.25
        let badgeRect = NSRect(
            x: rect.maxX - badgeDiameter - rect.width * 0.12,
            y: rect.minY + rect.height * 0.10,
            width: badgeDiameter,
            height: badgeDiameter
        )
        let badgePath = NSBezierPath(ovalIn: badgeRect)
        palette.badge.setFill()
        badgePath.fill()

        let minusRect = NSRect(
            x: badgeRect.minX + badgeRect.width * 0.22,
            y: badgeRect.midY - badgeRect.height * 0.06,
            width: badgeRect.width * 0.56,
            height: badgeRect.height * 0.12
        )
        let minusPath = NSBezierPath(roundedRect: minusRect, xRadius: minusRect.height / 2, yRadius: minusRect.height / 2)
        NSColor.white.setFill()
        minusPath.fill()
    }
}
