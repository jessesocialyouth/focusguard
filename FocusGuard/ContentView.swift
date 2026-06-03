import SwiftUI
import ApplicationServices

struct ContentView: View {
    @ObservedObject var session: SessionManager
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var pollTimer: Timer?
    @State private var waitingForUser = false

    var body: some View {
        if accessibilityGranted {
            mainView
        } else {
            onboardingView
        }
    }

    // MARK: - Onboarding

    private var onboardingView: some View {
        VStack(spacing: 24) {
            Image(systemName: "accessibility")
                .font(.system(size: 52))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Accessibility Access Required")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("FocusGuard watches which app and window you're using to track whether you stay on task.\n\nThis requires Accessibility access.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if waitingForUser {
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Enable FocusGuard in:\nSystem Settings → Privacy & Security → Accessibility")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                Button("Grant Access") {
                    triggerAccessibilityPrompt()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(40)
        .frame(minWidth: 420, minHeight: 340)
        .onDisappear {
            pollTimer?.invalidate()
        }
    }

    // MARK: - Main

    private var mainView: some View {
        VStack(spacing: 24) {
            Text("FocusGuard")
                .font(.largeTitle)
                .fontWeight(.bold)

            Divider()

            switch session.state {
            case .idle:
                idleView
            case .running:
                runningView
            case .ended:
                endedView
            }

            Spacer()
        }
        .padding(32)
        .frame(minWidth: 400, minHeight: 340)
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 16) {
            TextField("What are you working on?", text: $session.task)
                .textFieldStyle(.roundedBorder)

            Button("Start Focus") {
                session.start()
            }
            .buttonStyle(.borderedProminent)
            .disabled(session.task.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: - Running

    private var runningView: some View {
        VStack(spacing: 16) {
            Label("In focus", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text(session.task)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(session.elapsedFormatted)
                .font(.system(size: 52, weight: .light, design: .monospaced))

            HStack(spacing: 6) {
                Text("Focus score:")
                    .foregroundStyle(.secondary)
                Text("\(session.focusScore)")
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
            }

            Divider()

            activeAppView

            Button("End Session") {
                session.end()
            }
            .buttonStyle(.bordered)
        }
    }

    private var activeAppView: some View {
        VStack(spacing: 6) {
            if session.activeAppName.isEmpty {
                Text("Watching for app switches…")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "app.badge")
                        .foregroundStyle(.secondary)
                    Text(session.activeAppName)
                        .fontWeight(.medium)
                    if let classification = session.activeContext?.classification {
                        ClassificationBadge(result: classification)
                    }
                }
                let detail = session.activeContext?.displayDetail ?? ""
                if !detail.isEmpty {
                    Text(detail)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    // MARK: - Classification badge

    struct ClassificationBadge: View {
        let result: ClassificationResult

        var body: some View {
            Text(result.label)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(result.badgeColor.opacity(0.15))
                .foregroundStyle(result.badgeColor)
                .clipShape(Capsule())
        }
    }

    // MARK: - Ended

    private var endedView: some View {
        VStack(spacing: 16) {
            Label("Session complete", systemImage: "flag.checkered")
                .font(.headline)

            Text("Duration: \(session.elapsedFormatted)")
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Text("Final score:")
                    .foregroundStyle(.secondary)
                Text("\(session.focusScore)")
                    .fontWeight(.semibold)
            }

            Button("New Session") {
                session.reset()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Permission logic

    private func triggerAccessibilityPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        waitingForUser = true
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        startPolling()
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if AXIsProcessTrusted() {
                pollTimer?.invalidate()
                accessibilityGranted = true
            }
        }
    }
}
