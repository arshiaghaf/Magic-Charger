import AppKit
import IOKit
import UserNotifications
import CryptoKit

func snapshot(identityKey: Data) -> [Reading] {
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleDeviceManagementHIDEventService"), &iterator) == KERN_SUCCESS else { return [] }
    defer { IOObjectRelease(iterator) }
    var result: [Reading] = []
    while true {
        let service = IOIteratorNext(iterator)
        if service == 0 { break }
        defer { IOObjectRelease(service) }
        func value(_ key: String) -> Any? { IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() }
        guard let product = value("Product") as? String, product.localizedCaseInsensitiveContains("Magic"), let vendor = value("VendorID") as? Int, vendor == 76 || vendor == 1452 else { continue }
        let keyboard = product.localizedCaseInsensitiveContains("Keyboard")
        guard keyboard || product.localizedCaseInsensitiveContains("Mouse") else { continue }
        // Never request serial numbers or HID input reports; only supported accessories reach this point.
        let productID = value("ProductID") as? Int ?? 0
        var entryID: UInt64 = 0; IORegistryEntryGetRegistryEntryID(service, &entryID)
        let stableID = DeviceIdentity.stable(address: value("DeviceAddress") as? String, productID: productID, key: identityKey)
        let id = stableID ?? "registry:\(productID):\(entryID)"
        let percent = (value("BatteryPercent") as? Int).flatMap { (0...100).contains($0) ? $0 : nil }
        func boolean(_ key: String) -> Bool? {
            guard let number = value(key) as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
            return number.boolValue
        }
        let first = boolean("BatteryCharging"), second = boolean("IsCharging")
        let flags = value("BatteryStatusFlags") as? Int
        let transport = value("Transport") as? String
        let state = ChargingDecoder.decode(vendor: vendor, product: productID, transport: transport,
            os: ProcessInfo.processInfo.operatingSystemVersion, percent: percent, flags: flags,
            batteryCharging: first, isCharging: second)
        result.append(Reading(id: id, name: keyboard ? "Magic Keyboard" : "Magic Mouse", symbol: keyboard ? "keyboard" : "computermouse", percent: percent, state: state, sampled: Date(), evidence: "Transport: \(value("Transport") as? String ?? "unknown"); flags: \(flags.map(String.init) ?? "unknown"); charging: \(state.rawValue). Driver freshness unavailable. Identity: \(stableID == nil ? "registry only" : "private stable digest")."))
    }
    return reconciled(result)
}

final class Delegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var matchingIterators: [io_iterator_t] = []
    var port: IONotificationPortRef?
    var interests: [UInt64: io_object_t] = [:]
    var items: [String: NSStatusItem] = [:]
    func observeRegistry() {
        if port == nil {
            port = IONotificationPortCreate(kIOMainPortDefault)
            if let port = port {
                IONotificationPortSetDispatchQueue(port, .main)
                for kind in [kIOFirstMatchNotification, kIOTerminatedNotification] {
                    var iterator: io_iterator_t = 0
                    let code = IOServiceAddMatchingNotification(port, kind, IOServiceMatching("AppleDeviceManagementHIDEventService"), { context, iterator in
                        while true { let object = IOIteratorNext(iterator); if object == 0 { break }; IOObjectRelease(object) }
                        guard let context = context else { return }
                        let owner = Unmanaged<Delegate>.fromOpaque(context).takeUnretainedValue()
                        DispatchQueue.main.async { owner.refresh() }
                    }, Unmanaged.passUnretained(self).toOpaque(), &iterator)
                    if code == KERN_SUCCESS {
                        matchingIterators.append(iterator)
                        while true { let object = IOIteratorNext(iterator); if object == 0 { break }; IOObjectRelease(object) }
                    }
                }
            }
        }
        guard let port = port else { return }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleDeviceManagementHIDEventService"), &iterator) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }
        var present = Set<UInt64>()
        while true {
            let service = IOIteratorNext(iterator); if service == 0 { break }
            defer { IOObjectRelease(service) }
            var id: UInt64 = 0; IORegistryEntryGetRegistryEntryID(service, &id); present.insert(id)
            guard interests[id] == nil else { continue }
            var interest: io_object_t = 0
            let code = IOServiceAddInterestNotification(port, service, kIOGeneralInterest, { context, _, _, _ in
                guard let context = context else { return }
                let owner = Unmanaged<Delegate>.fromOpaque(context).takeUnretainedValue()
                DispatchQueue.main.async { owner.refresh() }
            }, Unmanaged.passUnretained(self).toOpaque(), &interest)
            if code == KERN_SUCCESS { interests[id] = interest }
        }
        for id in Array(interests.keys) where !present.contains(id) { IOObjectRelease(interests.removeValue(forKey: id)!) }
    }
    var window: NSWindow!
    var label: NSTextField!
    var timer: Timer?
    var engine = Thresholds()
    var observations: [NSObjectProtocol] = []
    var suspended = false
    var refreshing = false
    var refreshPending = false
    var generation = 0
    var identityKey = Data()
    var notificationStatus = "Notifications have not been enabled."
    var pollInterval: TimeInterval = 30
    let telemetryQueue = DispatchQueue(label: "local.magiccharger.telemetry", qos: .utility)
    let center = UNUserNotificationCenter.current()
    let storage = "chargingSessions.v2"
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        center.delegate = self
        let defaults = UserDefaults.standard
        if let key = defaults.data(forKey: "identityKey.v1"), key.count == 32 { identityKey = key }
        else { identityKey = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }; defaults.set(identityKey, forKey: "identityKey.v1") }
        updateNotificationStatus()
        if let data = UserDefaults.standard.data(forKey: storage), let sessions = try? JSONDecoder().decode([String: Session].self, from: data) { engine.sessions = sessions }
        makeWindow(); refresh(); showSettings()
        schedulePolling(30)
        let nc = NSWorkspace.shared.notificationCenter
        observations.append(nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.suspended = true; self?.generation += 1; self?.clearItems() })
        observations.append(nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.suspended = false; self?.generation += 1; self?.refresh() })
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    func schedulePolling(_ interval: TimeInterval) {
        if timer != nil && pollInterval == interval { return }
        timer?.invalidate(); pollInterval = interval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in self?.refresh() }
        timer?.tolerance = interval == 10 ? 1 : 5
    }
    func clearItems() { items.values.forEach { NSStatusBar.system.removeStatusItem($0) }; items.removeAll() }
    func refresh() {
        guard !suspended else { return }
        guard !refreshing else { refreshPending = true; return }
        refreshing = true
        let requestGeneration = generation, key = identityKey
        observeRegistry()
        telemetryQueue.async {
            let readings = snapshot(identityKey: key)
            DispatchQueue.main.async {
                self.refreshing = false
                if !self.suspended && requestGeneration == self.generation { self.render(readings) }
                if self.refreshPending { self.refreshPending = false; self.refresh() }
            }
        }
    }
    func render(_ readings: [Reading]) {
        // Reuse items so an open menu is not destroyed on each telemetry update.
        let activeIDs = Set(readings.filter { $0.active }.map { $0.id })
        for id in Array(items.keys) where !activeIDs.contains(id) { NSStatusBar.system.removeStatusItem(items.removeValue(forKey: id)!) }
        schedulePolling(activeIDs.isEmpty ? 30 : 10)
        label.stringValue = readings.isEmpty ? "No supported accessories detected.\nMonitoring every 30 seconds." : readings.map { "\($0.name): \($0.percent.map { "\($0)%" } ?? "unknown") — \($0.state.rawValue)\n\($0.evidence)" }.joined(separator: "\n\n")
        label.stringValue += "\n\nMenu-bar items: \(activeIDs.count); polling: \(Int(pollInterval)) seconds.\n" + notificationStatus
        for r in readings {
            let thresholds = engine.consume(r)
            if !thresholds.isEmpty { notify(r, threshold: thresholds.max()!) }
            guard r.active else { continue }
            let item = items[r.id] ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            items[r.id] = item
            item.button?.image = NSImage(systemSymbolName: r.symbol, accessibilityDescription: r.name)
            item.button?.title = " \(r.percent.map { "\($0)%" } ?? "?") ⚡"
            let menu = NSMenu(); menu.addItem(withTitle: "\(r.name) — Charging", action: nil, keyEquivalent: "")
            menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
            menu.addItem(withTitle: "Quit Magic Charger", action: #selector(quit), keyEquivalent: "q").target = self
            if item.menu == nil { item.menu = menu }
        }
        if let data = try? JSONEncoder().encode(engine.sessions) { UserDefaults.standard.set(data, forKey: storage) }
    }
    func notify(_ r: Reading, threshold: Int) {
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent(); content.title = "\(r.name) reached \(threshold)%"; content.body = "Battery is currently \(r.percent ?? threshold)%. You can unplug it when convenient."; content.sound = .default
            self.center.add(UNNotificationRequest(identifier: "\(r.id)-\(threshold)", content: content, trigger: nil)) { error in
                if error != nil { DispatchQueue.main.async { self.notificationStatus = "Notification delivery failed; check notification settings." } }
            }
        }
    }
    func makeWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 350), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Magic Charger"; window.isReleasedWhenClosed = false; window.center()
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16; stack.translatesAutoresizingMaskIntoConstraints = false
        let title = NSTextField(labelWithString: "Magic Charger"); title.font = .boldSystemFont(ofSize: 23)
        label = NSTextField(wrappingLabelWithString: ""); label.font = .systemFont(ofSize: 12)
        let note = NSTextField(wrappingLabelWithString: "Menu-bar items require recognized charging evidence. The validated mouse profile uses a charging indication below full; other raw flags remain unknown. Relaunch this app to open these controls. Alerts at 78% and 80%; no automatic power cutoff.")
        let permission = NSButton(title: "Enable Notifications…", target: self, action: #selector(permissions))
        let quit = NSButton(title: "Quit Magic Charger", target: self, action: #selector(quit))
        [title, label, note, permission, quit].forEach(stack.addArrangedSubview)
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24), stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24)])
    }
    func updateNotificationStatus() {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional: self.notificationStatus = "Notifications enabled."
                case .denied: self.notificationStatus = "Notifications denied. Change this in System Settings if desired."
                default: self.notificationStatus = "Use Enable Notifications to allow alerts."
                }
            }
        }
    }
    @objc func permissions() { center.requestAuthorization(options: [.alert, .sound]) { _, _ in self.updateNotificationStatus() } }
    @objc func showSettings() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func quit() { NSApp.terminate(nil) }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) { completionHandler([.banner, .sound]) }
}
let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.run()
