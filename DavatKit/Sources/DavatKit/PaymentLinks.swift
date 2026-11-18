import Foundation

public enum PaymentLinks {
    public static func venmo(handle: String, cents: Int, note: String) -> URL? {
        let h = strip(handle, "@")
        guard !h.isEmpty else { return nil }
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=#")
        let n = note.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        return URL(string: "https://venmo.com/u/\(h)?txn=pay&amount=\(amount(cents))&note=\(n)")
    }

    public static func cashApp(tag: String, cents: Int) -> URL? {
        let t = strip(tag, "$")
        guard !t.isEmpty else { return nil }
        return URL(string: "https://cash.app/$\(t)/\(amount(cents))")
    }

    private static func strip(_ s: String, _ prefix: Character) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.first == prefix ? String(t.dropFirst()) : t
    }

    private static func amount(_ cents: Int) -> String {
        String(format: "%d.%02d", cents / 100, cents % 100)
    }
}

public func formatCents(_ cents: Int) -> String {
    cents % 100 == 0 ? "$\(cents / 100)" : "$" + String(format: "%d.%02d", cents / 100, cents % 100)
}
