import Foundation
import AppKit
import ApplicationServices

enum FocusSession {
    case idle, running, ended
}

class SessionManager: ObservableObject {
    @Published var state: FocusSession = .idle
    @Published var task: String = ""
    @Published var elapsed: TimeInterval = 0
    @Published var focusScore: Int = 100

    @Published var activeAppName: String = ""
    @Published var activeWindowTitle: String = ""

    @Published var isDistracted: Bool = false
    @Published var distractionAppName: String = ""

    private var focusAppBundleID: String = ""
    private var focusAppName: String = ""

    private var sessionTimer: Timer?
    private var distractionTimer: Timer?
    private var appObserver: NSObjectProtocol?

    static let distractionGrace: TimeInterval = 30

    // MARK: - Session control

    func start() {
        guard !task.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        elapsed = 0
        focusScore = 100
        isDistracted = false

        if let current = NSWorkspace.shared.frontmostApplication {
            focusAppBundleID = current.bundleIdentifier ?? ""
            focusAppName = current.localizedName ?? ""
        }

        state = .running
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsed += 1
        }
        startAppTracking()
    }

    func end() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        distractionTimer?.invalidate()
        distractionTimer = nil
        stopAppTracking()
        isDistracted = false
        state = .ended
    }

    func reset() {
        task = ""
        elapsed = 0
        focusScore = 100
        activeAppName = ""
        activeWindowTitle = ""
        isDistracted = false
        distractionAppName = ""
        state = .idle
    }

    func answerDistraction(related: Bool) {
        if !related {
            focusScore = max(0, focusScore - 10)
        }
        isDistracted = false
        distractionTimer?.invalidate()
        distractionTimer = nil
    }

    var elapsedFormatted: String {
        let m = Int(elapsed) / 60
        let s = Int(elapsed) % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - App tracking

    private func startAppTracking() {
        if let current = NSWorkspace.shared.frontmostApplication {
            updateActive(app: current)
        }
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.updateActive(app: app)
        }
    }

    private func stopAppTracking() {
        if let obs = appObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        appObserver = nil
        activeAppName = ""
        activeWindowTitle = ""
    }

    private func updateActive(app: NSRunningApplication) {
        activeAppName = app.localizedName ?? app.bundleIdentifier ?? "Unknown"
        activeWindowTitle = windowTitle(for: app.processIdentifier)

        guard state == .running else { return }

        let isSelf = app.bundleIdentifier == Bundle.main.bundleIdentifier
        let isFocusApp = app.bundleIdentifier == focusAppBundleID

        if isFocusApp || isSelf {
            cancelDistractionTimer()
        } else if !isDistracted {
            startDistractionTimer(appName: activeAppName)
        }
    }

    private func startDistractionTimer(appName: String) {
        distractionTimer?.invalidate()
        distractionAppName = appName
        distractionTimer = Timer.scheduledTimer(
            withTimeInterval: Self.distractionGrace,
            repeats: false
        ) { [weak self] _ in
            self?.isDistracted = true
        }
    }

    private func cancelDistractionTimer() {
        distractionTimer?.invalidate()
        distractionTimer = nil
        distractionAppName = ""
    }

    // MARK: - Window title

    private func windowTitle(for pid: pid_t) -> String {
        guard AXIsProcessTrusted() else { return "" }
        let axApp = AXUIElementCreateApplication(pid)
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowRef else { return "" }
        let axWindow = windowRef as! AXUIElement
        var titleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef) == .success,
              let title = titleRef as? String else { return "" }
        return title
    }
}
