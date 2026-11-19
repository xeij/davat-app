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

/// Synchronous image lookup for CanvasView, which can't wait on the network: memory cache, then the
/// backend's local file (LocalBackend), then a disk copy in Caches (remote backends). Remote images get
/// that disk copy when uploaded or prefetched, so call `prefetch(paths:)` before rendering a design.
final class ImageStore: @unchecked Sendable {   // NSCache and FileManager are thread-safe
    private let backend: any Backend
    private let cache = NSCache<NSString, UIImage>()
    private let dir = URL.cachesDirectory.appending(path: "images", directoryHint: .isDirectory)

    init(backend: any Backend) { self.backend = backend }

    /// Where an image lives on this device: the backend's own file, or our cached copy of a remote one.
    private func localURL(_ path: String) -> URL {
        if let url = backend.imageURL(path: path), url.isFileURL { return url }
        return dir.appending(path: path.replacingOccurrences(of: "..", with: "_"))   // paths can come from other people's designs
    }

    func image(_ path: String) -> Image? {
        if let ui = cache.object(forKey: path as NSString) { return Image(uiImage: ui) }
        guard let ui = UIImage(contentsOfFile: localURL(path).path) else { return nil }
        cache.setObject(ui, forKey: path as NSString)
        return Image(uiImage: ui)
    }

    /// Downloads any remote images not yet on disk.
    func prefetch(paths: [String]) async {
        for p in paths where !FileManager.default.fileExists(atPath: localURL(p).path) {
            guard let url = backend.imageURL(path: p),
                  let (data, _) = try? await URLSession.shared.data(from: url) else { continue }
            writeCopy(data, path: p)
        }
    }

    private func writeCopy(_ data: Data, path: String) {
        let url = localURL(path)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
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
        if !FileManager.default.fileExists(atPath: localURL(stored).path) { writeCopy(png, path: stored) }
        cache.setObject(ui, forKey: stored as NSString)
        return stored
    }
}
