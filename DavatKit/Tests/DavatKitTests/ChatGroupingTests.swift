import Foundation
import Testing
@testable import DavatKit

@Suite struct ChatGroupingTests {
    func msg(_ t: TimeInterval) -> ChatMessage {
        ChatMessage(id: UUID(), inviteID: UUID(), name: "a", userID: nil, body: "x", createdAt: Date(timeIntervalSince1970: t))
    }
    @Test func empty() { #expect(ChatGrouping.timestamps(for: [], gap: 900).isEmpty) }
    @Test func firstAndGaps() {
        let a = msg(0), b = msg(60), c = msg(60 + 901), d = msg(60 + 901 + 900)
        #expect(ChatGrouping.timestamps(for: [d, c, b, a], gap: 900) == [a.id, c.id])
    }
}
