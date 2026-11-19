import DavatKit
import SwiftUI

struct ProfileView: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var venmo = ""
    @State private var cashtag = ""
    @State private var confirmDelete = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("profile").font(.system(size: 40, weight: .thin)).padding(.horizontal, 24).padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)
            Form {
                Section("you") {
                    TextField("display name", text: $name)
                    TextField("venmo handle", text: $venmo).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("$cashtag", text: $cashtag).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                if let error { Text(error).foregroundStyle(.red) }
                Section {
                    Link("privacy", destination: DavatConfig.webBaseURL.appending(path: "privacy.html"))
                }
                Section {
                    Button("Sign out") { Task { do { try await session.signOut() } catch { self.error = error.localizedDescription } } }
                    Button("Delete account", role: .destructive) { confirmDelete = true }
                }
            }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .confirmationDialog("Delete your account and all your invites?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete account", role: .destructive) {
                    Task { do { try await session.deleteAccount() } catch { self.error = error.localizedDescription } }
                }
            }
            .onAppear {
                name = session.profile?.displayName ?? ""
                venmo = session.profile?.venmo ?? ""
                cashtag = session.profile?.cashtag ?? ""
            }
        }
    }

    private func save() {
        guard let id = session.userID else { return }
        // names go out with RSVPs and chat, which hold 60 characters (Postgres counts unicode scalars)
        let n = name.trimmingCharacters(in: .whitespaces)
        let p = Profile(id: id, displayName: String(String.UnicodeScalarView(n.unicodeScalars.prefix(60))),
                        venmo: PaymentLinks.clean(venmo), cashtag: PaymentLinks.clean(cashtag))
        Task {
            do { try await session.saveProfile(p); dismiss() }
            catch { self.error = error.localizedDescription }
        }
    }
}
