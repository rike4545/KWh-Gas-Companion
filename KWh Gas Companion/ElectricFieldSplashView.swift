//  ElectricFieldSplashView.swift
//  My KWh Companion
//
//  Minimal Electric Field splash (robust):
//  • Solid black safety background (prevents white screen)
//  • Animated field lines (RK2) with radial glows (no blur filters)
//  • Dark lab gradient + vignette
//  • Legible title + CTA
//  iOS 15+

import SwiftUI

public struct ElectricFieldSplashView: View {
    public var title: String = "My KWh Companion"
    public var subtitle: String = "Electric Field • Energy Flows"
    public var autoAdvanceAfter: TimeInterval = 0
    public var onContinue: () -> Void = {}

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = false

    public init(
        title: String = "My KWh Companion",
        subtitle: String = "Electric Field • Energy Flows",
        autoAdvanceAfter: TimeInterval = 1.6,
        onContinue: @escaping () -> Void = {}
    ) {
        self.title = title
        self.subtitle = subtitle
        self.autoAdvanceAfter = autoAdvanceAfter
        self.onContinue = onContinue
    }

    public var body: some View {
        ZStack {
            // SAFETY BACKGROUND to avoid any white flash
            Color.black.ignoresSafeArea()

            // Dark gradient + vignette
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.06),
                    Color(red: 0.06, green: 0.08, blue: 0.14)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .overlay(
                RadialGradient(colors: [.clear, .black.opacity(0.35)],
                               center: .center, startRadius: 0, endRadius: 900)
                    .ignoresSafeArea()
            )

            // Electric field layer
            ElectricFieldLayer(reduceMotion: reduceMotion)

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.7), radius: 10, y: 3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(subtitle)
                            .font(.footnote.weight(.medium))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
                    }
                    Spacer()
                }
                .padding(.top, 24)
                .padding(.horizontal, 24)

                Spacer()

                // Footer
                VStack(spacing: 12) {
                    LoadingLine(reduced: reduceMotion)
                        .frame(height: 2)
                        .padding(.horizontal, 48)

                    Button {
                        onContinue()
                    } label: {
                        Label("Continue", systemImage: "chevron.right")
                            .font(.callout.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(scheme == .dark ? Color.white : Color.black)
                    .controlSize(.regular)
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                    .padding(.bottom, 22)
                }
            }
        }
        .onAppear {
            guard !started else { return }
            started = true
            if !reduceMotion, autoAdvanceAfter > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + autoAdvanceAfter) {
                    onContinue()
                }
            }
        }
    }
}

// MARK: - Electric Field (robust Canvas)

private struct ElectricFieldLayer: View {
    var reduceMotion: Bool

    // Conservative defaults (render fast, avoid GPU stalls)
    private let seedCount = 14        // per charge
    private let stepsPerLine = 150
    private let stepLen: CGFloat = 0.010
    private let soften: CGFloat = 0.002

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas(opaque: false, colorMode: .extendedLinear) { ctx, size in
                let W = size.width, H = size.height

                // Charges (±q) with small wobble; keep motion gentle
                let baseL = CGPoint(x: 0.32, y: 0.5)
                let baseR = CGPoint(x: 0.68, y: 0.5)
                let wobble: CGFloat = reduceMotion ? 0.0 : 0.024
                let left = CGPoint(
                    x: baseL.x + wobble * CGFloat(sin(t * 0.7)),
                    y: baseL.y + wobble * CGFloat(cos(t * 0.9))
                )
                let right = CGPoint(
                    x: baseR.x + wobble * CGFloat(cos(t * 0.6)),
                    y: baseR.y + wobble * CGFloat(sin(t * 0.75))
                )
                let charges: [(p: CGPoint, q: CGFloat)] = [(left, -1.0), (right, +1.0)]

                // Radial glow WITHOUT blur filter (prevents blank canvases on some GPUs)
                func glow(at p: CGPoint, color: Color, radius: CGFloat) {
                    let center = CGPoint(x: p.x * W, y: p.y * H)
                    let shading = GraphicsContext.Shading.radialGradient(
                        Gradient(colors: [color.opacity(0.35), .clear]),
                        center: center, startRadius: 0, endRadius: radius
                    )
                    let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                    ctx.fill(Path(ellipseIn: rect), with: shading)
                }
                glow(at: left,  color: .cyan,  radius: 90)
                glow(at: right, color: .white, radius: 90)

                // E field function
                func field(_ u: CGPoint) -> CGVector {
                    var vx: CGFloat = 0, vy: CGFloat = 0
                    for c in charges {
                        let dx = u.x - c.p.x, dy = u.y - c.p.y
                        let r2 = dx*dx + dy*dy + soften
                        let inv = c.q / pow(r2, 1.5)
                        vx += dx * inv
                        vy += dy * inv
                    }
                    return CGVector(dx: vx, dy: vy)
                }

                // RK2 step
                func rk2(_ u: CGPoint, h: CGFloat) -> CGPoint {
                    let v1 = field(u)
                    let mid = CGPoint(x: u.x + 0.5 * h * v1.dx, y: u.y + 0.5 * h * v1.dy)
                    let v2 = field(mid)
                    return CGPoint(x: u.x + h * v2.dx, y: u.y + h * v2.dy)
                }

                // Draw streamline
                func drawLine(from seed: CGPoint, direction: CGFloat) {
                    var p = seed
                    var path = Path()
                    path.move(to: CGPoint(x: p.x * W, y: p.y * H))
                    var i = 0
                    while i < stepsPerLine {
                        p = rk2(p, h: stepLen * direction)
                        if !p.x.isFinite || !p.y.isFinite { break }
                        if p.x < -0.1 || p.x > 1.1 || p.y < -0.1 || p.y > 1.1 { break }
                        path.addLine(to: CGPoint(x: p.x * W, y: p.y * H))
                        i += 1
                    }
                    ctx.stroke(path, with: .color(.white.opacity(0.18)), lineWidth: 5)
                    ctx.stroke(path, with: .color(.white.opacity(0.95)), lineWidth: 1.4)
                }

                // Seeds around each charge (ring)
                func seeds(around c: CGPoint, radius: CGFloat, count: Int) -> [CGPoint] {
                    (0..<count).map { k in
                        let a = (CGFloat(k) / CGFloat(count)) * 2 * .pi
                        return CGPoint(x: c.x + radius * cos(a), y: c.y + radius * sin(a))
                    }
                }

                let ringL = seeds(around: left,  radius: 0.08, count: seedCount)
                let ringR = seeds(around: right, radius: 0.08, count: seedCount)

                // Integrate
                for s in ringL { drawLine(from: s, direction: -1) } // from negative backward
                for s in ringR { drawLine(from: s, direction: +1) } // from positive forward

                // Gentle drift particles (no shadows/filters)
                if !reduceMotion {
                    let count = 70
                    for n in 0..<count {
                        let f = CGFloat(n) / CGFloat(count)
                        let px = 0.15 + 0.70 * f
                        let py = 0.35 + 0.30 * CGFloat(abs(sin(Double(n) * 0.37 + t * 0.6)))
                        var p = CGPoint(x: px, y: py)
                        for _ in 0..<6 { p = rk2(p, h: 0.01) }
                        let r: CGFloat = 1.4
                        let dotRect = CGRect(x: p.x * W - r, y: p.y * H - r, width: r*2, height: r*2)
                        ctx.fill(Path(ellipseIn: dotRect), with: .color(.white.opacity(0.9)))
                    }
                }
            }
        }
    }
}

// MARK: - Loading Line

private struct LoadingLine: View {
    @State private var pct: CGFloat = 0.12
    var reduced: Bool = false

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: width * pct)
                    .animation(reduced ? nil :
                               .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                               value: pct)
            }
            .onAppear { pct = reduced ? 0.5 : 0.78 }
        }
    }
}

// MARK: - Preview

#Preview {
    ElectricFieldSplashView(onContinue: {})
        .preferredColorScheme(.dark)
}
