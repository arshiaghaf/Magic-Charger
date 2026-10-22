import AppKit

final class MenuBarPresenter {
    private var items: [String: NSStatusItem] = [:]
    private var itemImageSignatures: [String: String] = [:]

    func clear() {
        items.values.forEach { NSStatusBar.system.removeStatusItem($0) }
        items.removeAll()
        itemImageSignatures.removeAll()
    }

    func retainChargingItems(for readings: [Reading]) -> Set<String> {
        // Reuse items so an open menu is not destroyed on each telemetry update.
        let activeIDs = Set(readings.filter { $0.active }.map { $0.id })
        for id in Array(items.keys) where !activeIDs.contains(id) {
            NSStatusBar.system.removeStatusItem(items.removeValue(forKey: id)!)
            itemImageSignatures.removeValue(forKey: id)
        }
        return activeIDs
    }

    func present(_ r: Reading, preferences: MenuBarPreferences, target: AppDelegate) {
        guard r.active else { return }
        let item: NSStatusItem
        if let existing = items[r.id] { item = existing }
        else {
            item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            items[r.id] = item
            let menu = NSMenu(); menu.addItem(withTitle: "\(r.name) — Charging", action: nil, keyEquivalent: "")
            menu.addItem(withTitle: "Settings…", action: #selector(AppDelegate.showSettings), keyEquivalent: ",").target = target
            menu.addItem(withTitle: "Quit Magic Charger", action: #selector(AppDelegate.quit), keyEquivalent: "q").target = target
            item.menu = menu
        }
        let title = preferences.percentage ? " \(r.percent.map { "\($0)%" } ?? "?")" : ""
        if item.button?.title != title { item.button?.title = title }
        let imageSignature = "\(r.symbol):\(MenuBarPreferences.level(r.percent) ?? -1):\(preferences.deviceGlyph):\(preferences.batteryBar)"
        if itemImageSignatures[r.id] != imageSignature {
            item.button?.image = (preferences.deviceGlyph || preferences.batteryBar)
                ? MenuBarIcon.image(symbol: r.symbol, percent: r.percent, deviceGlyph: preferences.deviceGlyph, batteryBar: preferences.batteryBar) : nil
            itemImageSignatures[r.id] = imageSignature
        }
        let description = "\(r.name), charging, \(r.percent.map { "\($0) percent" } ?? "battery level unknown")"
        if item.button?.toolTip != description {
            item.button?.setAccessibilityLabel(description)
            item.button?.toolTip = description
        }
    }
}
