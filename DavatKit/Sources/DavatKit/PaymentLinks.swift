import Foundation

public enum PaymentLinks {
    public static func venmo(handle: String, cents: Int, note: String) -> URL? {
        let h = strip(handle, "@")
        guard !h.isEmpty else { return nil }
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=#")
        let n = note.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        return URL(string: "https://venmo.com/u/\(h)?txn=pay&amount=\(decimal(cents))&note=\(n)")
    }

    public static func cashApp(tag: String, cents: Int) -> URL? {
        let t = strip(tag, "$")
        guard !t.isEmpty else { return nil }
        return URL(string: "https://cash.app/$\(t)/\(decimal(cents))")
    }

    private static func strip(_ s: String, _ prefix: Character) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.first == prefix ? String(t.dropFirst()) : t
    }

}

/// "20.50" for 2050; shared by the payment links and formatCents.
private func decimal(_ cents: Int) -> String {
    "\(cents / 100)." + String(format: "%02ld", cents % 100)
}

public func formatCents(_ cents: Int) -> String {
    cents % 100 == 0 ? "$\(cents / 100)" : "$" + decimal(cents)
}
