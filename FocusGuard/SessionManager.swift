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
    @Published var isAccessibilityGranted: Bool = false

    private var sessionTimer: Timer?
    private var appObserver: NSObjectProtocol?

    // MARK: - Session control

    func start() {
        guard !task.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        elapsed = 0
        focusScore = 100
        state = .running
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsed += 1
        }
        requestAccessibility()
        startAppTracking()
    }

    func end() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        stopAppTracking()
        state = .ended
    }

    func reset() {
        task = ""
        elapsed = 0
        focusScore = 100
        activeAppName = ""
        activeWindowTitle = ""
        state = .idle
    }

    var elapsedFormatted: String {
        let m = Int(elapsed) / 60
        let s = Int(elapsed) % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Accessibility

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        isAccessibilityGranted = AXIsProcessTrustedWithOptions(options)
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
        isAccessibilityGranted = AXIsProcessTrusted()
    }

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
