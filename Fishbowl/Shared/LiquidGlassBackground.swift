import SwiftUI

struct LiquidGlassBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            baseColor

            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.9)

            Circle()
                .fill(Color(red: 0.34, green: 0.84, blue: 0.95).opacity(colorScheme == .dark ? 0.16 : 0.18))
                .frame(width: 360, height: 360)
                .blur(radius: 64)
                .offset(x: -150, y: -210)
                .blendMode(colorScheme == .dark ? .screen : .normal)

            Circle()
                .fill(Color(red: 0.97, green: 0.38, blue: 0.55).opacity(colorScheme == .dark ? 0.12 : 0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 54)
                .offset(x: 160, y: -36)
                .blendMode(colorScheme == .dark ? .screen : .normal)

            Circle()
                .fill(Color(red: 0.96, green: 0.75, blue: 0.39).opacity(colorScheme == .dark ? 0.14 : 0.18))
                .frame(width: 240, height: 240)
                .blur(radius: 48)
                .offset(x: -36, y: 260)
                .blendMode(colorScheme == .dark ? .screen : .normal)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: sheenColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blendMode(.screen)
        }
        .ignoresSafeArea()
    }

    private var baseColor: Color {
        colorScheme == .dark
        ? Color.black
        : Color(red: 0.95, green: 0.96, blue: 0.98)
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.08, green: 0.10, blue: 0.14).opacity(0.76),
                Color(red: 0.05, green: 0.07, blue: 0.12).opacity(0.72),
                Color(red: 0.09, green: 0.07, blue: 0.12).opacity(0.74),
            ]
        }

        return [
            Color.white.opacity(0.70),
            Color(red: 0.88, green: 0.92, blue: 0.97),
            Color(red: 0.94, green: 0.93, blue: 0.97),
        ]
    }

    private var sheenColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.white.opacity(0.22),
                Color.white.opacity(0.02),
            ]
        }

        return [
            Color.white.opacity(0.78),
            Color.white.opacity(0.06),
        ]
    }
}

struct GlassPanel<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    private let cornerRadius: CGFloat
    private let showsGlassEffect: Bool
    private let content: Content

    init(
        cornerRadius: CGFloat = 30,
        showsGlassEffect: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.showsGlassEffect = showsGlassEffect
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .padding(20)
            .background {
                shape
                    .fill(baseFill)
                    .modifier(OptionalGlassEffect(isEnabled: showsGlassEffect, shape: shape))
                    .overlay {
                        shape
                            .stroke(
                                LinearGradient(
                                    colors: strokeColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: shadowColor, radius: showsGlassEffect ? 26 : 18, y: showsGlassEffect ? 12 : 8)
            }
    }

    private var baseFill: Color {
        if showsGlassEffect {
            return colorScheme == .dark ? Color.black.opacity(0.22) : Color.white.opacity(0.10)
        }

        return colorScheme == .dark
        ? Color(red: 0.10, green: 0.11, blue: 0.15).opacity(0.84)
        : Color.white.opacity(0.78)
    }

    private var strokeColors: [Color] {
        if !showsGlassEffect {
            if colorScheme == .dark {
                return [
                    Color.white.opacity(0.20),
                    Color.white.opacity(0.05),
                ]
            }

            return [
                Color.white.opacity(0.82),
                Color.black.opacity(0.04),
            ]
        }

        if colorScheme == .dark {
            return [
                Color.white.opacity(0.34),
                Color.white.opacity(0.08),
            ]
        }

        return [
            Color.white.opacity(0.92),
            Color.white.opacity(0.16),
        ]
    }

    private var shadowColor: Color {
        if showsGlassEffect {
            return colorScheme == .dark ? Color.black.opacity(0.30) : Color.black.opacity(0.08)
        }

        return colorScheme == .dark ? Color.black.opacity(0.22) : Color.black.opacity(0.06)
    }
}

private struct OptionalGlassEffect<S: InsettableShape>: ViewModifier {
    let isEnabled: Bool
    let shape: S

    func body(content: Content) -> some View {
        if isEnabled {
            content.glassEffect(.regular, in: shape)
        } else {
            content
        }
    }
}

struct SectionEyebrow: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.secondary)

            Text(detail)
                .font(.system(size: 17, weight: .medium, design: .serif))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.88) : Color.black.opacity(0.84))
        }
    }
}

struct SelectablePill: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let subtitle: String?
    let isSelected: Bool
    var badge: String? = nil
    var isLocked: Bool = false
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(titleColor)

                    Spacer(minLength: 0)

                    if let badge {
                        Text(badge.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.9)
                            .foregroundStyle(Color(red: 0.64, green: 0.48, blue: 0.08))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(badgeFill)
                                    .overlay {
                                        Capsule(style: .continuous)
                                            .stroke(badgeStroke, lineWidth: 0.8)
                                    }
                            }
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(subtitleColor)
                        .lineLimit(2)
                        .frame(maxWidth: 132, alignment: .leading)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 64, alignment: .leading)
            .background {
                shape
                    .fill(
                        LinearGradient(
                            colors: backgroundColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        shape.stroke(
                            isSelected
                            ? LinearGradient(
                                colors: selectedStrokeColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: regularStrokeColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isSelected ? 1.4 : 1
                        )
                    }
                    .shadow(
                        color: isSelected
                        ? Color(red: 0.43, green: 0.79, blue: 0.95).opacity(0.14)
                        : Color.clear,
                        radius: 10,
                        y: 4
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var titleColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(isLocked ? 0.64 : 0.90)
        }
        return Color.black.opacity(isLocked ? 0.70 : 0.88)
    }

    private var subtitleColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(isLocked ? 0.38 : 0.56)
        }
        return Color.black.opacity(isLocked ? 0.46 : 0.58)
    }

    private var badgeFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.72)
    }

    private var badgeStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.20) : Color.white.opacity(0.92)
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.white.opacity(isSelected ? 0.14 : (isLocked ? 0.09 : 0.07)),
                Color.white.opacity(isSelected ? 0.06 : (isLocked ? 0.04 : 0.03)),
            ]
        }

        return [
            Color.white.opacity(isSelected ? 0.30 : (isLocked ? 0.24 : 0.18)),
            Color.white.opacity(isSelected ? 0.16 : (isLocked ? 0.14 : 0.08)),
        ]
    }

    private var selectedStrokeColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.white.opacity(0.54),
                Color(red: 0.46, green: 0.83, blue: 0.98).opacity(0.56),
            ]
        }

        return [
            Color.white.opacity(0.96),
            Color(red: 0.46, green: 0.83, blue: 0.98).opacity(0.65),
        ]
    }

    private var regularStrokeColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.white.opacity(isLocked ? 0.26 : 0.22),
                Color.white.opacity(isLocked ? 0.08 : 0.05),
            ]
        }

        return [
            Color.white.opacity(isLocked ? 0.88 : 0.75),
            Color.white.opacity(isLocked ? 0.28 : 0.16),
        ]
    }
}

struct AquariumTileBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: baseGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: topGlowColors,
                center: .top,
                startRadius: 12,
                endRadius: 220
            )

            LinearGradient(
                colors: shadowGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 24)
        }
    }

    private var baseGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.16, green: 0.18, blue: 0.24),
                Color(red: 0.10, green: 0.11, blue: 0.15),
            ]
        }

        return [
            Color(red: 0.90, green: 0.92, blue: 0.96),
            Color(red: 0.82, green: 0.84, blue: 0.90),
        ]
    }

    private var topGlowColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.white.opacity(0.22),
                Color.clear,
            ]
        }

        return [
            Color.white.opacity(0.78),
            Color.clear,
        ]
    }

    private var shadowGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.black.opacity(0.28),
                Color.clear,
                Color.black.opacity(0.18),
            ]
        }

        return [
            Color.black.opacity(0.14),
            Color.clear,
            Color.black.opacity(0.08),
        ]
    }
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
