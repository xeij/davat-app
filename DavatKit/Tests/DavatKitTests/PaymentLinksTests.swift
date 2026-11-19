import Foundation
import Testing
@testable import DavatKit

@Suite struct PaymentLinksTests {
    @Test func venmoLink() {
        let u = PaymentLinks.venmo(handle: "leila", cents: 2000, note: "Leila's 30th")
        #expect(u?.absoluteString == "https://venmo.com/u/leila?txn=pay&amount=20.00&note=Leila's%2030th")
    }

    @Test func cashAppLink() {
        #expect(PaymentLinks.cashApp(tag: "leila", cents: 2050)?.absoluteString == "https://cash.app/$leila/20.50")
    }

    @Test func handlesStripPrefixes() {
        #expect(PaymentLinks.venmo(handle: "@leila", cents: 2000, note: "Leila's 30th")
            == PaymentLinks.venmo(handle: "leila", cents: 2000, note: "Leila's 30th"))
        #expect(PaymentLinks.cashApp(tag: "$leila", cents: 2050) == PaymentLinks.cashApp(tag: "leila", cents: 2050))
        #expect(PaymentLinks.venmo(handle: "", cents: 100, note: "x") == nil)
        #expect(PaymentLinks.venmo(handle: "@", cents: 100, note: "x") == nil)
        #expect(PaymentLinks.cashApp(tag: "", cents: 100) == nil)
    }

    @Test func handlesDropOtherCharacters() {
        #expect(PaymentLinks.venmo(handle: " @le ila/<x>?", cents: 100, note: "x")?.absoluteString
            == "https://venmo.com/u/leilax?txn=pay&amount=1.00&note=x")
        #expect(PaymentLinks.cashApp(tag: "$le_i-la#1", cents: 100)?.absoluteString == "https://cash.app/$le_i-la1/1.00")
        #expect(PaymentLinks.clean(" @Leila_9-x! ") == "Leila_9-x")
    }

    @Test func formatCentsCases() {
        #expect(formatCents(2000) == "$20")
        #expect(formatCents(2050) == "$20.50")
        #expect(formatCents(0) == "$0")
    }

    @Test func inviteLink() {
        let id = UUID()
        #expect(DavatConfig.link(for: id).absoluteString == "https://davat.vercel.app/i/\(id.uuidString.lowercased())")
    }
}
