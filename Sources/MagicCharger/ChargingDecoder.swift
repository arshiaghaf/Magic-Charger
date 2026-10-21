import Foundation

struct ChargingDecoder {
    // Deliberately narrow compatibility profile, based on controlled cable
    // transitions. This is not a general interpretation of undocumented flags.
    static func decode(vendor: Int, product: Int, transport: String?, os: OperatingSystemVersion,
                       percent: Int?, flags: Int?, batteryCharging: Bool?, isCharging: Bool?) -> Charging {
        if let a = batteryCharging, let b = isCharging, a != b { return .unknown }
        let explicit = (batteryCharging ?? isCharging).map { $0 ? Charging.charging : .idle }
        var indication: Charging = .unknown
        if vendor == 76, product == 803, transport == "Bluetooth", os.majorVersion == 27, os.minorVersion == 2 {
            switch flags {
            case 4: indication = .idle
            case 3:
                // Full does not prove the battery is still accepting current.
                if let percent = percent, (0..<100).contains(percent) { indication = .charging }
            default: break
            }
        }
        if let explicit = explicit {
            if indication != .unknown && indication != explicit { return .unknown }
            return explicit
        }
        return indication
    }
}

func reconciled(_ readings: [Reading]) -> [Reading] {
    Dictionary(grouping: readings, by: { $0.id }).values.compactMap { group in
        guard let newest = group.max(by: { $0.sampled < $1.sampled }) else { return nil }
        guard group.count > 1 else { return newest }
        let disagreement = Set(group.map { $0.state }).count > 1 || Set(group.map { $0.percent }).count > 1
        guard disagreement else { return newest }
        return Reading(id: newest.id, name: newest.name, symbol: newest.symbol, percent: nil, state: .unknown,
                       sampled: newest.sampled, evidence: "Conflicting observations for the same private device identity.")
    }.sorted { $0.id < $1.id }
}
