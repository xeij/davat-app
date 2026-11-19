import DavatKit
import SwiftUI

/// The invite's chat, for the host. Guests chat on the web page and in the iMessage extension.
struct ChatView: View {
    let invite: Invite
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var error: String?
    @State private var sending = false

    private var trimmed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool { !sending && (1...1000).contains(trimmed.count) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("chat").font(.system(size: 34, weight: .thin))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                ScrollViewReader { proxy in
                    ScrollView {
                        if messages.isEmpty {
                            Text("no messages yet. say hi.").font(.body.weight(.light)).foregroundStyle(.secondary).padding(.top, 60)
                        }
                        LazyVStack(spacing: 8) {
                            let stamps = ChatGrouping.timestamps(for: messages, gap: 15 * 60)
                            ForEach(messages) { m in
                                if stamps.contains(m.id) {
                                    Text(m.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption.weight(.light)).foregroundStyle(.secondary).padding(.top, 8)
                                }
                                bubble(m).id(m.id)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: messages.last?.id) {
                        if let id = messages.last?.id { withAnimation(.spring(duration: 0.4, bounce: 0.2)) { proxy.scrollTo(id, anchor: .bottom) } }
                    }
                }
                if let error { Text(error).font(.footnote).foregroundStyle(.red).padding(.horizontal, 16) }
                HStack(spacing: 10) {
                    TextField("message", text: $draft, axis: .vertical).lineLimit(1...4)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .glassEffect(.regular, in: .capsule)
                    Button("Send", systemImage: "arrow.up") { Task { await send() } }
                        .labelStyle(.iconOnly).buttonStyle(.glassProminent).buttonBorderShape(.circle)
                        .disabled(!canSend)
                }
                .padding(12)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
        .tint(.saffron)
        .task {
            await reload()
            for await _ in session.backend.changes(inviteID: invite.id) { await reload() }
        }
    }

    private func bubble(_ m: ChatMessage) -> some View {
        let mine = m.userID != nil && m.userID == session.userID
        return VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
            if !mine { Text(m.name).font(.caption2.weight(.light)).foregroundStyle(.secondary).padding(.horizontal, 6) }
            Text(m.body).font(.body.weight(.light))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .glassEffect(mine ? .regular.tint(.saffron.opacity(0.35)) : .regular, in: .rect(cornerRadius: 18))
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }

    private func reload() async {
        do {
            messages = try await session.backend.messages(inviteID: invite.id).sorted { $0.createdAt < $1.createdAt }
            error = nil
        }
        catch is CancellationError {}
        catch { self.error = "couldn't refresh: \(error.localizedDescription)" }
    }

    private func send() async {
        let name = session.profile?.displayName ?? ""
        let m = ChatMessage(id: UUID(), inviteID: invite.id, name: name.isEmpty ? "host" : name,
                            userID: session.userID, body: trimmed, createdAt: .now)
        sending = true; defer { sending = false }
        do {
            try await session.backend.send(m)
            draft = ""; error = nil
            await reload()
        } catch { self.error = "couldn't send: \(error.localizedDescription)" }
    }
}
