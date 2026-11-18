import Foundation
import Supabase

/// Talks to the Task 3 schema. Untested until the project exists; rows map to snake_case here only.
public final class SupabaseBackend: Backend, @unchecked Sendable {
    private let client: SupabaseClient

    public init(url: URL, anonKey: String) {
        client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
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
        init(_ r: Response) {
            id = r.id; inviteID = r.inviteID; name = r.name; userID = r.userID
            guestToken = r.guestToken; rsvp = r.rsvp; paid = r.paid
        }
        // id is left out so an upsert conflict keeps the existing row's primary key (DB defaults it on insert)
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(inviteID, forKey: .inviteID); try c.encode(name, forKey: .name)
            try c.encode(userID, forKey: .userID); try c.encode(guestToken, forKey: .guestToken)
            try c.encode(rsvp, forKey: .rsvp); try c.encode(paid, forKey: .paid)
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
        init(_ m: ChatMessage) {
            id = m.id; inviteID = m.inviteID; name = m.name; userID = m.userID
            guestToken = nil; body = m.body; createdAt = m.createdAt
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

    public func responses(inviteID: UUID) async throws -> [Response] {
        let rows: [ResponseRow] = try await client.from("responses").select().eq("invite_id", value: inviteID).execute().value
        return rows.map(\.response)
    }
    public func respond(_ r: Response) async throws {
        // ponytail: assumes unique (invite_id, guest_token) and (invite_id, user_id) constraints from Task 3
        try await client.from("responses")
            .upsert(ResponseRow(r), onConflict: r.userID != nil ? "invite_id,user_id" : "invite_id,guest_token").execute()
    }
    public func setPaid(responseID: UUID, paid: Bool) async throws {
        try await client.from("responses").update(["paid": paid]).eq("id", value: responseID).execute()
    }

    public func messages(inviteID: UUID) async throws -> [ChatMessage] {
        let rows: [MessageRow] = try await client.from("messages").select().eq("invite_id", value: inviteID)
            .order("created_at", ascending: true).execute().value
        return rows.map(\.message)
    }
    public func send(_ m: ChatMessage) async throws { try await client.from("messages").insert(MessageRow(m)).execute() }

    public func changes(inviteID: UUID) -> AsyncStream<Void> {
        let client = client
        let channel = client.channel("invite-\(inviteID.uuidString)")
        let filter = RealtimePostgresFilter.eq("invite_id", value: inviteID.uuidString)
        let r = channel.postgresChange(AnyAction.self, schema: "public", table: "responses", filter: filter)
        let m = channel.postgresChange(AnyAction.self, schema: "public", table: "messages", filter: filter)
        return AsyncStream { cont in
            let task = Task {
                do { try await channel.subscribeWithError() } catch { cont.finish(); return }
                await withTaskGroup(of: Void.self) { g in
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
