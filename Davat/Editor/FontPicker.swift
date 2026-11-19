import SwiftUI
import UIKit

/// Families that ship with iOS (nothing bundled), then the faces of the chosen family.
struct FontPicker: View {
    @Binding var fontName: String

    static let families: [String] = ["system"] + [
        "Didot", "Bodoni 72", "Snell Roundhand", "Zapfino", "Savoye LET", "Party LET", "Bradley Hand", "Marker Felt",
        "Chalkduster", "Noteworthy", "Chalkboard SE", "Papyrus", "Copperplate", "Academy Engraved LET", "Futura",
        "Avenir Next", "Avenir Next Condensed", "Impact", "DIN Condensed", "Arial Rounded MT Bold", "Gill Sans", "Optima",
        "Baskerville", "Cochin", "Hoefler Text", "Georgia", "Palatino", "American Typewriter", "Rockwell", "Trebuchet MS",
        "Kefa", "Menlo",
    ].filter { !UIFont.fontNames(forFamilyName: $0).isEmpty }

    private var family: String { fontName == "system" ? "system" : UIFont(name: fontName, size: 12)?.familyName ?? "system" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("font").font(.subheadline).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.families, id: \.self) { f in
                        let face = Self.defaultFace(f)
                        Button { fontName = face } label: {
                            VStack(spacing: 2) {
                                Text("Aa").font(face == "system" ? .system(size: 24) : .custom(face, fixedSize: 24))
                                    .frame(height: 34)
                                Text(f).font(.caption2).lineLimit(1)
                            }
                            .frame(width: 76, height: 64)
                        }
                        .buttonStyle(.glass)
                        .tint(f == family ? .accentColor : nil)
                    }
                }
                .padding(.vertical, 2)
            }
            let faces = family == "system" ? [] : UIFont.fontNames(forFamilyName: family).sorted()
            if faces.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(faces, id: \.self) { face in
                            Button { fontName = face } label: {
                                Text(Self.faceName(face)).font(.custom(face, fixedSize: 15))
                            }
                            .buttonStyle(.glass)
                            .tint(face == fontName ? .accentColor : nil)
                        }
                    }
                }
            }
        }
    }

    /// "regular", "bold italic": the face as the font describes it, not the PostScript suffix.
    static func faceName(_ postScript: String) -> String {
        (UIFont(name: postScript, size: 15)?.fontDescriptor.object(forKey: .face) as? String)?.lowercased() ?? "regular"
    }

    /// The plainest face of a family: the shortest PostScript name ("Didot", not "Didot-Italic").
    static func defaultFace(_ family: String) -> String {
        family == "system" ? "system" : UIFont.fontNames(forFamilyName: family).min { $0.count < $1.count } ?? "system"
    }
}
