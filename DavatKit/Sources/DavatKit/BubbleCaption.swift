import Foundation

public enum BubbleCaption {
    /// The caption on an updated bubble: "sam's in · 3 going · $60 of $80".
    public static func make(name: String, rsvp: RSVP, summary: PublicSummary, fundraiser: Fundraiser?) -> String {
        let who = switch rsvp {
        case .going: "\(name)'s in"
        case .maybe: "\(name)'s a maybe"
        case .cant: "\(name) can't make it"
        }
        var parts = [who, "\(summary.goingCount) going"]
        if fundraiser != nil { parts.append("\(formatCents(summary.raisedCents)) of \(formatCents(summary.goalCents))") }
        return parts.joined(separator: " · ")
    }
}

extension DavatConfig {
    /// The invite id in a link made by `link(for:)`, ignoring any query such as `?v=`.
    public static func inviteID(from url: URL) -> UUID? {
        let parts = url.pathComponents
        guard parts.count >= 2, parts[parts.count - 2] == "i" else { return nil }
        return UUID(uuidString: parts[parts.count - 1])
    }
}
