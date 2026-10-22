import CoreGraphics
import DSStore
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let width = 680
private let height = 400
private let appPosition = (x: 170, y: 205)
private let applicationsPosition = (x: 510, y: 205)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: 1)
}

func makeBackground(in folder: URL) throws {
    let backgroundFolder = folder.appending(path: ".background")
    try FileManager.default.createDirectory(at: backgroundFolder, withIntermediateDirectories: true)
    let output = backgroundFolder.appending(path: "installer.png")
    let scale = 2
    let space = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(data: nil, width: width * scale, height: height * scale,
                                  bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw NSError(domain: "DmgLayout", code: 1)
    }
    context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    let gradient = CGGradient(colorsSpace: space,
                              colors: [color(0.11, 0.11, 0.12), color(0.025, 0.025, 0.03)] as CFArray,
                              locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: CGFloat(height)),
                               end: .zero, options: [])

    // A quiet center guide leaves the app and Applications icons unobstructed.
    context.setStrokeColor(color(0.72, 0.74, 0.75))
    context.setLineWidth(3)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: 284, y: 195))
    context.addLine(to: CGPoint(x: 395, y: 195))
    context.strokePath()
    context.setFillColor(color(0.72, 0.74, 0.75))
    context.move(to: CGPoint(x: 397, y: 195))
    context.addLine(to: CGPoint(x: 380, y: 206))
    context.addLine(to: CGPoint(x: 380, y: 184))
    context.closePath()
    context.fillPath()

    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(
            output as CFURL, UTType.png.identifier as CFString, 1, nil
          ) else { throw NSError(domain: "DmgLayout", code: 2) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "DmgLayout", code: 3)
    }
}

func applyLayout(to volume: URL) throws {
    let image = volume.appending(path: ".background/installer.png")
    guard FileManager.default.fileExists(atPath: image.path) else {
        throw NSError(domain: "DmgLayout", code: 4)
    }
    var store = DSStore()
    try store.setIconPosition(for: "Magic Charger.app", x: appPosition.x, y: appPosition.y)
    try store.setIconPosition(for: "Applications", x: applicationsPosition.x, y: applicationsPosition.y)
    try store.setWindowBounds(top: 120, left: 120, bottom: 520, right: 800)
    store.setViewStyle(.iconView)
    store.setWindowSettings(.init(windowBounds: "{{120, 120}, {680, 400}}",
                                  containerShowSidebar: false, showSidebar: false,
                                  showTabView: false, showToolbar: false,
                                  showStatusBar: false, showPathBar: false,
                                  viewStyle: "icnv"))
    store.setIconViewSettings(.init(showIconPreview: false, showItemInfo: false,
                                    labelOnBottom: true, textSize: 14, iconSize: 112,
                                    gridSpacing: 90, viewOptionsVersion: 1))
    try store.setBackgroundPicture(imageURL: image, relativeTo: volume)
    try store.write(to: volume.appending(path: ".DS_Store"))
}

func verifyLayout(in volume: URL) throws {
    let store = try DSStore.read(from: volume.appending(path: ".DS_Store"))
    let app = store.iconPosition(for: "Magic Charger.app")
    let applications = store.iconPosition(for: "Applications")
    let bounds = store.windowBounds()
    let window = store.windowSettings()
    let view = store.iconViewSettings()
    guard app?.x == appPosition.x, app?.y == appPosition.y,
          applications?.x == applicationsPosition.x, applications?.y == applicationsPosition.y,
          bounds?.right == 800, bounds?.bottom == 520,
          window?.windowBounds == "{{120, 120}, {680, 400}}",
          window?.showToolbar == false, window?.showSidebar == false,
          view?.iconSize == 112, view?.backgroundType == 2,
          !(view?.backgroundImageAlias?.isEmpty ?? true),
          FileManager.default.fileExists(atPath: volume.appending(path: ".background/installer.png").path)
    else { throw NSError(domain: "DmgLayout", code: 5) }
}

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: DmgLayout background|apply|verify folder")
}
let folder = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
switch CommandLine.arguments[1] {
case "background": try makeBackground(in: folder)
case "apply": try applyLayout(to: folder)
case "verify": try verifyLayout(in: folder)
default: fatalError("Unknown command")
}
