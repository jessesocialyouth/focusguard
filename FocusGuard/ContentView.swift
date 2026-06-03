import SwiftUI

struct ContentView: View {
    @StateObject private var session = SessionManager()

    var body: some View {
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
        VStack(spacing: 4) {
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
                }
                if !session.activeWindowTitle.isEmpty {
                    Text(session.activeWindowTitle)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            if !session.isAccessibilityGranted {
                Text("Grant Accessibility in System Settings to see window titles")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
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
}
