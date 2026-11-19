import Foundation

public enum DavatConfig {
    public static let webBaseURL = URL(string: "https://davat-app-web.vercel.app")!

    public static func link(for id: UUID) -> URL {
        webBaseURL.appending(path: "i/\(id.uuidString.lowercased())")
    }
}
