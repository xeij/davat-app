import Foundation

public enum PublishPaths {
    /// One poster per invite, so re-publishing replaces the PNG behind the same link.
    public static func poster(hostID: UUID, inviteID: UUID) -> String {
        "\(hostID.uuidString.lowercased())/\(inviteID.uuidString.lowercased()).png"
    }
}

public enum GuestGroups {
    /// Going, maybe, can't, in that order, names sorted within each. Empty groups are left out.
    public static func of(_ responses: [Response]) -> [(rsvp: RSVP, guests: [Response])] {
        RSVP.allCases.compactMap { rsvp in
            let g = responses.filter { $0.rsvp == rsvp }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return g.isEmpty ? nil : (rsvp, g)
        }
    }
}
