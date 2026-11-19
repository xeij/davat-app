import DavatKit
import SwiftUI

/// Editor, then details, then publish. Starts on the details step when only those are being changed.
struct InviteComposer: View {
    @State private var invite: Invite
    @State private var showDetails: Bool
    let onPublished: (Invite) -> Void

    init(invite: Invite, detailsFirst: Bool = false, onPublished: @escaping (Invite) -> Void) {
        _invite = State(initialValue: invite)
        _showDetails = State(initialValue: detailsFirst)
        self.onPublished = onPublished
    }

    var body: some View {
        NavigationStack {
            EditorView(design: invite.design) { invite.design = $0; showDetails = true }
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $showDetails) { DetailsView(invite: $invite, onPublished: onPublished) }
        }
    }
}

struct DetailsView: View {
    @Binding var invite: Invite
    let onPublished: (Invite) -> Void
    @Environment(Session.self) private var session
    @State private var publishing = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                TextField("what's the occasion", text: $invite.title)
                    .font(.system(size: 30, weight: .light))
                    .accessibilityIdentifier("title")
                DatePicker("when", selection: Binding(get: { invite.startsAt ?? .now }, set: { invite.startsAt = $0 }))
                TextField("where", text: $invite.location)
                TextField("anything else guests should know", text: $invite.details, axis: .vertical).lineLimit(3...8)
            } header: {
                Text("details").font(.system(size: 40, weight: .thin)).textCase(nil).foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, 8)
            }
            Section {
                Toggle("fundraiser", isOn: Binding(
                    get: { invite.fundraiser != nil },
                    set: { invite.fundraiser = $0 ? Fundraiser(priceCents: 2000, hostPays: false) : nil }))
                if invite.fundraiser != nil {
                    LabeledContent("each person pays") {
                        TextField("price", text: price).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    }
                    Toggle("I'm paying too", isOn: Binding(
                        get: { invite.fundraiser?.hostPays ?? false }, set: { invite.fundraiser?.hostPays = $0 }))
                }
            } footer: {
                if invite.fundraiser != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("the goal grows with everyone who says going.")
                        if session.profile.map({ $0.venmo.isEmpty && $0.cashtag.isEmpty }) ?? true {
                            Text("add your venmo or cash app in profile so people can pay you").foregroundStyle(.tint)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .tint(.saffron)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if publishing { ProgressView() } else {
                    Button("Publish") { publish() }.buttonStyle(.glassProminent).disabled(!ready)
                }
            }
        }
        .onAppear {
            if invite.startsAt == nil { invite.startsAt = Invite.defaultStart(after: .now) }
        }
        .alert("couldn't publish", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
        } message: { Text(error ?? "") }
        .animation(.spring(duration: 0.4, bounce: 0.2), value: invite.fundraiser != nil)
    }

    private var ready: Bool {
        !invite.title.trimmingCharacters(in: .whitespaces).isEmpty && (invite.fundraiser?.priceCents ?? 1) > 0
    }

    /// Cash-register entry: digits fill in from the cents side, so "2000" reads "$20.00".
    private var price: Binding<String> {
        Binding(
            get: { let c = invite.fundraiser?.priceCents ?? 0; return String(format: "$%d.%02d", c / 100, c % 100) },
            set: { invite.fundraiser?.priceCents = Int($0.filter(\.isNumber).suffix(7)) ?? 0 })
    }

    private func publish() {
        publishing = true
        Task {
            defer { publishing = false }
            do { onPublished(try await PublishService.publish(invite, backend: session.backend, images: session.images)) }
            catch { self.error = error.localizedDescription }
        }
    }
}
