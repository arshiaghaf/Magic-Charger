struct NotificationCopy {
    let title: String
    let body: String

    static func started(name: String, percent: Int) -> Self {
        Self(title: "\(name) started charging", body: "Currently at \(percent)%")
    }

    static func milestone(name: String, percent: Int?, threshold: Int) -> Self {
        switch threshold {
        case 78:
            return Self(title: "\(name) reached 78%", body: "Get ready to unplug soon.")
        case 80:
            return Self(title: "\(name) reached 80%", body: "Unplug to preserve battery life.")
        case 100:
            return Self(title: "\(name) is fully charged",
                body: "You can leave it plugged in. There’s no need to unplug right away.")
        default:
            return Self(title: "\(name) reached \(threshold)%",
                body: "Battery is currently \(percent ?? threshold)%. You can unplug it when convenient.")
        }
    }
}
