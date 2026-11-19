import Foundation

public enum PaymentLinks {
    public static func venmo(handle: String, cents: Int, note: String) -> URL? {
        let h = clean(handle)
        guard !h.isEmpty else { return nil }
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=#")
        let n = note.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        return URL(string: "https://venmo.com/u/\(h)?txn=pay&amount=\(decimal(cents))&note=\(n)")
    }

    public static func cashApp(tag: String, cents: Int) -> URL? {
        let t = clean(tag)
        guard !t.isEmpty else { return nil }
        return URL(string: "https://cash.app/$\(t)/\(decimal(cents))")
    }

    /// Keeps only what a Venmo handle or cashtag can hold, [A-Za-z0-9_-]. Drops "@", "$" and anything that
    /// could change the link. The profile screen saves handles through this too.
    public static func clean(_ handle: String) -> String {
        handle.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }
    }

}

/// "20.50" for 2050; shared by the payment links and formatCents.
private func decimal(_ cents: Int) -> String {
    "\(cents / 100)." + String(format: "%02ld", cents % 100)
}

public func formatCents(_ cents: Int) -> String {
    cents % 100 == 0 ? "$\(cents / 100)" : "$" + decimal(cents)
}
