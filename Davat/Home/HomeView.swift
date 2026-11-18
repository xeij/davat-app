import DavatKit
import SwiftUI

struct HomeView: View {
    @Environment(Session.self) private var session
    @State private var invites: [Invite] = []
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Text("your invites").font(.system(size: 40, weight: .thin)).padding(.horizontal, 24)
                if invites.isEmpty {
                    Text("nothing yet. make one.").font(.title3.weight(.light)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(invites) { Text($0.title) }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Profile", systemImage: "person.crop.circle") { showProfile = true }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // ponytail: no-op until the editor lands in a later task
                Button("New invite", systemImage: "plus") { }
                    .labelStyle(.iconOnly).font(.title)
                    .buttonStyle(.glass).buttonBorderShape(.circle)
                    .padding(24)
            }
            .sheet(isPresented: $showProfile) { ProfileView() }
            .task { invites = (try? await session.backend.myInvites()) ?? [] }
        }
    }
}
