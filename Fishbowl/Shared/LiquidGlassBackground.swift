import SwiftUI

enum GlassPalette {
    static let ivory = Color(red: 0.95, green: 0.95, blue: 0.91)
    static let ink = Color(red: 0.16, green: 0.25, blue: 0.25)
    static let sea = Color(red: 0.25, green: 0.49, blue: 0.47)
    static let mist = Color(red: 0.68, green: 0.83, blue: 0.79)
    static let gold = Color(red: 0.60, green: 0.48, blue: 0.29)
    static let night = Color(red: 0.075, green: 0.13, blue: 0.14)
}

struct LiquidGlassBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                colorScheme == .dark ? GlassPalette.night : GlassPalette.ivory
                RadialGradient(colors: [.white.opacity(colorScheme == .dark ? 0.06 : 0.90), .clear],
                               center: .topLeading, startRadius: 0, endRadius: geometry.size.height * 0.7)
                Ellipse()
                    .fill(GlassPalette.mist.opacity(colorScheme == .dark ? 0.12 : 0.30))
                    .frame(width: geometry.size.width * 1.15, height: geometry.size.height * 0.42)
                    .blur(radius: 75)
                    .offset(x: geometry.size.width * 0.25, y: geometry.size.height * 0.25)
                Canvas { context, size in
                    for index in 0..<5 {
                        let offset = CGFloat(index) * size.width * 0.16
                        var path = Path()
                        path.move(to: CGPoint(x: -size.width * 0.7 + offset, y: -30))
                        path.addCurve(to: CGPoint(x: size.width * 1.1 + offset, y: size.height * 1.1),
                                      control1: CGPoint(x: size.width * 1.1 + offset, y: size.height * 0.2),
                                      control2: CGPoint(x: -size.width * 0.2 + offset, y: size.height * 0.55))
                        context.stroke(path, with: .color(.white.opacity(colorScheme == .dark ? 0.045 : 0.38)), lineWidth: index == 1 ? 2.5 : 1)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct GlassPanel<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let cornerRadius: CGFloat
    private let content: Content

    init(cornerRadius: CGFloat = 26, showsGlassEffect: Bool = true, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(colorScheme == .dark ? Color.white.opacity(0.045) : Color.white.opacity(0.46),
                        in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.white.opacity(colorScheme == .dark ? 0.09 : 0.72), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

struct StudioSectionHeading: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(.title2, design: .serif).weight(.regular))
            if !detail.isEmpty {
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SelectablePill: View {
    @ScaledMetric(relativeTo: .caption) private var captionHeight: CGFloat = 34
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String?
    let isSelected: Bool
    var badge: String? = nil
    var isLocked: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(title).font(.subheadline.weight(.medium))
                    if isSelected {
                        Image(systemName: "checkmark").font(.caption.weight(.semibold))
                    } else if badge != nil {
                        Image(systemName: isLocked ? "lock" : "sparkle")
                            .font(.caption).foregroundStyle(GlassPalette.gold)
                    }
                }
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2).frame(width: 155, height: captionHeight, alignment: .topLeading)
                }
            }
            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.88) : GlassPalette.ink)
            .padding(.horizontal, 17).padding(.vertical, 13)
            .frame(minHeight: 50, alignment: .leading)
            .background(isSelected ? GlassPalette.mist.opacity(colorScheme == .dark ? 0.16 : 0.42)
                        : Color.white.opacity(colorScheme == .dark ? 0.04 : 0.42), in: .rect(cornerRadius: 19))
            .overlay {
                RoundedRectangle(cornerRadius: 19)
                    .strokeBorder(isSelected ? GlassPalette.sea.opacity(0.58)
                                  : Color.white.opacity(colorScheme == .dark ? 0.09 : 0.85), lineWidth: 1)
            }
        }
        .buttonStyle(GlassPressStyle())
        .fixedSize(horizontal: true, vertical: true)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isLocked ? "Premium" : "")
    }
}

struct GlassPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

struct AquariumTileBackground: View {
    var body: some View { LiquidGlassBackdrop() }
}

struct AquariumAppIconArtwork: View {
    var configuration: AquariumConfiguration = .appIcon
    var phase: Double = 0.72

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height) * 0.84

            ZStack {
                AquariumTileBackground()

                AquariumSceneView(
                    configuration: configuration,
                    format: .appIcon,
                    phase: phase,
                    petSnapshot: .decorative(at: Date(timeIntervalSinceReferenceDate: 0))
                )
                .frame(width: side, height: side)
                .drawingGroup(opaque: false)
            }
        }
    }
}
