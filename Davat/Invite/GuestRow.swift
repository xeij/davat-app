import DavatKit
import SwiftUI

/// A guest's name; in fundraiser mode a going guest also gets the host-only paid switch.
struct GuestRow: View {
    let response: Response
    let showsPaid: Bool
    let setPaid: @MainActor (Bool) -> Void
    @State private var taps = 0   // haptic on the host's own taps, not on refreshes

    var body: some View {
        Group {
            if showsPaid {
                Toggle(isOn: Binding(get: { response.paid }, set: { taps += 1; setPaid($0) })) {
                    Text(response.name)
                    Text(response.paid ? "paid" : "not yet")
                }
            } else {
                Text(response.name).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.body.weight(.light))
        .padding(.vertical, 4)
        .sensoryFeedback(.selection, trigger: taps)
    }
}
