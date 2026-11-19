import Foundation

public enum ChatGrouping {
    /// Ids of messages that get a time header above them: the first one, and any more than `gap` seconds after the previous.
    public static func timestamps(for messages: [ChatMessage], gap: TimeInterval) -> Set<UUID> {
        let sorted = messages.sorted { $0.createdAt < $1.createdAt }
        var ids = Set<UUID>()
        var prev: Date?
        for m in sorted {
            if prev == nil || m.createdAt.timeIntervalSince(prev!) > gap { ids.insert(m.id) }
            prev = m.createdAt
        }
        return ids
    }
}
