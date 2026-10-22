import AppKit
import ServiceManagement

private final class ControlsDocumentView: NSView {
    override var isFlipped: Bool { true }
}

struct LoginItemViewState {
    let toggle: NSControl.StateValue
    let canToggle: Bool
    let needsApproval: Bool

    init(_ status: SMAppService.Status) {
        toggle = status == .enabled ? .on : (status == .requiresApproval ? .mixed : .off)
        canToggle = status == .notRegistered || status == .enabled
        needsApproval = status == .requiresApproval
    }
}

final class ControlsWindow: NSWindowController {
    private let scrollView = NSScrollView()
    private let documentView = ControlsDocumentView()
    private let stack = NSStackView()
    private let devices = NSStackView()
    private let notificationLabel = NSTextField(wrappingLabelWithString: "Checking permission…")
    private let enableButton: NSButton
    private let testButton: NSButton
    private let feedback = NSTextField(wrappingLabelWithString: "")
    private let loginToggle = NSButton(checkboxWithTitle: "Launch at Login", target: nil, action: nil)
    private let loginHint = NSTextField(wrappingLabelWithString: "")
    private let loginSettingsButton: NSButton
    private let cancelLoginButton = NSButton(title: "Cancel Login Request", target: nil, action: nil)
    private let updateFeedback = NSTextField(wrappingLabelWithString: "")
    private let glyphToggle = NSButton(checkboxWithTitle: "Device icon", target: nil, action: nil)
    private let percentToggle = NSButton(checkboxWithTitle: "Percentage", target: nil, action: nil)
    private let barToggle = NSButton(checkboxWithTitle: "Battery bar", target: nil, action: nil)
    private let preferenceHint = NSTextField(wrappingLabelWithString: "Keep at least one item visible.")
    private let onPreferencesChange: (MenuBarPreferences) -> Void
    private let onAlertsChange: (NotificationPreferences) -> Void
    private let onLoginChange: (Bool) -> Void
    private var alertToggles: [AlertKind: NSButton] = [:]
    private var diagnostic = ""
    private var deviceSignature = ""
    private var detailsWindow: NSWindow?

    init(target: AnyObject, enable: Selector, test: Selector, updates: Selector, loginSettings: Selector, quit: Selector, preferences: MenuBarPreferences, alerts: NotificationPreferences, onChange: @escaping (MenuBarPreferences) -> Void, onAlertsChange: @escaping (NotificationPreferences) -> Void, onLoginChange: @escaping (Bool) -> Void) {
        onPreferencesChange = onChange
        self.onAlertsChange = onAlertsChange
        self.onLoginChange = onLoginChange
        enableButton = NSButton(title: "Enable Notifications…", target: target, action: enable)
        testButton = NSButton(title: "Send Test", target: target, action: test)
        loginSettingsButton = NSButton(title: "Open Login Items…", target: target, action: loginSettings)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 430),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Magic Charger"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.center()
        let content = window.contentView!
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        let title = NSTextField(labelWithString: "Magic Charger")
        title.font = .systemFont(ofSize: 23, weight: .semibold)
        let introduction = NSTextField(wrappingLabelWithString: "Menu-bar items appear only while a supported accessory is charging. Reopen Magic Charger from Finder or Spotlight for controls.")
        introduction.font = .systemFont(ofSize: 12); introduction.textColor = .secondaryLabelColor
        let heading = NSStackView(views: [title, introduction]); heading.orientation = .vertical; heading.alignment = .leading; heading.spacing = 7
        introduction.widthAnchor.constraint(equalTo: heading.widthAnchor).isActive = true
        devices.orientation = .vertical; devices.alignment = .leading; devices.spacing = 10
        let notificationTitle = NSTextField(labelWithString: "Notifications"); notificationTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        notificationLabel.font = .systemFont(ofSize: 12); notificationLabel.textColor = .secondaryLabelColor
        let notificationHeading = NSStackView(views: [notificationTitle, notificationLabel]); notificationHeading.orientation = .vertical; notificationHeading.alignment = .leading; notificationHeading.spacing = 4
        notificationLabel.widthAnchor.constraint(equalTo: notificationHeading.widthAnchor).isActive = true
        let controls = NSStackView(views: [enableButton, testButton]); controls.spacing = 10
        enableButton.keyEquivalent = "e"; enableButton.keyEquivalentModifierMask = .command
        testButton.keyEquivalent = "t"; testButton.keyEquivalentModifierMask = .command
        enableButton.setAccessibilityHelp("Request notification permission or open macOS notification settings.")
        testButton.setAccessibilityHelp("Send one labeled test notification without changing charging data.")
        let alertOptions = NSStackView(); alertOptions.orientation = .vertical; alertOptions.alignment = .leading; alertOptions.spacing = 8
        for kind in AlertKind.allCases {
            let toggle = NSButton(checkboxWithTitle: kind.title, target: self, action: #selector(changeAlerts))
            toggle.state = alerts.allows(kind) ? .on : .off
            alertToggles[kind] = toggle
        }
        let kinds = AlertKind.allCases
        for offset in stride(from: 0, to: kinds.count, by: 2) {
            let row = NSStackView(views: [alertToggles[kinds[offset]]!, alertToggles[kinds[offset + 1]]!])
            row.spacing = 12; row.distribution = .fillEqually
            alertOptions.addArrangedSubview(row); row.widthAnchor.constraint(equalTo: alertOptions.widthAnchor).isActive = true
        }
        feedback.font = .systemFont(ofSize: 11); feedback.textColor = .secondaryLabelColor; feedback.isHidden = true
        let notifications = NSStackView(views: [notificationHeading, alertOptions, controls, feedback]); notifications.orientation = .vertical; notifications.alignment = .leading; notifications.spacing = 10
        notificationHeading.widthAnchor.constraint(equalTo: notifications.widthAnchor).isActive = true
        alertOptions.widthAnchor.constraint(equalTo: notifications.widthAnchor).isActive = true
        feedback.widthAnchor.constraint(equalTo: notifications.widthAnchor).isActive = true
        let menuTitle = NSTextField(labelWithString: "Menu Bar"); menuTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        glyphToggle.state = preferences.deviceGlyph ? .on : .off
        percentToggle.state = preferences.percentage ? .on : .off
        barToggle.state = preferences.batteryBar ? .on : .off
        for toggle in [glyphToggle, percentToggle, barToggle] { toggle.target = self; toggle.action = #selector(changePreferences(_:)) }
        let toggles = NSStackView(views: [glyphToggle, percentToggle, barToggle]); toggles.spacing = 14
        preferenceHint.font = .systemFont(ofSize: 11); preferenceHint.textColor = .secondaryLabelColor; preferenceHint.isHidden = true
        let menuOptions = NSStackView(views: [menuTitle, toggles, preferenceHint]); menuOptions.orientation = .vertical; menuOptions.alignment = .leading; menuOptions.spacing = 10
        let generalTitle = NSTextField(labelWithString: "General"); generalTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        loginToggle.target = self; loginToggle.action = #selector(changeLogin(_:))
        loginToggle.allowsMixedState = true
        loginToggle.setAccessibilityHelp("Start Magic Charger automatically when you sign in. Off until you enable it.")
        loginHint.font = .systemFont(ofSize: 11); loginHint.textColor = .secondaryLabelColor
        loginSettingsButton.bezelStyle = .inline; loginSettingsButton.isHidden = true
        loginSettingsButton.setAccessibilityHelp("Open macOS Login Items settings to approve Magic Charger.")
        cancelLoginButton.target = self; cancelLoginButton.action = #selector(cancelLogin)
        cancelLoginButton.bezelStyle = .inline; cancelLoginButton.isHidden = true
        cancelLoginButton.setAccessibilityHelp("Remove the pending login item registration.")
        let updatesButton = NSButton(title: "View Releases…", target: target, action: updates)
        updatesButton.keyEquivalent = "u"; updatesButton.keyEquivalentModifierMask = .command
        updatesButton.setAccessibilityHelp("Open the official Magic Charger releases page in your browser.")
        updateFeedback.font = .systemFont(ofSize: 11); updateFeedback.textColor = .secondaryLabelColor; updateFeedback.isHidden = true
        let general = NSStackView(views: [generalTitle, loginToggle, loginHint, loginSettingsButton, cancelLoginButton, updatesButton, updateFeedback]); general.orientation = .vertical; general.alignment = .leading; general.spacing = 7
        loginHint.widthAnchor.constraint(equalTo: general.widthAnchor).isActive = true
        updateFeedback.widthAnchor.constraint(equalTo: general.widthAnchor).isActive = true
        let details = NSButton(title: "Technical Details…", target: self, action: #selector(showDetails)); details.bezelStyle = .inline
        let quitButton = NSButton(title: "Quit Magic Charger", target: target, action: quit); quitButton.keyEquivalent = "q"; quitButton.keyEquivalentModifierMask = .command
        let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let about = NSButton(title: "About", target: self, action: #selector(showAbout)); about.bezelStyle = .inline
        let footer = NSStackView(views: [details, about, spacer, quitButton]); footer.spacing = 12
        for view in [heading, devices, menuOptions, notifications, general, footer] { stack.addArrangedSubview(view); view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        scrollView.hasVerticalScroller = true; scrollView.autohidesScrollers = true; scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        documentView.frame = NSRect(x: 0, y: 0, width: 440, height: 430)
        scrollView.documentView = documentView
        documentView.addSubview(stack)
        content.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor), scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: content.topAnchor), scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 26)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(readings: [Reading], notificationStatus: String, feedback message: String, diagnostic: String) {
        self.diagnostic = diagnostic
        let sorted = readings.sorted { $0.name < $1.name }
        let signature = sorted.map { "\($0.id):\($0.percent ?? -1):\($0.state.rawValue):\($0.fullChargeEvidence)" }.joined(separator: ";")
        if signature != deviceSignature || devices.arrangedSubviews.isEmpty {
            deviceSignature = signature
            devices.arrangedSubviews.forEach { devices.removeArrangedSubview($0); $0.removeFromSuperview() }
            if sorted.isEmpty {
                let empty = NSTextField(wrappingLabelWithString: "No Magic accessories detected.\nConnect a Magic Keyboard or Magic Mouse to get started.")
                empty.font = .systemFont(ofSize: 13); empty.textColor = .secondaryLabelColor
                devices.addArrangedSubview(empty)
            } else {
                for reading in sorted {
                    let row = card(reading)
                    devices.addArrangedSubview(row); row.widthAnchor.constraint(equalTo: devices.widthAnchor).isActive = true
                }
            }
        }
        let enabled = notificationStatus == "Notifications enabled."
        notificationLabel.stringValue = enabled ? "Allowed by macOS" : (notificationStatus.contains("denied") ? "Blocked by macOS · Open Notification Settings to allow alerts" : (notificationStatus.contains("not requested") ? "Off · Enable Notifications to receive alerts" : "Permission unavailable · Open Notification Settings"))
        enableButton.title = notificationStatus.contains("not requested") ? "Enable Notifications…" : "Notification Settings…"
        enableButton.isHidden = false
        testButton.isEnabled = enabled
        if message.hasPrefix("Test submitted") { feedback.stringValue = "Test sent to macOS. Check Notification Center if needed."; feedback.isHidden = false }
        else if message.hasPrefix("Open Notifications") || message.hasPrefix("System Settings") { feedback.stringValue = message; feedback.isHidden = false }
        else if message.hasPrefix("Test not sent") || message.contains("failed") { feedback.stringValue = "Notification wasn’t sent. Open Notification Settings, then try again."; feedback.isHidden = false }
        else { feedback.isHidden = true }
        resizeForContent()
    }

    func updateLogin(status: SMAppService.Status, feedback: String = "") {
        let viewState = LoginItemViewState(status)
        loginToggle.state = viewState.toggle
        loginToggle.isEnabled = viewState.canToggle
        loginSettingsButton.isHidden = !viewState.needsApproval
        cancelLoginButton.isHidden = !viewState.needsApproval
        switch status {
        case .enabled: loginHint.stringValue = "Starts automatically when you sign in."
        case .notRegistered: loginHint.stringValue = feedback.isEmpty ? "Optional; currently off." : feedback
        case .requiresApproval: loginHint.stringValue = "Registered; approval needed in System Settings > General > Login Items."
        case .notFound: loginHint.stringValue = "Available from the signed app bundle."
        @unknown default: loginHint.stringValue = "Login item status unavailable."
        }
        if !feedback.isEmpty && status != .notRegistered { loginHint.stringValue = feedback }
        resizeForContent()
    }

    func updateFeedbackForUpdates(_ message: String) {
        updateFeedback.stringValue = message
        updateFeedback.isHidden = message.isEmpty
        resizeForContent()
    }

    static func boundedContentHeight(requested: CGFloat, visible: CGFloat, chrome: CGFloat) -> CGFloat {
        min(requested, max(1, visible - chrome - 40))
    }

    private func resizeForContent() {
        guard let window = window, let content = window.contentView else { return }
        content.layoutSubtreeIfNeeded()
        let width = max(1, scrollView.contentSize.width)
        documentView.setFrameSize(NSSize(width: width, height: documentView.frame.height))
        documentView.layoutSubtreeIfNeeded()
        let requested = max(CGFloat(430), stack.fittingSize.height + 48)
        documentView.setFrameSize(NSSize(width: width, height: requested))
        let chrome = window.frame.height - window.contentLayoutRect.height
        let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 440, height: 700)
        let height = Self.boundedContentHeight(requested: requested, visible: visible.height, chrome: chrome)
        guard abs(window.contentLayoutRect.height - height) > 1 else { return }
        var frame = window.frame
        let newHeight = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: frame.width, height: height)).height
        let top = frame.maxY
        frame.size.height = newHeight
        frame.origin.y = min(max(top - newHeight, visible.minY + 20), visible.maxY - newHeight - 20)
        window.setFrame(frame, display: true)
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Magic Charger",
            .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development",
            .credits: NSAttributedString(string: "MIT License · Copyright © 2026 Arshia Ghaf\nLocal accessory charging notifications.")
        ])
    }

    private func card(_ reading: Reading) -> NSView {
        let box = NSBox(); box.boxType = .custom; box.cornerRadius = 12; box.borderWidth = 0
        box.fillColor = .controlBackgroundColor; box.contentViewMargins = NSSize(width: 16, height: 12)
        let image = NSImageView(image: NSImage(systemSymbolName: reading.symbol, accessibilityDescription: reading.name)?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 26, weight: .regular)) ?? NSImage())
        image.contentTintColor = .labelColor; image.imageScaling = .scaleProportionallyDown
        image.widthAnchor.constraint(equalToConstant: 32).isActive = true; image.heightAnchor.constraint(equalToConstant: 30).isActive = true
        let name = NSTextField(labelWithString: reading.name); name.font = .systemFont(ofSize: 13, weight: .semibold)
        let status: String
        switch reading.state { case .charging: status = "Charging"; case .idle: status = "Not charging"; case .unknown: status = reading.fullChargeEvidence ? "100% reported · charging state unknown" : "Charging state unknown" }
        let state = NSTextField(wrappingLabelWithString: status); state.font = .systemFont(ofSize: 11); state.textColor = .secondaryLabelColor
        let labels = NSStackView(views: [name, state]); labels.orientation = .vertical; labels.alignment = .leading; labels.spacing = 4
        let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let percent = NSTextField(labelWithString: reading.percent.map { "\($0)%" } ?? "—")
        percent.font = .monospacedDigitSystemFont(ofSize: 24, weight: .regular); percent.alignment = .right
        percent.setContentHuggingPriority(.required, for: .horizontal)
        percent.setAccessibilityLabel(reading.percent.map { "\($0) percent" } ?? "Battery level unknown")
        let row = NSStackView(views: [image, labels, spacer, percent]); row.spacing = 14; row.alignment = .centerY; row.translatesAutoresizingMaskIntoConstraints = false
        box.setAccessibilityLabel("\(reading.name), \(status), \(reading.percent.map { "\($0) percent" } ?? "battery level unknown")")
        box.contentView!.addSubview(row)
        NSLayoutConstraint.activate([row.leadingAnchor.constraint(equalTo: box.contentView!.leadingAnchor), row.trailingAnchor.constraint(equalTo: box.contentView!.trailingAnchor), row.topAnchor.constraint(equalTo: box.contentView!.topAnchor), row.bottomAnchor.constraint(equalTo: box.contentView!.bottomAnchor), box.heightAnchor.constraint(greaterThanOrEqualToConstant: 68)])
        return box
    }

    @objc private func changeAlerts() {
        onAlertsChange(NotificationPreferences(started: alertToggles[.started]?.state == .on,
            soon: alertToggles[.soon]?.state == .on, target: alertToggles[.target]?.state == .on,
            full: alertToggles[.full]?.state == .on))
    }

    @objc private func changeLogin(_ sender: NSButton) {
        onLoginChange(sender.state == .on)
    }

    @objc private func cancelLogin() { onLoginChange(false) }

    @objc private func changePreferences(_ sender: NSButton) {
        let preferences = MenuBarPreferences(deviceGlyph: glyphToggle.state == .on, percentage: percentToggle.state == .on, batteryBar: barToggle.state == .on)
        guard preferences.isValid else { sender.state = .on; preferenceHint.isHidden = false; resizeForContent(); return }
        preferenceHint.isHidden = true
        resizeForContent()
        onPreferencesChange(preferences)
    }

    @objc private func showDetails() {
        guard let parent = window else { return }
        let sheet = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 360), styleMask: [.titled], backing: .buffered, defer: false)
        sheet.title = "Technical Details"
        let scroll = NSScrollView(frame: NSRect(x: 20, y: 60, width: 540, height: 280)); scroll.hasVerticalScroller = true
        let text = NSTextView(frame: scroll.bounds); text.isEditable = false; text.isSelectable = true; text.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        text.string = diagnostic; text.textContainerInset = NSSize(width: 8, height: 8); scroll.documentView = text
        let done = NSButton(title: "Done", target: self, action: #selector(closeDetails)); done.keyEquivalent = "\r"; done.frame = NSRect(x: 490, y: 18, width: 70, height: 30)
        sheet.contentView!.addSubview(scroll); sheet.contentView!.addSubview(done)
        detailsWindow = sheet; parent.beginSheet(sheet)
    }
    @objc private func closeDetails() {
        if let sheet = detailsWindow { window?.endSheet(sheet); sheet.orderOut(nil); detailsWindow = nil }
    }
}
