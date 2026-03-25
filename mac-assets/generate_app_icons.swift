import AppKit
import Foundation

enum IconVariant: String {
    case main
    case stop
}

struct Palette {
    let backgroundTop: NSColor
    let backgroundBottom: NSColor
    let ambientGlow: NSColor
    let moonFill: NSColor
    let moonRim: NSColor
    let bodyDark: NSColor
    let bodyLight: NSColor
    let horn: NSColor
    let crown: NSColor
    let crownDark: NSColor
    let gem: NSColor
    let nose: NSColor
    let scarf: NSColor
    let staff: NSColor
    let staffGold: NSColor
    let eyeBrown: NSColor
    let lightning: NSColor
    let stopBadge: NSColor

    static let main = Palette(
        backgroundTop: NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.20, alpha: 1.0),
        backgroundBottom: NSColor(calibratedRed: 0.15, green: 0.30, blue: 0.36, alpha: 1.0),
        ambientGlow: NSColor(calibratedRed: 0.97, green: 0.48, blue: 0.17, alpha: 0.18),
        moonFill: NSColor(calibratedRed: 0.99, green: 0.95, blue: 0.84, alpha: 1.0),
        moonRim: NSColor(calibratedRed: 0.98, green: 0.88, blue: 0.58, alpha: 0.58),
        bodyDark: NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.09, alpha: 1.0),
        bodyLight: NSColor(calibratedRed: 0.24, green: 0.24, blue: 0.27, alpha: 1.0),
        horn: NSColor(calibratedRed: 0.94, green: 0.17, blue: 0.12, alpha: 1.0),
        crown: NSColor(calibratedRed: 0.98, green: 0.80, blue: 0.23, alpha: 1.0),
        crownDark: NSColor(calibratedRed: 0.78, green: 0.53, blue: 0.10, alpha: 1.0),
        gem: NSColor(calibratedRed: 0.90, green: 0.13, blue: 0.10, alpha: 1.0),
        nose: NSColor(calibratedRed: 0.16, green: 0.67, blue: 0.96, alpha: 1.0),
        scarf: NSColor(calibratedRed: 0.87, green: 0.11, blue: 0.11, alpha: 1.0),
        staff: NSColor(calibratedRed: 0.84, green: 0.12, blue: 0.10, alpha: 1.0),
        staffGold: NSColor(calibratedRed: 0.95, green: 0.73, blue: 0.17, alpha: 1.0),
        eyeBrown: NSColor(calibratedRed: 0.39, green: 0.22, blue: 0.10, alpha: 1.0),
        lightning: NSColor(calibratedRed: 0.98, green: 0.98, blue: 1.0, alpha: 1.0),
        stopBadge: NSColor(calibratedRed: 0.88, green: 0.21, blue: 0.18, alpha: 1.0)
    )

    static let stop = Palette(
        backgroundTop: NSColor(calibratedRed: 0.12, green: 0.09, blue: 0.14, alpha: 1.0),
        backgroundBottom: NSColor(calibratedRed: 0.22, green: 0.13, blue: 0.16, alpha: 1.0),
        ambientGlow: NSColor(calibratedRed: 0.95, green: 0.25, blue: 0.20, alpha: 0.18),
        moonFill: NSColor(calibratedRed: 0.98, green: 0.94, blue: 0.85, alpha: 1.0),
        moonRim: NSColor(calibratedRed: 0.98, green: 0.78, blue: 0.37, alpha: 0.52),
        bodyDark: NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.09, alpha: 1.0),
        bodyLight: NSColor(calibratedRed: 0.24, green: 0.24, blue: 0.27, alpha: 1.0),
        horn: NSColor(calibratedRed: 0.94, green: 0.17, blue: 0.12, alpha: 1.0),
        crown: NSColor(calibratedRed: 0.98, green: 0.80, blue: 0.23, alpha: 1.0),
        crownDark: NSColor(calibratedRed: 0.78, green: 0.53, blue: 0.10, alpha: 1.0),
        gem: NSColor(calibratedRed: 0.90, green: 0.13, blue: 0.10, alpha: 1.0),
        nose: NSColor(calibratedRed: 0.16, green: 0.67, blue: 0.96, alpha: 1.0),
        scarf: NSColor(calibratedRed: 0.87, green: 0.11, blue: 0.11, alpha: 1.0),
        staff: NSColor(calibratedRed: 0.84, green: 0.12, blue: 0.10, alpha: 1.0),
        staffGold: NSColor(calibratedRed: 0.95, green: 0.73, blue: 0.17, alpha: 1.0),
        eyeBrown: NSColor(calibratedRed: 0.39, green: 0.22, blue: 0.10, alpha: 1.0),
        lightning: NSColor(calibratedRed: 0.98, green: 0.98, blue: 1.0, alpha: 1.0),
        stopBadge: NSColor(calibratedRed: 0.90, green: 0.22, blue: 0.20, alpha: 1.0)
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

        drawBase(in: rect, palette: palette)
        drawMoon(in: rect, palette: palette)
        drawAmbientGlow(in: rect, palette: palette)
        drawStaff(in: rect, palette: palette)
        drawCape(in: rect, palette: palette)
        drawBody(in: rect, palette: palette)
        drawHead(in: rect, palette: palette)
        drawHorns(in: rect, palette: palette)
        drawCrown(in: rect, palette: palette)
        drawEyes(in: rect, palette: palette)
        drawNoseAndSmile(in: rect, palette: palette)
        drawScarf(in: rect, palette: palette)
        drawLightning(in: rect, palette: palette)

        if variant == .stop {
            drawStopBadge(in: rect, palette: palette)
        }
    }

    static func drawBase(in rect: NSRect, palette: Palette) {
        let basePath = NSBezierPath(
            roundedRect: rect,
            xRadius: rect.width * 0.22,
            yRadius: rect.width * 0.22
        )
        let gradient = NSGradient(starting: palette.backgroundTop, ending: palette.backgroundBottom)
        gradient?.draw(in: basePath, angle: 90)

        let rimPath = NSBezierPath(
            roundedRect: rect.insetBy(dx: rect.width * 0.03, dy: rect.width * 0.03),
            xRadius: rect.width * 0.19,
            yRadius: rect.width * 0.19
        )
        palette.moonRim.withAlphaComponent(0.35).setStroke()
        rimPath.lineWidth = rect.width * 0.012
        rimPath.stroke()
    }

    static func drawAmbientGlow(in rect: NSRect, palette: Palette) {
        let glowRect = NSRect(
            x: rect.minX + rect.width * 0.07,
            y: rect.minY + rect.height * 0.54,
            width: rect.width * 0.50,
            height: rect.height * 0.30
        )
        let glowPath = NSBezierPath(ovalIn: glowRect)
        palette.ambientGlow.setFill()
        glowPath.fill()
    }

    static func drawMoon(in rect: NSRect, palette: Palette) {
        let moonRect = NSRect(
            x: rect.minX + rect.width * 0.14,
            y: rect.minY + rect.height * 0.12,
            width: rect.width * 0.72,
            height: rect.height * 0.72
        )
        let moonPath = NSBezierPath(ovalIn: moonRect)
        palette.moonFill.setFill()
        moonPath.fill()

        palette.moonRim.withAlphaComponent(0.55).setStroke()
        moonPath.lineWidth = rect.width * 0.012
        moonPath.stroke()
    }

    static func drawStaff(in rect: NSRect, palette: Palette) {
        let center = NSPoint(x: rect.midX + rect.width * 0.01, y: rect.midY + rect.height * 0.14)
        fillRotatedCapsule(
            center: center,
            length: rect.width * 0.92,
            thickness: rect.width * 0.072,
            angle: -14,
            color: palette.staff
        )

        fillRotatedCapsule(
            center: NSPoint(x: rect.midX + rect.width * 0.33, y: rect.midY + rect.height * 0.21),
            length: rect.width * 0.26,
            thickness: rect.width * 0.086,
            angle: -14,
            color: palette.staffGold
        )
    }

    static func drawCape(in rect: NSRect, palette: Palette) {
        let cape = NSBezierPath()
        cape.move(to: NSPoint(x: rect.midX - rect.width * 0.03, y: rect.midY + rect.height * 0.01))
        cape.curve(
            to: NSPoint(x: rect.midX + rect.width * 0.32, y: rect.midY - rect.height * 0.00),
            controlPoint1: NSPoint(x: rect.midX + rect.width * 0.10, y: rect.midY + rect.height * 0.05),
            controlPoint2: NSPoint(x: rect.midX + rect.width * 0.27, y: rect.midY + rect.height * 0.10)
        )
        cape.curve(
            to: NSPoint(x: rect.midX + rect.width * 0.10, y: rect.midY - rect.height * 0.15),
            controlPoint1: NSPoint(x: rect.midX + rect.width * 0.32, y: rect.midY - rect.height * 0.12),
            controlPoint2: NSPoint(x: rect.midX + rect.width * 0.18, y: rect.midY - rect.height * 0.18)
        )
        cape.close()
        palette.scarf.withAlphaComponent(0.82).setFill()
        cape.fill()
    }

    static func drawBody(in rect: NSRect, palette: Palette) {
        let bodyRect = NSRect(
            x: rect.midX - rect.width * 0.15,
            y: rect.minY + rect.height * 0.10,
            width: rect.width * 0.31,
            height: rect.height * 0.30
        )
        let bodyPath = NSBezierPath(ovalIn: bodyRect)
        let bodyGradient = NSGradient(starting: palette.bodyLight, ending: palette.bodyDark)
        bodyGradient?.draw(in: bodyPath, angle: 120)

        palette.bodyLight.withAlphaComponent(0.38).setStroke()
        bodyPath.lineWidth = rect.width * 0.010
        bodyPath.stroke()

        let leftArm = NSBezierPath()
        leftArm.move(to: NSPoint(x: rect.midX - rect.width * 0.10, y: rect.minY + rect.height * 0.25))
        leftArm.curve(
            to: NSPoint(x: rect.midX - rect.width * 0.30, y: rect.minY + rect.height * 0.24),
            controlPoint1: NSPoint(x: rect.midX - rect.width * 0.19, y: rect.minY + rect.height * 0.28),
            controlPoint2: NSPoint(x: rect.midX - rect.width * 0.28, y: rect.minY + rect.height * 0.30)
        )
        leftArm.curve(
            to: NSPoint(x: rect.midX - rect.width * 0.25, y: rect.minY + rect.height * 0.14),
            controlPoint1: NSPoint(x: rect.midX - rect.width * 0.31, y: rect.minY + rect.height * 0.18),
            controlPoint2: NSPoint(x: rect.midX - rect.width * 0.29, y: rect.minY + rect.height * 0.11)
        )
        leftArm.curve(
            to: NSPoint(x: rect.midX - rect.width * 0.08, y: rect.minY + rect.height * 0.18),
            controlPoint1: NSPoint(x: rect.midX - rect.width * 0.20, y: rect.minY + rect.height * 0.15),
            controlPoint2: NSPoint(x: rect.midX - rect.width * 0.11, y: rect.minY + rect.height * 0.17)
        )
        leftArm.close()
        palette.bodyDark.setFill()
        leftArm.fill()
    }

    static func drawHead(in rect: NSRect, palette: Palette) {
        let headRect = NSRect(
            x: rect.midX - rect.width * 0.26,
            y: rect.minY + rect.height * 0.24,
            width: rect.width * 0.52,
            height: rect.height * 0.48
        )

        let shadow = NSShadow()
        shadow.shadowBlurRadius = rect.width * 0.035
        shadow.shadowOffset = NSSize(width: 0, height: -rect.height * 0.01)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        NSGraphicsContext.saveGraphicsState()
        shadow.set()

        let headPath = NSBezierPath(ovalIn: headRect)
        let gradient = NSGradient(colors: [
            palette.bodyLight,
            palette.bodyDark,
            palette.bodyDark
        ])
        gradient?.draw(in: headPath, angle: 120)
        NSGraphicsContext.restoreGraphicsState()

        palette.bodyLight.withAlphaComponent(0.42).setStroke()
        headPath.lineWidth = rect.width * 0.010
        headPath.stroke()

        let faceGlowRect = NSRect(
            x: headRect.minX + headRect.width * 0.12,
            y: headRect.midY + headRect.height * 0.02,
            width: headRect.width * 0.32,
            height: headRect.height * 0.20
        )
        let faceGlow = NSBezierPath(ovalIn: faceGlowRect)
        palette.moonFill.withAlphaComponent(0.08).setFill()
        faceGlow.fill()
    }

    static func drawHorns(in rect: NSRect, palette: Palette) {
        func hornPath(side: CGFloat) -> NSBezierPath {
            let path = NSBezierPath()
            let startX = rect.midX + side * rect.width * 0.12
            let startY = rect.minY + rect.height * 0.67
            path.move(to: NSPoint(x: startX, y: startY))
            path.curve(
                to: NSPoint(x: startX + side * rect.width * 0.045, y: rect.minY + rect.height * 0.95),
                controlPoint1: NSPoint(x: startX + side * rect.width * 0.00, y: rect.minY + rect.height * 0.81),
                controlPoint2: NSPoint(x: startX + side * rect.width * 0.07, y: rect.minY + rect.height * 0.87)
            )
            path.curve(
                to: NSPoint(x: startX - side * rect.width * 0.028, y: rect.minY + rect.height * 0.72),
                controlPoint1: NSPoint(x: startX + side * rect.width * 0.012, y: rect.minY + rect.height * 0.90),
                controlPoint2: NSPoint(x: startX - side * rect.width * 0.05, y: rect.minY + rect.height * 0.80)
            )
            path.close()
            return path
        }

        palette.horn.setFill()
        hornPath(side: -1).fill()
        hornPath(side: 1).fill()
    }

    static func drawCrown(in rect: NSRect, palette: Palette) {
        let crown = NSBezierPath()
        crown.move(to: NSPoint(x: rect.midX - rect.width * 0.14, y: rect.minY + rect.height * 0.68))
        crown.line(to: NSPoint(x: rect.midX - rect.width * 0.08, y: rect.minY + rect.height * 0.78))
        crown.line(to: NSPoint(x: rect.midX, y: rect.minY + rect.height * 0.72))
        crown.line(to: NSPoint(x: rect.midX + rect.width * 0.08, y: rect.minY + rect.height * 0.78))
        crown.line(to: NSPoint(x: rect.midX + rect.width * 0.14, y: rect.minY + rect.height * 0.68))
        crown.curve(
            to: NSPoint(x: rect.midX - rect.width * 0.14, y: rect.minY + rect.height * 0.68),
            controlPoint1: NSPoint(x: rect.midX + rect.width * 0.11, y: rect.minY + rect.height * 0.61),
            controlPoint2: NSPoint(x: rect.midX - rect.width * 0.11, y: rect.minY + rect.height * 0.61)
        )
        palette.crown.setFill()
        crown.fill()

        palette.crownDark.setStroke()
        crown.lineWidth = rect.width * 0.008
        crown.stroke()

        let gemRect = NSRect(
            x: rect.midX - rect.width * 0.040,
            y: rect.minY + rect.height * 0.666,
            width: rect.width * 0.080,
            height: rect.width * 0.080
        )
        let gemPath = NSBezierPath(ovalIn: gemRect)
        palette.gem.setFill()
        gemPath.fill()
        palette.moonFill.withAlphaComponent(0.55).setStroke()
        gemPath.lineWidth = rect.width * 0.006
        gemPath.stroke()
    }

    static func drawEyes(in rect: NSRect, palette: Palette) {
        drawEye(
            center: NSPoint(x: rect.midX - rect.width * 0.12, y: rect.minY + rect.height * 0.54),
            size: CGSize(width: rect.width * 0.16, height: rect.height * 0.20),
            palette: palette,
            pupilOffset: NSPoint(x: -rect.width * 0.002, y: -rect.height * 0.004)
        )
        drawEye(
            center: NSPoint(x: rect.midX + rect.width * 0.12, y: rect.minY + rect.height * 0.54),
            size: CGSize(width: rect.width * 0.16, height: rect.height * 0.20),
            palette: palette,
            pupilOffset: NSPoint(x: rect.width * 0.002, y: -rect.height * 0.004)
        )
    }

    static func drawEye(center: NSPoint, size: CGSize, palette: Palette, pupilOffset: NSPoint) {
        let eyeRect = NSRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        let eyePath = NSBezierPath(ovalIn: eyeRect)
        NSColor.white.setFill()
        eyePath.fill()
        palette.bodyDark.withAlphaComponent(0.55).setStroke()
        eyePath.lineWidth = size.width * 0.06
        eyePath.stroke()

        let irisRect = NSRect(
            x: center.x - size.width * 0.30 + pupilOffset.x,
            y: center.y - size.height * 0.21 + pupilOffset.y,
            width: size.width * 0.60,
            height: size.width * 0.60
        )
        let irisPath = NSBezierPath(ovalIn: irisRect)
        let irisGradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.92, green: 0.77, blue: 0.35, alpha: 1.0),
            palette.eyeBrown,
        ])
        irisGradient?.draw(in: irisPath, angle: 90)

        let pupilRect = irisRect.insetBy(dx: irisRect.width * 0.18, dy: irisRect.height * 0.18)
        NSColor.black.setFill()
        NSBezierPath(ovalIn: pupilRect).fill()

        let highlightRect = NSRect(
            x: irisRect.minX + irisRect.width * 0.16,
            y: irisRect.maxY - irisRect.height * 0.30,
            width: irisRect.width * 0.18,
            height: irisRect.height * 0.18
        )
        NSColor.white.withAlphaComponent(0.95).setFill()
        NSBezierPath(ovalIn: highlightRect).fill()
    }

    static func drawNoseAndSmile(in rect: NSRect, palette: Palette) {
        let noseRect = NSRect(
            x: rect.midX - rect.width * 0.034,
            y: rect.minY + rect.height * 0.423,
            width: rect.width * 0.068,
            height: rect.width * 0.050
        )
        let nose = NSBezierPath(roundedRect: noseRect, xRadius: noseRect.height * 0.45, yRadius: noseRect.height * 0.45)
        palette.nose.setFill()
        nose.fill()

        palette.moonFill.withAlphaComponent(0.35).setStroke()
        nose.lineWidth = rect.width * 0.004
        nose.stroke()

        let smile = NSBezierPath()
        smile.move(to: NSPoint(x: rect.midX - rect.width * 0.038, y: rect.minY + rect.height * 0.405))
        smile.curve(
            to: NSPoint(x: rect.midX + rect.width * 0.038, y: rect.minY + rect.height * 0.405),
            controlPoint1: NSPoint(x: rect.midX - rect.width * 0.020, y: rect.minY + rect.height * 0.388),
            controlPoint2: NSPoint(x: rect.midX + rect.width * 0.020, y: rect.minY + rect.height * 0.388)
        )
        palette.bodyLight.withAlphaComponent(0.78).setStroke()
        smile.lineWidth = rect.width * 0.007
        smile.stroke()
    }

    static func drawScarf(in rect: NSRect, palette: Palette) {
        let scarfRect = NSRect(
            x: rect.midX - rect.width * 0.20,
            y: rect.minY + rect.height * 0.26,
            width: rect.width * 0.40,
            height: rect.height * 0.10
        )
        let scarf = NSBezierPath(roundedRect: scarfRect, xRadius: scarfRect.height * 0.48, yRadius: scarfRect.height * 0.48)
        palette.scarf.setFill()
        scarf.fill()

        let knotRect = NSRect(
            x: rect.midX - rect.width * 0.032,
            y: rect.minY + rect.height * 0.225,
            width: rect.width * 0.074,
            height: rect.height * 0.074
        )
        let knot = NSBezierPath(ovalIn: knotRect)
        palette.scarf.setFill()
        knot.fill()

        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: rect.midX + rect.width * 0.01, y: rect.minY + rect.height * 0.29))
        tail.curve(
            to: NSPoint(x: rect.midX + rect.width * 0.28, y: rect.minY + rect.height * 0.17),
            controlPoint1: NSPoint(x: rect.midX + rect.width * 0.14, y: rect.minY + rect.height * 0.31),
            controlPoint2: NSPoint(x: rect.midX + rect.width * 0.29, y: rect.minY + rect.height * 0.25)
        )
        tail.curve(
            to: NSPoint(x: rect.midX + rect.width * 0.08, y: rect.minY + rect.height * 0.10),
            controlPoint1: NSPoint(x: rect.midX + rect.width * 0.22, y: rect.minY + rect.height * 0.12),
            controlPoint2: NSPoint(x: rect.midX + rect.width * 0.14, y: rect.minY + rect.height * 0.08)
        )
        tail.curve(
            to: NSPoint(x: rect.midX - rect.width * 0.01, y: rect.minY + rect.height * 0.22),
            controlPoint1: NSPoint(x: rect.midX + rect.width * 0.07, y: rect.minY + rect.height * 0.14),
            controlPoint2: NSPoint(x: rect.midX - rect.width * 0.02, y: rect.minY + rect.height * 0.18)
        )
        tail.close()
        palette.scarf.withAlphaComponent(0.95).setFill()
        tail.fill()
    }

    static func drawLightning(in rect: NSRect, palette: Palette) {
        let bolt = NSBezierPath()
        bolt.move(to: NSPoint(x: rect.midX - rect.width * 0.020, y: rect.minY + rect.height * 0.25))
        bolt.line(to: NSPoint(x: rect.midX + rect.width * 0.036, y: rect.minY + rect.height * 0.25))
        bolt.line(to: NSPoint(x: rect.midX + rect.width * 0.004, y: rect.minY + rect.height * 0.18))
        bolt.line(to: NSPoint(x: rect.midX + rect.width * 0.060, y: rect.minY + rect.height * 0.18))
        bolt.line(to: NSPoint(x: rect.midX - rect.width * 0.032, y: rect.minY + rect.height * 0.08))
        bolt.line(to: NSPoint(x: rect.midX - rect.width * 0.006, y: rect.minY + rect.height * 0.145))
        bolt.line(to: NSPoint(x: rect.midX - rect.width * 0.055, y: rect.minY + rect.height * 0.145))
        bolt.close()
        palette.lightning.setFill()
        bolt.fill()
    }

    static func drawStopBadge(in rect: NSRect, palette: Palette) {
        let badgeRect = NSRect(
            x: rect.maxX - rect.width * 0.30,
            y: rect.minY + rect.height * 0.07,
            width: rect.width * 0.22,
            height: rect.width * 0.22
        )
        let badge = NSBezierPath(ovalIn: badgeRect)
        palette.stopBadge.setFill()
        badge.fill()

        let minusRect = NSRect(
            x: badgeRect.minX + badgeRect.width * 0.20,
            y: badgeRect.midY - badgeRect.height * 0.065,
            width: badgeRect.width * 0.60,
            height: badgeRect.height * 0.13
        )
        let minus = NSBezierPath(roundedRect: minusRect, xRadius: minusRect.height / 2, yRadius: minusRect.height / 2)
        NSColor.white.setFill()
        minus.fill()
    }

    static func fillRotatedCapsule(center: NSPoint, length: CGFloat, thickness: CGFloat, angle: CGFloat, color: NSColor) {
        let rect = NSRect(
            x: center.x - length / 2,
            y: center.y - thickness / 2,
            width: length,
            height: thickness
        )
        let path = NSBezierPath(roundedRect: rect, xRadius: thickness / 2, yRadius: thickness / 2)
        var transform = AffineTransform()
        transform.translate(x: center.x, y: center.y)
        transform.rotate(byDegrees: angle)
        transform.translate(x: -center.x, y: -center.y)
        path.transform(using: transform)
        color.setFill()
        path.fill()
    }
}
