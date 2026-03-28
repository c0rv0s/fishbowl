import SwiftUI

struct ContentView: View {
    @State private var configuration = AquariumConfiguration.hero
    @State private var previewFormat: AquariumDisplayFormat = .studioHero

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidGlassBackdrop()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        heroSection
                        controlsSection
                        setupSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 34)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var heroSection: some View {
        GlassPanel(cornerRadius: 34) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Fishbowl")
                        .font(.system(size: 38, weight: .medium, design: .serif))
                        .foregroundStyle(Color.black.opacity(0.88))

                    Text("A little glass aquarium for your Home Screen, whether you want a single bowl or a wider tank.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.60))
                        .fixedSize(horizontal: false, vertical: true)
                }

                heroPreview

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach([AquariumDisplayFormat.studioHero, .widgetSmall, .widgetMedium, .widgetLarge]) { option in
                            SelectablePill(
                                title: option.title,
                                subtitle: option == .studioHero ? "Big preview" : "Widget size",
                                isSelected: previewFormat == option
                            ) {
                                previewFormat = option
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var heroPreview: some View {
        switch previewFormat {
        case .studioHero:
            AquariumSceneView(
                configuration: previewConfiguration,
                format: previewFormat,
                phase: 0.24
            )
            .frame(maxWidth: .infinity)
            .frame(height: 360)
            .drawingGroup(opaque: false)
            .overlay(alignment: .bottomLeading) {
                heroPlaque
                    .padding(18)
            }
        default:
            VStack(spacing: 14) {
                WidgetSizePreview(
                    configuration: previewConfiguration,
                    format: previewFormat
                )

                heroPlaque
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var heroPlaque: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(configuration.vesselStyle.title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.2)

            Text(configuration.descriptor)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(Color.black.opacity(0.86))

            Text(configuration.detailLine)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.54))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var controlsSection: some View {
        VStack(spacing: 16) {
            GlassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    SectionEyebrow(
                        title: "Vessel",
                        detail: "Choose the kind of bowl or tank you want."
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(AquariumVesselStyle.allCases) { option in
                                SelectablePill(
                                    title: option.title,
                                    subtitle: option.summary,
                                    isSelected: configuration.vesselStyle == option
                                ) {
                                    configuration.vesselStyle = option
                                }
                            }
                        }
                    }
                }
            }

            GlassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    SectionEyebrow(
                        title: "Fish",
                        detail: "Pick the fish and how many you want swimming around."
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(FishSpecies.allCases) { option in
                                SelectablePill(
                                    title: option.title,
                                    subtitle: option.summary,
                                    isSelected: configuration.fishSpecies == option
                                ) {
                                    configuration.fishSpecies = option
                                }
                            }
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(FishCount.allCases) { option in
                                SelectablePill(
                                    title: option.title,
                                    subtitle: "Fish count",
                                    isSelected: configuration.fishCount == option
                                ) {
                                    configuration.fishCount = option
                                }
                            }
                        }
                    }
                }
            }

            GlassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    SectionEyebrow(
                        title: "Habitat",
                        detail: "Choose the bottom and the little details that sit inside the bowl."
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(SubstrateStyle.allCases) { option in
                                SelectablePill(
                                    title: option.title,
                                    subtitle: option.summary,
                                    isSelected: configuration.substrate == option
                                ) {
                                    configuration.substrate = option
                                }
                            }
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(DecorationStyle.allCases) { option in
                                SelectablePill(
                                    title: option.title,
                                    subtitle: option.summary,
                                    isSelected: configuration.decoration == option
                                ) {
                                    configuration.decoration = option
                                }
                            }
                        }
                    }
                }
            }

            GlassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    SectionEyebrow(
                        title: "Companion",
                        detail: "Add a snail, shrimp, or crab, or leave it simple."
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(CompanionStyle.allCases) { option in
                                SelectablePill(
                                    title: option.title,
                                    subtitle: option.summary,
                                    isSelected: configuration.companion == option
                                ) {
                                    configuration.companion = option
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var previewConfiguration: AquariumConfiguration {
        switch previewFormat {
        case .widgetMedium where configuration.vesselStyle == .orb:
            return configuration.withFallbackStyle(.gallery)
        case .widgetLarge where configuration.vesselStyle == .orb:
            return configuration.withFallbackStyle(.panorama)
        default:
            return configuration
        }
    }

    private var setupSection: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow(
                    title: "Widget Setup",
                    detail: "Add the widget to your Home Screen, then long press it to pick the bowl, fish, companion, sand, and decor."
                )

                Text("Use the app to try things out, then set the widget the way you want it to look on your Home Screen.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct WidgetSizePreview: View {
    let configuration: AquariumConfiguration
    let format: AquariumDisplayFormat

    var body: some View {
        GeometryReader { geometry in
            let tileSize = previewTileSize(for: geometry.size.width)
            let tileShape = RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous)

            ZStack {
                tileShape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.93, green: 0.95, blue: 0.98),
                                Color(red: 0.84, green: 0.87, blue: 0.92),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                AquariumSceneView(
                    configuration: configuration,
                    format: format,
                    phase: 0.24
                )
                .padding(tileSceneInset)
                .drawingGroup(opaque: false)
            }
            .frame(width: tileSize.width, height: tileSize.height)
            .clipShape(tileShape)
            .overlay {
                tileShape
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.10), radius: 16, y: 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: stageHeight)
    }

    private var tileCornerRadius: CGFloat {
        format == .widgetMedium ? 30 : 32
    }

    private var tileSceneInset: CGFloat {
        switch format {
        case .widgetSmall:
            return 2
        case .widgetMedium:
            return 4
        case .widgetLarge:
            return 6
        default:
            return 0
        }
    }

    private var stageHeight: CGFloat {
        switch format {
        case .widgetSmall:
            return 205
        case .widgetMedium:
            return 190
        case .widgetLarge:
            return 340
        default:
            return 360
        }
    }

    private func previewTileSize(for availableWidth: CGFloat) -> CGSize {
        let width: CGFloat

        switch format {
        case .widgetSmall:
            width = min(176, availableWidth * 0.56)
        case .widgetMedium:
            width = min(availableWidth, 350)
        case .widgetLarge:
            width = min(availableWidth, 350)
        default:
            width = availableWidth
        }

        return CGSize(width: width, height: width / format.aspectRatio)
    }
}

private extension AquariumConfiguration {
    func withFallbackStyle(_ style: AquariumVesselStyle) -> AquariumConfiguration {
        AquariumConfiguration(
            vesselStyle: vesselStyle == .orb && style != .orb ? style : vesselStyle,
            fishSpecies: fishSpecies,
            fishCount: fishCount,
            companion: companion,
            substrate: substrate,
            decoration: decoration
        )
    }
}
