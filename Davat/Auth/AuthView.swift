import AuthenticationServices
import CryptoKit
import SwiftUI

struct AuthView: View {
    enum Mode { case signUp, signIn }

    @State var mode: Mode
    let back: () -> Void
    @Environment(Session.self) private var session
    @Environment(\.colorScheme) private var scheme
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var busy = false
    @State private var nonce = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Button("Back", systemImage: "chevron.left", action: back).buttonStyle(.glass)
                Text("who's hosting?").font(.system(size: 40, weight: .thin)).padding(.top, 24)
                    .accessibilityAddTraits(.isHeader)

                SignInWithAppleButton(mode == .signUp ? .signUp : .signIn) { req in
                    nonce = Self.randomNonce()
                    req.requestedScopes = [.fullName, .email]
                    req.nonce = Self.sha256(nonce)
                } onCompletion: { result in
                    switch result {
                    case .success(let auth):
                        guard let data = (auth.credential as? ASAuthorizationAppleIDCredential)?.identityToken,
                              let token = String(data: data, encoding: .utf8) else { return error = "apple didn't send a token. try again." }
                        run { try await session.backend.signInWithApple(idToken: token, nonce: nonce) }
                    case .failure(let e):
                        if (e as? ASAuthorizationError)?.code != .canceled { error = "couldn't sign in with apple. use email instead." }
                    }
                }
                .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
                .disabled(busy)
                .frame(height: 54)
                .clipShape(.capsule)

                VStack(spacing: 12) {
                    TextField("email", text: $email)
                        .textContentType(.emailAddress).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(16).glassEffect(.regular, in: .capsule)
                    SecureField("password", text: $password)
                        .textContentType(mode == .signUp ? .newPassword : .password)
                        .padding(16).glassEffect(.regular, in: .capsule)
                }

                if let error { Text(error).font(.callout).foregroundStyle(.red) }

                Button {
                    run { mode == .signUp
                        ? try await session.backend.signUp(email: email, password: password)
                        : try await session.backend.signIn(email: email, password: password) }
                } label: {
                    Text(mode == .signUp ? "Create account" : "Sign in").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent).controlSize(.large).disabled(busy)

                Button(mode == .signUp ? "I have an account" : "New here? Create one") {
                    withAnimation(.spring(duration: 0.4, bounce: 0.2)) { mode = mode == .signUp ? .signIn : .signUp }
                    error = nil
                }
                .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .background { WarmTint() }
    }

    private func run(_ op: @escaping () async throws -> UUID) {
        busy = true; error = nil
        Task {
            defer { busy = false }
            do { await session.finish(try await op()) }
            catch { self.error = error.localizedDescription }
        }
    }

    private static func randomNonce() -> String {
        (0..<32).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
    }
    private static func sha256(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
