import DavatKit
import SwiftUI

private let saffron = Color(red: 0.851, green: 0.573, blue: 0.180)   // same as the app's Color.saffron

/// Compact: the host's published invites to send. Expanded on a bubble: the guest's RSVP card.
struct BubbleView: View {
    let model: BubbleModel

    var body: some View {
        Group {
            if model.style == .expanded, let url = model.selected?.url, let id = DavatConfig.inviteID(from: url) {
                GuestView(model: model, inviteID: id).id(id)
            } else {
                HostRow(model: model)
            }
        }
        .tint(saffron)
    }
}

private struct HostRow: View {
    let model: BubbleModel
    @State private var error: String?

    var body: some View {
        if !model.loaded {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.userID == nil {
            note("open davat to sign in")
        } else if model.invites.isEmpty {
            note("publish an invite in davat to send it here")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(model.invites) { invite in
                            Thumb(model: model, invite: invite) {
                                Task {
                                    do { try await model.insert(invite) } catch { self.error = error.localizedDescription }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
                if let error { Text(error).font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 16) }
            }
            .padding(.vertical, 12)
        }
    }

    private func note(_ s: String) -> some View {
        Text(s).font(.system(size: 28, weight: .thin)).multilineTextAlignment(.center)
            .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct Thumb: View {
    let model: BubbleModel
    let invite: Invite
    let tap: () -> Void
    @State private var poster: UIImage?

    var body: some View {
        Button(action: tap) {
            VStack(alignment: .leading, spacing: 6) {
                Group {
                    if let poster { Image(uiImage: poster).resizable() } else { Rectangle().fill(.quaternary) }
                }
                .aspectRatio(9 / 16, contentMode: .fit)
                .frame(height: 160)
                .clipShape(.rect(cornerRadius: 12))
                Text(invite.title).font(.footnote.weight(.light)).lineLimit(1).frame(width: 90, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("send \(invite.title)")
        .task { poster = await model.thumbnail(invite) }
    }
}

struct GuestView: View {
    let model: BubbleModel
    let inviteID: UUID
    @State private var invite: Invite?
    @State private var summary: PublicSummary?
    @State private var poster: UIImage?
    @State private var mine: RSVP?
    @State private var draft = ""
    @State private var busy = false
    @State private var error: String?
    @State private var answered = 0
    @State private var paid = false
    @AppStorage("guestName") private var guestName = ""
    @AppStorage("guestToken") private var guestToken = ""

    /// Signed in: the account's name. Otherwise the name this device gave once.
    private var name: String {
        if model.userID != nil, let n = model.profile?.displayName, !n.isEmpty { return n }
        return guestName
    }
    private var mineKey: String { "rsvp." + inviteID.uuidString }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let invite {
                    header(invite)
                    if name.isEmpty { namePrompt }
                    rsvpButtons(invite)
                    if let f = invite.fundraiser, let summary { fundraiser(invite, f, summary) }
                    Button { model.open(DavatConfig.link(for: invite.id)) } label: {
                        Label("chat", systemImage: "bubble.left.and.bubble.right").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass).controlSize(.large)
                    Button("report this invite") { model.open(Self.reportLink(invite.id)) }
                        .font(.footnote).foregroundStyle(.secondary).buttonStyle(.plain)
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.secondary)
                } else if invite == nil {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
        .animation(.spring(duration: 0.4, bounce: 0.2), value: summary)
        .sensoryFeedback(.success, trigger: answered)
        .task { await load() }
    }

    private func header(_ invite: Invite) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Group {
                if let poster { Image(uiImage: poster).resizable() } else { Rectangle().fill(.quaternary) }
            }
            .aspectRatio(9 / 16, contentMode: .fit)
            .frame(width: 110)
            .clipShape(.rect(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 6) {
                Text(invite.title).font(.system(size: 34, weight: .thin)).accessibilityAddTraits(.isHeader)
                Group {
                    if let d = invite.startsAt { Text(d.formatted(date: .abbreviated, time: .shortened)) }
                    if !invite.location.isEmpty { Text(invite.location) }
                }
                .font(.body.weight(.light)).foregroundStyle(.secondary)
            }
        }
    }

    private var namePrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("what's your name?").font(.title3.weight(.light))
            HStack {
                TextField("name", text: $draft)
                    .textContentType(.givenName)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .glassEffect()
                    .onSubmit(saveName)
                Button("save", action: saveName).buttonStyle(.glassProminent)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func rsvpButtons(_ invite: Invite) -> some View {
        GlassEffectContainer {
            HStack(spacing: 10) {
                ForEach(RSVP.allCases, id: \.self) { r in
                    let b = Button { Task { await answer(r, paid: false) } } label: {
                        Text(label(r)).lineLimit(1).frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    if mine == r { b.buttonStyle(.glassProminent) } else { b.buttonStyle(.glass) }
                }
            }
        }
        .disabled(name.isEmpty || busy)
    }

    private func fundraiser(_ invite: Invite, _ f: Fundraiser, _ s: PublicSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(formatCents(f.priceCents)) each · \(formatCents(s.raisedCents)) of \(formatCents(s.goalCents)) in")
                .font(.title3.weight(.light))
            ProgressView(value: s.goalCents == 0 ? 0 : min(1, Double(s.raisedCents) / Double(s.goalCents)))
            GlassEffectContainer {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        if let url = PaymentLinks.venmo(handle: s.hostVenmo, cents: f.priceCents, note: invite.title) {
                            Button { model.open(url) } label: { Text("Venmo").frame(maxWidth: .infinity) }.buttonStyle(.glass)
                        }
                        if let url = PaymentLinks.cashApp(tag: s.hostCashtag, cents: f.priceCents) {
                            Button { model.open(url) } label: { Text("Cash App").frame(maxWidth: .infinity) }.buttonStyle(.glass)
                        }
                    }
                    Button { Task { await answer(.going, paid: true) } } label: {   // paying counts only when going
                        Text(paid ? "marked as going and paid" : "I paid").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(name.isEmpty || busy || paid)
                }
                .controlSize(.large)
            }
        }
    }

    private func label(_ r: RSVP) -> String {
        switch r { case .going: "Going"; case .maybe: "Maybe"; case .cant: "Can't" }
    }

    private func saveName() {
        let n = draft.trimmingCharacters(in: .whitespaces)
        if !n.isEmpty { guestName = String(String.UnicodeScalarView(n.unicodeScalars.prefix(60))) }   // the database holds 60
    }

    /// The web page opens its report form on #report.
    static func reportLink(_ id: UUID) -> URL {
        URL(string: DavatConfig.link(for: id).absoluteString + "#report")!
    }

    private func load() async {
        mine = UserDefaults.standard.string(forKey: mineKey).flatMap(RSVP.init(rawValue:))
        do {
            guard let i = try await model.backend.invite(id: inviteID) else { error = "this invite is gone"; return }
            invite = i
            summary = try await model.backend.summary(inviteID: inviteID)
            poster = await model.poster(i)
        } catch {
            self.error = error.localizedDescription
            return
        }
        for await _ in model.backend.changes(inviteID: inviteID) {
            if let s = try? await model.backend.summary(inviteID: inviteID) { summary = s }
        }
    }

    /// `paid` is true only from "I paid"; the backends keep a guest's earlier paid mark when it's false.
    private func answer(_ rsvp: RSVP, paid: Bool) async {
        guard let invite, !name.isEmpty else { return }
        busy = true
        defer { busy = false }
        if guestToken.isEmpty { guestToken = UUID().uuidString }
        do {
            try await model.backend.respond(Response(
                id: UUID(), inviteID: invite.id, name: name, userID: model.userID,
                guestToken: model.userID == nil ? guestToken : nil, rsvp: rsvp, paid: paid))
            mine = rsvp
            if paid { self.paid = true }
            answered += 1
            UserDefaults.standard.set(rsvp.rawValue, forKey: mineKey)
            let s = try await model.backend.summary(inviteID: invite.id)
            summary = s
            error = nil
            // Only RSVPs update the bubble; a paid tap would tell the whole thread who paid.
            if !paid {
                try await model.update(invite, caption: BubbleCaption.make(name: name, rsvp: rsvp, summary: s,
                                                                             fundraiser: invite.fundraiser))
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
