import Foundation

struct MenuBarPreferences: Equatable {
    var deviceGlyph = true
    var percentage = true
    var batteryBar = true
    var isValid: Bool { deviceGlyph || percentage || batteryBar }
    static func load(_ defaults: UserDefaults) -> Self {
        var value = Self()
        if defaults.object(forKey: "menu.deviceGlyph") != nil { value.deviceGlyph = defaults.bool(forKey: "menu.deviceGlyph") }
        if defaults.object(forKey: "menu.percentage") != nil { value.percentage = defaults.bool(forKey: "menu.percentage") }
        if defaults.object(forKey: "menu.batteryBar") != nil { value.batteryBar = defaults.bool(forKey: "menu.batteryBar") }
        return value.isValid ? value : Self()
    }
    func save(_ defaults: UserDefaults) {
        guard isValid else { return }
        defaults.set(deviceGlyph, forKey: "menu.deviceGlyph")
        defaults.set(percentage, forKey: "menu.percentage")
        defaults.set(batteryBar, forKey: "menu.batteryBar")
    }
    static func level(_ percent: Int?) -> Int? {
        guard let percent = percent, (0...100).contains(percent) else { return nil }
        return (percent / 10) * 10
    }
}
