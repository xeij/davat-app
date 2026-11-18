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
            Form {
                Section("you") {
                    TextField("display name", text: $name)
                    TextField("venmo handle", text: $venmo).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("$cashtag", text: $cashtag).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                if let error { Text(error).foregroundStyle(.red) }
                Section {
                    Button("Sign out") { Task { await session.signOut() } }
                    Button("Delete account", role: .destructive) { confirmDelete = true }
                }
            }
            .navigationTitle("profile")
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
        Task {
            do { try await session.saveProfile(Profile(id: id, displayName: name, venmo: venmo, cashtag: cashtag)); dismiss() }
            catch { self.error = error.localizedDescription }
        }
    }
}
