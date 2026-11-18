import DavatKit
import Observation
import SwiftUI

@MainActor @Observable final class Session {
    var userID: UUID?
    var profile: Profile?
    var loaded = false
    let backend: any Backend

    init(backend: any Backend = Backends.make()) { self.backend = backend }

    func restore() async {
        userID = await backend.currentUserID()
        if userID != nil { profile = try? await backend.profile() }
        loaded = true
    }

    func finish(_ id: UUID) async {
        profile = try? await backend.profile()
        withAnimation(.spring(duration: 0.4, bounce: 0.2)) { userID = id }
    }

    func saveProfile(_ p: Profile) async throws {
        try await backend.saveProfile(p)
        profile = p
    }

    func signOut() async {
        try? await backend.signOut()
        withAnimation(.spring(duration: 0.4, bounce: 0.2)) { userID = nil; profile = nil }
    }

    func deleteAccount() async throws {
        try await backend.deleteAccount()
        withAnimation(.spring(duration: 0.4, bounce: 0.2)) { userID = nil; profile = nil }
    }
}
