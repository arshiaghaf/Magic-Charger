import AppKit
import IOKit
import UserNotifications
import CryptoKit
import ServiceManagement
import CoreServices

enum AppLaunch {
    static func isLoginItem(eventID: AEEventID?, launchData: AEKeyword?) -> Bool {
        eventID == kAEOpenApplication && launchData == keyAELaunchedAsLogInItem
    }
}

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
        let fullEvidence = ChargingDecoder.fullChargeEvidence(vendor: vendor, product: productID, transport: transport,
            os: ProcessInfo.processInfo.operatingSystemVersion, percent: percent, flags: flags,
            batteryCharging: first, isCharging: second)
        result.append(Reading(id: id, name: keyboard ? "Magic Keyboard" : "Magic Mouse", symbol: keyboard ? "keyboard" : "magicmouse", percent: percent, state: state, sampled: Date(), evidence: "Transport: \(value("Transport") as? String ?? "unknown"); flags: \(flags.map(String.init) ?? "unknown"); charging: \(state.rawValue). Driver freshness unavailable. Identity: \(stableID == nil ? "registry only" : "private stable digest").", fullChargeEvidence: fullEvidence))
    }
    return reconciled(result)
}

final class Delegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var matchingIterators: [io_iterator_t] = []
    var port: IONotificationPortRef?
    var interests: [UInt64: io_object_t] = [:]
    var registryDirty = true
    var items: [String: NSStatusItem] = [:]
    var itemImageSignatures: [String: String] = [:]
    var displayPreferences = MenuBarPreferences.load(.standard)
    var alertSettings = AlertSettings(preferences: .load(.standard))
    var alertPreferences: NotificationPreferences { alertSettings.preferences }
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
                        DispatchQueue.main.async { owner.registryDirty = true; owner.refresh() }
                    }, Unmanaged.passUnretained(self).toOpaque(), &iterator)
                    if code == KERN_SUCCESS {
                        matchingIterators.append(iterator)
                        while true { let object = IOIteratorNext(iterator); if object == 0 { break }; IOObjectRelease(object) }
                    }
                }
            }
        }
        guard let port = port, registryDirty else { return }
        registryDirty = false
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
    var controls: ControlsWindow!
    var timer: Timer?
    var engine = Thresholds()
    var starts = ChargingStarts()
    var latestReadings: [String: Reading] = [:]
    var lastPersistedAt = Date.distantPast
    var lastSessionSignature = ""
    var observations: [NSObjectProtocol] = []
    var suspended = false
    var refreshing = false
    var refreshPending = false
    var generation = 0
    var identityKey = Data()
    var notificationStatus = "Notifications have not been enabled."
    var notificationFeedback = ""
    var notificationDetails = "Notification policy has not been read."
    var foregroundPresentation = "No foreground presentation callback observed in this process."
    var pollInterval: TimeInterval = 30
    let telemetryQueue = DispatchQueue(label: "local.magiccharger.telemetry", qos: .utility)
    let center = UNUserNotificationCenter.current()
    let storage = "chargingSessions.v2"
    func applicationDidFinishLaunching(_ notification: Notification) {
        let launchEvent = NSAppleEventManager.shared().currentAppleEvent
        let launchedAtLogin = AppLaunch.isLoginItem(eventID: launchEvent?.eventID,
            launchData: launchEvent?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue)
        NSApp.setActivationPolicy(.accessory)
        center.delegate = self
        let defaults = UserDefaults.standard
        if let key = defaults.data(forKey: "identityKey.v1"), key.count == 32 { identityKey = key }
        else { identityKey = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }; defaults.set(identityKey, forKey: "identityKey.v1") }
        updateNotificationStatus()
        if let data = UserDefaults.standard.data(forKey: storage), let sessions = try? JSONDecoder().decode([String: Session].self, from: data) { engine.sessions = sessions }
        makeWindow(); refresh()
        if !launchedAtLogin { showSettings() }
        schedulePolling(30)
        let nc = NSWorkspace.shared.notificationCenter
        observations.append(nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.suspended = true; self?.generation += 1; self?.starts.invalidate(); self?.engine.invalidateContinuity(); self?.clearItems() })
        observations.append(nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.suspended = false; self?.generation += 1; self?.refresh() })
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    func applicationDidBecomeActive(_ notification: Notification) {
        guard controls != nil else { return }
        controls.updateLogin(status: SMAppService.mainApp.status)
        updateNotificationStatus()
    }
    func schedulePolling(_ interval: TimeInterval) {
        if timer != nil && pollInterval == interval { return }
        timer?.invalidate(); pollInterval = interval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in self?.refresh() }
        timer?.tolerance = interval == 10 ? 1 : 5
    }
    func clearItems() { items.values.forEach { NSStatusBar.system.removeStatusItem($0) }; items.removeAll(); itemImageSignatures.removeAll() }
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
        latestReadings = Dictionary(uniqueKeysWithValues: readings.map { ($0.id, $0) })
        engine.retainContinuity(for: Set(readings.map { $0.id }))
        for started in starts.consume(readings) where alertPreferences.started { notifyStarted(started) }
        // Reuse items so an open menu is not destroyed on each telemetry update.
        let activeIDs = Set(readings.filter { $0.active }.map { $0.id })
        for id in Array(items.keys) where !activeIDs.contains(id) {
            NSStatusBar.system.removeStatusItem(items.removeValue(forKey: id)!); itemImageSignatures.removeValue(forKey: id)
        }
        schedulePolling(activeIDs.isEmpty ? 30 : 10)
        var diagnostic = readings.isEmpty ? "No supported accessories detected.\nMonitoring every 30 seconds." : readings.map { "\($0.name): \($0.percent.map { "\($0)%" } ?? "unknown") — \($0.state.rawValue)\n\($0.evidence)" }.joined(separator: "\n\n")
        diagnostic += "\n\nMenu-bar items: \(activeIDs.count); polling: \(Int(pollInterval)) seconds.\n" + notificationStatus
        if !notificationFeedback.isEmpty { diagnostic += "\n" + notificationFeedback }
        diagnostic += "\n" + starts.lastDecisions.joined(separator: "\n")
        diagnostic += "\n\n" + notificationDetails + "\n" + foregroundPresentation
        controls.update(readings: readings, notificationStatus: notificationStatus, feedback: notificationFeedback, diagnostic: diagnostic)
        for r in readings {
            let thresholds = engine.consume(r, enabled: alertPreferences.milestones)
            if !thresholds.isEmpty { notify(r, threshold: thresholds.max()!) }
            guard r.active else { continue }
            let item: NSStatusItem
            if let existing = items[r.id] { item = existing }
            else {
                item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                items[r.id] = item
                let menu = NSMenu(); menu.addItem(withTitle: "\(r.name) — Charging", action: nil, keyEquivalent: "")
                menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
                menu.addItem(withTitle: "Quit Magic Charger", action: #selector(quit), keyEquivalent: "q").target = self
                item.menu = menu
            }
            let title = displayPreferences.percentage ? " \(r.percent.map { "\($0)%" } ?? "?")" : ""
            if item.button?.title != title { item.button?.title = title }
            let imageSignature = "\(r.symbol):\(MenuBarPreferences.level(r.percent) ?? -1):\(displayPreferences.deviceGlyph):\(displayPreferences.batteryBar)"
            if itemImageSignatures[r.id] != imageSignature {
                item.button?.image = (displayPreferences.deviceGlyph || displayPreferences.batteryBar)
                    ? MenuBarIcon.image(symbol: r.symbol, percent: r.percent, deviceGlyph: displayPreferences.deviceGlyph, batteryBar: displayPreferences.batteryBar) : nil
                itemImageSignatures[r.id] = imageSignature
            }
            let description = "\(r.name), charging, \(r.percent.map { "\($0) percent" } ?? "battery level unknown")"
            if item.button?.toolTip != description {
                item.button?.setAccessibilityLabel(description)
                item.button?.toolTip = description
            }
        }
        let signature = engine.sessions.sorted { $0.key < $1.key }.map {
            "\($0.key):\($0.value.sent.sorted()):\($0.value.lastPercent ?? -1):\($0.value.ended)"
        }.joined(separator: ";")
        if signature != lastSessionSignature || (!activeIDs.isEmpty && Date().timeIntervalSince(lastPersistedAt) >= 60) {
            persistSessions(); lastSessionSignature = signature
        }
    }
    func persistSessions() {
        if let data = try? JSONEncoder().encode(engine.sessions) {
            UserDefaults.standard.set(data, forKey: storage); lastPersistedAt = Date()
        }
    }
    func applicationWillTerminate(_ notification: Notification) { persistSessions() }
    func submitNotification(_ content: UNMutableNotificationContent, reading: Reading, identifier: String, kind: AlertKind, full: Bool = false) {
        guard alertPreferences.allows(kind) else { return }
        let requestGeneration = generation
        let requestToken = alertSettings.token(kind)
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                DispatchQueue.main.async { self.notificationFeedback = "Automatic alert not submitted: notification permission unavailable."; self.refresh() }
                return
            }
            DispatchQueue.main.async {
                guard self.alertSettings.canSubmit(kind, token: requestToken) else {
                    self.notificationFeedback = "Automatic alert canceled: notification choice changed."; self.refresh(); return
                }
                guard !self.suspended, requestGeneration == self.generation,
                      reading.fresh(at: Date()), let current = self.latestReadings[reading.id], current.fresh(at: Date()) else {
                    self.notificationFeedback = "Automatic alert canceled: sleep, disconnect or stale observation."; self.refresh(); return
                }
                let stillValid = full ? (current.percent == 100 && current.fullChargeEvidence) : current.active
                guard stillValid else { self.notificationFeedback = "Automatic alert canceled: current charging evidence changed."; self.refresh(); return }
                self.center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil)) { error in
                    DispatchQueue.main.async {
                        self.notificationFeedback = error == nil ? "Automatic notification submitted to macOS." : "Automatic notification submission failed; check notification settings."
                        self.refresh()
                    }
                }
            }
        }
    }
    func notifyStarted(_ r: Reading) {
        guard let percent = r.percent, (0...100).contains(percent) else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(r.name) started charging"
        content.body = "Currently at \(percent)%"
        content.sound = .default
        submitNotification(content, reading: r, identifier: "started-\(r.id)-\(UUID().uuidString)", kind: .started)
    }
    func notify(_ r: Reading, threshold: Int) {
        let content = UNMutableNotificationContent()
        if threshold == 100 {
            content.title = "\(r.name) is at 100%"
            content.body = r.symbol == "keyboard"
                ? "No need to unplug right away. You can keep using your keyboard while it’s connected."
                : "No need to unplug right away. Disconnect it whenever you’re ready to use it."
        } else {
            content.title = "\(r.name) reached \(threshold)%"
            content.body = "Battery is currently \(r.percent ?? threshold)%. You can unplug it when convenient."
        }
        content.sound = .default
        submitNotification(content, reading: r, identifier: "milestone-\(threshold)-\(r.id)", kind: .milestone(threshold), full: threshold == 100 || r.fullChargeEvidence)
    }
    func makeWindow() {
        controls = ControlsWindow(target: self, enable: #selector(permissions), test: #selector(testNotification), updates: #selector(viewReleases), loginSettings: #selector(openLoginItemsSettings), quit: #selector(quit), preferences: displayPreferences, alerts: alertPreferences, onChange: { [weak self] preferences in
            self?.displayPreferences = preferences
            preferences.save(.standard)
            self?.refresh()
        }, onAlertsChange: { [weak self] preferences in
            guard let self = self else { return }
            let disabled = AlertKind.allCases.filter { !preferences.allows($0) }
            self.alertSettings.update(preferences); preferences.save(.standard)
            self.center.getPendingNotificationRequests { requests in
                let identifiers = requests.filter { request in
                    disabled.contains { kind in
                        switch kind {
                        case .started: return request.identifier.hasPrefix("started-")
                        case .soon: return request.identifier.hasPrefix("milestone-78-")
                        case .target: return request.identifier.hasPrefix("milestone-80-")
                        case .full: return request.identifier.hasPrefix("milestone-100-")
                        }
                    }
                }.map { $0.identifier }
                self.center.removePendingNotificationRequests(withIdentifiers: identifiers)
            }
            self.refresh()
        }, onLoginChange: { [weak self] enabled in self?.changeLaunchAtLogin(enabled) })
        window = controls.window
    }
    func changeLaunchAtLogin(_ enabled: Bool) {
        // Registration changes the user's login items only after an explicit control action.
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            controls.updateLogin(status: SMAppService.mainApp.status)
        } catch {
            controls.updateLogin(status: SMAppService.mainApp.status,
                feedback: "Couldn’t change Login Items. Check System Settings > General > Login Items.")
        }
    }
    @objc func viewReleases() {
        let releases = URL(string: "https://github.com/arshiaghaf/Magic-Charger/releases")!
        controls.updateFeedbackForUpdates(NSWorkspace.shared.open(releases) ? "" : "Couldn’t open the releases page. Try again from your browser.")
    }
    @objc func openLoginItemsSettings() { SMAppService.openSystemSettingsLoginItems() }
    func updateNotificationStatus() {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                func setting(_ value: UNNotificationSetting) -> String {
                    switch value { case .enabled: return "enabled"; case .disabled: return "disabled"; case .notSupported: return "not supported"; @unknown default: return "unknown" }
                }
                let authorization: String
                switch settings.authorizationStatus {
                case .authorized: authorization = "authorized"
                case .provisional: authorization = "provisional (quiet delivery)"
                case .denied: authorization = "denied"
                case .notDetermined: authorization = "not requested"
                default: authorization = "other"
                }
                let style: String
                switch settings.alertStyle { case .banner: style = "banner"; case .alert: style = "alert"; case .none: style = "none"; @unknown default: style = "unknown" }
                self.notificationDetails = "Notification policy: authorization=\(authorization); alerts=\(setting(settings.alertSetting)); style=\(style); Notification Center=\(setting(settings.notificationCenterSetting)); sound=\(setting(settings.soundSetting)); scheduled delivery=\(setting(settings.scheduledDeliverySetting))."
                switch settings.authorizationStatus {
                case .authorized, .provisional: self.notificationStatus = "Notifications enabled."
                case .denied: self.notificationStatus = "Notifications denied. Change this in System Settings if desired."
                case .notDetermined: self.notificationStatus = "Notification permission not requested. Use Enable Notifications to allow alerts."
                default: self.notificationStatus = "Notification authorization unavailable."
                }
                self.refresh()
            }
        }
    }
    @objc func testNotification() {
        // User-triggered test only. Never inject a battery sample or touch dedup state.
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                DispatchQueue.main.async {
                    self.notificationFeedback = settings.authorizationStatus == .notDetermined
                        ? "Test not sent. Click Enable Notifications and answer the macOS prompt first."
                        : "Test not sent. Notification permission is not enabled."
                    self.updateNotificationStatus()
                }
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "Magic Charger — Test Notification"
            content.body = "This is a user-requested notification test. No battery threshold was crossed."
            content.sound = .default
            self.center.add(UNNotificationRequest(identifier: "test-" + UUID().uuidString, content: content, trigger: nil)) { error in
                DispatchQueue.main.async {
                    self.notificationFeedback = error == nil
                        ? "Test submitted to macOS. Confirm whether its banner appeared; Focus may suppress it."
                        : "Test submission failed. Check notification settings."
                    self.refresh()
                }
            }
        }
    }
    @objc func permissions() {
        center.getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                self.center.requestAuthorization(options: [.alert, .sound]) { _, error in
                    DispatchQueue.main.async {
                        if error != nil { self.notificationFeedback = "Notification permission request failed. See System Settings > Notifications." }
                        self.updateNotificationStatus()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.notificationFeedback = "Open Notifications in System Settings and select Magic Charger."
                    NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/System Settings.app"), configuration: NSWorkspace.OpenConfiguration()) { _, error in
                        if error != nil { DispatchQueue.main.async { self.notificationFeedback = "System Settings could not be opened. Open Notifications manually."; self.refresh() } }
                    }
                    self.refresh()
                }
            }
        }
    }
    @objc func showSettings() {
        window.makeKeyAndOrderFront(nil)
        controls.updateLogin(status: SMAppService.mainApp.status)
        updateNotificationStatus()
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func quit() { NSApp.terminate(nil) }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
        DispatchQueue.main.async {
            self.foregroundPresentation = "Foreground delegate ran: requested banner, Notification Center and sound for \(notification.request.identifier.hasPrefix("test-") ? "test" : "automatic") notification."
            self.refresh()
        }
    }
}
let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.run()
