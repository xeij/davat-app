import CoreGraphics
import Foundation

// Sizes are points on a 390-wide canvas; CanvasView scales them with its width.
public enum Templates {
    public static let all: [(name: String, design: Design)] = [
        ("disco birthday", disco), ("bridal shower", bridal), ("absolutely unhinged", unhinged),
        ("dinner at ours", dinner), ("nowruz", nowruz), ("game night", gameNight),
        ("ski trip", ski), ("galentine's", galentines), ("road trip fund", roadTrip),
        ("graduation", graduation), ("baby shower", babyShower), ("pool party", pool), ("book club", bookClub),
    ]

    static let disco = Design(
        background: .gradient([hex(0x1A0533), hex(0x5B1A8C), hex(0xD62AD0), hex(0x1A0533)], angle: 160),
        layers: [
            emoji("✨", x: 0.18, y: 0.12, scale: 0.7, rotation: -15),
            emoji("✨", x: 0.84, y: 0.30, scale: 0.5, rotation: 20),
            emoji("🪩", x: 0.5, y: 0.25, scale: 2.4),
            text("DISCO", font: "Futura-CondensedExtraBold", size: 120, color: hex(0xFFFFFF),
                 gradient: [hex(0xFFFFFF), hex(0xB9B9CC), hex(0xF7F7FF), hex(0x6E6E86), hex(0xFFFFFF)],
                 shadow: true, spacing: 4, x: 0.5, y: 0.52),
            text("maya turns 30", font: "SnellRoundhand-Bold", size: 46, color: hex(0xFF9CE6), shadow: true, x: 0.5, y: 0.66, rotation: -4),
            text("SAT DEC 6  ·  9PM TIL LATE", font: "AvenirNext-DemiBold", size: 15, color: hex(0xFFFFFF), spacing: 3, x: 0.5, y: 0.80),
            text("wear something shiny", font: "AvenirNext-Italic", size: 15, color: hex(0xFFFFFF, 0.7), x: 0.5, y: 0.85),
        ],
        effect: .sparkle)

    static let bridal = Design(
        background: .pattern(.flowers, hex(0xFBEFF2), hex(0xF4C6D3)),
        layers: [
            shape(.rect, fill: hex(0xFFFDFB, 0.92), stroke: hex(0xE7B3C1), w: 300, h: 440, x: 0.5, y: 0.5),
            emoji("🌸", x: 0.2, y: 0.2, scale: 0.9, rotation: -20),
            emoji("🌷", x: 0.82, y: 0.79, scale: 0.9, rotation: 15),
            emoji("🎀", x: 0.5, y: 0.25, scale: 0.8),
            text("a shower for", font: "Cochin-Italic", size: 24, color: hex(0x9C5A6E), x: 0.5, y: 0.34),
            text("Leila", font: "SnellRoundhand-Bold", size: 92, color: hex(0xB5657B), x: 0.5, y: 0.45),
            text("SUNDAY, APRIL 12  ·  1PM", font: "Didot", size: 14, color: hex(0x5E3B45), spacing: 3, x: 0.5, y: 0.58),
            text("tea, cake and far too many flowers", font: "Cochin-Italic", size: 17, color: hex(0x9C5A6E), x: 0.5, y: 0.64),
        ],
        effect: .petals)

    static let unhinged = Design(
        background: .pattern(.checker, hex(0xFFE600), hex(0xFF2BD6)),
        layers: [
            emoji("🦖", x: 0.55, y: 0.6, scale: 4.2, rotation: -12),
            emoji("🍕", x: 0.15, y: 0.16, scale: 1.4, rotation: 25),
            emoji("🤠", x: 0.84, y: 0.13, scale: 1.6, rotation: -18),
            emoji("🎉", x: 0.86, y: 0.88, scale: 1.3, rotation: 10),
            text("PARTY", font: "Impact", size: 124, color: hex(0x00F0FF), outline: hex(0x000000), outlineWidth: 6,
                 shadow: true, x: 0.5, y: 0.3, rotation: -8),
            text("you are legally required to attend", font: "Impact", size: 24, color: hex(0xFFFFFF),
                 outline: hex(0x000000), outlineWidth: 3, curve: 0.45, x: 0.5, y: 0.43),
            text("bring snacks. bring chaos.", font: "MarkerFelt-Wide", size: 28, color: hex(0x000000),
                 outline: hex(0xFFFFFF), outlineWidth: 3, x: 0.42, y: 0.9, rotation: 4),
        ],
        effect: .confetti)

    static let dinner = Design(
        background: .color(hex(0x0E0E0E)),
        layers: [
            text("AT OURS", font: "Didot", size: 14, color: hex(0xFFFFFF, 0.7), spacing: 8, x: 0.5, y: 0.36),
            text("dinner", font: "Didot-Italic", size: 96, color: hex(0xFFFFFF), x: 0.5, y: 0.45),
            shape(.rect, fill: hex(0xFFFFFF), stroke: nil, w: 90, h: 1, x: 0.5, y: 0.54),
            text("friday the 14th, eight o'clock", font: "Didot", size: 17, color: hex(0xFFFFFF), x: 0.5, y: 0.59),
            text("wine encouraged", font: "GillSans-Light", size: 14, color: hex(0x8A8A8A), spacing: 2, x: 0.5, y: 0.88),
        ])

    static let nowruz = Design(
        background: .gradient([hex(0xFFF3C4), hex(0xF6C445), hex(0xE8A317)], angle: 180),
        layers: [
            shape(.blob, fill: hex(0x2E7D32, 0.9), stroke: nil, w: 520, h: 300, x: 0.5, y: 1.0),
            text("نوروز مبارک", font: "system", size: 44, weight: 0.6, color: hex(0x1F5E2E), x: 0.5, y: 0.13),
            text("nowruz mobarak", font: "Baskerville-SemiBoldItalic", size: 46, color: hex(0x1F5E2E), x: 0.5, y: 0.22),
            text("come sit at the haft-sin with us", font: "Cochin-Italic", size: 18, color: hex(0x5A3E00), x: 0.5, y: 0.29),
            emoji("🌱", x: 0.5, y: 0.6, scale: 2.8),
            emoji("🐠", x: 0.2, y: 0.71, scale: 1.3, rotation: -8),
            emoji("🪻", x: 0.82, y: 0.55, scale: 1.7, rotation: 8),
            emoji("🍎", x: 0.25, y: 0.48, scale: 0.9),
            emoji("🪙", x: 0.76, y: 0.74, scale: 0.8),
            emoji("🥚", x: 0.33, y: 0.81, scale: 0.8, rotation: 15),
            text("MARCH 20  ·  6PM", font: "AvenirNext-DemiBold", size: 15, color: hex(0xFFF3C4), spacing: 3, x: 0.5, y: 0.92),
        ],
        effect: .petals)

    static let gameNight = Design(
        background: .pattern(.grid, hex(0x14213D), hex(0x22396B)),
        layers: [
            emoji("🎲", x: 0.2, y: 0.18, scale: 1.6, rotation: -20),
            emoji("🃏", x: 0.8, y: 0.2, scale: 1.5, rotation: 14),
            text("GAME\nNIGHT", font: "Rockwell-Bold", size: 88, color: hex(0xFCA311), outline: hex(0x000000),
                 outlineWidth: 3, shadow: true, x: 0.5, y: 0.45),
            text("loser does the dishes", font: "Noteworthy-Bold", size: 24, color: hex(0xFFFFFF), x: 0.5, y: 0.63, rotation: -3),
            emoji("♟️", x: 0.25, y: 0.8, scale: 1.3),
            emoji("🎮", x: 0.75, y: 0.8, scale: 1.3, rotation: 10),
            text("thursday 7pm  ·  bring a game", font: "AvenirNext-Medium", size: 15, color: hex(0xE5E5E5), x: 0.5, y: 0.92),
        ])

    static let ski = Design(
        background: .gradient([hex(0x6A9BD8), hex(0xC2E3FB), hex(0xFFFFFF)], angle: 180),
        layers: [
            emoji("🏔️", x: 0.5, y: 0.82, scale: 5),
            text("SKI TRIP", font: "Futura-Bold", size: 60, color: hex(0x0B2545), spacing: 4, x: 0.5, y: 0.2),
            text("tahoe  ·  jan 16 to 19", font: "AvenirNext-DemiBold", size: 18, color: hex(0x13315C), x: 0.5, y: 0.28),
            emoji("⛷️", x: 0.7, y: 0.46, scale: 2, rotation: -10),
            text("the cabin has a hot tub. pack a swimsuit.", font: "AvenirNext-Medium", size: 15,
                 color: hex(0x13315C), x: 0.5, y: 0.34),
        ],
        effect: .snow)

    static let galentines = Design(
        background: .pattern(.hearts, hex(0xFFD6E0), hex(0xFFB3C6)),
        layers: [
            shape(.heart, fill: hex(0xFF4D6D), stroke: nil, w: 330, h: 300, x: 0.5, y: 0.45),
            text("galentine's", font: "SavoyeLetPlain", size: 84, color: hex(0xFFFFFF), shadow: true, x: 0.5, y: 0.42),
            text("brunch, bubbles, no boys", font: "AmericanTypewriter", size: 18, color: hex(0xFFF0F3), x: 0.5, y: 0.5),
            emoji("💌", x: 0.2, y: 0.15, scale: 1.2, rotation: -14),
            emoji("🍓", x: 0.82, y: 0.17, scale: 1.1, rotation: 12),
            emoji("🥂", x: 0.78, y: 0.76, scale: 1.4),
            emoji("💅", x: 0.22, y: 0.78, scale: 1.2, rotation: -6),
            text("FEB 13  ·  11AM  ·  my place", font: "AmericanTypewriter-Semibold", size: 15, color: hex(0xC9184A),
                 spacing: 2, x: 0.5, y: 0.9),
        ],
        effect: .hearts)

    static let roadTrip = Design(
        background: .gradient([hex(0xFF5F6D), hex(0xFF9966), hex(0xFFC371)], angle: 200),
        layers: [
            text("ROAD TRIP", font: "Rockwell-Bold", size: 62, color: hex(0xFFFFFF), outline: hex(0x3D1E6D),
                 outlineWidth: 4, curve: 0.35, x: 0.5, y: 0.17),
            emoji("🚐", x: 0.5, y: 0.42, scale: 3.6),
            emoji("🌵", x: 0.12, y: 0.55, scale: 1.4),
            emoji("🗺️", x: 0.85, y: 0.27, scale: 1, rotation: 12),
            text("help us get to joshua tree", font: "Noteworthy-Bold", size: 28, color: hex(0x3D1E6D), x: 0.5, y: 0.66),
            text("CHIP IN FOR GAS + SNACKS", font: "AvenirNext-Bold", size: 15, color: hex(0xFFFFFF), spacing: 3, x: 0.5, y: 0.74),
            emoji("⛽", x: 0.86, y: 0.88, scale: 1.1, rotation: -10),
        ])

    static let graduation = Design(
        background: .pattern(.stars, hex(0x0A1F44), hex(0x1C3A70)),
        layers: [
            emoji("🎓", x: 0.5, y: 0.24, scale: 2.8, rotation: -10),
            text("sam's done.", font: "Didot-Bold", size: 64, color: hex(0xFFFFFF), x: 0.5, y: 0.46),
            text("CLASS OF 2026", font: "Copperplate-Bold", size: 34,
                 color: hex(0xD4AF37), gradient: [hex(0xFFF4C2), hex(0xD4AF37), hex(0xF9E79F), hex(0xB8860B)],
                 spacing: 3, x: 0.5, y: 0.55),
            text("backyard party, june 14, 4pm\nthere will be a speech. it will be short.", font: "Optima-Regular",
                 size: 16, color: hex(0xDDE6F5), x: 0.5, y: 0.7),
        ],
        effect: .confetti)

    static let babyShower = Design(
        background: .pattern(.dots, hex(0xEEF6F3), hex(0xCFE5DD)),
        layers: [
            shape(.circle, fill: hex(0xFFFFFF, 0.85), stroke: nil, w: 230, h: 230, x: 0.5, y: 0.3),
            emoji("🧸", x: 0.5, y: 0.3, scale: 2.6),
            emoji("☁️", x: 0.2, y: 0.12, scale: 1.2),
            emoji("☁️", x: 0.84, y: 0.2, scale: 0.9),
            text("oh baby", font: "BradleyHandITCTT-Bold", size: 78, color: hex(0x5E8C7A), x: 0.5, y: 0.56),
            text("a shower for nina and cam", font: "Optima-Regular", size: 19, color: hex(0x44665A), x: 0.5, y: 0.64),
            text("SATURDAY MAY 3  ·  11AM", font: "Optima-Bold", size: 14, color: hex(0x44665A), spacing: 3, x: 0.5, y: 0.7),
            emoji("🍼", x: 0.22, y: 0.84, scale: 1, rotation: -15),
            emoji("🐣", x: 0.78, y: 0.85, scale: 1.1),
        ],
        effect: .bubbles)

    static let pool = Design(
        background: .pattern(.waves, hex(0x00B4D8), hex(0x48CAE4)),
        layers: [
            emoji("🌴", x: 0.12, y: 0.12, scale: 2, rotation: 10),
            emoji("🦩", x: 0.82, y: 0.68, scale: 2.6),
            text("POOL\nPARTY", font: "Futura-CondensedExtraBold", size: 112, color: hex(0xFFFFFF),
                 outline: hex(0xFF4F79), outlineWidth: 5, shadow: true, x: 0.46, y: 0.36, rotation: -5),
            text("cannonballs at 2", font: "MarkerFelt-Wide", size: 30, color: hex(0xFFE66D), outline: hex(0x0077B6),
                 outlineWidth: 2, curve: -0.3, x: 0.42, y: 0.6),
            emoji("🍉", x: 0.2, y: 0.8, scale: 1.5, rotation: -20),
            emoji("🕶️", x: 0.62, y: 0.86, scale: 1.2, rotation: 8),
        ],
        effect: .bubbles)

    static let bookClub = Design(
        background: .color(hex(0xF3EBDD)),
        layers: [
            shape(.rect, fill: hex(0xF3EBDD, 0), stroke: hex(0x7A5C3E), w: 340, h: 620, x: 0.5, y: 0.5),
            shape(.rect, fill: hex(0xF3EBDD, 0), stroke: hex(0x7A5C3E, 0.5), w: 326, h: 606, x: 0.5, y: 0.5),
            emoji("📚", x: 0.5, y: 0.27, scale: 1.4),
            text("book club", font: "HoeflerText-Italic", size: 66, color: hex(0x3B2F2F), x: 0.5, y: 0.4),
            text("this month: whatever we\ndidn't finish last month", font: "Cochin", size: 18, color: hex(0x5A4636), x: 0.5, y: 0.5),
            text("WEDNESDAY  ·  7PM", font: "Cochin-Bold", size: 13, color: hex(0x7A5C3E), spacing: 4, x: 0.5, y: 0.62),
            emoji("☕", x: 0.38, y: 0.76, scale: 0.8),
            emoji("🕯️", x: 0.62, y: 0.76, scale: 0.8),
        ])

    private static func hex(_ v: UInt32, _ a: Double = 1) -> RGBA {
        RGBA(r: Double(v >> 16 & 0xFF) / 255, g: Double(v >> 8 & 0xFF) / 255, b: Double(v & 0xFF) / 255, a: a)
    }

    private static func emoji(_ e: String, x: Double, y: Double, scale: Double = 1, rotation: Double = 0) -> Layer {
        Layer(kind: .emoji(e), x: x, y: y, scale: scale, rotation: rotation)
    }

    private static func shape(_ k: ShapeLayer.Kind, fill: RGBA, stroke: RGBA?, w: Double, h: Double, x: Double, y: Double) -> Layer {
        Layer(kind: .shape(ShapeLayer(kind: k, fill: fill, stroke: stroke, size: CGSize(width: w, height: h))), x: x, y: y)
    }

    private static func text(_ s: String, font: String, size: Double, weight: Double = 0.2, color: RGBA,
                             gradient: [RGBA]? = nil, outline: RGBA? = nil, outlineWidth: Double = 0,
                             shadow: Bool = false, curve: Double = 0, spacing: Double = 0,
                             x: Double, y: Double, rotation: Double = 0) -> Layer {
        Layer(kind: .text(TextLayer(text: s, fontName: font, size: size, weight: weight, color: color, gradient: gradient,
                                    outline: outline, outlineWidth: outlineWidth, shadow: shadow, curve: curve,
                                    letterSpacing: spacing)),
              x: x, y: y, rotation: rotation)
    }
}
