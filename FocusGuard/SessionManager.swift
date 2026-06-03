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

    @Published var activeContext: ActivityContext?
    @Published var distractionContext: ActivityContext?
    @Published var isDistracted: Bool = false

    // Convenience accessors for views
    var activeAppName: String { activeContext?.appName ?? "" }
    var activeWindowTitle: String { activeContext?.windowTitle ?? "" }
    var distractionAppName: String { distractionContext?.appName ?? "" }

    private var focusAppBundleID: String = ""
    private var contextStartTime: Date = Date()

    private var sessionTimer: Timer?
    private var distractionTimer: Timer?
    private var classifyTimer: Timer?
    private var appObserver: NSObjectProtocol?

    static let distractionGrace: TimeInterval = 30

    // MARK: - Session control

    func start() {
        guard !task.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        elapsed = 0
        focusScore = 100
        isDistracted = false
        distractionContext = nil

        if let current = NSWorkspace.shared.frontmostApplication {
            focusAppBundleID = current.bundleIdentifier ?? ""
        }

        state = .running
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsed += 1
            self?.tickActiveContext()
        }
        startAppTracking()
    }

    func end() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        distractionTimer?.invalidate()
        distractionTimer = nil
        classifyTimer?.invalidate()
        classifyTimer = nil
        stopAppTracking()
        isDistracted = false
        state = .ended
    }

    func reset() {
        classifyTimer?.invalidate()
        classifyTimer = nil
        distractionTimer?.invalidate()
        distractionTimer = nil
        task = ""
        elapsed = 0
        focusScore = 100
        activeContext = nil
        distractionContext = nil
        isDistracted = false
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
            setContext(for: current)
        }
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.setContext(for: app)
        }
    }

    private func stopAppTracking() {
        if let obs = appObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        appObserver = nil
        activeContext = nil
    }

    private func setContext(for app: NSRunningApplication) {
        contextStartTime = Date()
        activeContext = ActivityContext(
            appName: app.localizedName ?? app.bundleIdentifier ?? "Unknown",
            bundleID: app.bundleIdentifier ?? "",
            windowTitle: windowTitle(for: app.processIdentifier),
            url: BrowserURLReader.readURL(from: app),
            timestamp: Date(),
            elapsedInContext: 0
        )

        guard state == .running else { return }

        let isSelf = app.bundleIdentifier == Bundle.main.bundleIdentifier
        let isFocusApp = app.bundleIdentifier == focusAppBundleID

        if isFocusApp || isSelf {
            cancelDistractionTimer()
        } else if !isDistracted, let ctx = activeContext {
            startDistractionTimer(context: ctx)
        }

        scheduleClassification()
    }

    // MARK: - Classification

    private func scheduleClassification() {
        classifyTimer?.invalidate()
        guard state == .running, let ctx = activeContext else { return }
        // Classify after 10s of stable context
        classifyTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            self?.runClassification(for: ctx)
        }
    }

    private func runClassification(for snapshot: ActivityContext) {
        let currentTask = task
        Task {
            guard let result = await ClaudeClassifier.shared.classify(context: snapshot, task: currentTask) else { return }
            await MainActor.run {
                guard var ctx = self.activeContext,
                      ctx.bundleID == snapshot.bundleID,
                      ctx.url == snapshot.url else { return }
                ctx.classification = result
                self.activeContext = ctx
            }
        }
    }

    private func tickActiveContext() {
        guard var ctx = activeContext else { return }
        ctx.elapsedInContext = Date().timeIntervalSince(contextStartTime)
        activeContext = ctx
    }

    // MARK: - Distraction timer

    private func startDistractionTimer(context: ActivityContext) {
        distractionTimer?.invalidate()
        distractionContext = context
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
        distractionContext = nil
    }

    // MARK: - Window title

    private func windowTitle(for pid: pid_t) -> String {
        guard AXIsProcessTrusted() else { return "" }
        let axApp = AXUIElementCreateApplication(pid)
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowRef else { return "" }
        guard let axWindow = windowRef as? AXUIElement else { return "" }
        var titleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef) == .success,
              let title = titleRef as? String else { return "" }
        return title
    }
}
