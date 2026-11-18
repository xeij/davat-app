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
            Form {
                Section("you") {
                    TextField("display name", text: $name)
                    TextField("venmo handle", text: $venmo).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("$cashtag", text: $cashtag).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                if let error { Text(error).foregroundStyle(.red) }
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

    private func strip(_ s: String, _ c: Character) -> String {
        s.trimmingCharacters(in: .whitespaces).drop { $0 == c }.description
    }

    private func save() {
        guard let id = session.userID else { return }
        Task {
            do { try await session.saveProfile(Profile(id: id, displayName: name, venmo: strip(venmo, "@"), cashtag: strip(cashtag, "$"))); dismiss() }
            catch { self.error = error.localizedDescription }
        }
    }
}
