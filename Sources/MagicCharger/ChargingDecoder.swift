import Foundation

struct ChargingDecoder {
    // Deliberately narrow compatibility profile, based on controlled cable
    // transitions. This is not a general interpretation of undocumented flags.
    static func fullChargeEvidence(vendor: Int, product: Int, transport: String?, os: OperatingSystemVersion,
                                   percent: Int?, flags: Int?, batteryCharging: Bool?, isCharging: Bool?) -> Bool {
        vendor == 76 && [803, 801].contains(product) && transport == "Bluetooth" &&
        os.majorVersion == 27 && os.minorVersion == 2 && percent == 100 && flags == 3 &&
        batteryCharging != false && isCharging != false
    }
    static func decode(vendor: Int, product: Int, transport: String?, os: OperatingSystemVersion,
                       percent: Int?, flags: Int?, batteryCharging: Bool?, isCharging: Bool?) -> Charging {
        if let a = batteryCharging, let b = isCharging, a != b { return .unknown }
        let explicit = (batteryCharging ?? isCharging).map { $0 ? Charging.charging : .idle }
        var indication: Charging = .unknown
        // Each model was validated separately; do not extend this list by family name.
        let validatedProduct: Bool
        switch product {
        case 803: validatedProduct = true // Magic Mouse profile
        case 801: validatedProduct = true // Magic Keyboard profile
        default: validatedProduct = false
        }
        if vendor == 76, validatedProduct, transport == "Bluetooth", os.majorVersion == 27, os.minorVersion == 2 {
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
        let disagreement = Set(group.map { $0.state }).count > 1 || Set(group.map { $0.percent }).count > 1 || Set(group.map { $0.fullChargeEvidence }).count > 1
        guard disagreement else { return newest }
        return Reading(id: newest.id, name: newest.name, symbol: newest.symbol, percent: nil, state: .unknown,
                       sampled: newest.sampled, evidence: "Conflicting observations for the same private device identity.")
    }.sorted { $0.id < $1.id }
}
