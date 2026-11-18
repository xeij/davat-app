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
