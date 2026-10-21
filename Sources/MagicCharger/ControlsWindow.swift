import AppKit

final class ControlsWindow: NSWindowController {
    private let devices = NSStackView()
    private let notificationLabel = NSTextField(labelWithString: "Checking permission…")
    private let enableButton: NSButton
    private let testButton: NSButton
    private let feedback = NSTextField(wrappingLabelWithString: "")
    private let glyphToggle = NSButton(checkboxWithTitle: "Device icon", target: nil, action: nil)
    private let percentToggle = NSButton(checkboxWithTitle: "Percentage", target: nil, action: nil)
    private let barToggle = NSButton(checkboxWithTitle: "Battery bar", target: nil, action: nil)
    private let preferenceHint = NSTextField(wrappingLabelWithString: "Keep at least one item visible.")
    private let onPreferencesChange: (MenuBarPreferences) -> Void
    private var diagnostic = ""
    private var deviceSignature = ""
    private var detailsWindow: NSWindow?

    init(target: AnyObject, enable: Selector, test: Selector, quit: Selector, preferences: MenuBarPreferences, onChange: @escaping (MenuBarPreferences) -> Void) {
        onPreferencesChange = onChange
        enableButton = NSButton(title: "Enable Notifications…", target: target, action: enable)
        testButton = NSButton(title: "Send Test", target: target, action: test)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 430),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Magic Charger"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.center()
        let content = window.contentView!
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        let title = NSTextField(labelWithString: "Magic Charger")
        title.font = .systemFont(ofSize: 23, weight: .semibold)
        let heading = NSStackView(views: [title]); heading.orientation = .vertical; heading.alignment = .leading
        devices.orientation = .vertical; devices.alignment = .leading; devices.spacing = 10
        let notificationTitle = NSTextField(labelWithString: "Notifications"); notificationTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        notificationLabel.font = .systemFont(ofSize: 12); notificationLabel.textColor = .secondaryLabelColor
        let notificationHeading = NSStackView(views: [notificationTitle, notificationLabel]); notificationHeading.orientation = .vertical; notificationHeading.alignment = .leading; notificationHeading.spacing = 4
        let controls = NSStackView(views: [enableButton, testButton]); controls.spacing = 10
        let reminder = NSTextField(wrappingLabelWithString: "Charging starts, 78%, 80%, and 100%.")
        reminder.font = .systemFont(ofSize: 11); reminder.textColor = .secondaryLabelColor
        feedback.font = .systemFont(ofSize: 11); feedback.textColor = .secondaryLabelColor; feedback.isHidden = true
        let notifications = NSStackView(views: [notificationHeading, controls, reminder, feedback]); notifications.orientation = .vertical; notifications.alignment = .leading; notifications.spacing = 10
        let menuTitle = NSTextField(labelWithString: "Menu Bar"); menuTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        glyphToggle.state = preferences.deviceGlyph ? .on : .off
        percentToggle.state = preferences.percentage ? .on : .off
        barToggle.state = preferences.batteryBar ? .on : .off
        for toggle in [glyphToggle, percentToggle, barToggle] { toggle.target = self; toggle.action = #selector(changePreferences(_:)) }
        let toggles = NSStackView(views: [glyphToggle, percentToggle, barToggle]); toggles.spacing = 14
        preferenceHint.font = .systemFont(ofSize: 11); preferenceHint.textColor = .secondaryLabelColor; preferenceHint.isHidden = true
        let menuOptions = NSStackView(views: [menuTitle, toggles, preferenceHint]); menuOptions.orientation = .vertical; menuOptions.alignment = .leading; menuOptions.spacing = 10
        let details = NSButton(title: "Technical Details…", target: self, action: #selector(showDetails)); details.bezelStyle = .inline
        let quitButton = NSButton(title: "Quit Magic Charger", target: target, action: quit); quitButton.keyEquivalent = "q"; quitButton.keyEquivalentModifierMask = .command
        let spacer = NSView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let footer = NSStackView(views: [details, spacer, quitButton]); footer.spacing = 12
        for view in [heading, devices, menuOptions, notifications, footer] { stack.addArrangedSubview(view); view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        content.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24), stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 26), stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -22)])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(readings: [Reading], notificationStatus: String, feedback message: String, diagnostic: String) {
        self.diagnostic = diagnostic
        let sorted = readings.sorted { $0.name < $1.name }
        let signature = sorted.map { "\($0.id):\($0.percent ?? -1):\($0.state.rawValue)" }.joined(separator: ";")
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
            let height = CGFloat(336 + max(1, sorted.count) * 78)
            if let window = window, abs(window.contentLayoutRect.height - height) > 1 {
                var frame = window.frame
                let newHeight = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: 440, height: height)).height
                frame.origin.y += frame.height - newHeight; frame.size.height = newHeight
                window.setFrame(frame, display: true)
            }
        }
        let enabled = notificationStatus == "Notifications enabled."
        notificationLabel.stringValue = enabled ? "On" : (notificationStatus.contains("denied") ? "Off · Enable in System Settings" : "Not enabled")
        enableButton.isHidden = enabled
        testButton.isEnabled = enabled
        if message.hasPrefix("Test submitted") { feedback.stringValue = "Test sent to macOS. Check Notification Center if needed."; feedback.isHidden = false }
        else if message.hasPrefix("Test not sent") || message.contains("failed") { feedback.stringValue = "Notification wasn’t sent. See Technical Details."; feedback.isHidden = false }
        else { feedback.isHidden = true }
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
        box.contentView!.addSubview(row)
        NSLayoutConstraint.activate([row.leadingAnchor.constraint(equalTo: box.contentView!.leadingAnchor), row.trailingAnchor.constraint(equalTo: box.contentView!.trailingAnchor), row.topAnchor.constraint(equalTo: box.contentView!.topAnchor), row.bottomAnchor.constraint(equalTo: box.contentView!.bottomAnchor), box.heightAnchor.constraint(greaterThanOrEqualToConstant: 68)])
        return box
    }

    @objc private func changePreferences(_ sender: NSButton) {
        let preferences = MenuBarPreferences(deviceGlyph: glyphToggle.state == .on, percentage: percentToggle.state == .on, batteryBar: barToggle.state == .on)
        guard preferences.isValid else { sender.state = .on; preferenceHint.isHidden = false; return }
        preferenceHint.isHidden = true
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
