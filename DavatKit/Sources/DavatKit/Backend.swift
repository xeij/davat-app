import Foundation

public protocol Backend: Sendable {
    func currentUserID() async -> UUID?
    func signInWithApple(idToken: String, nonce: String) async throws -> UUID
    func signIn(email: String, password: String) async throws -> UUID
    func signUp(email: String, password: String) async throws -> UUID
    func signOut() async throws
    func deleteAccount() async throws
    func profile() async throws -> Profile?
    func saveProfile(_ p: Profile) async throws
    func myInvites() async throws -> [Invite]
    func saveInvite(_ i: Invite) async throws
    func deleteInvite(id: UUID) async throws
    func uploadImage(_ png: Data, path: String) async throws -> String   // returns storage path
    func imageURL(path: String) -> URL?
    func invite(id: UUID) async throws -> Invite?            // any invite by id, for guests
    func summary(inviteID: UUID) async throws -> PublicSummary // guest-safe: no per-person paid
    func responses(inviteID: UUID) async throws -> [Response]
    func respond(_ r: Response) async throws        // upsert
    func setPaid(responseID: UUID, paid: Bool) async throws
    func messages(inviteID: UUID) async throws -> [ChatMessage]
    func send(_ m: ChatMessage) async throws
    func changes(inviteID: UUID) -> AsyncStream<Void>   // fires when responses or messages change
}

public enum Backends {
    public static func make() -> any Backend {
        let info = Bundle.main.infoDictionary
        if let s = info?["SupabaseURL"] as? String, let url = URL(string: s), !s.isEmpty,
           let key = info?["SupabaseAnonKey"] as? String, !key.isEmpty {
            return SupabaseBackend(url: url, anonKey: key)
        }
        return LocalBackend()
    }
}

public struct BackendError: LocalizedError, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

/// JSON files on disk, one per collection. Single local user; every write wakes `changes`.
public final class LocalBackend: Backend, @unchecked Sendable {
    static let localUser = UUID(uuidString: "00000000-0000-0000-0000-00000000DA7A")!
    private let dir: URL
    private let lock = NSLock()
    private var watchers: [(token: UUID, invite: UUID, cont: AsyncStream<Void>.Continuation)] = []
    private let encoder: JSONEncoder = { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }()
    private let decoder: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()

    public init(directory: URL? = nil) {
        let base = directory
            ?? FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.davat.app")
            ?? URL.applicationSupportDirectory
        dir = base.appending(path: "local", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func load<T: Decodable>(_ name: String, _ type: T.Type) -> T? {
        (try? Data(contentsOf: dir.appending(path: name + ".json"))).flatMap { try? decoder.decode(T.self, from: $0) }
    }
    private func store<T: Encodable>(_ name: String, _ value: T) throws {
        try encoder.encode(value).write(to: dir.appending(path: name + ".json"), options: .atomic)
    }
    private func notify(_ invite: UUID) {
        for w in watchers where w.invite == invite { w.cont.yield() }
    }

    public func currentUserID() async -> UUID? {
        lock.withLock { load("session", UUID.self) }
    }
    private func login() throws -> UUID {
        try lock.withLock { try store("session", Self.localUser) }
        return Self.localUser
    }
    public func signInWithApple(idToken: String, nonce: String) async throws -> UUID { try login() }
    public func signIn(email: String, password: String) async throws -> UUID {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else { throw BackendError("enter your email") }
        guard password.count >= 6 else { throw BackendError("password needs 6 or more characters") }
        return try login()
    }
    public func signUp(email: String, password: String) async throws -> UUID {
        try await signIn(email: email, password: password)
    }
    public func signOut() async throws {
        lock.withLock { try? FileManager.default.removeItem(at: dir.appending(path: "session.json")) }
    }
    public func deleteAccount() async throws {
        lock.withLock {
            for f in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] {
                try? FileManager.default.removeItem(at: f)
            }
        }
    }

    public func profile() async throws -> Profile? { lock.withLock { load("profile", Profile.self) } }
    public func saveProfile(_ p: Profile) async throws { try lock.withLock { try store("profile", p) } }

    public func myInvites() async throws -> [Invite] {
        lock.withLock { (load("invites", [Invite].self) ?? []).sorted { $0.updatedAt > $1.updatedAt } }
    }
    public func saveInvite(_ i: Invite) async throws {
        try lock.withLock {
            var all = load("invites", [Invite].self) ?? []
            if let n = all.firstIndex(where: { $0.id == i.id }) { all[n] = i } else { all.append(i) }
            try store("invites", all)
        }
    }
    public func deleteInvite(id: UUID) async throws {
        try lock.withLock {
            try store("invites", (load("invites", [Invite].self) ?? []).filter { $0.id != id })
        }
    }

    public func uploadImage(_ png: Data, path: String) async throws -> String {
        try lock.withLock {
            let url = dir.appending(path: "images/" + path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try png.write(to: url, options: .atomic)
        }
        return path
    }
    public func imageURL(path: String) -> URL? { dir.appending(path: "images/" + path) }

    public func invite(id: UUID) async throws -> Invite? {
        lock.withLock { (load("invites", [Invite].self) ?? []).first { $0.id == id } }
    }
    public func summary(inviteID: UUID) async throws -> PublicSummary {
        lock.withLock {
            let rs = (load("responses", [Response].self) ?? []).filter { $0.inviteID == inviteID }
            let f = (load("invites", [Invite].self) ?? []).first { $0.id == inviteID }?.fundraiser
            let s = f.map { summarize($0, responses: rs) }
            let p = load("profile", Profile.self)
            return PublicSummary(
                guests: rs.sorted { $0.name < $1.name }.map { .init(name: $0.name, rsvp: $0.rsvp) },
                goingCount: rs.filter { $0.rsvp == .going }.count,
                goalCents: s?.goalCents ?? 0, raisedCents: s?.raisedCents ?? 0,
                hostVenmo: p?.venmo ?? "", hostCashtag: p?.cashtag ?? "")
        }
    }
    public func responses(inviteID: UUID) async throws -> [Response] {
        lock.withLock { (load("responses", [Response].self) ?? []).filter { $0.inviteID == inviteID } }
    }
    public func respond(_ r: Response) async throws {
        try lock.withLock {
            var all = load("responses", [Response].self) ?? []
            let n = all.firstIndex { old in
                old.id == r.id || (old.inviteID == r.inviteID && r.guestToken != nil && old.guestToken == r.guestToken)
                    || (old.inviteID == r.inviteID && r.userID != nil && old.userID == r.userID)
            }
            if let n { var new = r; new.id = all[n].id; all[n] = new } else { all.append(r) }
            try store("responses", all)
            notify(r.inviteID)
        }
    }
    public func setPaid(responseID: UUID, paid: Bool) async throws {
        try lock.withLock {
            var all = load("responses", [Response].self) ?? []
            guard let n = all.firstIndex(where: { $0.id == responseID }) else { return }
            all[n].paid = paid
            try store("responses", all)
            notify(all[n].inviteID)
        }
    }

    public func messages(inviteID: UUID) async throws -> [ChatMessage] {
        lock.withLock { (load("messages", [ChatMessage].self) ?? []).filter { $0.inviteID == inviteID }.sorted { $0.createdAt < $1.createdAt } }
    }
    public func send(_ m: ChatMessage) async throws {
        try lock.withLock {
            try store("messages", (load("messages", [ChatMessage].self) ?? []) + [m])
            notify(m.inviteID)
        }
    }

    public func changes(inviteID: UUID) -> AsyncStream<Void> {
        let (stream, cont) = AsyncStream<Void>.makeStream()
        let token = UUID()
        lock.withLock { watchers.append((token, inviteID, cont)) }
        cont.onTermination = { [weak self] _ in
            guard let self else { return }
            lock.withLock { watchers.removeAll { $0.token == token } }
        }
        return stream
    }
}
