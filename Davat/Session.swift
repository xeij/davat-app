import DavatKit
import Observation
import SwiftUI

@MainActor @Observable final class Session {
    var userID: UUID?
    var profile: Profile?
    var loaded = false
    let backend: any Backend
    let images: ImageStore

    init(backend: any Backend = Backends.make()) { self.backend = backend; images = ImageStore(backend: backend) }

    func restore() async {
        userID = await backend.currentUserID()
        if userID != nil { profile = try? await backend.profile() }
        loaded = true
    }

    func finish(_ id: UUID) async {
        profile = try? await backend.profile()
        withAnimation(.spring(duration: 0.4, bounce: 0.2)) { userID = id }
    }

    func saveProfile(_ p: Profile) async throws {
        try await backend.saveProfile(p)
        profile = p
    }

    func signOut() async throws {
        try await backend.signOut()
        withAnimation(.spring(duration: 0.4, bounce: 0.2)) { userID = nil; profile = nil }
    }

    func deleteAccount() async throws {
        try await backend.deleteAccount()
        withAnimation(.spring(duration: 0.4, bounce: 0.2)) { userID = nil; profile = nil }
    }
}

/// Synchronous image lookup for CanvasView: memory cache first, then the backend's local file.
final class ImageStore: @unchecked Sendable {   // NSCache is thread-safe
    private let backend: any Backend
    private let cache = NSCache<NSString, UIImage>()

    init(backend: any Backend) { self.backend = backend }

    func image(_ path: String) -> Image? {
        if let ui = cache.object(forKey: path as NSString) { return Image(uiImage: ui) }
        guard let url = backend.imageURL(path: path), url.isFileURL, let ui = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(ui, forKey: path as NSString)
        return Image(uiImage: ui)
    }

    /// Downloads remote images a design uses so `image(_:)` can return them synchronously.
    func prefetch(_ design: Design) async {
        var paths = design.layers.compactMap { if case .image(let p) = $0.kind { p } else { nil } }
        if case .image(let p) = design.background { paths.append(p) }
        for p in paths where cache.object(forKey: p as NSString) == nil {
            guard let url = backend.imageURL(path: p), !url.isFileURL,
                  let (data, _) = try? await URLSession.shared.data(from: url), let ui = UIImage(data: data) else { continue }
            cache.setObject(ui, forKey: p as NSString)
        }
    }

    /// Shrinks to at most 1600px on the long side, uploads as PNG and returns the storage path.
    func upload(_ data: Data, userID: UUID) async throws -> String {
        guard let src = UIImage(data: data) else { throw BackendError("couldn't read that image") }
        let k = min(1, 1600 / max(src.size.width, src.size.height))
        let size = CGSize(width: src.size.width * k, height: src.size.height * k)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let ui = UIGraphicsImageRenderer(size: size, format: format).image { _ in src.draw(in: CGRect(origin: .zero, size: size)) }
        guard let png = ui.pngData() else { throw BackendError("couldn't read that image") }
        let path = "\(userID.uuidString.lowercased())/\(UUID().uuidString.lowercased()).png"
        let stored = try await backend.uploadImage(png, path: path)
        cache.setObject(ui, forKey: stored as NSString)
        return stored
    }
}
