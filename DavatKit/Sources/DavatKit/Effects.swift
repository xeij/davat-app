import SwiftUI

/// Animated particles over the canvas. Particles are generated once per effect and positions are a
/// pure function of time, so a frame only reads arrays and fills prebuilt paths. Reduce Motion
/// freezes it on a single frame.
public struct EffectOverlay: View {
    let effect: Effect
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(effect: Effect) { self.effect = effect }

    public var body: some View {
        if effect != .none {
            let system = ParticleSystem.for(effect)
            TimelineView(.animation(paused: reduceMotion)) { tl in
                Canvas { ctx, size in
                    system.draw(in: &ctx, size: size, t: reduceMotion ? 4 : tl.date.timeIntervalSinceReferenceDate)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

struct Particle: Sendable {
    var x, y, speed, size, phase, sway, spin: Double
    var color: Int
}

struct ParticleSystem: Sendable {
    enum Motion { case fall, rise, twinkle }
    let particles: [Particle]
    let path: Path            // unit path centred on the origin
    let colors: [Color]
    let motion: Motion
    let stroke: Bool
    let flutter: Bool         // confetti-style flip as it falls

    func draw(in ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let u = size.width / CanvasView.baseWidth
        for p in particles {
            var y = p.y, alpha = 1.0, scale = p.size * u
            switch motion {
            case .fall: y = (p.y + t * p.speed).truncatingRemainder(dividingBy: 1.1) - 0.05
            case .rise: y = 1.05 - (p.y + t * p.speed).truncatingRemainder(dividingBy: 1.1)
            case .twinkle:
                let s = sin(t * p.speed * 6 + p.phase)
                alpha = max(0, s); scale *= 0.4 + 0.6 * max(0, s)
            }
            guard alpha > 0.02 else { continue }
            let x = p.x + sin(t * 0.9 + p.phase) * p.sway
            var c = ctx
            c.opacity = alpha
            c.translateBy(x: x * size.width, y: y * size.height)
            c.rotate(by: .radians(p.phase + t * p.spin))
            c.scaleBy(x: flutter ? scale * cos(t * p.spin * 1.7 + p.phase) : scale, y: scale)
            let shading = GraphicsContext.Shading.color(colors[p.color])
            if stroke { c.stroke(path, with: shading, lineWidth: 0.12) } else { c.fill(path, with: shading) }
        }
    }

    static func `for`(_ e: Effect) -> ParticleSystem {
        switch e {
        case .none, .confetti: confetti
        case .snow: snow
        case .sparkle: sparkle
        case .hearts: hearts
        case .bubbles: bubbles
        case .petals: petals
        }
    }

    private static let unit = CGRect(x: -0.5, y: -0.5, width: 1, height: 1)

    static let confetti = ParticleSystem(
        particles: make(70, speed: 0.08...0.18, size: 7...12, sway: 0.01...0.04, spin: 1...4, colors: 6),
        path: Path(CGRect(x: -0.5, y: -0.25, width: 1, height: 0.5)),
        colors: [.pink, .yellow, .cyan, .orange, .purple, .green], motion: .fall, stroke: false, flutter: true)
    static let snow = ParticleSystem(
        particles: make(90, speed: 0.025...0.07, size: 3...8, sway: 0.01...0.03, spin: 0...0, colors: 2),
        path: Path(ellipseIn: unit), colors: [.white, .white.opacity(0.7)], motion: .fall, stroke: false, flutter: false)
    static let sparkle = ParticleSystem(
        particles: make(45, speed: 0.2...0.6, size: 8...20, sway: 0...0, spin: 0...0, colors: 3),
        path: StarShape(points: 4, inner: 0.22).path(in: unit),
        colors: [.white, Color(red: 1, green: 0.88, blue: 0.55), Color(red: 1, green: 0.75, blue: 0.95)],
        motion: .twinkle, stroke: false, flutter: false)
    static let hearts = ParticleSystem(
        particles: make(28, speed: 0.04...0.09, size: 12...24, sway: 0.02...0.05, spin: -0.3...0.3, colors: 3),
        path: HeartShape().path(in: unit),
        colors: [Color(red: 1, green: 0.3, blue: 0.43), Color(red: 1, green: 0.56, blue: 0.67), .white],
        motion: .rise, stroke: false, flutter: false)
    static let bubbles = ParticleSystem(
        particles: make(32, speed: 0.04...0.1, size: 8...26, sway: 0.01...0.03, spin: 0...0, colors: 2),
        path: Path(ellipseIn: unit), colors: [.white.opacity(0.8), .white.opacity(0.5)],
        motion: .rise, stroke: true, flutter: false)
    static let petals = ParticleSystem(
        particles: make(40, speed: 0.03...0.07, size: 8...14, sway: 0.03...0.07, spin: -1.5...1.5, colors: 3),
        path: Path(ellipseIn: CGRect(x: -0.5, y: -0.3, width: 1, height: 0.6)),
        colors: [Color(red: 1, green: 0.78, blue: 0.85), Color(red: 0.98, green: 0.65, blue: 0.75), Color(red: 0.8, green: 0.7, blue: 0.95)],
        motion: .fall, stroke: false, flutter: true)

    /// Deterministic so every render of the same effect matches.
    private static func make(_ n: Int, speed: ClosedRange<Double>, size: ClosedRange<Double>, sway: ClosedRange<Double>,
                             spin: ClosedRange<Double>, colors: Int) -> [Particle] {
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func rnd(_ r: ClosedRange<Double>) -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return r.lowerBound + Double(seed >> 11) / Double(1 << 53) * (r.upperBound - r.lowerBound)
        }
        return (0..<n).map { _ in
            Particle(x: rnd(0...1), y: rnd(0...1), speed: rnd(speed), size: rnd(size), phase: rnd(0...(2 * .pi)),
                     sway: rnd(sway), spin: rnd(spin), color: Int(rnd(0...Double(colors) - 0.001)))
        }
    }
}
