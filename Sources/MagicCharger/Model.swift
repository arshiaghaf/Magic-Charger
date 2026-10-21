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
    mutating func consume(_ r: Reading, now: Date = Date()) -> [Int] {
        guard r.fresh(at: now), r.state != .unknown else { return [] }
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
        guard let previous = s.lastPercent else {
            s.sent.formUnion([78, 80].filter { percent >= $0 })
            s.lastSeen = r.sampled; s.lastPercent = percent; sessions[r.id] = s
            return []
        }
        let crossed = [78, 80].filter { previous < $0 && percent >= $0 && !s.sent.contains($0) }
        s.sent.formUnion(crossed)
        // A short persisted cooldown also protects against noisy idle/charging flips.
        let eligible = crossed.filter { now.timeIntervalSince(s.lastAlert[$0] ?? .distantPast) >= 300 }
        if let highest = eligible.max() { for threshold in crossed { s.lastAlert[threshold] = now }; s.lastAlert[highest] = now }
        s.lastSeen = r.sampled; s.lastPercent = percent; sessions[r.id] = s
        return eligible.max().map { [$0] } ?? []
    }
}
