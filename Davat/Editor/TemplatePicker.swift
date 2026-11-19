import DavatKit
import SwiftUI

struct TemplatePicker: View {
    let onPublished: (Invite) -> Void
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Namespace private var zoom
    @State private var editing: Pick?

    struct Pick: Identifiable { let id: String; let design: Design }
    static let blank = Design(background: .color(.hex(0xF5F1EA)),
                              layers: [Layer(kind: .text(TextLayer(text: "your party", size: 54, weight: 0.1, color: .hex(0x111111))), y: 0.4)])

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("start with").font(.system(size: 40, weight: .thin)).accessibilityAddTraits(.isHeader)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 18) {
                        tile("blank", Self.blank, blank: true)
                        ForEach(Templates.all, id: \.name) { tile($0.name, $0.design) }
                    }
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
            }
            .fullScreenCover(item: $editing) { pick in
                InviteComposer(invite: Invite(id: UUID(), hostID: session.userID ?? UUID(), title: "", design: pick.design,
                                              updatedAt: .now), onPublished: onPublished)
                    .navigationTransition(.zoom(sourceID: pick.id, in: zoom))
            }
        }
    }

    private func tile(_ name: String, _ design: Design, blank: Bool = false) -> some View {
        Button { editing = Pick(id: name, design: design) } label: {
            VStack(alignment: .leading, spacing: 6) {
                CanvasView(design: blank ? Design(background: design.background) : design, imageLoader: { _ in nil })
                    .overlay { if blank { Image(systemName: "plus").font(.system(size: 34, weight: .thin)).foregroundStyle(.secondary) } }
                    .clipShape(.rect(cornerRadius: 16))
                    .matchedTransitionSource(id: name, in: zoom)
                Text(name).font(.subheadline.weight(.light)).foregroundStyle(.primary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("template.\(name)")
    }
}
