import DavatKit
import SwiftUI

struct HomeView: View {
    @Environment(Session.self) private var session
    @State private var invites: [Invite] = []
    @State private var showProfile = false
    @State private var showPicker = false
    @State private var path: [Invite] = []
    @State private var imagesReady = 0
    @Namespace private var zoom

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading) {
                Text("your invites").font(.system(size: 40, weight: .thin)).padding(.horizontal, 24)
                    .accessibilityAddTraits(.isHeader)
                if invites.isEmpty {
                    Text("nothing yet. make one.").font(.title3.weight(.light)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 18) {
                            ForEach(invites) { invite in
                                Button { path.append(invite) } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        CanvasView(design: invite.design, imageLoader: session.images.image, showsEffect: false)
                                            .clipShape(.rect(cornerRadius: 16))
                                            .matchedTransitionSource(id: invite.id, in: zoom)
                                        Text(invite.title).font(.subheadline.weight(.light))
                                    }
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(invite.title)
                                .accessibilityAddTraits(.isButton)
                            }
                        }
                        .padding(.horizontal, 20).padding(.bottom, 100)
                        .id(imagesReady)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background { WarmTint() }
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
                TemplatePicker { invite in
                    UserDefaults.standard.set(false, forKey: InviteDetailView.envelopeKey(invite.id))   // fresh: reveal it once
                    showPicker = false
                    path = [invite]
                }
            }
            .navigationDestination(for: Invite.self) { invite in
                InviteDetailView(invite: invite).navigationTransition(.zoom(sourceID: invite.id, in: zoom))
            }
            .task { await load() }
            .onChange(of: path) { Task { await refresh() } }   // back from a detail, or just published
        }
    }

    private func load() async {
        await refresh()
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-demoSeed"), invites.isEmpty {
            for (i, t) in Templates.all.prefix(2).enumerated() {
                try? await session.backend.saveInvite(Invite(
                    id: UUID(), hostID: session.userID ?? UUID(), title: t.name, startsAt: .now.addingTimeInterval(86400 * 9),
                    location: "the rooftop on 5th", details: "bring a friend and your best moves",
                    design: t.design, fundraiser: i == 0 ? Fundraiser(priceCents: 2000, hostPays: true) : nil, updatedAt: .now))
            }
            invites = (try? await session.backend.myInvites()) ?? []
        }
        if args.contains("-demoPicker") { showPicker = true }
        if ["-demoDetail", "-demoDetails", "-demoEditor", "-demoGuests", "-demoChat"].contains(where: args.contains), let first = invites.first {
            path = [first]
        }
        #endif
    }

    /// Remote images land in the image cache, then the grid redraws to pick them up.
    private func prefetch() async {
        let paths = invites.flatMap(\.design.imagePaths)
        guard !paths.isEmpty else { return }
        await session.images.prefetch(paths: paths)
        imagesReady += 1
    }

    private func refresh() async {
        invites = (try? await session.backend.myInvites()) ?? []
        await prefetch()
    }
}
