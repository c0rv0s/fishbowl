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
        configuration.substrate.accentColors + configuration.decoration.accentColors + configuration.fishPalette
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let waterLevel = configuration.vesselStyle == .orb ? 0.75 : 0.80
            let sceneTone = AquariumSceneTone(at: petSnapshot.date)
            let layouts = fishLayouts(in: size)
            let visitor = rareVisitorLayout(in: size)

            ZStack {
                LinearGradient(
                    colors: sceneTone.backgroundColors,
                    startPoint: .top,
                    endPoint: .bottom
                )

                if sceneTone == .night {
                    NightGlints(phase: phase)
                        .opacity(0.30)
                }

                IridescentMist(colors: sceneAccentColors + sceneTone.accentColors)
                    .opacity((petSnapshot.isAlive ? 0.72 + petSnapshot.colorStrength * 0.28 : 0.46) * sceneTone.mistStrength)

                WaterSurfaceShape(
                    level: waterLevel,
                    waveShift: 0.02 * sin(phase * 1.7)
                )
                .fill(
                    LinearGradient(
                        colors: sceneTone.waterColors,
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

                ZStack {
                    BubbleField(
                        phase: phase,
                        waterLevel: waterLevel,
                        intensity: petSnapshot.bubbleIntensity * sceneTone.bubbleStrength
                    )

                    FoodPelletField(pellets: foodPellets)

                    if configuration.featurePiece == .kelp {
                        featurePieceView(in: size)
                    }

                    SubstrateLayer(
                        substrate: configuration.substrate,
                        phase: phase
                    )

                    if configuration.featurePiece != .none, configuration.featurePiece != .kelp {
                        featurePieceView(in: size)
                    }

                    DecorationLayer(decoration: configuration.decoration)

                    if configuration.companion != .none {
                        companionView(in: size)
                    }

                    if let visitor {
                        rareVisitorView(visitor)
                    }

                    ForEach(Array(layouts.enumerated()), id: \.offset) { _, layout in
                        FishSprite(
                            species: layout.species,
                            isMirrored: layout.isMirrored,
                            vitality: petSnapshot.colorStrength,
                            isAlive: petSnapshot.isAlive
                        )
                        .scaleEffect(layout.spriteScale)
                        .frame(
                            width: layout.size.width,
                            height: layout.size.height
                        )
                        .rotationEffect(.degrees(layout.rotation))
                        .position(layout.position)
                        .opacity(petSnapshot.isAlive ? 1 : 0.62)
                        .shadow(color: layout.species.palette.last?.opacity(0.28) ?? .clear, radius: 12)
                    }
                }
                .mask(waterMask(level: waterLevel))

                if let visitorThought = visitorThoughtBubble(visitor) {
                    ThoughtBubble(
                        text: visitorThought.text,
                        pointsToTrailing: visitorThought.pointsToTrailing
                    )
                        .position(visitorThought.position)
                }

                ForEach(fishThoughtBubbles(for: layouts), id: \.position.x) { thought in
                    ThoughtBubble(
                        text: thought.text,
                        pointsToTrailing: thought.pointsToTrailing
                    )
                        .position(thought.position)
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
        let speciesLineup = configuration.resolvedFishSpecies
        let count = speciesLineup.count
        let isCompactFormat = format == .widgetSmall
        let isAppIconFormat = format == .appIcon
        let waterLevel = configuration.vesselStyle == .orb ? 0.75 : 0.80
        let sceneTone = AquariumSceneTone(at: petSnapshot.date)
        let personality = configuration.personality
        let formatScale: CGFloat = isCompactFormat ? 0.82 : (isAppIconFormat ? 1.58 : 1.0)
        let baseX: [CGFloat]
        let baseY: [CGFloat]
        let scales: [CGFloat]
        let foodResponse = foodResponse(in: size)
        let laneWidth = size.width * (isCompactFormat ? 0.068 : (isAppIconFormat ? 0.060 : 0.086)) * personality.horizontalRangeMultiplier
        let verticalRange = size.height * (isCompactFormat ? 0.038 : (isAppIconFormat ? 0.034 : 0.048)) * personality.verticalRangeMultiplier

        switch count {
        case 1:
            if isAppIconFormat {
                baseX = [0.50]
                baseY = [0.45]
                scales = [0.46]
            } else {
                baseX = [0.48]
                baseY = [0.42]
                scales = [0.30]
            }
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
            let species = speciesLineup[index]
            let spriteScale = visualSpriteScale(for: species)
            let motionScale = personality.motionScale * sceneTone.motionScale
            let cruisePhase = phase * motionScale * (0.46 + Double(index) * 0.05) + Double(index) * 1.7
            let meanderPhase = phase * motionScale * (0.92 + Double(index) * 0.07) + Double(index) * 2.4
            let bobPhase = phase * motionScale * (0.74 + Double(index) * 0.06) + Double(index) * 1.2
            let tiltPhase = phase * motionScale * (1.16 + Double(index) * 0.04) + Double(index) * 0.9
            let driftScale = petSnapshot.driftIntensity * personality.driftIntensityMultiplier
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
                min(0.96, interestStrength(response.strength, index: index, count: count) * personality.foodInterestMultiplier)
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
            let unclampedLivePosition = CGPoint(
                x: idlePosition.x + (foodOrbitPosition.x - idlePosition.x) * approachStrength,
                y: idlePosition.y + (foodOrbitPosition.y - idlePosition.y) * approachStrength
            )
            let livePosition = clampedFishPosition(
                unclampedLivePosition,
                species: species,
                spriteScale: spriteScale,
                size: size,
                waterLevel: waterLevel
            )
            let targetHeading = max(-1, min(1, Double((foodOrbitPosition.x - idlePosition.x) / max(size.width * 0.18, 1))))
            let heading = idleHeading * Double(1 - approachStrength) + targetHeading * Double(approachStrength)
            let deadPosition = clampedFishPosition(
                CGPoint(
                x: size.width * min(max(baseX[index], 0.28), 0.72),
                y: size.height * (0.77 + CGFloat(index) * 0.04)
                ),
                species: species,
                spriteScale: spriteScale,
                size: size,
                waterLevel: waterLevel
            )

            return FishLayout(
                species: species,
                position: petSnapshot.isAlive ? livePosition : deadPosition,
                size: CGSize(width: width, height: height),
                spriteScale: isAppIconFormat ? 3.6 : spriteScale,
                rotation: petSnapshot.isAlive
                ? Double(-4 + index * 4) + heading * 10 + Double(bob) * 6 * Double(driftScale)
                : Double(76 - index * 9),
                isMirrored: petSnapshot.isAlive ? heading > 0 : index % 2 == 0
            )
        }
    }

    private func visualSpriteScale(for species: FishSpecies) -> CGFloat {
        let baseScale: CGFloat

        switch format {
        case .widgetSmall:
            baseScale = 0.84
        case .widgetMedium:
            baseScale = 0.88
        case .widgetLarge:
            baseScale = 0.94
        case .appIcon:
            baseScale = 3.6
        default:
            baseScale = 1.0
        }

        if format == .widgetSmall || format == .widgetMedium {
            switch species {
            case .royalBetta, .opalAngelfish, .leopardShark:
                return baseScale * 0.94
            default:
                return baseScale
            }
        }

        return baseScale
    }

    private func clampedFishPosition(
        _ position: CGPoint,
        species: FishSpecies,
        spriteScale: CGFloat,
        size: CGSize,
        waterLevel: CGFloat
    ) -> CGPoint {
        let extents = fishSpriteExtents(for: species, spriteScale: spriteScale)
        let waterTop = size.height * (1 - waterLevel)
        let topPadding: CGFloat = format == .widgetSmall ? 8 : (format == .widgetMedium ? 7 : 6)
        let bottomPadding: CGFloat = format == .widgetSmall ? 7 : 6
        let yRange = max(size.height * waterLevel - extents.top - extents.bottom, 1)
        let normalizedY = min(max((position.y - waterTop) / yRange, 0), 1)
        let orbCurveBoost = configuration.vesselStyle == .orb
        ? abs(normalizedY - 0.52) * size.width * (format == .widgetSmall ? 0.18 : 0.12)
        : 0
        let sidePadding: CGFloat

        switch format {
        case .widgetSmall:
            sidePadding = 14
        case .widgetMedium:
            sidePadding = 12
        case .widgetLarge:
            sidePadding = 9
        case .appIcon:
            sidePadding = 8
        default:
            sidePadding = 6
        }

        let xMargin = extents.halfWidth + sidePadding + orbCurveBoost
        let minY = waterTop + extents.top + topPadding
        let maxY = size.height - extents.bottom - bottomPadding

        return CGPoint(
            x: min(max(position.x, xMargin), size.width - xMargin),
            y: min(max(position.y, minY), maxY)
        )
    }

    private func fishSpriteExtents(for species: FishSpecies, spriteScale: CGFloat) -> (halfWidth: CGFloat, top: CGFloat, bottom: CGFloat) {
        let bodyWidth = species.bodyWidth * spriteScale
        let bodyHeight = species.bodyHeight * spriteScale
        let tailWidth = species.bodyWidth * 0.92 * species.tailScale * spriteScale
        let upperFinHeight = species.bodyHeight * 1.1 * species.finHeightMultiplier * spriteScale
        let lowerFinHeight = species.bodyHeight * 0.92 * species.finHeightMultiplier * spriteScale

        var halfWidth = max(bodyWidth * 0.54, bodyWidth * 0.42 + tailWidth * 0.5) + 4 * spriteScale
        var topExtent = max(bodyHeight * 0.5, bodyHeight * 0.48 + upperFinHeight * 0.5) + 4 * spriteScale
        var bottomExtent = max(bodyHeight * 0.5, bodyHeight * 0.48 + lowerFinHeight * 0.5) + 4 * spriteScale

        if species == .leopardShark {
            topExtent = max(topExtent, species.bodyHeight * 1.08 * spriteScale + 4 * spriteScale)
        }

        if species == .opalAngelfish {
            bottomExtent = max(bottomExtent, species.bodyHeight * 1.58 * spriteScale + 4 * spriteScale)
        }

        if species == .royalBetta {
            halfWidth += 2 * spriteScale
        }

        return (halfWidth, topExtent, bottomExtent)
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
        let spread = size.width * (format == .widgetSmall ? 0.034 : (format == .appIcon ? 0.040 : 0.046))
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
        let secondary = configuration.fishPalette.last ?? .white
        let layout = companionLayout(in: size)

        Group {
            switch configuration.companion {
            case .none:
                EmptyView()
            case .snail:
                SnailSprite(accent: accent)
                    .frame(width: size.width * 0.13, height: size.width * 0.10)
            case .shrimp:
                ShrimpSprite(shell: accent, highlight: secondary)
                    .frame(width: size.width * 0.15, height: size.width * 0.10)
            case .crab:
                CrabSprite(shell: accent, highlight: secondary)
                    .frame(width: size.width * 0.16, height: size.width * 0.11)
            case .seaCucumber:
                SeaCucumberSprite(bodyColor: accent, underside: secondary, highlight: configuration.substrate.accentColors[1])
                    .frame(width: size.width * 0.22, height: size.width * 0.10)
            case .nudibranchFlame:
                NudibranchSprite(variant: .flame)
                    .frame(width: size.width * 0.23, height: size.width * 0.11)
            case .nudibranchRibbon:
                NudibranchSprite(variant: .ribbon)
                    .frame(width: size.width * 0.22, height: size.width * 0.11)
            }
        }
        .rotationEffect(.degrees(layout.rotation))
        .scaleEffect(x: layout.isMirrored ? -1 : 1, y: 1)
        .position(layout.position)
    }

    private func companionLayout(in size: CGSize) -> CompanionLayout {
        let metrics: (
            baseX: CGFloat,
            baseY: CGFloat,
            range: CGFloat,
            stepLift: CGFloat,
            speed: Double,
            offset: Double,
            naturalFacingRight: Bool
        )

        switch configuration.companion {
        case .none:
            metrics = (0.50, 0.84, 0, 0, 0, 0, true)
        case .snail:
            metrics = (
                configuration.vesselStyle == .panorama ? 0.80 : 0.68,
                0.83,
                configuration.vesselStyle == .panorama ? 0.050 : 0.026,
                0.004,
                0.48,
                0.7,
                true
            )
        case .shrimp:
            metrics = (
                configuration.vesselStyle == .panorama ? 0.68 : 0.61,
                0.80,
                configuration.vesselStyle == .panorama ? 0.052 : 0.044,
                0.006,
                0.72,
                1.8,
                false
            )
        case .crab:
            metrics = (
                configuration.vesselStyle == .panorama ? 0.54 : 0.50,
                0.81,
                configuration.vesselStyle == .panorama ? 0.046 : 0.038,
                0.004,
                0.60,
                2.7,
                false
            )
        case .seaCucumber:
            metrics = (
                configuration.vesselStyle == .panorama ? 0.34 : 0.38,
                0.82,
                configuration.vesselStyle == .panorama ? 0.036 : 0.030,
                0.002,
                0.34,
                3.4,
                false
            )
        case .nudibranchFlame, .nudibranchRibbon:
            metrics = (
                configuration.vesselStyle == .panorama ? 0.42 : 0.46,
                0.82,
                configuration.vesselStyle == .panorama ? 0.040 : 0.034,
                0.003,
                0.42,
                4.2,
                false
            )
        }

        let motionPhase = phase * metrics.speed + metrics.offset
        let horizontalDrift = CGFloat(sin(motionPhase))
        let lift = abs(CGFloat(sin(motionPhase * 1.9))) * size.height * metrics.stepLift
        let movingRight = cos(motionPhase) > 0
        let isMirrored = metrics.naturalFacingRight ? !movingRight : movingRight
        let rotationStrength: CGFloat

        switch configuration.companion {
        case .shrimp:
            rotationStrength = 4.8
        case .crab:
            rotationStrength = 2.6
        case .seaCucumber, .nudibranchFlame, .nudibranchRibbon:
            rotationStrength = 1.4
        default:
            rotationStrength = 1.8
        }

        return CompanionLayout(
            position: CGPoint(
                x: size.width * metrics.baseX + horizontalDrift * size.width * metrics.range,
                y: size.height * metrics.baseY - lift
            ),
            isMirrored: isMirrored,
            rotation: Double(horizontalDrift * rotationStrength)
        )
    }

    @ViewBuilder
    private func featurePieceView(in size: CGSize) -> some View {
        let colors = configuration.featurePiece.accentColors
        let highlight = configuration.decoration.accentColors.first ?? configuration.substrate.accentColors.first ?? .white

        switch configuration.featurePiece {
        case .none:
            EmptyView()
        case .bubbleStone:
            BubbleStoneFeature(primary: colors[0], highlight: colors[2])
                .frame(width: size.width * 0.18, height: size.width * 0.20)
                .position(featurePiecePosition(in: size))
        case .driftwoodArch:
            DriftwoodArchFeature(primary: colors[0], secondary: colors[1], highlight: colors[2])
                .frame(width: size.width * 0.30, height: size.width * 0.19)
                .position(featurePiecePosition(in: size))
        case .moonLantern:
            MoonLanternFeature(glow: colors[1], stand: highlight)
                .frame(width: size.width * 0.18, height: size.width * 0.24)
                .position(featurePiecePosition(in: size))
        case .kelp:
            KelpFeature(
                primary: colors[0],
                secondary: colors[1],
                highlight: colors[2],
                phase: phase
            )
                .frame(
                    width: size.width * (configuration.vesselStyle == .panorama ? 0.24 : 0.22),
                    height: size.height * (configuration.vesselStyle == .panorama ? 0.64 : 0.61)
                )
                .position(featurePiecePosition(in: size))
        }
    }

    private func featurePiecePosition(in size: CGSize) -> CGPoint {
        switch configuration.featurePiece {
        case .none:
            return CGPoint(x: size.width * 0.50, y: size.height * 0.80)
        case .bubbleStone:
            return CGPoint(
                x: size.width * (configuration.vesselStyle == .panorama ? 0.70 : 0.68),
                y: size.height * 0.79
            )
        case .driftwoodArch:
            return CGPoint(
                x: size.width * (configuration.vesselStyle == .panorama ? 0.45 : 0.44),
                y: size.height * 0.79
            )
        case .moonLantern:
            return CGPoint(
                x: size.width * (configuration.vesselStyle == .panorama ? 0.66 : 0.70),
                y: size.height * 0.78
            )
        case .kelp:
            return CGPoint(
                x: size.width * (configuration.vesselStyle == .panorama ? 0.29 : 0.32),
                y: size.height * 0.64
            )
        }
    }

    private func waterMask(level: CGFloat) -> some View {
        WaterSurfaceShape(
            level: level,
            waveShift: 0.02 * sin(phase * 1.7)
        )
    }

    private func fishThoughtBubbles(for layouts: [FishLayout]) -> [ThoughtLayout] {
        guard format != .widgetSmall, !layouts.isEmpty else { return [] }

        let hourBucket = Int(petSnapshot.date.timeIntervalSince1970 / 3600)
        let seed = abs(configuration.hashValue ^ hourBucket)
        let shouldShow = petSnapshot.mood == .critical || seed.isMultiple(of: 2)
        guard shouldShow else { return [] }

        let index = seed % layouts.count
        let layout = layouts[index]
        let extents = fishSpriteExtents(for: layout.species, spriteScale: layout.spriteScale)
        let horizontalOffset = layout.isMirrored ? extents.halfWidth * 0.18 : -extents.halfWidth * 0.18
        return [
            ThoughtLayout(
                text: configuration.personality.thoughtText(
                    mood: petSnapshot.mood,
                    tone: AquariumSceneTone(at: petSnapshot.date)
                ),
                position: CGPoint(
                    x: layout.position.x + horizontalOffset,
                    y: layout.position.y - extents.top - 14
                ),
                pointsToTrailing: layout.isMirrored
            )
        ]
    }

    private func rareVisitorLayout(in size: CGSize) -> RareVisitorLayout? {
        let bucket = Int(petSnapshot.date.timeIntervalSince1970 / 43200)
        let seed = abs(configuration.hashValue ^ bucket)
        guard seed % 7 == 0 else { return nil }

        let kind: RareVisitorKind = seed.isMultiple(of: 2) ? .moonJelly : .seaAngel
        let baseX = size.width * (0.20 + CGFloat(seed % 37) / 100)
        let driftX = CGFloat(sin(phase * 0.42 + Double(seed % 11))) * size.width * 0.04
        let baseY = kind == .moonJelly ? size.height * 0.30 : size.height * 0.38

        return RareVisitorLayout(
            kind: kind,
            position: CGPoint(x: min(max(baseX + driftX, size.width * 0.16), size.width * 0.84), y: baseY),
            scale: kind == .moonJelly ? 1.0 : 0.92
        )
    }

    @ViewBuilder
    private func rareVisitorView(_ visitor: RareVisitorLayout) -> some View {
        switch visitor.kind {
        case .moonJelly:
            MoonJellyVisitor()
                .frame(width: 30 * visitor.scale, height: 36 * visitor.scale)
                .position(visitor.position)
        case .seaAngel:
            SeaAngelVisitor()
                .frame(width: 28 * visitor.scale, height: 22 * visitor.scale)
                .position(visitor.position)
        }
    }

    private func visitorThoughtBubble(_ visitor: RareVisitorLayout?) -> ThoughtLayout? {
        guard format != .widgetSmall, let visitor else { return nil }

        return ThoughtLayout(
            text: visitor.kind == .moonJelly ? "✨" : "🪽",
            position: CGPoint(x: visitor.position.x, y: visitor.position.y - 16),
            pointsToTrailing: visitor.kind == .seaAngel
        )
    }
}

private struct FishLayout {
    let species: FishSpecies
    let position: CGPoint
    let size: CGSize
    let spriteScale: CGFloat
    let rotation: Double
    let isMirrored: Bool
}

private struct CompanionLayout {
    let position: CGPoint
    let isMirrored: Bool
    let rotation: Double
}

private struct ThoughtLayout {
    let text: String
    let position: CGPoint
    let pointsToTrailing: Bool
}

private enum RareVisitorKind {
    case moonJelly
    case seaAngel
}

private struct RareVisitorLayout {
    let kind: RareVisitorKind
    let position: CGPoint
    let scale: CGFloat
}

private enum AquariumSceneTone: Equatable {
    case dawn
    case day
    case dusk
    case night

    init(at date: Date) {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<8:
            self = .dawn
        case 8..<17:
            self = .day
        case 17..<20:
            self = .dusk
        default:
            self = .night
        }
    }

    var backgroundColors: [Color] {
        switch self {
        case .dawn:
            return [
                Color(red: 0.99, green: 0.93, blue: 0.88),
                Color(red: 0.90, green: 0.95, blue: 1.00),
                Color(red: 0.78, green: 0.88, blue: 0.99),
            ]
        case .day:
            return [
                Color.white.opacity(0.94),
                Color(red: 0.88, green: 0.95, blue: 1.00),
                Color(red: 0.74, green: 0.87, blue: 0.98),
            ]
        case .dusk:
            return [
                Color(red: 0.98, green: 0.90, blue: 0.86),
                Color(red: 0.88, green: 0.87, blue: 0.98),
                Color(red: 0.68, green: 0.80, blue: 0.96),
            ]
        case .night:
            return [
                Color(red: 0.07, green: 0.10, blue: 0.17),
                Color(red: 0.12, green: 0.18, blue: 0.28),
                Color(red: 0.20, green: 0.28, blue: 0.38),
            ]
        }
    }

    var waterColors: [Color] {
        switch self {
        case .dawn:
            return [
                Color.white.opacity(0.22),
                Color(red: 0.97, green: 0.82, blue: 0.73).opacity(0.24),
                Color(red: 0.46, green: 0.76, blue: 0.96).opacity(0.42),
            ]
        case .day:
            return [
                Color.white.opacity(0.18),
                Color(red: 0.50, green: 0.82, blue: 0.99).opacity(0.24),
                Color(red: 0.12, green: 0.52, blue: 0.83).opacity(0.42),
            ]
        case .dusk:
            return [
                Color.white.opacity(0.18),
                Color(red: 0.91, green: 0.66, blue: 0.80).opacity(0.24),
                Color(red: 0.34, green: 0.50, blue: 0.86).opacity(0.44),
            ]
        case .night:
            return [
                Color.white.opacity(0.08),
                Color(red: 0.33, green: 0.56, blue: 0.86).opacity(0.18),
                Color(red: 0.07, green: 0.20, blue: 0.44).opacity(0.56),
            ]
        }
    }

    var accentColors: [Color] {
        switch self {
        case .dawn:
            return [Color(red: 1.00, green: 0.79, blue: 0.54), Color(red: 0.92, green: 0.90, blue: 1.00)]
        case .day:
            return [Color(red: 0.82, green: 0.94, blue: 1.00), Color(red: 0.92, green: 0.97, blue: 1.00)]
        case .dusk:
            return [Color(red: 0.98, green: 0.68, blue: 0.66), Color(red: 0.88, green: 0.74, blue: 0.98)]
        case .night:
            return [Color(red: 0.46, green: 0.72, blue: 1.00), Color(red: 0.78, green: 0.86, blue: 1.00)]
        }
    }

    var mistStrength: Double {
        switch self {
        case .dawn, .dusk:
            return 1.08
        case .day:
            return 1.0
        case .night:
            return 0.82
        }
    }

    var bubbleStrength: Double {
        self == .night ? 0.72 : 1.0
    }

    var motionScale: Double {
        self == .night ? 0.88 : 1.0
    }
}

private struct ThoughtBubble: View {
    let text: String
    let pointsToTrailing: Bool

    var body: some View {
        ZStack(alignment: pointsToTrailing ? .bottomTrailing : .bottomLeading) {
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.74))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.92))
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.72), lineWidth: 0.6)
                        }
                }

            Circle()
                .fill(Color.white.opacity(0.82))
                .frame(width: 5.5, height: 5.5)
                .offset(x: pointsToTrailing ? -7 : 7, y: 9)

            Circle()
                .fill(Color.white.opacity(0.72))
                .frame(width: 3.2, height: 3.2)
                .offset(x: pointsToTrailing ? -3 : 3, y: 13)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

private struct NightGlints: View {
    let phase: Double

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(index.isMultiple(of: 2) ? 0.32 : 0.18))
                    .frame(width: CGFloat(index.isMultiple(of: 2) ? 3.2 : 2.2))
                    .blur(radius: index.isMultiple(of: 2) ? 0.6 : 0.2)
                    .position(
                        x: size.width * (0.12 + CGFloat(index) * 0.17) + CGFloat(sin(phase * 0.4 + Double(index))) * 6,
                        y: size.height * (0.12 + CGFloat(index % 2) * 0.10)
                    )
            }
        }
    }
}

private struct MoonJellyVisitor: View {
    var body: some View {
        ZStack(alignment: .top) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.82),
                            Color(red: 0.78, green: 0.90, blue: 1.00).opacity(0.54),
                            Color(red: 0.62, green: 0.82, blue: 0.98).opacity(0.18),
                        ],
                        center: .top,
                        startRadius: 1,
                        endRadius: 14
                    )
                )
                .frame(width: 24, height: 18)

            ForEach(0..<4, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.36))
                    .frame(width: 1.4, height: 11)
                    .offset(x: -6 + CGFloat(index) * 4, y: 12 + CGFloat(index % 2))
            }
        }
        .blur(radius: 0.1)
    }
}

private struct SeaAngelVisitor: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.white.opacity(0.84))
                .frame(width: 8, height: 12)

            Ellipse()
                .fill(Color(red: 0.82, green: 0.94, blue: 1.00).opacity(0.74))
                .frame(width: 12, height: 7)
                .rotationEffect(.degrees(-28))
                .offset(x: -6, y: -1)

            Ellipse()
                .fill(Color(red: 0.82, green: 0.94, blue: 1.00).opacity(0.74))
                .frame(width: 12, height: 7)
                .rotationEffect(.degrees(28))
                .offset(x: 6, y: -1)
        }
        .blur(radius: 0.1)
    }
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
                            colors: configuration.decoration.accentColors + configuration.fishPalette + [Color.clear],
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

private struct SubstrateLayer: View {
    let substrate: SubstrateStyle
    let phase: Double

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            SandbedShape(curve: 0.12 + 0.02 * CGFloat(sin(phase)))
                .fill(
                    LinearGradient(
                        colors: substrate.bedColors,
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(height: size.height * 0.28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

private struct DecorationLayer: View {
    let decoration: DecorationStyle

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            decorationView(size: size)
                .padding(.horizontal, size.width * 0.07)
                .padding(.bottom, size.height * 0.045)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    @ViewBuilder
    private func decorationView(size: CGSize) -> some View {
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
                let baseRadius = size.width * (0.012 + CGFloat(index % 3) * 0.005)
                let diameter = baseRadius * (0.72 + 0.28 * intensity)
                let fillColor = Color.white.opacity(0.24 * intensity)
                let strokeColor = Color.white.opacity(0.45 * intensity)
                let xPosition = size.width * horizontal + CGFloat(sin(bubblePhase * 2.2)) * size.width * 0.012
                let yPosition = max(y, size.height * (1 - waterLevel) + 12)

                Circle()
                    .fill(fillColor)
                    .frame(width: diameter)
                    .overlay {
                        Circle()
                            .stroke(strokeColor, lineWidth: 0.6)
                    }
                    .position(x: xPosition, y: yPosition)
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

            if species == .leopardShark {
                Triangle()
                    .fill(species.palette[0].opacity(0.92))
                    .frame(width: species.bodyWidth * 0.22, height: species.bodyHeight * 0.72)
                    .rotationEffect(.degrees(-4))
                    .offset(x: 3, y: -species.bodyHeight * 0.72)

                Ellipse()
                    .fill(species.palette[1].opacity(0.26))
                    .frame(width: species.bodyWidth * 0.20, height: species.bodyHeight * 0.46)
                    .rotationEffect(.degrees(-18))
                    .offset(x: -1, y: species.bodyHeight * 0.34)

                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(Color.black.opacity(0.30))
                        .frame(width: index.isMultiple(of: 2) ? 4.5 : 3.4)
                        .offset(
                            x: -6 + CGFloat(index) * 6,
                            y: index.isMultiple(of: 2) ? -2 : 3
                        )
                }
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
            Ellipse()
                .fill(Color.black.opacity(0.08))
                .frame(width: 24, height: 7)
                .blur(radius: 2.5)
                .offset(x: 3, y: 11)

            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.76, green: 0.67, blue: 0.54),
                            Color(red: 0.60, green: 0.50, blue: 0.39),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 24, height: 8)
                .overlay(alignment: .trailing) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(red: 0.72, green: 0.61, blue: 0.49))
                        .frame(width: 9, height: 7)
                        .offset(x: 2, y: -1)
                }
                .overlay(alignment: .trailing) {
                    HStack(spacing: 4) {
                        Capsule(style: .continuous)
                            .fill(Color(red: 0.58, green: 0.48, blue: 0.38))
                            .frame(width: 1.6, height: 9.5)
                            .rotationEffect(.degrees(-10))
                            .overlay(alignment: .top) {
                                Circle()
                                    .fill(Color.black.opacity(0.72))
                                    .frame(width: 1.9, height: 1.9)
                                    .offset(y: -0.8)
                            }
                            .offset(y: -3.9)

                        Capsule(style: .continuous)
                            .fill(Color(red: 0.58, green: 0.48, blue: 0.38))
                            .frame(width: 1.6, height: 8.5)
                            .rotationEffect(.degrees(15))
                            .overlay(alignment: .top) {
                                Circle()
                                    .fill(Color.black.opacity(0.72))
                                    .frame(width: 1.8, height: 1.8)
                                    .offset(x: 0.35, y: -0.8)
                            }
                            .offset(x: -1.1, y: -3.5)
                    }
                    .offset(x: 4.8, y: -2.8)
                }
                .offset(x: 8, y: 8)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(0.95),
                            Color(red: 0.70, green: 0.55, blue: 0.37),
                            Color(red: 0.36, green: 0.26, blue: 0.18),
                        ],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 14
                    )
                )
                .frame(width: 17, height: 17)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.42), lineWidth: 0.8)
                }
                .overlay {
                    Circle()
                        .trim(from: 0.10, to: 0.90)
                        .stroke(Color.white.opacity(0.30), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                        .frame(width: 10, height: 10)
                }
                .overlay {
                    Circle()
                        .trim(from: 0.14, to: 0.82)
                        .stroke(Color.white.opacity(0.20), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
                        .frame(width: 5.5, height: 5.5)
                }
                .offset(x: 12, y: 2)
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
                .frame(width: 15, height: 11)
                .rotationEffect(.degrees(180))
                .offset(x: 18, y: 0)

            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            shell.opacity(0.92),
                            highlight.opacity(0.68),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 9, height: 3.2)
                .rotationEffect(.degrees(-10))
                .offset(x: -13.5, y: -3)

            Capsule(style: .continuous)
                .fill(shell.opacity(0.82))
                .frame(width: 1.8, height: 13)
                .rotationEffect(.degrees(-28))
                .offset(x: -14.5, y: -5.5)

            Capsule(style: .continuous)
                .fill(highlight.opacity(0.76))
                .frame(width: 1.5, height: 11)
                .rotationEffect(.degrees(-12))
                .offset(x: -11.8, y: -5.2)

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

private struct SeaCucumberSprite: View {
    let bodyColor: Color
    let underside: Color
    let highlight: Color

    var bodyView: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            bodyColor.opacity(0.96),
                            highlight.opacity(0.88),
                            underside.opacity(0.82),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 44, height: 16)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.32), lineWidth: 0.8)
                }

            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.20))
                .frame(width: 32, height: 5)
                .offset(y: -2)

            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.08))
                .frame(width: 36, height: 4)
                .offset(y: 4)

            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.52),
                                highlight.opacity(0.92),
                                bodyColor.opacity(0.84),
                            ],
                            center: .topLeading,
                            startRadius: 1,
                            endRadius: 6
                        )
                    )
                    .frame(width: index.isMultiple(of: 2) ? 6 : 5)
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                    }
                    .offset(
                        x: -16 + CGFloat(index) * 6,
                        y: index.isMultiple(of: 2) ? -4 : 4
                    )
            }

            ForEach(0..<5, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(underside.opacity(0.72))
                    .frame(width: 2.6, height: 6)
                    .offset(x: -12 + CGFloat(index) * 6, y: 10)
            }

            Ellipse()
                .fill(bodyColor.opacity(0.88))
                .frame(width: 8, height: 12)
                .offset(x: -20, y: 1)

            Ellipse()
                .fill(underside.opacity(0.90))
                .frame(width: 7, height: 11)
                .offset(x: 20, y: 1)
        }
    }

    var body: some View {
        bodyView
            .shadow(color: highlight.opacity(0.18), radius: 6, y: 2)
    }
}

private enum NudibranchVariant {
    case flame
    case ribbon
}

private struct NudibranchSprite: View {
    let variant: NudibranchVariant

    var body: some View {
        Group {
            switch variant {
            case .flame:
                flameBody
            case .ribbon:
                ribbonBody
            }
        }
    }

    private var flameBody: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.54, green: 0.22, blue: 0.95),
                            Color(red: 0.74, green: 0.34, blue: 0.98),
                            Color(red: 0.48, green: 0.24, blue: 0.90),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 42, height: 14)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.26), lineWidth: 0.8)
                }

            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.16))
                .frame(width: 26, height: 4)
                .offset(y: -2)

            ForEach(0..<8, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.00, green: 0.60, blue: 0.16),
                                Color(red: 1.00, green: 0.36, blue: 0.10),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3.8, height: index.isMultiple(of: 2) ? 10 : 8)
                    .rotationEffect(.degrees(Double(-20 + index * 5)))
                    .offset(x: -15 + CGFloat(index) * 4.8, y: -8)
            }

            ForEach(0..<6, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(Color(red: 0.92, green: 0.42, blue: 0.90).opacity(0.70))
                    .frame(width: 3.3, height: index.isMultiple(of: 2) ? 6.5 : 5.2)
                    .rotationEffect(.degrees(Double(18 - index * 5)))
                    .offset(x: -13 + CGFloat(index) * 5, y: 7)
            }

            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.44),
                                Color(red: 1.00, green: 0.66, blue: 0.20).opacity(0.70),
                                Color(red: 0.64, green: 0.22, blue: 0.92).opacity(0.72),
                            ],
                            center: .topLeading,
                            startRadius: 1,
                            endRadius: 5
                        )
                    )
                    .frame(width: index.isMultiple(of: 2) ? 5 : 4)
                    .offset(x: -10 + CGFloat(index) * 6, y: index.isMultiple(of: 2) ? -1 : 2)
            }

            Capsule(style: .continuous)
                .fill(Color(red: 0.78, green: 0.74, blue: 1.00))
                .frame(width: 2.4, height: 11)
                .rotationEffect(.degrees(-24))
                .offset(x: -17, y: -7)

            Capsule(style: .continuous)
                .fill(Color(red: 0.78, green: 0.74, blue: 1.00))
                .frame(width: 2.2, height: 10)
                .rotationEffect(.degrees(-6))
                .offset(x: -12, y: -7)
        }
        .shadow(color: Color(red: 1.00, green: 0.46, blue: 0.12).opacity(0.16), radius: 6, y: 2)
    }

    private var ribbonBody: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.95, blue: 0.90),
                            Color.white,
                            Color(red: 0.96, green: 0.90, blue: 0.82),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 42, height: 14)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.40), lineWidth: 0.8)
                }

            ForEach(0..<4, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.72))
                    .frame(width: 5.5, height: 16)
                    .rotationEffect(.degrees(Double(24 - index * 10)))
                    .offset(x: -9 + CGFloat(index) * 7, y: 0)
            }

            ForEach(0..<7, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(Color(red: 1.00, green: 0.54, blue: 0.14))
                    .frame(width: 4.4, height: index.isMultiple(of: 2) ? 7.5 : 6.0)
                    .rotationEffect(.degrees(Double(-16 + index * 5)))
                    .offset(x: -15 + CGFloat(index) * 5, y: -8)

                Capsule(style: .continuous)
                    .fill(Color(red: 1.00, green: 0.72, blue: 0.26))
                    .frame(width: 4.0, height: index.isMultiple(of: 2) ? 6.6 : 5.2)
                    .rotationEffect(.degrees(Double(16 - index * 5)))
                    .offset(x: -15 + CGFloat(index) * 5, y: 8)
            }

            Capsule(style: .continuous)
                .fill(Color(red: 1.00, green: 0.58, blue: 0.16))
                .frame(width: 3.0, height: 11)
                .rotationEffect(.degrees(-22))
                .offset(x: -17, y: -8)

            Capsule(style: .continuous)
                .fill(Color(red: 1.00, green: 0.58, blue: 0.16))
                .frame(width: 3.0, height: 10)
                .rotationEffect(.degrees(-6))
                .offset(x: -12, y: -8)

            Ellipse()
                .fill(Color(red: 1.00, green: 0.56, blue: 0.18).opacity(0.92))
                .frame(width: 9, height: 6)
                .rotationEffect(.degrees(18))
                .offset(x: 17, y: -7)
        }
        .shadow(color: Color(red: 1.00, green: 0.54, blue: 0.14).opacity(0.14), radius: 6, y: 2)
    }
}

private struct BubbleStoneFeature: View {
    let primary: Color
    let highlight: Color

    var body: some View {
        ZStack(alignment: .bottom) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            highlight.opacity(0.96),
                            primary.opacity(0.90),
                            primary.opacity(0.42),
                        ],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: 28
                    )
                )
                .frame(width: 28, height: 28)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.82), lineWidth: 0.9)
                }
                .shadow(color: primary.opacity(0.24), radius: 12, y: 4)

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(primary.opacity(0.26))
                        .frame(width: CGFloat(3 + index), height: CGFloat(3 + index))
                }
            }
            .offset(y: 2)

            VStack(spacing: 6) {
                Circle()
                    .fill(Color.white.opacity(0.50))
                    .frame(width: 4)
                Circle()
                    .fill(Color.white.opacity(0.34))
                    .frame(width: 6)
                Circle()
                    .fill(Color.white.opacity(0.24))
                    .frame(width: 8)
            }
            .offset(y: -16)
        }
    }
}

private struct DriftwoodArchFeature: View {
    let primary: Color
    let secondary: Color
    let highlight: Color

    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(Color.black.opacity(0.10))
                .frame(width: 78, height: 16)
                .blur(radius: 5)
                .offset(y: 20)

            archStroke(lineWidth: 13)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            highlight.opacity(0.44),
                            secondary.opacity(0.96),
                            primary.opacity(0.96),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            archStroke(lineWidth: 7)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.16),
                            highlight.opacity(0.18),
                            .clear,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blur(radius: 0.3)
                .offset(x: -1, y: -1)

            innerBranchStroke(lineWidth: 6)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            highlight.opacity(0.30),
                            secondary.opacity(0.82),
                            primary.opacity(0.86),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            twigStroke(lineWidth: 4.5)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            secondary.opacity(0.90),
                            primary.opacity(0.84),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            ForEach([
                (x: -25.0, y: 14.0, w: 14.0, h: 7.0, a: -22.0),
                (x: 23.0, y: 15.0, w: 15.0, h: 7.0, a: 19.0),
                (x: -2.0, y: 2.0, w: 10.0, h: 4.0, a: -12.0),
            ], id: \.x) { streak in
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.13))
                    .frame(width: streak.w, height: streak.h)
                    .rotationEffect(.degrees(streak.a))
                    .offset(x: streak.x, y: streak.y)
            }

            ForEach([
                (x: -22.0, y: 16.0, s: 7.0),
                (x: 18.0, y: 14.0, s: 6.0),
            ], id: \.x) { knot in
                Circle()
                    .fill(primary.opacity(0.50))
                    .frame(width: knot.s, height: knot.s)
                    .overlay {
                        Circle()
                            .stroke(highlight.opacity(0.22), lineWidth: 0.7)
                    }
                    .offset(x: knot.x, y: knot.y)
            }
        }
        .shadow(color: Color.black.opacity(0.12), radius: 9, y: 4)
    }

    private func archStroke(lineWidth: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 12, y: 39))
            path.addCurve(
                to: CGPoint(x: 68, y: 38),
                control1: CGPoint(x: 16, y: 10),
                control2: CGPoint(x: 61, y: 10)
            )
        }
        .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }

    private func innerBranchStroke(lineWidth: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 20, y: 33))
            path.addCurve(
                to: CGPoint(x: 60, y: 33),
                control1: CGPoint(x: 25, y: 16),
                control2: CGPoint(x: 53, y: 16)
            )
        }
        .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }

    private func twigStroke(lineWidth: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 26, y: 22))
            path.addCurve(
                to: CGPoint(x: 14, y: 9),
                control1: CGPoint(x: 21, y: 16),
                control2: CGPoint(x: 18, y: 12)
            )

            path.move(to: CGPoint(x: 54, y: 24))
            path.addCurve(
                to: CGPoint(x: 66, y: 12),
                control1: CGPoint(x: 59, y: 18),
                control2: CGPoint(x: 62, y: 15)
            )
        }
        .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
}

private struct MoonLanternFeature: View {
    let glow: Color
    let stand: Color

    var body: some View {
        ZStack(alignment: .bottom) {
            Circle()
                .fill(glow.opacity(0.42))
                .frame(width: 42, height: 42)
                .blur(radius: 13)
                .offset(y: -13)

            Circle()
                .fill(Color.white.opacity(0.34))
                .frame(width: 30, height: 30)
                .blur(radius: 5)
                .offset(y: -11)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white,
                            glow.opacity(0.96),
                            glow.opacity(0.36),
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: 20
                    )
                )
                .frame(width: 28, height: 28)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.90), lineWidth: 0.9)
                }
                .overlay {
                    Circle()
                        .stroke(stand.opacity(0.20), lineWidth: 1.1)
                        .padding(4)
                }
                .offset(y: -12)

            Capsule(style: .continuous)
                .fill(stand.opacity(0.90))
                .frame(width: 3, height: 16)
                .offset(y: -28)

            Capsule(style: .continuous)
                .fill(stand.opacity(0.82))
                .frame(width: 16, height: 3)
                .offset(y: -35)

            Capsule(style: .continuous)
                .fill(stand.opacity(0.70))
                .frame(width: 3, height: 10)
                .rotationEffect(.degrees(32))
                .offset(x: -10, y: -18)

            Capsule(style: .continuous)
                .fill(stand.opacity(0.70))
                .frame(width: 3, height: 10)
                .rotationEffect(.degrees(-32))
                .offset(x: 10, y: -18)

            Capsule(style: .continuous)
                .fill(stand.opacity(0.92))
                .frame(width: 5, height: 20)
                .offset(y: 5)

            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            stand.opacity(0.90),
                            Color.white.opacity(0.42),
                            stand.opacity(0.78),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 26, height: 5)
                .offset(y: 14)

            Capsule(style: .continuous)
                .fill(stand.opacity(0.76))
                .frame(width: 18, height: 3)
                .offset(y: 18)
        }
        .shadow(color: glow.opacity(0.22), radius: 10, y: 4)
    }
}

private struct KelpFeature: View {
    let primary: Color
    let secondary: Color
    let highlight: Color
    let phase: Double

    private let canvasSize = CGSize(width: 84, height: 156)
    private let floorY: CGFloat = 147
    private let strands: [(baseX: CGFloat, height: CGFloat, width: CGFloat, phaseOffset: Double)] = [
        (18, 102, 6.5, 0.4),
        (33, 128, 7.0, 1.1),
        (49, 114, 6.0, 1.8),
        (65, 136, 7.4, 2.5),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(Color.black.opacity(0.08))
                .frame(width: 54, height: 12)
                .blur(radius: 4)
                .offset(y: 8)

            ForEach(Array(strands.enumerated()), id: \.offset) { index, strand in
                kelpStrand(
                    index: index,
                    baseX: strand.baseX,
                    height: strand.height,
                    width: strand.width,
                    phaseOffset: strand.phaseOffset
                )
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .shadow(color: primary.opacity(0.16), radius: 8, y: 4)
    }

    @ViewBuilder
    private func kelpStrand(
        index: Int,
        baseX: CGFloat,
        height: CGFloat,
        width: CGFloat,
        phaseOffset: Double
    ) -> some View {
        let sway = CGFloat(sin(phase * (0.88 + Double(index) * 0.08) + phaseOffset)) * (7 + CGFloat(index))
        let crestX = baseX + sway
        let crestY = floorY - height

        Path { path in
            path.move(to: CGPoint(x: baseX, y: floorY))
            path.addCurve(
                to: CGPoint(x: crestX, y: crestY),
                control1: CGPoint(x: baseX - width * 1.3, y: floorY - height * 0.34),
                control2: CGPoint(x: crestX + sway * 0.30, y: floorY - height * 0.74)
            )
        }
        .stroke(
            LinearGradient(
                colors: [
                    primary.opacity(0.98),
                    secondary.opacity(0.94),
                    highlight.opacity(0.82),
                ],
                startPoint: .bottom,
                endPoint: .top
            ),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        )

        Path { path in
            path.move(to: CGPoint(x: baseX + 1, y: floorY - 5))
            path.addCurve(
                to: CGPoint(x: crestX - width * 0.20, y: crestY + 8),
                control1: CGPoint(x: baseX + width * 0.6, y: floorY - height * 0.26),
                control2: CGPoint(x: crestX - sway * 0.14, y: floorY - height * 0.62)
            )
        }
        .stroke(
            Color.white.opacity(0.14),
            style: StrokeStyle(lineWidth: max(1.5, width * 0.22), lineCap: .round)
        )

        ForEach(0..<3, id: \.self) { leafIndex in
            let progress = 0.26 + CGFloat(leafIndex) * 0.21 + CGFloat(index) * 0.03
            let leafY = floorY - height * progress
            let leafDrift = sway * (0.16 + progress * 0.28)
            let leafDirection: CGFloat = leafIndex.isMultiple(of: 2) ? -1 : 1
            let leafRotation = Double(leafDirection * (28 + CGFloat(leafIndex * 6)) + sway * 0.7)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            highlight.opacity(0.62),
                            secondary.opacity(0.94),
                            primary.opacity(0.84),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: width * 4.4, height: width * 1.9)
                .rotationEffect(.degrees(leafRotation))
                .position(
                    x: baseX + leafDrift + leafDirection * width * 1.1,
                    y: leafY
                )
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

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private extension FishPersonality {
    var motionScale: Double {
        switch self {
        case .playful:
            return 1.14
        case .shy:
            return 0.88
        case .greedy:
            return 1.02
        case .dreamy:
            return 0.78
        }
    }

    var driftIntensityMultiplier: CGFloat {
        switch self {
        case .playful:
            return 1.16
        case .shy:
            return 0.82
        case .greedy:
            return 0.98
        case .dreamy:
            return 0.94
        }
    }

    var foodInterestMultiplier: CGFloat {
        switch self {
        case .playful:
            return 1.02
        case .shy:
            return 0.72
        case .greedy:
            return 1.28
        case .dreamy:
            return 0.66
        }
    }

    var horizontalRangeMultiplier: CGFloat {
        switch self {
        case .playful:
            return 1.12
        case .shy:
            return 0.82
        case .greedy:
            return 1.00
        case .dreamy:
            return 0.92
        }
    }

    var verticalRangeMultiplier: CGFloat {
        switch self {
        case .playful:
            return 1.08
        case .shy:
            return 0.88
        case .greedy:
            return 0.94
        case .dreamy:
            return 1.18
        }
    }

    func thoughtText(mood: AquariumPetMood, tone: AquariumSceneTone) -> String {
        switch mood {
        case .critical:
            return self == .greedy ? "🍽️" : "😫"
        case .hungry:
            return self == .shy ? "🥺" : "🍤"
        case .dead:
            return "💤"
        case .decorative, .content:
            switch self {
            case .playful:
                return tone == .night ? "✨" : "⚡️"
            case .shy:
                return tone == .night ? "🌙" : "🫧"
            case .greedy:
                return "🍽️"
            case .dreamy:
                return tone == .night ? "💭" : "☁️"
            }
        }
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
