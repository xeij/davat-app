import CoreGraphics
import Foundation

public struct RGBA: Codable, Hashable, Sendable {
    public var r: Double, g: Double, b: Double, a: Double
    public init(r: Double, g: Double, b: Double, a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
}

public enum PatternKind: String, Codable, CaseIterable, Sendable { case dots, stripes, grid, waves }

public enum Background: Codable, Hashable, Sendable {
    case color(RGBA)
    case gradient([RGBA], angle: Double)
    case pattern(PatternKind, RGBA, RGBA)
    case image(path: String)
}

public enum Effect: String, Codable, CaseIterable, Sendable { case none, confetti, snow, sparkle, hearts }

public struct TextLayer: Codable, Hashable, Sendable {
    public var text: String
    public var fontName: String          // PostScript name or "system"
    public var size: Double
    public var weight: Double            // 0...1 mapped by the renderer
    public var color: RGBA
    public var alignment: Alignment
    public var outline: RGBA?
    public var outlineWidth: Double
    public var shadow: Bool
    public var curve: Double             // -1...1
    public var letterSpacing: Double

    public enum Alignment: String, Codable, Sendable { case leading, center, trailing }

    public init(text: String, fontName: String = "system", size: Double = 48, weight: Double = 0.2, color: RGBA,
                alignment: Alignment = .center, outline: RGBA? = nil, outlineWidth: Double = 0,
                shadow: Bool = false, curve: Double = 0, letterSpacing: Double = 0) {
        self.text = text; self.fontName = fontName; self.size = size; self.weight = weight; self.color = color
        self.alignment = alignment; self.outline = outline; self.outlineWidth = outlineWidth
        self.shadow = shadow; self.curve = curve; self.letterSpacing = letterSpacing
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

    // Layers with a kind this build doesn't know (written by a newer app) are dropped, not fatal.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        background = try c.decode(Background.self, forKey: .background)
        layers = try c.decode([Lossy<Layer>].self, forKey: .layers).compactMap(\.value)
        effect = try c.decode(Effect.self, forKey: .effect)
        envelope = try c.decode(Bool.self, forKey: .envelope)
    }
}

private struct Lossy<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}
