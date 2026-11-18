import SwiftUI

@main
struct DavatApp: App {
    @State private var session = Session()
    @State private var authMode: AuthView.Mode?

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !session.loaded {
                    Color.clear
                } else if session.userID != nil {
                    HomeView().transition(.move(edge: .trailing))
                } else if let mode = authMode {
                    AuthView(mode: mode, back: { authMode = nil }).transition(.move(edge: .trailing))
                } else {
                    WelcomeView(start: { authMode = $0 }).transition(.opacity)
                }
            }
            .animation(.spring(duration: 0.4, bounce: 0.2), value: authMode)
            .animation(.spring(duration: 0.4, bounce: 0.2), value: session.userID)
            .environment(session)
            .task { await session.restore() }
        }
    }
}
