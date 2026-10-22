// Render the approved master image into standard macOS icon representations.
// The composition is unchanged; only scaling and a transparent tile mask are applied.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: swift scripts/generate-icon.swift master.png output.icns")
}

let masterURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = CGImageSourceCreateWithURL(masterURL as CFURL, nil),
      let master = CGImageSourceCreateImageAtIndex(source, 0, nil),
      master.width == master.height, master.width >= 1024 else {
    fatalError("Master must be a square image at least 1024 pixels wide")
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }

func render(_ pixels: Int, to url: URL) throws {
    let space = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(data: nil, width: pixels, height: pixels,
                                  bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fatalError("Cannot create icon bitmap")
    }

    let side = CGFloat(pixels)
    let inset = side * 0.045
    let tile = CGRect(x: inset, y: inset, width: side - 2 * inset, height: side - 2 * inset)
    let radius = tile.width * 0.22
    context.addPath(CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.clip()
    context.interpolationQuality = .high
    context.draw(master, in: tile)

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
try icns.write(to: outputURL, options: .atomic)
