import Foundation
import Supabase

/// Talks to supabase/migrations/0001_init.sql. Untested until a project exists; rows map to snake_case here only.
public final class SupabaseBackend: Backend, @unchecked Sendable {
    private let client: SupabaseClient

    public init(url: URL, anonKey: String) {
        client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey, options: .init(auth: .init(storage: SharedStorage())))
    }

    /// Keeps the session in the shared keychain group so the iMessage extension shares the app's login.
    /// Info.plist carries `AppIdentifierPrefix`; unsigned builds have none, or the keychain refuses the
    /// group, and then the app's own keychain is used instead.
    private struct SharedStorage: AuthLocalStorage {
        let shared: KeychainLocalStorage? = {
            guard let prefix = Bundle.main.infoDictionary?["AppIdentifierPrefix"] as? String,
                  !prefix.isEmpty, !prefix.hasPrefix("$(") else { return nil }
            return KeychainLocalStorage(accessGroup: prefix + "com.davat.shared")
        }()
        let local = KeychainLocalStorage()

        func store(key: String, value: Data) throws {
            if let shared, (try? shared.store(key: key, value: value)) != nil { return }
            try local.store(key: key, value: value)
        }
        func retrieve(key: String) throws -> Data? {
            if let d = try? shared?.retrieve(key: key) { return d }
            return try local.retrieve(key: key)
        }
        func remove(key: String) throws {   // deleting a missing item throws, so both are best effort
            try? shared?.remove(key: key)
            try? local.remove(key: key)
        }
    }

    private struct ProfileRow: Codable {
        var id: UUID, displayName: String, venmo: String, cashtag: String
        enum CodingKeys: String, CodingKey { case id, venmo, cashtag; case displayName = "display_name" }
    }
    private struct InviteRow: Codable {
        var id: UUID, hostID: UUID, title: String, startsAt: Date?, location: String, details: String
        var design: Design, posterPath: String?, priceCents: Int?, hostPays: Bool, updatedAt: Date
        enum CodingKeys: String, CodingKey {
            case id, title, location, details, design
            case hostID = "host_id", startsAt = "starts_at", posterPath = "poster_path"
            case priceCents = "price_cents", hostPays = "host_pays", updatedAt = "updated_at"
        }
        init(_ i: Invite) {
            id = i.id; hostID = i.hostID; title = i.title; startsAt = i.startsAt; location = i.location
            details = i.details; design = i.design; posterPath = i.posterPath
            priceCents = i.fundraiser?.priceCents; hostPays = i.fundraiser?.hostPays ?? false; updatedAt = i.updatedAt
        }
        var invite: Invite {
            Invite(id: id, hostID: hostID, title: title, startsAt: startsAt, location: location, details: details,
                   design: design, posterPath: posterPath,
                   fundraiser: priceCents.map { Fundraiser(priceCents: $0, hostPays: hostPays) }, updatedAt: updatedAt)
        }
    }
    private struct ResponseRow: Codable {
        var id: UUID, inviteID: UUID, name: String, userID: UUID?, guestToken: String?, rsvp: RSVP, paid: Bool
        enum CodingKeys: String, CodingKey {
            case id, name, rsvp, paid
            case inviteID = "invite_id", userID = "user_id", guestToken = "guest_token"
        }
        var response: Response {
            Response(id: id, inviteID: inviteID, name: name, userID: userID, guestToken: guestToken, rsvp: rsvp, paid: paid)
        }
    }
    private struct MessageRow: Codable {
        var id: UUID, inviteID: UUID, name: String, userID: UUID?, guestToken: String?, body: String, createdAt: Date
        enum CodingKeys: String, CodingKey {
            case id, name, body
            case inviteID = "invite_id", userID = "user_id", guestToken = "guest_token", createdAt = "created_at"
        }
        var message: ChatMessage {
            ChatMessage(id: id, inviteID: inviteID, name: name, userID: userID, body: body, createdAt: createdAt)
        }
    }

    public func currentUserID() async -> UUID? { try? await client.auth.session.user.id }

    public func signInWithApple(idToken: String, nonce: String) async throws -> UUID {
        try await client.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)).user.id
    }
    public func signIn(email: String, password: String) async throws -> UUID {
        try await client.auth.signIn(email: email, password: password).user.id
    }
    public func signUp(email: String, password: String) async throws -> UUID {
        try await client.auth.signUp(email: email, password: password).user.id
    }
    public func signOut() async throws { try await client.auth.signOut() }
    public func deleteAccount() async throws {
        try await client.rpc("delete_me").execute()
        try? await client.auth.signOut()
    }

    public func profile() async throws -> Profile? {
        let id = try await client.auth.session.user.id
        let rows: [ProfileRow] = try await client.from("profiles").select().eq("id", value: id).execute().value
        return rows.first.map { Profile(id: $0.id, displayName: $0.displayName, venmo: $0.venmo, cashtag: $0.cashtag) }
    }
    public func saveProfile(_ p: Profile) async throws {
        try await client.from("profiles")
            .upsert(ProfileRow(id: p.id, displayName: p.displayName, venmo: p.venmo, cashtag: p.cashtag)).execute()
    }

    public func myInvites() async throws -> [Invite] {
        let id = try await client.auth.session.user.id
        let rows: [InviteRow] = try await client.from("invites").select().eq("host_id", value: id)
            .order("updated_at", ascending: false).execute().value
        return rows.map(\.invite)
    }
    public func saveInvite(_ i: Invite) async throws { try await client.from("invites").upsert(InviteRow(i)).execute() }
    public func deleteInvite(id: UUID) async throws { try await client.from("invites").delete().eq("id", value: id).execute() }

    public func uploadImage(_ png: Data, path: String) async throws -> String {
        try await client.storage.from("posters").upload(path, data: png, options: FileOptions(contentType: "image/png", upsert: true)).path
    }
    public func imageURL(path: String) -> URL? { try? client.storage.from("posters").getPublicURL(path: path) }

    private struct InviteArg: Encodable {
        var inviteID: UUID
        enum CodingKeys: String, CodingKey { case inviteID = "invite_id" }
    }
    private struct SummaryRow: Decodable {
        var guests: [PublicSummary.Guest], goingCount: Int, goalCents: Int?, raisedCents: Int?
        var hostVenmo: String?, hostCashtag: String?
        enum CodingKeys: String, CodingKey {
            case guests, goingCount = "going_count", goalCents = "goal_cents", raisedCents = "raised_cents"
            case hostVenmo = "host_venmo", hostCashtag = "host_cashtag"
        }
    }

    public func invite(id: UUID) async throws -> Invite? {
        let rows: [InviteRow] = try await client.rpc("get_invite", params: InviteArg(inviteID: id)).execute().value
        return rows.first?.invite
    }
    public func summary(inviteID: UUID) async throws -> PublicSummary {
        let rows: [SummaryRow] = try await client.rpc("invite_public_summary", params: InviteArg(inviteID: inviteID)).execute().value
        guard let r = rows.first else { throw BackendError("invite not found") }
        return PublicSummary(guests: r.guests, goingCount: r.goingCount, goalCents: r.goalCents ?? 0,
                             raisedCents: r.raisedCents ?? 0, hostVenmo: r.hostVenmo ?? "", hostCashtag: r.hostCashtag ?? "")
    }

    public func responses(inviteID: UUID) async throws -> [Response] {
        // guest_token is not readable, so list the columns instead of *
        let rows: [ResponseRow] = try await client.from("responses").select("id,invite_id,name,user_id,rsvp,paid").eq("invite_id", value: inviteID).execute().value
        return rows.map(\.response)
    }
    private struct RespondParams: Encodable {
        var inviteID: UUID, guestToken: String?, name: String, rsvp: RSVP, paid: Bool?
        enum CodingKeys: String, CodingKey { case name, rsvp, paid; case inviteID = "invite_id", guestToken = "guest_token" }
        // guest_token has no SQL default, so send an explicit null for signed-in users
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(inviteID, forKey: .inviteID); try c.encode(guestToken, forKey: .guestToken)
            try c.encode(name, forKey: .name); try c.encode(rsvp, forKey: .rsvp); try c.encodeIfPresent(paid, forKey: .paid)
        }
    }
    /// Goes through the respond() function, which upserts on user or guest token. The server keeps the row id.
    public func respond(_ r: Response) async throws {
        try await client.rpc("respond", params: RespondParams(
            inviteID: r.inviteID, guestToken: r.userID == nil ? r.guestToken : nil,
            name: r.name, rsvp: r.rsvp, paid: r.paid ? true : nil)).execute()
    }
    public func setPaid(responseID: UUID, paid: Bool) async throws {
        try await client.from("responses").update(["paid": paid]).eq("id", value: responseID).execute()
    }

    public func messages(inviteID: UUID) async throws -> [ChatMessage] {
        let rows: [MessageRow] = try await client.rpc("invite_messages", params: InviteArg(inviteID: inviteID)).execute().value
        return rows.map(\.message)
    }
    private struct PostArgs: Encodable {
        var inviteID: UUID, name: String, body: String
        enum CodingKeys: String, CodingKey { case name, body; case inviteID = "invite_id", guestToken = "guest_token" }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(inviteID, forKey: .inviteID); try c.encode(name, forKey: .name)
            try c.encodeNil(forKey: .guestToken); try c.encode(body, forKey: .body)
        }
    }
    /// post_message sets user_id from the session. ChatMessage carries no guest token, so guests post without one.
    public func send(_ m: ChatMessage) async throws {
        try await client.rpc("post_message", params: PostArgs(inviteID: m.inviteID, name: m.name, body: m.body)).execute()
    }

    public func changes(inviteID: UUID) -> AsyncStream<Void> {
        let client = client
        let channel = client.channel("invite-\(inviteID.uuidString)")
        let filter = RealtimePostgresFilter.eq("invite_id", value: inviteID.uuidString)
        let r = channel.postgresChange(AnyAction.self, schema: "public", table: "responses", filter: filter)
        let m = channel.postgresChange(AnyAction.self, schema: "public", table: "messages", filter: filter)
        return AsyncStream { cont in
            let task = Task {
                // Realtime only reaches the host (RLS). Everyone also gets a 4 second tick so guests see updates.
                try? await channel.subscribeWithError()
                await withTaskGroup(of: Void.self) { g in
                    g.addTask {
                        while !Task.isCancelled {
                            try? await Task.sleep(for: .seconds(4))
                            if !Task.isCancelled { cont.yield() }
                        }
                    }
                    g.addTask { for await _ in r { cont.yield() } }
                    g.addTask { for await _ in m { cont.yield() } }
                }
                cont.finish()
            }
            cont.onTermination = { _ in
                task.cancel()
                Task { await client.removeChannel(channel) }
            }
        }
    }
}
