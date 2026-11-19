import Foundation
import Testing
@testable import DavatKit

@Suite struct BubbleCaptionTests {
    func summary(going: Int, raised: Int = 0, goal: Int = 0) -> PublicSummary {
        PublicSummary(guests: [], goingCount: going, goalCents: goal, raisedCents: raised, hostVenmo: "", hostCashtag: "")
    }
    let f = Fundraiser(priceCents: 2000, hostPays: false)

    @Test func going() {
        #expect(BubbleCaption.make(name: "sam", rsvp: .going, summary: summary(going: 3), fundraiser: nil) == "sam's in · 3 going")
    }
    @Test func maybe() {
        #expect(BubbleCaption.make(name: "sam", rsvp: .maybe, summary: summary(going: 2), fundraiser: nil) == "sam's a maybe · 2 going")
    }
    @Test func cant() {
        #expect(BubbleCaption.make(name: "sam", rsvp: .cant, summary: summary(going: 2), fundraiser: nil) == "sam can't make it · 2 going")
    }
    @Test func withFundraiser() {
        #expect(BubbleCaption.make(name: "sam", rsvp: .going, summary: summary(going: 3, raised: 6000, goal: 8000), fundraiser: f)
            == "sam's in · 3 going · $60 of $80")
        #expect(BubbleCaption.make(name: "sam", rsvp: .cant, summary: summary(going: 2, raised: 2050, goal: 4000), fundraiser: f)
            == "sam can't make it · 2 going · $20.50 of $40")
    }
    @Test func noEmDashes() {
        for rsvp in RSVP.allCases {
            for fr in [nil, f] {
                #expect(!BubbleCaption.make(name: "sam", rsvp: rsvp, summary: summary(going: 1, raised: 2000, goal: 2000), fundraiser: fr).contains("—"))
            }
        }
    }
    @Test func inviteIDFromLink() {
        let id = UUID()
        var c = URLComponents(url: DavatConfig.link(for: id), resolvingAgainstBaseURL: false)!
        c.queryItems = [.init(name: "v", value: "123")]
        #expect(DavatConfig.inviteID(from: c.url!) == id)
        #expect(DavatConfig.inviteID(from: URL(string: "https://davat-app-web.vercel.app/x/abc")!) == nil)
    }
}
