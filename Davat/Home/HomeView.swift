import DavatKit
import SwiftUI

struct HomeView: View {
    @Environment(Session.self) private var session
    @State private var invites: [Invite] = []
    @State private var showProfile = false
    @State private var showPicker = false
    @State private var editing: Invite?
    @State private var error: String?
    @Namespace private var zoom

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Text("your invites").font(.system(size: 40, weight: .thin)).padding(.horizontal, 24)
                if invites.isEmpty {
                    Text("nothing yet. make one.").font(.title3.weight(.light)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 18) {
                            ForEach(invites) { invite in
                                Button { editing = invite } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        CanvasView(design: invite.design, imageLoader: session.images.image)
                                            .clipShape(.rect(cornerRadius: 16))
                                            .matchedTransitionSource(id: invite.id, in: zoom)
                                        Text(invite.title).font(.subheadline.weight(.light))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20).padding(.bottom, 100)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Profile", systemImage: "person.crop.circle") { showProfile = true }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button("New invite", systemImage: "plus") { showPicker = true }
                    .labelStyle(.iconOnly).font(.title)
                    .buttonStyle(.glass).buttonBorderShape(.circle)
                    .padding(24)
            }
            .sheet(isPresented: $showProfile) { ProfileView() }
            .sheet(isPresented: $showPicker) {
                TemplatePicker { design in
                    showPicker = false
                    save(Invite(id: UUID(), hostID: session.userID ?? UUID(), title: "untitled", design: design, updatedAt: .now))
                }
            }
            .fullScreenCover(item: $editing) { invite in
                EditorView(design: invite.design) { design in
                    editing = nil
                    var updated = invite
                    updated.design = design; updated.updatedAt = .now
                    save(updated)
                }
                .navigationTransition(.zoom(sourceID: invite.id, in: zoom))
            }
            .alert("couldn't save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            } message: { Text(error ?? "") }
            .task { await load() }
        }
    }

    private func load() async {
        let all = (try? await session.backend.myInvites()) ?? []
        for i in all { await session.images.prefetch(i.design) }   // so remote images are ready before first draw
        invites = all
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-demoSeed"), invites.isEmpty {
            for t in Templates.all.prefix(2) {
                try? await session.backend.saveInvite(Invite(id: UUID(), hostID: session.userID ?? UUID(), title: t.name,
                                                             design: t.design, updatedAt: .now))
            }
            invites = (try? await session.backend.myInvites()) ?? []
        }
        if args.contains("-demoPicker") { showPicker = true }
        if args.contains("-demoEditor") { editing = invites.first }
        #endif
    }

    private func save(_ invite: Invite) {
        Task {
            do { try await session.backend.saveInvite(invite) } catch { self.error = error.localizedDescription }
            invites = (try? await session.backend.myInvites()) ?? []
        }
    }
}
