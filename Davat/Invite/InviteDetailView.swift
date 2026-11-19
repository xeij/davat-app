import DavatKit
import SwiftUI

/// The host's view of one invite: the live poster, share, fundraiser totals and the guest list.
struct InviteDetailView: View {
    @State var invite: Invite
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var responses: [Response] = []
    @State private var summary: PublicSummary?
    @State private var poster: Image?
    @State private var editing: EditStep?
    @State private var confirmDelete = false
    @State private var error: String?
    @State private var loadError: String?
    @State private var messageCount = 0
    @State private var chatting = false
    @State private var envelope: Envelope.Stage?
    @State private var published = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// false right after the first publish, true once the reveal has played. Missing: never reveal.
    static func envelopeKey(_ id: UUID) -> String { "envelopeSeen." + id.uuidString }

    enum EditStep: Identifiable { case design, details; var id: Self { self } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                CanvasView(design: invite.design, imageLoader: session.images.image)
                    .overlay { if let envelope { Envelope(stage: envelope) } }
                    .clipShape(.rect(cornerRadius: 22))
                VStack(alignment: .leading, spacing: 6) {
                    Text(invite.title).font(.system(size: 44, weight: .thin)).accessibilityAddTraits(.isHeader)
                    Group {
                        if let d = invite.startsAt { Text(d.formatted(date: .complete, time: .shortened)) }
                        if !invite.location.isEmpty { Text(invite.location) }
                    }
                    .font(.title3.weight(.light)).foregroundStyle(.secondary)
                }
                if !invite.details.isEmpty { Text(invite.details).font(.body.weight(.light)) }
                ShareLink(item: DavatConfig.link(for: invite.id),
                          preview: SharePreview(invite.title, image: poster ?? Image(systemName: "envelope"))) {
                    Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent).controlSize(.large)
                if let f = invite.fundraiser { fundraiserCard(f) }
                Button { chatting = true } label: {
                    Label(messageCount == 0 ? "chat" : "chat · \(messageCount)", systemImage: "bubble.left.and.bubble.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass).controlSize(.large)
                guests
                if let loadError {
                    Label(loadError, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.secondary)
                }
                #if DEBUG
                if session.backend is LocalBackend {
                    Button("simulate guests") { Task { await simulateGuests() } }.buttonStyle(.glass)
                }
                #endif
            }
            .padding(20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .tint(.saffron)
        .toolbar {
            Menu("More", systemImage: "ellipsis") {
                Button("Edit design", systemImage: "paintbrush") { editing = .design }
                Button("Edit details", systemImage: "pencil") { editing = .details }
                Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
            }
        }
        .confirmationDialog("delete this invite?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
        } message: { Text("the link stops working for everyone.") }
        .sheet(isPresented: $chatting) { ChatView(invite: invite) }
        .fullScreenCover(item: $editing) { step in
            InviteComposer(invite: invite, detailsFirst: step == .details) { invite = $0; editing = nil; published += 1 }
        }
        .sensoryFeedback(.success, trigger: published)
        .onAppear {
            let key = Self.envelopeKey(invite.id)
            guard UserDefaults.standard.object(forKey: key) as? Bool == false else { return }
            published += 1
            if reduceMotion { UserDefaults.standard.set(true, forKey: key) } else { envelope = .closed }
        }
        .task {
            guard envelope == .closed else { return }
            do {   // leaving early cancels the sleeps, so the reveal plays again next time
                try await Task.sleep(for: .milliseconds(250))
                withAnimation(.spring(duration: 0.4, bounce: 0.15)) { envelope = .flapOpen }
                try await Task.sleep(for: .milliseconds(350))
                withAnimation(.spring(duration: 0.5, bounce: 0)) { envelope = .gone }
                try await Task.sleep(for: .milliseconds(500))
                envelope = nil
                UserDefaults.standard.set(true, forKey: Self.envelopeKey(invite.id))
            } catch {}
        }
        .alert("that didn't work", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
        } message: { Text(error ?? "") }
        .task(id: invite.updatedAt) {   // re-keyed after an edit, so the totals follow a new price
            await reload()
            for await _ in session.backend.changes(inviteID: invite.id) { await reload() }
        }
        #if DEBUG
        .task {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-demoGuests") || args.contains("-demoChat") { await simulateGuests() }
            if args.contains("-demoChat") { chatting = true }
            if args.contains("-demoEditor") { editing = .design }
            if args.contains("-demoDetails") { editing = .details }
        }
        #endif
        .task(id: invite.updatedAt) {
            poster = await PublishService.poster(invite.design, images: session.images, scale: 0.3).map(Image.init(uiImage:))
        }
    }

    private func fundraiserCard(_ f: Fundraiser) -> some View {
        let raised = summary?.raisedCents ?? 0, goal = summary?.goalCents ?? 0
        return VStack(alignment: .leading, spacing: 14) {
            Text("\(formatCents(f.priceCents)) each · \(formatCents(raised)) of \(formatCents(goal)) in")
                .font(.title3.weight(.light))
            GeometryReader { g in
                Capsule().fill(.tint)
                    .frame(width: g.size.width * (goal == 0 ? 0 : min(1, Double(raised) / Double(goal))))
            }
            .frame(height: 10)
            .padding(4)
            .glassEffect(.regular, in: .capsule)
            .animation(.spring(duration: 0.4, bounce: 0.2), value: raised)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    @ViewBuilder private var guests: some View {
        let groups = GuestGroups.of(responses)
        if groups.isEmpty {
            Text("no replies yet. share it around.").font(.body.weight(.light)).foregroundStyle(.secondary)
        }
        ForEach(groups, id: \.rsvp) { group in
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.label(group.rsvp) + " \(group.guests.count)")
                    .font(.headline.weight(.light)).foregroundStyle(.secondary)
                ForEach(group.guests) { r in
                    GuestRow(response: r, showsPaid: invite.fundraiser != nil && r.rsvp == .going) { paid in
                        Task {
                            do { try await session.backend.setPaid(responseID: r.id, paid: paid) }
                            catch { self.error = error.localizedDescription }
                            await reload()
                        }
                    }
                }
            }
        }
    }

    private static func label(_ rsvp: RSVP) -> String {
        switch rsvp { case .going: "going"; case .maybe: "maybe"; case .cant: "can't" }
    }

    private func reload() async {
        do {
            responses = try await session.backend.responses(inviteID: invite.id)
            summary = try await session.backend.summary(inviteID: invite.id)
            messageCount = try await session.backend.messages(inviteID: invite.id).count
            loadError = nil
        } catch is CancellationError {
        } catch {
            loadError = "couldn't refresh: \(error.localizedDescription)"
        }
    }

    private func delete() {
        Task {
            do {
                try await session.backend.deleteInvite(id: invite.id)
                dismiss()
                let backend = session.backend, paths = [invite.posterPath].compactMap(\.self) + invite.design.imagePaths
                Task.detached {   // best effort, after the screen is gone: the invite already is
                    for path in paths { try? await backend.deleteImage(path: path) }
                }
            }
            catch { self.error = error.localizedDescription }
        }
    }

    #if DEBUG
    /// Lets the host try the guest side before iMessage exists. Fixed tokens, so tapping again updates them.
    private func simulateGuests() async {
        let guests: [(String, RSVP, Bool)] = [("sara", .going, true), ("omid", .going, false), ("leila", .maybe, false)]
        for (i, g) in guests.enumerated() {
            try? await session.backend.respond(Response(id: UUID(), inviteID: invite.id, name: g.0, userID: nil,
                                                        guestToken: "simulated-guest-\(i)-token", rsvp: g.1, paid: g.2))
        }
        let said = ["see you there", "can i bring anything?", "so excited"]
        for (i, text) in said.enumerated() {
            let id = UUID(uuidString: "00000000-0000-0000-0000-00000000010\(i)")!   // fixed, so tapping again doesn't duplicate
            try? await session.backend.send(ChatMessage(id: id, inviteID: invite.id, name: guests[i].0, userID: nil,
                                                        body: text, createdAt: Date(timeIntervalSinceNow: Double(i - 3) * 60)))
        }
        await reload()
    }
    #endif
}

/// Covers the poster the first time a fresh invite is opened: the flap swings open past upright, then the envelope
/// fades and drops away. The hinge sits below the top edge so the open flap stays inside the poster's clip.
private struct Envelope: View {
    enum Stage { case closed, flapOpen, gone }
    let stage: Stage

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .top) {
                LinearGradient(colors: [.saffron, .rose], startPoint: .topLeading, endPoint: .bottomTrailing)
                Flap()
                    .fill(Color.saffron.mix(with: .white, by: 0.15))
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                    .frame(height: g.size.height * 0.36)
                    .rotation3DEffect(.degrees(stage == .closed ? 0 : 110), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.5)
                    .padding(.top, g.size.height * 0.22)
            }
            .offset(y: stage == .gone ? g.size.height : 0)
            .opacity(stage == .gone ? 0 : 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    struct Flap: Shape {
        func path(in r: CGRect) -> Path {
            Path { p in
                p.move(to: CGPoint(x: r.minX, y: r.minY))
                p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
                p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
                p.closeSubpath()
            }
        }
    }
}
