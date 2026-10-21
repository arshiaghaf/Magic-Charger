import Foundation

enum Charging: String, Codable { case charging, idle, unknown }
struct Reading {
    let id: String
    let name: String
    let symbol: String
    let percent: Int?
    let state: Charging
    let sampled: Date
    let evidence: String
    var fullChargeEvidence = false
    func fresh(at now: Date) -> Bool { (0..<90).contains(now.timeIntervalSince(sampled)) }
    var active: Bool { state == .charging && fresh(at: Date()) }
}
struct Session: Codable {
    var sent: Set<Int> = []
    var lastSeen: Date
    var lastPercent: Int?
    var ended = false
    var lastAlert: [Int: Date] = [:]
}
struct Thresholds {
    var sessions: [String: Session] = [:]
    private var continuousCharging = Set<String>()
    mutating func invalidateContinuity() { continuousCharging.removeAll() }
    mutating func retainContinuity(for ids: Set<String>) { continuousCharging.formIntersection(ids) }
    mutating func consume(_ r: Reading, now: Date = Date()) -> [Int] {
        guard r.fresh(at: now) else { continuousCharging.remove(r.id); return [] }
        let full = r.percent == 100 && r.fullChargeEvidence
        let priorCharging = continuousCharging.contains(r.id)
        if r.state == .charging, let percent = r.percent, (0...100).contains(percent) { continuousCharging.insert(r.id) }
        else if !full { continuousCharging.remove(r.id) }
        guard r.state != .unknown || full else { return [] }
        // Keep a bounded history without interpreting absence as unplugging.
        sessions = sessions.filter { now.timeIntervalSince($0.value.lastSeen) < 30 * 86400 }
        if r.state == .idle {
            var s = sessions[r.id] ?? Session(lastSeen: r.sampled)
            s.ended = true; s.lastSeen = r.sampled; s.lastPercent = nil
            sessions[r.id] = s
            return []
        }
        guard let percent = r.percent, (0...100).contains(percent) else { return [] }
        var s = sessions[r.id] ?? Session(lastSeen: r.sampled)
        if s.ended { s.sent = []; s.lastPercent = nil; s.ended = false }
        // Establish a baseline on first observation, never send historical alerts.
        guard let previous = s.lastPercent, r.sampled.timeIntervalSince(s.lastSeen) < 90, percent != 100 || priorCharging else {
            s.sent.formUnion([78, 80, 100].filter { percent >= $0 })
            s.lastSeen = r.sampled; s.lastPercent = percent; sessions[r.id] = s
            return []
        }
        let crossed = [78, 80, 100].filter { previous < $0 && percent >= $0 && !s.sent.contains($0) }
        s.sent.formUnion(crossed)
        // A short persisted cooldown also protects against noisy idle/charging flips.
        let eligible = crossed.filter { now.timeIntervalSince(s.lastAlert[$0] ?? .distantPast) >= 300 }
        if let highest = eligible.max() { for threshold in crossed { s.lastAlert[threshold] = now }; s.lastAlert[highest] = now }
        s.lastSeen = r.sampled; s.lastPercent = percent; sessions[r.id] = s
        return eligible.max().map { [$0] } ?? []
    }
}

// Process-local continuity is intentional: a restart must establish a new
// baseline, never replay a historical "started" event from persisted state.
struct ChargingStarts {
    private var previous: [String: Reading] = [:]
    mutating func invalidate() { previous.removeAll() }
    mutating func consume(_ readings: [Reading], now: Date = Date()) -> [Reading] {
        let current = reconciled(readings)
        defer { previous = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) }) }
        return current.filter { r in
            guard r.fresh(at: now), r.state == .charging,
                  let percent = r.percent, (0...100).contains(percent),
                  let old = previous[r.id], old.fresh(at: now), old.state == .idle else { return false }
            return true
        }
    }
}
