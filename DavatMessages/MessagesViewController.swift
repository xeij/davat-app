import DavatKit
import Messages
import SwiftUI

/// Hosts BubbleView and turns Messages callbacks into BubbleModel state.
final class MessagesViewController: MSMessagesAppViewController {
    private let model = BubbleModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        model.controller = self
        let host = UIHostingController(rootView: BubbleView(model: model))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    override func willBecomeActive(with conversation: MSConversation) {
        model.style = presentationStyle
        model.selected = conversation.selectedMessage
        Task { await model.restore() }
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        model.selected = message
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        model.style = presentationStyle
    }
}

@MainActor @Observable final class BubbleModel {
    let backend = Backends.make()
    var userID: UUID?
    var profile: Profile?
    var invites: [Invite] = []
    var loaded = false
    var style: MSMessagesAppPresentationStyle = .compact
    var selected: MSMessage?
    @ObservationIgnored weak var controller: MSMessagesAppViewController?
    @ObservationIgnored private var posters: [String: UIImage] = [:]

    /// Shared login: LocalBackend reads the App Group container and SupabaseBackend the App Group keychain.
    func restore() async {
        userID = await backend.currentUserID()
        if userID != nil {
            profile = try? await backend.profile()
            invites = ((try? await backend.myInvites()) ?? []).filter { $0.posterPath != nil }
        }
        loaded = true
    }

    /// The published PNG: a file for LocalBackend, a download otherwise. Kept in memory for the session.
    func poster(_ invite: Invite) async -> UIImage? {
        guard let path = invite.posterPath else { return nil }
        if let ui = posters[path] { return ui }
        guard let url = backend.imageURL(path: path) else { return nil }
        let data = url.isFileURL ? try? Data(contentsOf: url) : try? await URLSession.shared.data(from: url).0
        let ui = data.flatMap(UIImage.init(data:))
        posters[path] = ui
        return ui
    }

    /// Inserts a new bubble for the invite into the compose field.
    func insert(_ invite: Invite) async throws {
        let date = invite.startsAt?.formatted(date: .abbreviated, time: .shortened)
        let each = invite.fundraiser.map { "\(formatCents($0.priceCents)) each" }
        let message = MSMessage(session: MSSession())
        message.layout = await layout(invite, caption: invite.title,
                                      subcaption: [date, each].compactMap { $0 }.joined(separator: " · "))
        message.url = bubbleURL(invite)
        message.summaryText = invite.title
        try await controller?.activeConversation?.insert(message)
        controller?.requestPresentationStyle(.compact)
    }

    /// Replaces the selected bubble for everyone in the thread with a new caption.
    func update(_ invite: Invite, caption: String) async throws {
        guard let selected, let conversation = controller?.activeConversation else { return }
        let message = MSMessage(session: selected.session ?? MSSession())
        message.layout = await layout(invite, caption: caption, subcaption: invite.title)
        message.url = selected.url ?? bubbleURL(invite)
        message.summaryText = caption
        try await conversation.send(message)
    }

    func open(_ url: URL) {
        controller?.extensionContext?.open(url)
    }

    private func layout(_ invite: Invite, caption: String, subcaption: String) async -> MSMessageTemplateLayout {
        let l = MSMessageTemplateLayout()
        l.image = await poster(invite)?.preparingThumbnail(of: CGSize(width: 540, height: 960))
        l.caption = caption
        l.subcaption = subcaption.isEmpty ? nil : subcaption
        return l
    }

    /// The web link, so guests without Davat land on the invite page. `v` busts link-preview caches.
    private func bubbleURL(_ invite: Invite) -> URL {
        DavatConfig.link(for: invite.id)
            .appending(queryItems: [URLQueryItem(name: "v", value: String(Int(invite.updatedAt.timeIntervalSince1970)))])
    }
}
