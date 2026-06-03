import SwiftUI

struct DistractionPopoverView: View {
    @ObservedObject var session: SessionManager

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Still on task?")
                    .font(.headline)
            }

            Text("You've been in **\(session.distractionAppName)** for 30s.\nIs this related to \"\(session.task)\"?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Yes, it is") {
                    session.answerDistraction(related: true)
                }
                .buttonStyle(.bordered)

                Button("No, going back") {
                    session.answerDistraction(related: false)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}
