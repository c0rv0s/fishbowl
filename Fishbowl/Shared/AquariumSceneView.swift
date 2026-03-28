import SwiftUI

struct AquariumSceneView: View {
    let configuration: AquariumConfiguration
    let format: AquariumDisplayFormat
    let phase: Double
    let petSnapshot: AquariumPetSnapshot
    let foodPellets: [AquariumFoodPellet]

    init(
        configuration: AquariumConfiguration,
        format: AquariumDisplayFormat,
        phase: Double,
        petSnapshot: AquariumPetSnapshot = .decorative(at: .now),
        foodPellets: [AquariumFoodPellet] = []
    ) {
        self.configuration = configuration
        self.format = format
        self.phase = phase
        self.petSnapshot = petSnapshot
        self.foodPellets = foodPellets
    }

    var body: some View {
        GeometryReader { geometry in
            AquariumGlassVessel(
                configuration: configuration,
                format: format,
                phase: phase,
                petSnapshot: petSnapshot,
                foodPellets: foodPellets
            )
            .padding(format.bodyInset)
        }
        .aspectRatio(format.aspectRatio, contentMode: .fit)
    }
}

private struct AquariumGlassVessel: View {
    let configuration: AquariumConfiguration
    let format: AquariumDisplayFormat
    let phase: Double
    let petSnapshot: AquariumPetSnapshot
    let foodPellets: [AquariumFoodPellet]

    private var bodyShape: AquariumBodyShape {
        AquariumBodyShape(style: configuration.vesselStyle)
    }

    var body: some View {
        baseBody
            .clipShape(bodyShape)
            .overlay {
                AquariumRefractionOverlay(
                    configuration: configuration,
                    style: configuration.vesselStyle
                )
            }
            .overlay { outerStroke }
            .overlay { innerStroke }
            .shadow(color: Color.white.opacity(0.35), radius: 8)
            .shadow(color: Color.black.opacity(0.16), radius: 22, y: 18)
    }

    private var baseBody: some View {
        bodyShape
            .fill(Color.white.opacity(0.08))
            .overlay {
                AquariumInteriorView(
                    configuration: configuration,
                    format: format,
                    phase: phase,
                    petSnapshot: petSnapshot,
                    foodPellets: foodPellets
                )
            }
    }

    private var outerStroke: some View {
        bodyShape
            .stroke(Color.white.opacity(0.82), lineWidth: 1.2)
    }

    private var innerStroke: some View {
        bodyShape
            .inset(by: 1.6)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.95),
                        Color.white.opacity(0.15),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.8
            )
    }
}

private struct AquariumInteriorView: View {
    let configuration: AquariumConfiguration
    let format: AquariumDisplayFormat
    let phase: Double
    let petSnapshot: AquariumPetSnapshot
    let foodPellets: [AquariumFoodPellet]

    private var sceneAccentColors: [Color] {
        configuration.substrate.accentColors + configuration.decoration.accentColors + configuration.fishSpecies.palette
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let waterLevel = configuration.vesselStyle == .orb ? 0.75 : 0.80

            ZStack {
                Color.white.opacity(0.06)

                IridescentMist(colors: sceneAccentColors)
                    .opacity(petSnapshot.isAlive ? 0.72 + petSnapshot.colorStrength * 0.28 : 0.46)

                WaterSurfaceShape(
                    level: waterLevel,
                    waveShift: 0.02 * sin(phase * 1.7)
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color(red: 0.50, green: 0.82, blue: 0.99).opacity(0.24),
                            Color(red: 0.12, green: 0.52, blue: 0.83).opacity(0.42),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                WaterSurfaceShape(
                    level: waterLevel,
                    waveShift: 0.02 * sin(phase * 1.7)
                )
                .stroke(Color.white.opacity(0.34), lineWidth: 1)
                .blur(radius: 0.6)

                BubbleField(
                    phase: phase,
                    waterLevel: waterLevel,
                    intensity: petSnapshot.bubbleIntensity
                )

                FoodPelletField(pellets: foodPellets)
                    .mask(waterMask(level: waterLevel))

                SubstrateBed(
                    substrate: configuration.substrate,
                    decoration: configuration.decoration,
                    phase: phase
                )
                .mask(waterMask(level: waterLevel))

                if configuration.companion != .none {
                    companionView(in: size)
                        .mask(waterMask(level: waterLevel))
                }

                ForEach(Array(fishLayouts(in: size).enumerated()), id: \.offset) { index, layout in
                    FishSprite(
                        species: configuration.fishSpecies,
                        isMirrored: layout.isMirrored,
                        vitality: petSnapshot.colorStrength,
                        isAlive: petSnapshot.isAlive
                    )
                    .frame(
                        width: layout.size.width,
                        height: layout.size.height
                    )
                    .rotationEffect(.degrees(layout.rotation))
                    .position(layout.position)
                    .opacity(petSnapshot.isAlive ? 1 : 0.62)
                    .shadow(color: configuration.fishSpecies.palette.last?.opacity(0.28) ?? .clear, radius: 12)
                    .mask(waterMask(level: waterLevel))
                }

                if !petSnapshot.isAlive {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            Color.black.opacity(0.10),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        }
    }

    private func fishLayouts(in size: CGSize) -> [FishLayout] {
        let count = configuration.fishCount.value
        let formatScale: CGFloat = format == .widgetSmall ? 0.82 : 1.0
        let baseX: [CGFloat]
        let baseY: [CGFloat]
        let scales: [CGFloat]
        let foodResponse = foodResponse(in: size)
        let laneWidth = size.width * (format == .widgetSmall ? 0.068 : 0.086)
        let verticalRange = size.height * (format == .widgetSmall ? 0.038 : 0.048)

        switch count {
        case 1:
            baseX = [0.48]
            baseY = [0.42]
            scales = [0.30]
        case 2:
            baseX = [0.27, 0.72]
            baseY = [0.48, 0.38]
            scales = [0.27, 0.23]
        default:
            baseX = [0.23, 0.52, 0.78]
            baseY = [0.50, 0.37, 0.46]
            scales = [0.25, 0.20, 0.19]
        }

        return (0..<count).map { index in
            let cruisePhase = phase * (0.46 + Double(index) * 0.05) + Double(index) * 1.7
            let meanderPhase = phase * (0.92 + Double(index) * 0.07) + Double(index) * 2.4
            let bobPhase = phase * (0.74 + Double(index) * 0.06) + Double(index) * 1.2
            let tiltPhase = phase * (1.16 + Double(index) * 0.04) + Double(index) * 0.9
            let driftScale = petSnapshot.driftIntensity
            let sweep = CGFloat(sin(cruisePhase) * 0.74 + sin(meanderPhase) * 0.26)
            let bob = CGFloat(sin(bobPhase) * 0.76 + cos(tiltPhase) * 0.24)
            let idlePosition = CGPoint(
                x: size.width * baseX[index] + sweep * laneWidth * driftScale,
                y: size.height * baseY[index] + bob * verticalRange * driftScale
            )
            let width = size.width * scales[index] * formatScale * petSnapshot.bodyScaleX
            let height = width * 0.72 * petSnapshot.bodyScaleY
            let idleHeading = cos(cruisePhase) * 0.72 + cos(meanderPhase) * 0.28
            let foodInterest = foodResponse.map { response in
                interestStrength(response.strength, index: index, count: count)
            } ?? 0
            let foodTarget = foodResponse.map { response in
                foodTargetPosition(
                    from: response.anchor,
                    index: index,
                    count: count,
                    size: size
                )
            } ?? idlePosition
            let approachStrength = smoothStep(from: 0.0, to: 0.80, value: foodInterest)
            let foodOrbitPosition = CGPoint(
                x: foodTarget.x + sweep * laneWidth * max(0.12, 0.42 - approachStrength * 0.26) * max(0.38, driftScale),
                y: foodTarget.y + bob * verticalRange * max(0.10, 0.30 - approachStrength * 0.18) * max(0.38, driftScale)
            )
            let livePosition = CGPoint(
                x: idlePosition.x + (foodOrbitPosition.x - idlePosition.x) * approachStrength,
                y: idlePosition.y + (foodOrbitPosition.y - idlePosition.y) * approachStrength
            )
            let targetHeading = max(-1, min(1, Double((foodOrbitPosition.x - idlePosition.x) / max(size.width * 0.18, 1))))
            let heading = idleHeading * Double(1 - approachStrength) + targetHeading * Double(approachStrength)
            let deadPosition = CGPoint(
                x: size.width * min(max(baseX[index], 0.28), 0.72),
                y: size.height * (0.77 + CGFloat(index) * 0.04)
            )

            return FishLayout(
                position: petSnapshot.isAlive ? livePosition : deadPosition,
                size: CGSize(width: width, height: height),
                rotation: petSnapshot.isAlive
                ? Double(-4 + index * 4) + heading * 10 + Double(bob) * 6 * Double(driftScale)
                : Double(76 - index * 9),
                isMirrored: petSnapshot.isAlive ? heading > 0 : index % 2 == 0
            )
        }
    }

    private func foodResponse(in size: CGSize) -> FoodResponse? {
        guard !foodPellets.isEmpty else { return nil }

        let xFraction = foodPellets.map(\.xFraction).reduce(0, +) / CGFloat(foodPellets.count)
        let yFraction = foodPellets.map(\.yFraction).reduce(0, +) / CGFloat(foodPellets.count)
        let attraction = foodPellets.map(\.attraction).reduce(0, +) / CGFloat(foodPellets.count)
        let depthProgress = smoothStep(from: 0.18, to: 0.74, value: yFraction)
        let freshness = smoothStep(from: 0.02, to: 0.82, value: attraction)
        let strength = min(0.90, depthProgress * freshness)

        guard strength > 0.008 else { return nil }

        return FoodResponse(
            anchor: CGPoint(
                x: size.width * xFraction,
                y: size.height * yFraction
            ),
            strength: strength
        )
    }

    private func foodTargetPosition(from anchor: CGPoint, index: Int, count: Int, size: CGSize) -> CGPoint {
        let centerOffset = CGFloat(index) - CGFloat(count - 1) * 0.5
        let spread = size.width * (format == .widgetSmall ? 0.034 : 0.046)
        let x = min(max(anchor.x + centerOffset * spread, size.width * 0.18), size.width * 0.82)
        let y = min(
            max(anchor.y - size.height * (0.035 + CGFloat(index % 2) * 0.018), size.height * 0.24),
            size.height * 0.72
        )
        return CGPoint(x: x, y: y)
    }

    private func interestStrength(_ base: CGFloat, index: Int, count: Int) -> CGFloat {
        let centerOffset = abs(CGFloat(index) - CGFloat(count - 1) * 0.5)
        let taper = max(0.82, 1 - centerOffset * 0.10)
        return min(0.86, base * taper)
    }

    private func smoothStep(from lower: CGFloat, to upper: CGFloat, value: CGFloat) -> CGFloat {
        guard upper > lower else { return 0 }
        let t = min(max((value - lower) / (upper - lower), 0), 1)
        return t * t * (3 - 2 * t)
    }

    @ViewBuilder
    private func companionView(in size: CGSize) -> some View {
        let accent = configuration.decoration.accentColors.first ?? configuration.substrate.accentColors.first ?? .orange
        let secondary = configuration.fishSpecies.palette.last ?? .white

        switch configuration.companion {
        case .none:
            EmptyView()
        case .snail:
            SnailSprite(accent: accent)
                .frame(width: size.width * 0.10, height: size.width * 0.10)
                .position(companionPosition(in: size))
        case .shrimp:
            ShrimpSprite(shell: accent, highlight: secondary)
                .frame(width: size.width * 0.15, height: size.width * 0.10)
                .position(companionPosition(in: size))
        case .crab:
            CrabSprite(shell: accent, highlight: secondary)
                .frame(width: size.width * 0.16, height: size.width * 0.11)
                .position(companionPosition(in: size))
        }
    }

    private func companionPosition(in size: CGSize) -> CGPoint {
        switch configuration.companion {
        case .none:
            return CGPoint(x: size.width * 0.5, y: size.height * 0.84)
        case .snail:
            return CGPoint(
                x: size.width * (configuration.vesselStyle == .panorama ? 0.82 : 0.74),
                y: size.height * 0.83
            )
        case .shrimp:
            return CGPoint(
                x: size.width * (configuration.vesselStyle == .panorama ? 0.70 : 0.63),
                y: size.height * 0.80
            )
        case .crab:
            return CGPoint(
                x: size.width * (configuration.vesselStyle == .panorama ? 0.54 : 0.50),
                y: size.height * 0.81
            )
        }
    }

    private func waterMask(level: CGFloat) -> some View {
        WaterSurfaceShape(
            level: level,
            waveShift: 0.02 * sin(phase * 1.7)
        )
    }
}

private struct FishLayout {
    let position: CGPoint
    let size: CGSize
    let rotation: Double
    let isMirrored: Bool
}

private struct FoodResponse {
    let anchor: CGPoint
    let strength: CGFloat
}

private struct AquariumRefractionOverlay: View {
    let configuration: AquariumConfiguration
    let style: AquariumVesselStyle

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: configuration.decoration.accentColors + configuration.fishSpecies.palette + [Color.clear],
                            center: .center
                        )
                    )
                    .frame(width: size.width * 1.02, height: size.width * 1.02)
                    .blur(radius: size.width * 0.05)
                    .offset(y: size.height * 0.16)
                    .opacity(style == .orb ? 0.40 : 0.30)
                    .blendMode(.screen)

                RoundedRectangle(cornerRadius: size.height * 0.2, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.34, green: 0.86, blue: 0.98).opacity(0.55),
                                Color.clear,
                                Color(red: 0.95, green: 0.16, blue: 0.46).opacity(0.38),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 5
                    )
                    .blur(radius: 14)
                    .mask(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white,
                                Color.white,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(0.65)
            }
        }
    }
}

private struct SubstrateBed: View {
    let substrate: SubstrateStyle
    let decoration: DecorationStyle
    let phase: Double

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack(alignment: .bottom) {
                SandbedShape(curve: 0.12 + 0.02 * CGFloat(sin(phase)))
                    .fill(
                        LinearGradient(
                            colors: substrate.bedColors,
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: size.height * 0.28)

                decorationLayer(size: size)
                    .padding(.horizontal, size.width * 0.07)
                    .padding(.bottom, size.height * 0.045)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    @ViewBuilder
    private func decorationLayer(size: CGSize) -> some View {
        switch decoration {
        case .minimal:
            MinimalDecoration(colors: decoration.accentColors, size: size)
        case .coralGarden:
            CoralGardenDecoration(colors: decoration.accentColors, size: size)
        case .riverRocks:
            RiverRockDecoration(colors: decoration.accentColors, size: size)
        case .glassPearls:
            GlassPearlDecoration(colors: decoration.accentColors, size: size)
        }
    }
}

private struct BubbleField: View {
    let phase: Double
    let waterLevel: CGFloat
    let intensity: Double

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ForEach(0..<7, id: \.self) { index in
                let horizontal = 0.16 + CGFloat(index) * 0.11
                let bubblePhase = phase * (0.7 + Double(index) * 0.08)
                let travel = bubblePhase.truncatingRemainder(dividingBy: 1.0)
                let y = size.height * (0.88 - 0.52 * CGFloat(travel))

                Circle()
                    .fill(Color.white.opacity(0.24 * intensity))
                    .frame(width: size.width * (0.012 + CGFloat(index % 3) * 0.005) * (0.72 + 0.28 * intensity))
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.45 * intensity), lineWidth: 0.6)
                    }
                    .position(
                        x: size.width * horizontal + CGFloat(sin(bubblePhase * 2.2)) * size.width * 0.012,
                        y: max(y, size.height * (1 - waterLevel) + 12)
                    )
            }
        }
    }
}

private struct FoodPelletField: View {
    let pellets: [AquariumFoodPellet]

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ForEach(pellets) { pellet in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.54, green: 0.37, blue: 0.20),
                                Color(red: 0.84, green: 0.67, blue: 0.39),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size.width * 0.018 * pellet.scale, height: size.width * 0.018 * pellet.scale)
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.24), lineWidth: 0.5)
                    }
                    .opacity(Double(min(max((pellet.scale - 0.04) / 0.80, 0), 1)) * 0.92)
                    .position(
                        x: size.width * pellet.xFraction,
                        y: size.height * pellet.yFraction
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 2, y: 1)
            }
        }
    }
}

private struct FishSprite: View {
    let species: FishSpecies
    let isMirrored: Bool
    let vitality: Double
    let isAlive: Bool

    var body: some View {
        let tailWidth = species.bodyWidth * 0.92 * species.tailScale
        let tailHeight = species.bodyHeight * 1.8 * species.tailScale
        let upperFinHeight = species.bodyHeight * 1.1 * species.finHeightMultiplier
        let lowerFinHeight = species.bodyHeight * 0.92 * species.finHeightMultiplier

        ZStack {
            TailShape()
                .fill(
                    LinearGradient(
                        colors: [
                            species.palette[1].opacity(0.42 + vitality * 0.44),
                            species.palette[2].opacity(0.10 + vitality * 0.12),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: tailWidth, height: tailHeight)
                .offset(x: species.bodyWidth * 0.42)
                .blur(radius: 0.2)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            species.palette[0].opacity(0.56 + vitality * 0.44),
                            species.palette[1].opacity(0.52 + vitality * 0.48),
                            species.palette[2].opacity(0.46 + vitality * 0.54),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: species.bodyWidth, height: species.bodyHeight)
                .overlay {
                    Ellipse()
                        .stroke(Color.white.opacity(0.28), lineWidth: 0.9)
                }
                .overlay(alignment: .leading) {
                    Circle()
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 4.4)
                        .overlay {
                            Circle()
                                .fill(Color.black.opacity(0.72))
                                .frame(width: 2.5)
                        }
                        .offset(x: 4)
                }
                .offset(x: -4)

            Ellipse()
                .fill(species.palette[2].opacity(0.26))
                .frame(width: species.bodyWidth * 0.34, height: upperFinHeight)
                .rotationEffect(.degrees(-36))
                .offset(x: -2, y: -species.bodyHeight * 0.48)

            Ellipse()
                .fill(species.palette[2].opacity(0.22))
                .frame(width: species.bodyWidth * 0.30, height: lowerFinHeight)
                .rotationEffect(.degrees(34))
                .offset(x: -2, y: species.bodyHeight * 0.48)

            if species == .moonKoi || species == .glassGold {
                Circle()
                    .fill(species.palette[2].opacity(0.34))
                    .frame(width: species.bodyWidth * 0.26)
                    .offset(x: 6, y: -2)
            }

            if species == .opalAngelfish {
                Capsule(style: .continuous)
                    .fill(species.palette[2].opacity(0.48))
                    .frame(width: 3, height: species.bodyHeight * 1.35)
                    .offset(x: 6, y: species.bodyHeight * 0.88)

                Capsule(style: .continuous)
                    .fill(species.palette[2].opacity(0.34))
                    .frame(width: 2.4, height: species.bodyHeight * 1.15)
                    .offset(x: -4, y: species.bodyHeight * 0.96)
            }
        }
        .saturation(isAlive ? 0.58 + vitality * 0.42 : 0.12)
        .scaleEffect(x: isMirrored ? -1 : 1, y: 1)
    }
}

private struct SnailSprite: View {
    let accent: Color

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(0.95),
                            Color.white.opacity(0.88),
                            Color(red: 0.40, green: 0.32, blue: 0.28),
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: 18
                    )
                )
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.42), lineWidth: 0.8)
                }

            Capsule(style: .continuous)
                .fill(Color(red: 0.75, green: 0.64, blue: 0.52))
                .frame(width: 20, height: 8)
                .offset(x: 10, y: 7)
        }
    }
}

private struct ShrimpSprite: View {
    let shell: Color
    let highlight: Color

    var body: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.32))
                .frame(width: 30, height: 16)
                .blur(radius: 5)
                .offset(y: 4)

            ForEach(0..<4, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                shell.opacity(0.95),
                                highlight.opacity(0.72),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: CGFloat(16 - index), height: CGFloat(8 - index / 2))
                    .rotationEffect(.degrees(Double(-20 + index * 12)))
                    .offset(x: CGFloat(index) * 6 - 6, y: CGFloat(index % 2))
            }

            TailShape()
                .fill(highlight.opacity(0.58))
                .frame(width: 16, height: 12)
                .rotationEffect(.degrees(180))
                .offset(x: 14, y: -1)

            Capsule(style: .continuous)
                .fill(shell.opacity(0.82))
                .frame(width: 2, height: 18)
                .rotationEffect(.degrees(64))
                .offset(x: -16, y: -8)

            Capsule(style: .continuous)
                .fill(highlight.opacity(0.76))
                .frame(width: 1.6, height: 16)
                .rotationEffect(.degrees(52))
                .offset(x: -12, y: -9)

            Circle()
                .fill(Color.white)
                .frame(width: 3)
                .overlay {
                    Circle()
                        .fill(Color.black.opacity(0.72))
                        .frame(width: 1.5)
                }
                .offset(x: -11, y: -2)
        }
    }
}

private struct CrabSprite: View {
    let shell: Color
    let highlight: Color

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(shell.opacity(0.78))
                    .frame(width: 2.2, height: 14)
                    .rotationEffect(.degrees(Double(52 - index * 20)))
                    .offset(x: -14 + CGFloat(index) * 6, y: 8)

                Capsule(style: .continuous)
                    .fill(shell.opacity(0.78))
                    .frame(width: 2.2, height: 14)
                    .rotationEffect(.degrees(Double(-52 + index * 20)))
                    .offset(x: 14 - CGFloat(index) * 6, y: 8)
            }

            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            shell,
                            highlight.opacity(0.92),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 18)
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Color.white.opacity(0.24), lineWidth: 0.8)
                }

            Ellipse()
                .fill(shell.opacity(0.92))
                .frame(width: 12, height: 7)
                .rotationEffect(.degrees(-24))
                .offset(x: -18, y: -4)

            Ellipse()
                .fill(shell.opacity(0.92))
                .frame(width: 12, height: 7)
                .rotationEffect(.degrees(24))
                .offset(x: 18, y: -4)

            Capsule(style: .continuous)
                .fill(shell.opacity(0.86))
                .frame(width: 2.4, height: 12)
                .rotationEffect(.degrees(-36))
                .offset(x: -12, y: -6)

            Capsule(style: .continuous)
                .fill(shell.opacity(0.86))
                .frame(width: 2.4, height: 12)
                .rotationEffect(.degrees(36))
                .offset(x: 12, y: -6)

            Circle()
                .fill(Color.white)
                .frame(width: 3.2)
                .overlay {
                    Circle()
                        .fill(Color.black.opacity(0.72))
                        .frame(width: 1.6)
                }
                .offset(x: -5, y: -7)

            Circle()
                .fill(Color.white)
                .frame(width: 3.2)
                .overlay {
                    Circle()
                        .fill(Color.black.opacity(0.72))
                        .frame(width: 1.6)
                }
                .offset(x: 5, y: -7)
        }
    }
}

private struct CoralGardenDecoration: View {
    let colors: [Color]
    let size: CGSize

    var body: some View {
        HStack(alignment: .bottom, spacing: size.width * 0.03) {
            ForEach(0..<6, id: \.self) { index in
                CoralBranch(
                    color: colors[index % colors.count],
                    height: size.height * (0.12 + CGFloat(index % 3) * 0.04),
                    tilt: Double(index - 2) * 6
                )
            }
        }
        .blur(radius: 0.1)
    }
}

private struct RiverRockDecoration: View {
    let colors: [Color]
    let size: CGSize

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(Array(rockSpecs.enumerated()), id: \.offset) { index, spec in
                RiverRock(colors: colors)
                    .frame(width: size.width * spec.width, height: size.height * spec.height)
                    .offset(x: size.width * spec.x, y: -size.height * spec.y)
                    .shadow(color: colors[index % colors.count].opacity(0.18), radius: 8, y: 4)
            }

            HStack(spacing: size.width * 0.02) {
                ForEach(0..<7, id: \.self) { index in
                    Circle()
                        .fill(colors[index % colors.count].opacity(0.78))
                        .frame(width: size.width * (0.022 + CGFloat(index % 2) * 0.008))
                }
            }
            .offset(y: size.height * 0.01)
        }
    }

    private var rockSpecs: [(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)] {
        [
            (x: -0.18, y: 0.01, width: 0.18, height: 0.12),
            (x: -0.04, y: 0.02, width: 0.24, height: 0.14),
            (x: 0.12, y: 0.00, width: 0.16, height: 0.10),
            (x: 0.24, y: 0.01, width: 0.20, height: 0.12),
        ]
    }
}

private struct GlassPearlDecoration: View {
    let colors: [Color]
    let size: CGSize

    var body: some View {
        HStack(alignment: .bottom, spacing: size.width * 0.028) {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.92),
                                colors[index % colors.count].opacity(0.82),
                                colors[(index + 1) % colors.count].opacity(0.32),
                            ],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: size.width * 0.06
                        )
                    )
                    .frame(width: size.width * (0.07 + CGFloat(index % 3) * 0.01))
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.52), lineWidth: 0.8)
                    }
                    .blur(radius: index.isMultiple(of: 2) ? 0 : 0.2)
            }
        }
    }
}

private struct MinimalDecoration: View {
    let colors: [Color]
    let size: CGSize

    var body: some View {
        HStack(spacing: size.width * 0.05) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(colors[index].opacity(0.40))
                    .frame(width: size.width * (0.035 + CGFloat(index) * 0.006))
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.34), lineWidth: 0.7)
                    }
            }
        }
    }
}

private struct RiverRock: View {
    let colors: [Color]

    var body: some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [
                        colors[0],
                        colors[1],
                        colors[2].opacity(0.92),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Ellipse()
                    .stroke(Color.white.opacity(0.24), lineWidth: 0.7)
            }
    }
}

private struct CoralBranch: View {
    let color: Color
    let height: CGFloat
    let tilt: Double

    var body: some View {
        ZStack(alignment: .bottom) {
            Capsule(style: .continuous)
                .fill(color)
                .frame(width: 8, height: height)

            Capsule(style: .continuous)
                .fill(color.opacity(0.92))
                .frame(width: 6, height: height * 0.56)
                .rotationEffect(.degrees(-28))
                .offset(x: -6, y: -height * 0.16)

            Capsule(style: .continuous)
                .fill(color.opacity(0.82))
                .frame(width: 6, height: height * 0.48)
                .rotationEffect(.degrees(24))
                .offset(x: 6, y: -height * 0.20)
        }
        .rotationEffect(.degrees(tilt))
        .shadow(color: color.opacity(0.5), radius: 10)
    }
}

private struct IridescentMist: View {
    let colors: [Color]

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                Circle()
                    .fill(colors[0].opacity(0.24))
                    .frame(width: size.width * 0.58, height: size.width * 0.58)
                    .blur(radius: size.width * 0.08)
                    .offset(x: -size.width * 0.28, y: size.height * 0.20)

                Circle()
                    .fill(colors[1].opacity(0.19))
                    .frame(width: size.width * 0.56, height: size.width * 0.56)
                    .blur(radius: size.width * 0.07)
                    .offset(x: size.width * 0.24, y: size.height * 0.18)

                Circle()
                    .fill(colors[2].opacity(0.16))
                    .frame(width: size.width * 0.42, height: size.width * 0.42)
                    .blur(radius: size.width * 0.06)
                    .offset(x: 0, y: size.height * 0.02)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.22),
                        Color.clear,
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
            }
        }
    }
}

private struct WaterSurfaceShape: Shape {
    let level: CGFloat
    let waveShift: CGFloat

    func path(in rect: CGRect) -> Path {
        let top = rect.maxY * (1 - level)
        let waveHeight = rect.height * 0.028
        let shift = rect.width * waveShift

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: top))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: top),
            control1: CGPoint(x: rect.maxX * 0.72, y: top - waveHeight + shift),
            control2: CGPoint(x: rect.maxX * 0.28, y: top + waveHeight - shift)
        )
        path.closeSubpath()
        return path
    }
}

private struct SandbedShape: Shape {
    let curve: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.32))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.42),
            control1: CGPoint(x: rect.maxX * 0.74, y: rect.minY + rect.height * (0.02 + curve)),
            control2: CGPoint(x: rect.maxX * 0.26, y: rect.minY + rect.height * (0.78 - curve))
        )
        path.closeSubpath()
        return path
    }
}

private struct TailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX * 0.38, y: rect.minY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.maxX * 0.58, y: rect.midY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.midY),
            control: CGPoint(x: rect.maxX * 0.38, y: rect.maxY)
        )
        return path
    }
}

private struct AquariumBodyShape: InsettableShape {
    let style: AquariumVesselStyle
    private var insetAmount: CGFloat = 0

    init(style: AquariumVesselStyle, insetAmount: CGFloat = 0) {
        self.style = style
        self.insetAmount = insetAmount
    }

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)

        switch style {
        case .orb:
            return Circle().path(in: insetRect)
        case .gallery:
            return RoundedRectangle(
                cornerRadius: insetRect.height * 0.18,
                style: .continuous
            )
            .path(in: insetRect)
        case .panorama:
            return RoundedRectangle(
                cornerRadius: insetRect.height * 0.14,
                style: .continuous
            )
            .path(in: insetRect.insetBy(dx: insetRect.width * 0.01, dy: insetRect.height * 0.02))
        }
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        AquariumBodyShape(style: style, insetAmount: insetAmount + amount)
    }
}
