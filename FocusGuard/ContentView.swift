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
        .frame(minWidth: 380, minHeight: 300)
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

            Button("End Session") {
                session.end()
            }
            .buttonStyle(.bordered)
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
