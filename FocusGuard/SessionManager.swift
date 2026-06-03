import Foundation

enum FocusSession {
    case idle, running, ended
}

class SessionManager: ObservableObject {
    @Published var state: FocusSession = .idle
    @Published var task: String = ""
    @Published var elapsed: TimeInterval = 0
    @Published var focusScore: Int = 100

    private var timer: Timer?

    func start() {
        guard !task.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        elapsed = 0
        focusScore = 100
        state = .running
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsed += 1
        }
    }

    func end() {
        timer?.invalidate()
        timer = nil
        state = .ended
    }

    func reset() {
        task = ""
        elapsed = 0
        focusScore = 100
        state = .idle
    }

    var elapsedFormatted: String {
        let m = Int(elapsed) / 60
        let s = Int(elapsed) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
