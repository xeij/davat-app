import DavatKit
import SwiftUI

@MainActor enum PublishService {
    /// Renders the poster at 1080x1920, uploads it to "<hostID>/<inviteID>.png" (replacing any earlier
    /// version, so the link stays the same), sets posterPath and saves the invite.
    static func publish(_ invite: Invite, backend: any Backend, images: ImageStore) async throws -> Invite {
        guard let ui = await poster(invite.design, images: images),
              let png = await Task.detached(operation: { ui.pngData() }).value else {   // encode off the main actor
            throw BackendError("couldn't draw the poster")
        }
        var out = invite
        out.posterPath = try await backend.uploadImage(png, path: PublishPaths.poster(hostID: invite.hostID, inviteID: invite.id))
        out.updatedAt = .now
        out.timeZone = TimeZone.current.identifier   // the web page shows the start time in the host's zone
        try await backend.saveInvite(out)
        return out
    }

    /// The still poster: no effect, every image fetched first so none is missing. Scale 1 is 1080x1920.
    static func poster(_ design: Design, images: ImageStore, scale: CGFloat = 1) async -> UIImage? {
        await images.prefetch(paths: design.imagePaths)
        let r = ImageRenderer(content: CanvasView(design: design, imageLoader: images.image, showsEffect: false)
            .frame(width: 1080, height: 1920))
        r.scale = scale
        return r.uiImage
    }
}
