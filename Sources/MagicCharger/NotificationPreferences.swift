import Foundation

enum AlertKind: String, CaseIterable {
    case started, soon, target, full
    var title: String {
        switch self {
        case .started: return "Charging Started"
        case .soon: return "Unplug Soon (78%)"
        case .target: return "Unplug Reminder (80%)"
        case .full: return "Fully Charged (100%)"
        }
    }
    static func milestone(_ percent: Int) -> Self {
        switch percent { case 78: return .soon; case 80: return .target; default: return .full }
    }
}
struct NotificationPreferences: Equatable {
    var started = true
    var soon = true
    var target = true
    var full = true
    func allows(_ kind: AlertKind) -> Bool {
        switch kind { case .started: return started; case .soon: return soon; case .target: return target; case .full: return full }
    }
    var milestones: Set<Int> { Set([78,80,100].filter { allows(.milestone($0)) }) }
    static func load(_ defaults: UserDefaults) -> Self {
        func enabled(_ kind: AlertKind) -> Bool { defaults.object(forKey: "alert." + kind.rawValue) == nil || defaults.bool(forKey: "alert." + kind.rawValue) }
        return Self(started: enabled(.started), soon: enabled(.soon), target: enabled(.target), full: enabled(.full))
    }
    func save(_ defaults: UserDefaults) {
        for kind in AlertKind.allCases { defaults.set(allows(kind), forKey: "alert." + kind.rawValue) }
    }
}

// A change token prevents an already-selected alert from escaping an off/on
// toggle while notification authorization/submission is still asynchronous.
struct AlertSettings {
    private(set) var preferences: NotificationPreferences
    private var revisions: [AlertKind: UInt64] = [:]
    init(preferences: NotificationPreferences) { self.preferences = preferences }
    func token(_ kind: AlertKind) -> UInt64 { revisions[kind] ?? 0 }
    func canSubmit(_ kind: AlertKind, token: UInt64) -> Bool { preferences.allows(kind) && self.token(kind) == token }
    mutating func update(_ preferences: NotificationPreferences) {
        for kind in AlertKind.allCases where self.preferences.allows(kind) != preferences.allows(kind) {
            revisions[kind, default: 0] += 1
        }
        self.preferences = preferences
    }
}
