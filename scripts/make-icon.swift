import AppKit

// Draws a placeholder app-icon layer for the fork: a rounded document mark with
// a bold downward chevron (the Markdown convention), on transparency so Icon
// Composer supplies the background gradient and glass treatment itself.

let side = 1024
let scale = CGFloat(side) / 1024.0

guard let context = CGContext(
    data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("context") }

NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

// Warm amber — deliberately far from upstream's palette and from the blue-grey
// of macOS Preview, which is the pair being confused in the Dock.
let ink = NSColor(srgbRed: 0.94, green: 0.62, blue: 0.16, alpha: 1.0)
let deep = NSColor(srgbRed: 0.55, green: 0.31, blue: 0.04, alpha: 1.0)

// Rounded page
let pageRect = NSRect(x: 232 * scale, y: 196 * scale, width: 560 * scale, height: 632 * scale)
let page = NSBezierPath(roundedRect: pageRect, xRadius: 84 * scale, yRadius: 84 * scale)
ink.setFill()
page.fill()

// Chevron: a thick stroked V, the Markdown down-arrow reduced to its essential.
let chevron = NSBezierPath()
chevron.move(to: NSPoint(x: 388 * scale, y: 566 * scale))
chevron.line(to: NSPoint(x: 512 * scale, y: 428 * scale))
chevron.line(to: NSPoint(x: 636 * scale, y: 566 * scale))
chevron.lineWidth = 74 * scale
chevron.lineCapStyle = .round
chevron.lineJoinStyle = .round
deep.setStroke()
chevron.stroke()

// Stem under the chevron, so the mark reads as "down" rather than as a caret.
let stem = NSBezierPath()
stem.move(to: NSPoint(x: 512 * scale, y: 428 * scale))
stem.line(to: NSPoint(x: 512 * scale, y: 640 * scale))
stem.lineWidth = 74 * scale
stem.lineCapStyle = .round
deep.setStroke()
stem.stroke()

NSGraphicsContext.current = nil

guard let image = context.makeImage() else { fatalError("image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png") }

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out) (\(side)x\(side))")
