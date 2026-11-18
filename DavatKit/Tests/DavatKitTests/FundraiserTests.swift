import Foundation
import Testing
@testable import DavatKit

private func resp(_ rsvp: RSVP, paid: Bool = false) -> Response {
    Response(id: UUID(), inviteID: UUID(), name: "x", userID: nil, guestToken: nil, rsvp: rsvp, paid: paid)
}

@Suite struct FundraiserTests {
    let f = Fundraiser(priceCents: 2000, hostPays: false)

    @Test func goalIsPriceTimesGoing() {
        let r = [resp(.going), resp(.going), resp(.going), resp(.going), resp(.maybe), resp(.cant)]
        #expect(summarize(f, responses: r).goalCents == 8000)
    }

    @Test func hostPaysAddsOneShareAndCountsAsRaised() {
        let r = [resp(.going), resp(.going), resp(.going)]
        let s = summarize(Fundraiser(priceCents: 2000, hostPays: true), responses: r)
        #expect(s.goalCents == 8000)
        #expect(s.raisedCents == 2000)
    }

    @Test func raisedCountsPaidGoingOnly() {
        let r = [resp(.going, paid: true), resp(.going, paid: true), resp(.going), resp(.going), resp(.maybe, paid: true)]
        let s = summarize(f, responses: r)
        #expect(s.raisedCents == 4000)
        #expect(s.progress == 0.5)
    }

    @Test func zeroGoingGoalIsZeroAndProgressZero() {
        let s = summarize(f, responses: [])
        #expect(s.goalCents == 0)
        #expect(s.progress == 0)
        #expect(summarize(Fundraiser(priceCents: 0, hostPays: false), responses: [resp(.going)]).progress == 0)
    }

    @Test func progressCapsAtOne() {
        let r = [resp(.going, paid: true)]
        let s = summarize(Fundraiser(priceCents: 2000, hostPays: true), responses: r)
        #expect(s.progress <= 1)
        #expect(s.progress == 1)
    }
}
