import SwiftUI

@main
struct FocusGuardApp: App {
    @StateObject private var session = SessionManager()
    @State private var menuBarManager: MenuBarManager?

    var body: some Scene {
        WindowGroup {
            ContentView(session: session)
                .task {
                    if menuBarManager == nil {
                        menuBarManager = MenuBarManager(session: session)
                    }
                }
        }
        .windowResizability(.contentSize)
    }
}
