// Original Magic Charger artwork. Rendered with system frameworks; no third-party assets.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: swift scripts/generate-icon.swift output.icns")
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: 1)
}

func render(_ pixels: Int, to url: URL) throws {
    let space = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
        bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("Cannot create icon bitmap") }

    let scale = CGFloat(pixels)
    context.scaleBy(x: scale, y: scale)
    let tile = CGPath(roundedRect: CGRect(x: 0.035, y: 0.035, width: 0.93, height: 0.93),
                      cornerWidth: 0.215, cornerHeight: 0.215, transform: nil)
    context.addPath(tile)
    context.clip()
    let gradient = CGGradient(
        colorsSpace: space,
        colors: [color(0.065, 0.20, 0.27), color(0.035, 0.085, 0.17)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1),
                               end: CGPoint(x: 1, y: 0), options: [])

    // A partial charging ring leaves room for the bolt and stays legible at menu sizes.
    context.setStrokeColor(color(0.22, 0.79, 0.68))
    context.setLineWidth(0.075)
    context.setLineCap(.round)
    context.addArc(center: CGPoint(x: 0.5, y: 0.5), radius: 0.303,
                   startAngle: .pi * 0.12, endAngle: .pi * 1.37, clockwise: false)
    context.strokePath()

    let bolt = CGMutablePath()
    bolt.move(to: CGPoint(x: 0.555, y: 0.83))
    bolt.addLine(to: CGPoint(x: 0.30, y: 0.475))
    bolt.addLine(to: CGPoint(x: 0.475, y: 0.475))
    bolt.addLine(to: CGPoint(x: 0.418, y: 0.17))
    bolt.addLine(to: CGPoint(x: 0.70, y: 0.555))
    bolt.addLine(to: CGPoint(x: 0.523, y: 0.555))
    bolt.closeSubpath()
    context.addPath(bolt)
    context.setFillColor(color(0.92, 1.0, 0.93))
    context.fillPath()

    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Cannot encode icon PNG")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Cannot write icon PNG") }
}

for points in [16, 32, 128, 256, 512] {
    for multiplier in [1, 2] {
        let suffix = multiplier == 2 ? "@2x" : ""
        try render(points * multiplier, to: iconset.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}

// The modern ICNS container embeds PNGs. Writing it directly also makes the
// generated asset independent of iconutil behavior across Xcode releases.
func bigEndian(_ number: UInt32) -> Data {
    withUnsafeBytes(of: number.bigEndian) { Data($0) }
}

let representations: [(String, String)] = [
    ("icp4", "icon_16x16.png"), ("ic11", "icon_16x16@2x.png"),
    ("icp5", "icon_32x32.png"), ("ic12", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"), ("ic13", "icon_128x128@2x.png"),
    ("ic08", "icon_256x256.png"), ("ic14", "icon_256x256@2x.png"),
    ("ic09", "icon_512x512.png"), ("ic10", "icon_512x512@2x.png")
]
var body = Data()
for (kind, name) in representations {
    let png = try Data(contentsOf: iconset.appendingPathComponent(name))
    body.append(contentsOf: kind.utf8)
    body.append(bigEndian(UInt32(png.count + 8)))
    body.append(png)
}
var icns = Data("icns".utf8)
icns.append(bigEndian(UInt32(body.count + 8)))
icns.append(body)
try icns.write(to: output, options: .atomic)
