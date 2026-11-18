import Foundation

public struct FundraiserSummary: Equatable, Sendable {
    public let goalCents: Int
    public let raisedCents: Int
    public let progress: Double
}

public func summarize(_ f: Fundraiser, responses: [Response]) -> FundraiserSummary {
    let going = responses.filter { $0.rsvp == .going }
    let host = f.hostPays ? 1 : 0
    let goal = f.priceCents * (going.count + host)
    let raised = f.priceCents * (going.filter(\.paid).count + host)
    return FundraiserSummary(goalCents: goal, raisedCents: raised,
                             progress: goal == 0 ? 0 : min(1, Double(raised) / Double(goal)))
}
