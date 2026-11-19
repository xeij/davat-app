import SwiftUI

/// Star with `points` tips; `inner` is the inner radius as a fraction of the outer.
public struct StarShape: Shape {
    var points = 5, inner = 0.45
    public init(points: Int = 5, inner: Double = 0.45) { self.points = points; self.inner = inner }
    public func path(in r: CGRect) -> Path {
        Path { p in
            for i in 0..<points * 2 {
                let a = Double(i) * .pi / Double(points) - .pi / 2
                let k = i.isMultiple(of: 2) ? 1 : inner
                let pt = CGPoint(x: r.midX + cos(a) * r.width / 2 * k, y: r.midY + sin(a) * r.height / 2 * k)
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
            p.closeSubpath()
        }
    }
}

public struct HeartShape: Shape {
    public init() {}
    public func path(in r: CGRect) -> Path {
        func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        return Path { p in
            p.move(to: pt(0.5, 0.97))
            p.addCurve(to: pt(0, 0.33), control1: pt(0.2, 0.78), control2: pt(0, 0.56))
            p.addCurve(to: pt(0.5, 0.2), control1: pt(0, 0.02), control2: pt(0.4, -0.04))
            p.addCurve(to: pt(1, 0.33), control1: pt(0.6, -0.04), control2: pt(1, 0.02))
            p.addCurve(to: pt(0.5, 0.97), control1: pt(1, 0.56), control2: pt(0.8, 0.78))
            p.closeSubpath()
        }
    }
}

/// A soft organic blob: a closed smooth curve through fixed uneven radii.
public struct BlobShape: Shape {
    public init() {}
    private static let radii: [Double] = [1, 0.82, 0.95, 0.78, 1, 0.86, 0.93, 0.8]
    public func path(in r: CGRect) -> Path {
        let n = Self.radii.count
        let pts = (0..<n).map { i -> CGPoint in
            let a = Double(i) / Double(n) * 2 * .pi
            return CGPoint(x: r.midX + cos(a) * r.width / 2 * Self.radii[i], y: r.midY + sin(a) * r.height / 2 * Self.radii[i])
        }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        return Path { p in
            p.move(to: mid(pts[n - 1], pts[0]))
            for i in 0..<n { p.addQuadCurve(to: mid(pts[i], pts[(i + 1) % n]), control: pts[i]) }
            p.closeSubpath()
        }
    }
}

extension ShapeLayer.Kind {
    func path(in r: CGRect) -> Path {
        switch self {
        case .circle: Ellipse().path(in: r)
        case .rect: Rectangle().path(in: r)
        case .star: StarShape().path(in: r)
        case .heart: HeartShape().path(in: r)
        case .blob: BlobShape().path(in: r)
        }
    }
}
