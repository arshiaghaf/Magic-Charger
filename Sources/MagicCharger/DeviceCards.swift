import AppKit

final class DeviceCards {
    let view = NSStackView()
    private var signature = ""

    init() {
        view.orientation = .vertical
        view.alignment = .leading
        view.spacing = 10
    }

    func update(_ readings: [Reading]) {
        let sorted = readings.sorted { $0.name < $1.name }
        let current = sorted.map { "\($0.id):\($0.percent ?? -1):\($0.state.rawValue):\($0.fullChargeEvidence)" }.joined(separator: ";")
        guard current != signature || view.arrangedSubviews.isEmpty else { return }
        signature = current
        view.arrangedSubviews.forEach { view.removeArrangedSubview($0); $0.removeFromSuperview() }
        if sorted.isEmpty {
            let empty = NSTextField(wrappingLabelWithString: "No Magic accessories detected.\nConnect a Magic Keyboard or Magic Mouse to get started.")
            empty.font = .systemFont(ofSize: 13); empty.textColor = .secondaryLabelColor
            view.addArrangedSubview(empty)
        } else {
            for reading in sorted {
                let row = card(reading)
                view.addArrangedSubview(row); row.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
            }
        }
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
}
