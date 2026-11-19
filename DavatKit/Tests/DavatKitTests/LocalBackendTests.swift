import Foundation
import Testing
@testable import DavatKit

struct LocalBackendTests {
    func make() -> LocalBackend {
        LocalBackend(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
    }
    func invite(_ host: UUID = UUID()) -> Invite {
        Invite(id: UUID(), hostID: host, title: "bbq", design: Design(background: .color(RGBA(r: 1, g: 1, b: 1))), updatedAt: Date())
    }

    @Test func saveAndListInvite() async throws {
        let b = make()
        let i = invite()
        try await b.saveInvite(i)
        #expect(try await b.myInvites().map(\.id) == [i.id])
        var edited = i; edited.title = "party"
        try await b.saveInvite(edited)
        #expect(try await b.myInvites().map(\.title) == ["party"])
        try await b.deleteInvite(id: i.id)
        #expect(try await b.myInvites().isEmpty)
    }

    @Test func respondUpsertsByGuestToken() async throws {
        let b = make()
        let inv = UUID()
        try await b.respond(Response(id: UUID(), inviteID: inv, name: "sam", userID: nil, guestToken: "t", rsvp: .maybe, paid: false))
        try await b.respond(Response(id: UUID(), inviteID: inv, name: "sam", userID: nil, guestToken: "t", rsvp: .going, paid: false))
        let rs = try await b.responses(inviteID: inv)
        #expect(rs.count == 1)
        #expect(rs[0].rsvp == .going)
    }

    @Test func setPaid() async throws {
        let b = make()
        let r = Response(id: UUID(), inviteID: UUID(), name: "a", userID: nil, guestToken: "x", rsvp: .going, paid: false)
        try await b.respond(r)
        try await b.setPaid(responseID: r.id, paid: true)
        #expect(try await b.responses(inviteID: r.inviteID)[0].paid)
    }

    @Test func messagesOrderedByDate() async throws {
        let b = make()
        let inv = UUID()
        for (body, t) in [("second", 20.0), ("first", 10.0)] {
            try await b.send(ChatMessage(id: UUID(), inviteID: inv, name: "a", userID: nil, body: body, createdAt: Date(timeIntervalSince1970: t)))
        }
        #expect(try await b.messages(inviteID: inv).map(\.body) == ["first", "second"])
    }

    @Test func changesFiresOnRespond() async throws {
        let b = make()
        let inv = UUID()
        var it = b.changes(inviteID: inv).makeAsyncIterator()
        try await b.respond(Response(id: UUID(), inviteID: inv, name: "a", userID: nil, guestToken: "x", rsvp: .going, paid: false))
        #expect(await it.next() != nil)
    }

    @Test func authRoundTrip() async throws {
        let b = make()
        await #expect(throws: (any Error).self) { try await b.signIn(email: "", password: "secret1") }
        await #expect(throws: (any Error).self) { try await b.signUp(email: "a@b.c", password: "123") }
        let id = try await b.signUp(email: "a@b.c", password: "secret1")
        #expect(await b.currentUserID() == id)
        try await b.signOut()
        #expect(await b.currentUserID() == nil)
    }

    @Test func deleteAccountWipesEverything() async throws {
        let b = make()
        let id = try await b.signUp(email: "a@b.c", password: "secret1")
        try await b.saveProfile(Profile(id: id, displayName: "a", venmo: "v", cashtag: "c"))
        try await b.saveInvite(invite(id))
        let path = try await b.uploadImage(Data([1, 2, 3]), path: "p/x.png")
        let url = try #require(b.imageURL(path: path))
        #expect(FileManager.default.fileExists(atPath: url.path))
        try await b.deleteAccount()
        #expect(try await b.myInvites().isEmpty)
        #expect(try await b.profile() == nil)
        #expect(await b.currentUserID() == nil)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func deleteImageRemovesTheFile() async throws {
        let b = make()
        let path = try await b.uploadImage(Data([1, 2, 3]), path: "p/x.png")
        let url = try #require(b.imageURL(path: path))
        try await b.deleteImage(path: path)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        try await b.deleteImage(path: path)   // a second delete is not an error
    }

    @Test func summaryHidesPaidAndTotals() async throws {
        let b = make()
        var inv = invite()
        inv.fundraiser = Fundraiser(priceCents: 2000, hostPays: true)
        try await b.saveInvite(inv)
        try await b.saveProfile(Profile(id: UUID(), displayName: "h", venmo: "hv", cashtag: "hc"))
        for (n, r, p) in [("a", RSVP.going, true), ("b", .going, false), ("c", .maybe, true)] {
            try await b.respond(Response(id: UUID(), inviteID: inv.id, name: n, userID: nil, guestToken: n, rsvp: r, paid: p))
        }
        let s = try await b.summary(inviteID: inv.id)
        #expect(s.goingCount == 2)
        #expect(s.goalCents == 6000)
        #expect(s.raisedCents == 4000)
        #expect(s.guests.map(\.name) == ["a", "b", "c"])
        #expect(s.hostVenmo == "hv" && s.hostCashtag == "hc")
        let json = String(decoding: try JSONEncoder().encode(s), as: UTF8.self)
        #expect(!json.contains("paid"))
    }

    @Test func hostDeletesResponseAndMessage() async throws {
        let b = make()
        let inv = UUID()
        let r = Response(id: UUID(), inviteID: inv, name: "a", userID: nil, guestToken: "x", rsvp: .going, paid: false)
        let m = ChatMessage(id: UUID(), inviteID: inv, name: "a", userID: nil, body: "spam", createdAt: Date())
        try await b.respond(r)
        try await b.send(m)
        var it = b.changes(inviteID: inv).makeAsyncIterator()
        try await b.deleteResponse(id: r.id)
        #expect(await it.next() != nil)
        try await b.deleteMessage(id: m.id)
        #expect(try await b.responses(inviteID: inv).isEmpty)
        #expect(try await b.messages(inviteID: inv).isEmpty)
        try await b.deleteMessage(id: m.id)   // already gone is fine
    }

    @Test func inviteByID() async throws {
        let b = make()
        let i = invite()
        try await b.saveInvite(i)
        #expect(try await b.invite(id: i.id)?.id == i.id)
        #expect(try await b.invite(id: UUID()) == nil)
    }
}
