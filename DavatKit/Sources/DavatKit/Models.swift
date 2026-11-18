import Foundation

public struct Invite: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var hostID: UUID
    public var title: String
    public var startsAt: Date?
    public var location: String
    public var details: String
    public var design: Design
    public var posterPath: String?
    public var fundraiser: Fundraiser?
    public var updatedAt: Date

    public init(id: UUID, hostID: UUID, title: String, startsAt: Date? = nil, location: String = "", details: String = "",
                design: Design, posterPath: String? = nil, fundraiser: Fundraiser? = nil, updatedAt: Date) {
        self.id = id; self.hostID = hostID; self.title = title; self.startsAt = startsAt
        self.location = location; self.details = details; self.design = design
        self.posterPath = posterPath; self.fundraiser = fundraiser; self.updatedAt = updatedAt
    }
}

public struct Fundraiser: Codable, Hashable, Sendable {
    public var priceCents: Int
    public var hostPays: Bool

    public init(priceCents: Int, hostPays: Bool) {
        self.priceCents = priceCents; self.hostPays = hostPays
    }
}

public enum RSVP: String, Codable, CaseIterable, Sendable { case going, maybe, cant }

public struct Response: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var inviteID: UUID
    public var name: String
    public var userID: UUID?
    public var guestToken: String?
    public var rsvp: RSVP
    public var paid: Bool

    public init(id: UUID, inviteID: UUID, name: String, userID: UUID?, guestToken: String?, rsvp: RSVP, paid: Bool) {
        self.id = id; self.inviteID = inviteID; self.name = name; self.userID = userID
        self.guestToken = guestToken; self.rsvp = rsvp; self.paid = paid
    }
}

public struct ChatMessage: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var inviteID: UUID
    public var name: String
    public var userID: UUID?
    public var body: String
    public var createdAt: Date

    public init(id: UUID, inviteID: UUID, name: String, userID: UUID?, body: String, createdAt: Date) {
        self.id = id; self.inviteID = inviteID; self.name = name; self.userID = userID
        self.body = body; self.createdAt = createdAt
    }
}

public struct Profile: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var displayName: String
    public var venmo: String
    public var cashtag: String

    public init(id: UUID, displayName: String, venmo: String, cashtag: String) {
        self.id = id; self.displayName = displayName; self.venmo = venmo; self.cashtag = cashtag
    }
}
