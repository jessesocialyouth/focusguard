import Foundation

class UsageTracker: ObservableObject {
    static let shared = UsageTracker()

    @Published private(set) var callsToday: Int = 0
    var dailyLimit: Int = 200

    private let defaults = UserDefaults.standard
    private let callsKey = "fg_calls_today"
    private let dateKey = "fg_calls_date"

    private init() {
        rolloverIfNeeded()
        callsToday = defaults.integer(forKey: callsKey)
    }

    var isUnderLimit: Bool { callsToday < dailyLimit }

    var usageSummary: String { "\(callsToday) / \(dailyLimit) calls today" }

    func recordCall() {
        rolloverIfNeeded()
        callsToday += 1
        defaults.set(callsToday, forKey: callsKey)
    }

    private func rolloverIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        let stored = defaults.object(forKey: dateKey) as? Date ?? .distantPast
        if stored < today {
            callsToday = 0
            defaults.set(0, forKey: callsKey)
            defaults.set(today, forKey: dateKey)
        }
    }
}
