import Foundation
import Testing
@testable import DavatKit

@Suite struct PublishTests {
    @Test func posterPathIsHostSlashInvite() {
        let host = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
        let invite = UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002")!
        #expect(PublishPaths.poster(hostID: host, inviteID: invite)
                == "aaaaaaaa-0000-0000-0000-000000000001/bbbbbbbb-0000-0000-0000-000000000002.png")
    }

    @Test func guestGroupsOrderAndSort() {
        let id = UUID()
        func r(_ n: String, _ s: RSVP) -> Response {
            Response(id: UUID(), inviteID: id, name: n, userID: nil, guestToken: nil, rsvp: s, paid: false)
        }
        let groups = GuestGroups.of([r("zed", .cant), r("bo", .going), r("Al", .going), r("mo", .cant)])
        #expect(groups.map(\.rsvp) == [.going, .cant])
        #expect(groups[0].guests.map(\.name) == ["Al", "bo"])
        #expect(groups[1].guests.map(\.name) == ["mo", "zed"])
    }
}

@Test func guestCannotUnmarkPaid() async throws {
    let b = LocalBackend(directory: URL.temporaryDirectory.appending(path: UUID().uuidString))
    let invite = UUID()
    var r = Response(id: UUID(), inviteID: invite, name: "sara", userID: nil, guestToken: "tok-0123456789abcdef", rsvp: .going, paid: true)
    try await b.respond(r)
    r.paid = false
    try await b.respond(r)
    #expect(try await b.responses(inviteID: invite).first?.paid == true)
}
