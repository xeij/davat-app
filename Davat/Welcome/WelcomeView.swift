import SwiftUI

struct WelcomeView: View {
    let start: (AuthView.Mode) -> Void
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate * 0.25
                MeshGradient(width: 3, height: 3, points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [Float(0.5 + 0.15 * sin(t)), Float(0.5 + 0.15 * cos(t * 1.3))], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1],
                ], colors: [
                    .saffron, .rose, .ink,
                    .rose, .saffron, .rose,
                    .ink, .rose, .saffron,
                ])
            }
            .ignoresSafeArea()

            VStack(spacing: 12) {
                Spacer()
                Text("davat")
                    .font(.system(size: 72, weight: .thin))
                    .reveal(shown, reduceMotion, delay: 0)
                Text("make the invite. send it. see who's in.")
                    .font(.system(size: 22, weight: .light))
                    .multilineTextAlignment(.center)
                    .reveal(shown, reduceMotion, delay: 0.1)
                Spacer()
                VStack(spacing: 12) {
                    Button { start(.signUp) } label: { Text("Get started").frame(maxWidth: .infinity) }
                        .buttonStyle(.glassProminent)
                        .tint(.saffron)
                    Button { start(.signIn) } label: { Text("I have an account").frame(maxWidth: .infinity) }
                        .buttonStyle(.glass)
                }
                .controlSize(.large)
                .reveal(shown, reduceMotion, delay: 0.2)
            }
            .foregroundStyle(.white)
            .padding(24)
        }
        .onAppear { shown = true }
    }
}

private extension Color {
    static let saffron = Color(red: 0.851, green: 0.573, blue: 0.180)
    static let rose = Color(red: 0.62, green: 0.22, blue: 0.30)
    static let ink = Color(red: 0.09, green: 0.07, blue: 0.14)
}

private extension View {
    func reveal(_ shown: Bool, _ reduceMotion: Bool, delay: Double) -> some View {
        opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 24)
            .animation(reduceMotion ? .easeIn(duration: 0.3) : .spring(duration: 0.4, bounce: 0.2).delay(delay), value: shown)
    }
}

#Preview { WelcomeView(start: { _ in }) }
