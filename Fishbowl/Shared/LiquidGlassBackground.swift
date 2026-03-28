import SwiftUI

struct LiquidGlassBackdrop: View {
    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.96, blue: 0.98)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.70),
                    Color(red: 0.88, green: 0.92, blue: 0.97),
                    Color(red: 0.94, green: 0.93, blue: 0.97),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.9)

            Circle()
                .fill(Color(red: 0.34, green: 0.84, blue: 0.95).opacity(0.18))
                .frame(width: 360, height: 360)
                .blur(radius: 64)
                .offset(x: -150, y: -210)

            Circle()
                .fill(Color(red: 0.97, green: 0.38, blue: 0.55).opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 54)
                .offset(x: 160, y: -36)

            Circle()
                .fill(Color(red: 0.96, green: 0.75, blue: 0.39).opacity(0.18))
                .frame(width: 240, height: 240)
                .blur(radius: 48)
                .offset(x: -36, y: 260)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.78),
                            Color.white.opacity(0.06),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blendMode(.screen)
        }
        .ignoresSafeArea()
    }
}

struct GlassPanel<Content: View>: View {
    private let cornerRadius: CGFloat
    private let content: Content

    init(cornerRadius: CGFloat = 30, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .padding(20)
            .background {
                shape
                    .fill(Color.white.opacity(0.10))
                    .glassEffect(.regular, in: shape)
                    .overlay {
                        shape
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.92),
                                        Color.white.opacity(0.16),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 26, y: 12)
            }
    }
}

struct SectionEyebrow: View {
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
                .foregroundStyle(Color.black.opacity(0.84))
        }
    }
}

struct SelectablePill: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.88))

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.58))
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
                            colors: [
                                Color.white.opacity(isSelected ? 0.30 : 0.18),
                                Color.white.opacity(isSelected ? 0.16 : 0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        shape.stroke(
                            isSelected
                            ? LinearGradient(
                                colors: [
                                    Color.white.opacity(0.96),
                                    Color(red: 0.46, green: 0.83, blue: 0.98).opacity(0.65),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(0.75),
                                    Color.white.opacity(0.16),
                                ],
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
}
