import AppKit

// Template rendering lets AppKit choose contrast for light/dark and highlighted
// menu bars. A hard-coded green raster would not adapt reliably to those states.
enum MenuBarIcon {
    static func image(symbol: String, percent: Int?, deviceGlyph: Bool = true, batteryBar: Bool = true) -> NSImage {
        let level = MenuBarPreferences.level(percent).map { CGFloat($0) / 100 }
        let width: CGFloat = deviceGlyph ? (batteryBar ? 30 : 18) : 10
        let batteryX: CGFloat = deviceGlyph ? 22.5 : 1.5
        let glyph = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [.black]))
        let image = NSImage(size: NSSize(width: width, height: 18), flipped: false) { _ in
            NSColor.black.set()
            if deviceGlyph, let glyph = glyph {
                let scale = min(18 / glyph.size.width, 14 / glyph.size.height)
                let size = NSSize(width: glyph.size.width * scale, height: glyph.size.height * scale)
                glyph.draw(in: NSRect(x: (18 - size.width) / 2, y: (18 - size.height) / 2, width: size.width, height: size.height))
            }
            guard batteryBar else { return true }
            NSColor.black.set()
            let shell = NSBezierPath(roundedRect: NSRect(x: batteryX, y: 2.5, width: 6, height: 12), xRadius: 1, yRadius: 1)
            shell.lineWidth = 1; shell.stroke()
            NSBezierPath(roundedRect: NSRect(x: batteryX + 1.5, y: 15, width: 3, height: 1), xRadius: 0.5, yRadius: 0.5).fill()
            if let level = level {
                let height = (10 * level * 2).rounded() / 2
                if height > 0 { NSRect(x: batteryX + 1.5, y: 3.5, width: 3, height: height).fill() }
            } else {
                // Unknown is a dash, not an empty battery falsely implying0%.
                NSRect(x: batteryX + 1.5, y: 8, width: 3, height: 1).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
