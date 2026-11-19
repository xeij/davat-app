import CoreGraphics
import Foundation

public struct RGBA: Codable, Hashable, Sendable {
    public var r: Double, g: Double, b: Double, a: Double
    public init(r: Double, g: Double, b: Double, a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    public static func hex(_ v: UInt32, _ a: Double = 1) -> RGBA {
        RGBA(r: Double(v >> 16 & 0xFF) / 255, g: Double(v >> 8 & 0xFF) / 255, b: Double(v & 0xFF) / 255, a: a)
    }
}

public enum PatternKind: String, Codable, CaseIterable, Sendable { case dots, stripes, grid, waves, checker, hearts, flowers, stars }

public enum Background: Codable, Hashable, Sendable {
    case color(RGBA)
    case gradient([RGBA], angle: Double)
    case pattern(PatternKind, RGBA, RGBA)
    case image(path: String)
}

public enum Effect: String, Codable, CaseIterable, Sendable { case none, confetti, snow, sparkle, hearts, bubbles, petals }

public struct TextLayer: Codable, Hashable, Sendable {
    public var text: String
    public var fontName: String          // PostScript name or "system"
    public var size: Double
    public var weight: Double            // 0...1 mapped by the renderer
    public var color: RGBA
    public var gradient: [RGBA]?         // top-to-bottom fill; overrides color when set
    public var alignment: Alignment
    public var outline: RGBA?
    public var outlineWidth: Double
    public var shadow: Bool
    public var curve: Double { didSet { curve = Self.clamp(curve) } }   // -1...1, arc bend
    public var letterSpacing: Double

    public enum Alignment: String, Codable, Sendable { case leading, center, trailing }

    static func clamp(_ c: Double) -> Double { min(max(c, -1), 1) }

    public init(text: String, fontName: String = "system", size: Double = 48, weight: Double = 0.2, color: RGBA,
                gradient: [RGBA]? = nil, alignment: Alignment = .center, outline: RGBA? = nil, outlineWidth: Double = 0,
                shadow: Bool = false, curve: Double = 0, letterSpacing: Double = 0) {
        self.text = text; self.fontName = fontName; self.size = size; self.weight = weight; self.color = color; self.gradient = gradient
        self.alignment = alignment; self.outline = outline; self.outlineWidth = outlineWidth
        self.shadow = shadow; self.curve = Self.clamp(curve); self.letterSpacing = letterSpacing
    }
}

public struct ShapeLayer: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable { case circle, rect, star, heart, blob }
    public var kind: Kind
    public var fill: RGBA
    public var stroke: RGBA?
    public var size: CGSize

    public init(kind: Kind, fill: RGBA, stroke: RGBA?, size: CGSize) {
        self.kind = kind; self.fill = fill; self.stroke = stroke; self.size = size
    }
}

public enum LayerKind: Codable, Hashable, Sendable {
    case text(TextLayer)
    case emoji(String)
    case image(path: String)
    case shape(ShapeLayer)
}

public struct Layer: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var kind: LayerKind
    public var x: Double, y: Double      // 0...1 canvas fraction
    public var scale: Double
    public var rotation: Double          // degrees
    public var opacity: Double

    public init(id: UUID = UUID(), kind: LayerKind, x: Double = 0.5, y: Double = 0.5,
                scale: Double = 1, rotation: Double = 0, opacity: Double = 1) {
        self.id = id; self.kind = kind; self.x = x; self.y = y
        self.scale = scale; self.rotation = rotation; self.opacity = opacity
    }
}

public struct Design: Codable, Hashable, Sendable {
    public var background: Background
    public var layers: [Layer]
    public var effect: Effect
    public var envelope: Bool

    public init(background: Background, layers: [Layer] = [], effect: Effect = .none, envelope: Bool = false) {
        self.background = background; self.layers = layers; self.effect = effect; self.envelope = envelope
    }

    private enum CodingKeys: String, CodingKey { case background, layers, effect, envelope }

    // Anything this build doesn't know (written by a newer app) degrades instead of failing the whole design:
    // unknown layers are dropped, an unknown effect is none, an unknown pattern becomes its base color.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let b = try? c.decode(Background.self, forKey: .background) {
            background = b
        } else {
            background = .color((try? c.decode(PatternBase.self, forKey: .background))?.pattern.base ?? RGBA(r: 1, g: 1, b: 1))
        }
        layers = try c.decode([Lossy<Layer>].self, forKey: .layers).compactMap(\.value)
        effect = (try? c.decode(Effect.self, forKey: .effect)) ?? .none
        envelope = try c.decode(Bool.self, forKey: .envelope)
    }
}

extension Design {
    /// Every stored image this design draws: the background photo and image layers.
    public var imagePaths: [String] {
        var paths = layers.compactMap { if case .image(let p) = $0.kind { p } else { nil } }
        if case .image(let p) = background { paths.insert(p, at: 0) }
        return paths
    }

    /// Appends a layer on top and returns it.
    @discardableResult
    public mutating func addLayer(_ kind: LayerKind) -> Layer {
        let l = Layer(kind: kind)
        layers.append(l)
        return l
    }

    /// Moves a layer up (positive) or down (negative) the stack, clamped to the ends.
    public mutating func moveLayer(id: UUID, by delta: Int) {
        guard let i = layers.firstIndex(where: { $0.id == id }) else { return }
        let j = min(max(i + delta, 0), layers.count - 1)
        layers.insert(layers.remove(at: i), at: j)
    }

    /// Copies a layer just above the original, nudged down-right so it's visible. Returns the copy's id.
    public mutating func duplicateLayer(id: UUID) -> UUID? {
        guard let i = layers.firstIndex(where: { $0.id == id }) else { return nil }
        var copy = layers[i]
        copy.id = UUID()
        copy.x = min(copy.x + 0.04, 1); copy.y = min(copy.y + 0.03, 1)
        layers.insert(copy, at: i + 1)
        return copy.id
    }
}

private struct PatternBase: Decodable {
    struct Inner: Decodable {
        let base: RGBA
        enum CodingKeys: String, CodingKey { case base = "_1" }
    }
    let pattern: Inner
}

private struct Lossy<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}
