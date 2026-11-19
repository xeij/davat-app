import SwiftUI

/// Renders a Design at any size with a 9:16 aspect. Positions are canvas fractions and every
/// size is in points of a 390-wide canvas, scaled by the actual width, so a thumbnail, the editor
/// and a 1080x1920 export all look the same. Images come from `imageLoader` synchronously.
public struct CanvasView: View {
    nonisolated public static let baseWidth: CGFloat = 390
    let design: Design
    let imageLoader: (String) -> Image?
    let selection: Binding<UUID?>?
    let showsEffect: Bool

    public init(design: Design, imageLoader: @escaping (String) -> Image?, selection: Binding<UUID?>? = nil,
                showsEffect: Bool = true) {
        self.design = design; self.imageLoader = imageLoader; self.selection = selection; self.showsEffect = showsEffect
    }

    public var body: some View {
        GeometryReader { geo in
            let size = geo.size, u = size.width / Self.baseWidth
            ZStack {
                BackgroundView(background: design.background, unit: u, imageLoader: imageLoader)
                    .frame(width: size.width, height: size.height)
                    .contentShape(Rectangle())
                    .onTapGesture { selection?.wrappedValue = nil }
                    .allowsHitTesting(selection != nil)   // display-only canvases let taps reach their container
                ForEach(design.layers) { layer in
                    LayerView(layer: layer, unit: u, imageLoader: imageLoader)
                        .overlay {
                            if selection?.wrappedValue == layer.id {
                                Rectangle()
                                    .stroke(.white, style: StrokeStyle(lineWidth: 1.5 / max(layer.scale, 0.1), dash: [5, 4]))
                                    .shadow(color: .black.opacity(0.5), radius: 1)
                                    .padding(-6 * u)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selection?.wrappedValue = layer.id }
                        .allowsHitTesting(selection != nil)
                        .scaleEffect(layer.scale)
                        .rotationEffect(.degrees(layer.rotation))
                        .opacity(layer.opacity)
                        .position(x: layer.x * size.width, y: layer.y * size.height)
                }
                if showsEffect { EffectOverlay(effect: design.effect) }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .aspectRatio(9 / 16, contentMode: .fit)
    }
}

extension RGBA {
    public var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
    public init(_ color: Color) {
        let c = color.resolve(in: EnvironmentValues())
        self.init(r: Double(c.red), g: Double(c.green), b: Double(c.blue), a: Double(c.opacity))
    }
}

struct BackgroundView: View {
    let background: Background
    let unit: CGFloat
    let imageLoader: (String) -> Image?

    var body: some View {
        switch background {
        case .color(let c): c.color
        case .gradient(let cs, let angle):
            let a = angle * .pi / 180, dx = sin(a) / 2, dy = cos(a) / 2   // CSS angles: 180 is top to bottom
            LinearGradient(colors: cs.map(\.color), startPoint: UnitPoint(x: 0.5 - dx, y: 0.5 + dy),
                           endPoint: UnitPoint(x: 0.5 + dx, y: 0.5 - dy))
        case .pattern(let kind, let bg, let fg):
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(bg.color))
                drawPattern(kind, fg: fg.color, in: &ctx, size: size, u: unit)
            }
        case .image(let path):
            if let img = imageLoader(path) {
                Color.clear.overlay { img.resizable().scaledToFill() }.clipped()
            } else {
                Color.gray.opacity(0.3)
            }
        }
    }
}

func drawPattern(_ kind: PatternKind, fg: Color, in ctx: inout GraphicsContext, size: CGSize, u: CGFloat) {
    let cell = 28 * u
    let cols = Int(size.width / cell) + 2, rows = Int(size.height / cell) + 2
    let shading = GraphicsContext.Shading.color(fg)
    func each(_ step: CGFloat = 1, _ body: (CGPoint, Int, Int) -> Void) {
        for r in 0..<Int(Double(rows) / step) + 1 {
            for c in 0..<Int(Double(cols) / step) + 1 {
                let x = CGFloat(c) * cell * step + (r.isMultiple(of: 2) ? 0 : cell * step / 2)
                body(CGPoint(x: x, y: CGFloat(r) * cell * step), r, c)
            }
        }
    }
    switch kind {
    case .dots:
        each { p, _, _ in ctx.fill(Path(ellipseIn: CGRect(x: p.x - 3.5 * u, y: p.y - 3.5 * u, width: 7 * u, height: 7 * u)), with: shading) }
    case .stripes:
        var path = Path()
        for i in stride(from: -size.height, through: size.width, by: cell) {
            path.move(to: CGPoint(x: i, y: size.height)); path.addLine(to: CGPoint(x: i + size.height, y: 0))
        }
        ctx.stroke(path, with: shading, lineWidth: cell / 3)
    case .grid:
        var path = Path()
        for c in 0...cols { path.move(to: CGPoint(x: CGFloat(c) * cell, y: 0)); path.addLine(to: CGPoint(x: CGFloat(c) * cell, y: size.height)) }
        for r in 0...rows { path.move(to: CGPoint(x: 0, y: CGFloat(r) * cell)); path.addLine(to: CGPoint(x: size.width, y: CGFloat(r) * cell)) }
        ctx.stroke(path, with: shading, lineWidth: 1.2 * u)
    case .waves:
        var path = Path()
        for r in 0...rows {
            let y0 = CGFloat(r) * cell
            path.move(to: CGPoint(x: 0, y: y0))
            for x in stride(from: CGFloat(0), through: size.width, by: 4 * u) {
                path.addLine(to: CGPoint(x: x, y: y0 + sin(x / cell * .pi) * cell / 5))
            }
        }
        ctx.stroke(path, with: shading, lineWidth: 3 * u)
    case .checker:
        let big = cell * 1.6
        for r in 0..<Int(size.height / big) + 1 {
            for c in 0..<Int(size.width / big) + 1 where (r + c).isMultiple(of: 2) {
                ctx.fill(Path(CGRect(x: CGFloat(c) * big, y: CGFloat(r) * big, width: big, height: big)), with: shading)
            }
        }
    case .hearts:
        each(1.5) { p, _, _ in ctx.fill(HeartShape().path(in: CGRect(x: p.x - 7 * u, y: p.y - 6 * u, width: 14 * u, height: 12 * u)), with: shading) }
    case .flowers:
        each(1.8) { p, _, _ in
            for k in 0..<5 {
                let a = Double(k) / 5 * 2 * .pi
                let c = CGPoint(x: p.x + cos(a) * 5 * u, y: p.y + sin(a) * 5 * u)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 4 * u, y: c.y - 4 * u, width: 8 * u, height: 8 * u)), with: shading)
            }
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2.5 * u, y: p.y - 2.5 * u, width: 5 * u, height: 5 * u)), with: .color(.white.opacity(0.9)))
        }
    case .stars:
        each(2) { p, r, c in
            let s = CGFloat((r * 7 + c * 13) % 5 + 4) * u   // uneven sizes, deterministic
            ctx.fill(StarShape().path(in: CGRect(x: p.x - s, y: p.y - s, width: s * 2, height: s * 2)), with: shading)
        }
    }
}

struct LayerView: View {
    let layer: Layer
    let unit: CGFloat
    let imageLoader: (String) -> Image?

    var body: some View {
        switch layer.kind {
        case .text(let t): TextLayerView(t: t, u: unit)
        case .emoji(let e): Text(e).font(.system(size: 64 * unit)).fixedSize()
        case .image(let path):
            Group {
                if let img = imageLoader(path) { img.resizable().scaledToFit() } else { Color.gray.opacity(0.3) }
            }
            .frame(width: 200 * unit)
            .frame(maxHeight: 400 * unit)
        case .shape(let s):
            let r = CGRect(x: 0, y: 0, width: s.size.width * unit, height: s.size.height * unit)
            ZStack {
                s.kind.path(in: r).fill(s.fill.color)
                if let st = s.stroke { s.kind.path(in: r).stroke(st.color, lineWidth: 1.5 * unit) }
            }
            .frame(width: r.width, height: r.height)
        }
    }
}

struct TextLayerView: View {
    let t: TextLayer
    let u: CGFloat
    private static let weights: [Font.Weight] = [.ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black]

    private var text: Text {
        let w = Self.weights[Int((min(max(t.weight, 0), 1) * 8).rounded())]
        let font: Font = t.fontName == "system" ? .system(size: t.size * u, weight: w) : .custom(t.fontName, fixedSize: t.size * u)
        return Text(t.text).font(font).tracking(t.letterSpacing * u)
    }

    var body: some View {
        ZStack {
            if let o = t.outline, t.outlineWidth > 0 {
                let w = t.outlineWidth * u
                // ponytail: outline is 16 offset copies; a real stroke needs Core Text paths if it ever looks rough
                ForEach(0..<16, id: \.self) { i in
                    let a = Double(i) * .pi / 8
                    text.foregroundStyle(o.color).offset(x: cos(a) * w, y: sin(a) * w).accessibilityHidden(true)
                }
            }
            if let g = t.gradient, g.count > 1 {
                text.foregroundStyle(LinearGradient(colors: g.map(\.color), startPoint: .top, endPoint: .bottom))
            } else {
                text.foregroundStyle(t.color.color)
            }
        }
        .multilineTextAlignment(t.alignment == .leading ? .leading : t.alignment == .trailing ? .trailing : .center)
        .textRenderer(ArcRenderer(curve: TextLayer.clamp(t.curve)))
        .shadow(color: t.shadow ? .black.opacity(0.35) : .clear, radius: 6 * u, y: 3 * u)
        .padding(.vertical, abs(TextLayer.clamp(t.curve)) * t.size * u * 0.6)   // room for the bend so selection and taps cover it
    }
}

/// Bends each line of text along a circular arc, one glyph at a time. curve 1 sweeps half a circle
/// as an arch, -1 as a smile.
struct ArcRenderer: TextRenderer {
    var curve: Double

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        let sweep = abs(curve) * .pi
        for line in layout {
            guard sweep > 0.01 else { ctx.draw(line); continue }
            let b = line.typographicBounds.rect
            let r = b.width / sweep, sign: Double = curve > 0 ? 1 : -1
            for run in line {
                for glyph in run {
                    let g = glyph.typographicBounds.rect
                    let a = (g.midX - b.midX) / r
                    var c = ctx
                    // Arc is centred on the line's middle so the text sags or rises away from its baseline.
                    c.translateBy(x: b.midX + r * sin(a), y: g.midY + sign * r * (1 - cos(a)) - sign * r * (1 - cos(sweep / 2)) / 2)
                    c.rotate(by: .radians(sign * a))
                    c.translateBy(x: -g.midX, y: -g.midY)
                    c.draw(glyph)
                }
            }
        }
    }
}
