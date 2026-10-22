import Foundation
import IOKit

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

final class AccessoryMonitor {
    var onChange: (() -> Void)?
    private var matchingIterators: [io_iterator_t] = []
    private var port: IONotificationPortRef?
    private var interests: [UInt64: io_object_t] = [:]
    private var registryDirty = true

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
                        let owner = Unmanaged<AccessoryMonitor>.fromOpaque(context).takeUnretainedValue()
                        DispatchQueue.main.async { owner.registryDirty = true; owner.onChange?() }
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
                let owner = Unmanaged<AccessoryMonitor>.fromOpaque(context).takeUnretainedValue()
                DispatchQueue.main.async { owner.onChange?() }
            }, Unmanaged.passUnretained(self).toOpaque(), &interest)
            if code == KERN_SUCCESS { interests[id] = interest }
        }
        for id in Array(interests.keys) where !present.contains(id) { IOObjectRelease(interests.removeValue(forKey: id)!) }
    }
}
