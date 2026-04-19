import SwiftUI
#if canImport(SpriteKit)
import SpriteKit
#endif
#if canImport(MetalKit)
import MetalKit
#endif
#if canImport(UIKit)
import UIKit
#endif

typealias AquariumFeedBurstConsumedHandler = @MainActor @Sendable (UUID) -> Void

struct AquariumFeedBurst: Identifiable, Hashable, Sendable {
    static let maxQueuedBursts = 10
    static let horizontalDropBounds: ClosedRange<CGFloat> = 0.10...0.90
    static let dropDuration: TimeInterval = 0.95
    static let grazeDuration: TimeInterval = 1.35
    static let releaseDuration: TimeInterval = 0.80
    static let settleDuration: TimeInterval = 0.60
    static let handoffBlendDuration: TimeInterval = 0.92
    static let returnBlendDuration: TimeInterval = 0.84
    static let burstAnimationDuration: TimeInterval = 0.88
    static let feedingCycleDuration = dropDuration + grazeDuration + releaseDuration + settleDuration
    static let interactionLockDuration = feedingCycleDuration + burstAnimationDuration

    let id: UUID
    let startedAt: Date
    let xFraction: CGFloat
    let feedingStartsAt: Date?

    init(
        id: UUID = UUID(),
        startedAt: Date,
        xFraction: CGFloat,
        feedingStartsAt: Date? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.xFraction = xFraction
        self.feedingStartsAt = feedingStartsAt
    }
}

struct AquariumTapRipple: Identifiable, Hashable, Sendable {
    let id: UUID
    let startedAt: Date
    let normalizedLocation: CGPoint

    init(id: UUID = UUID(), startedAt: Date, normalizedLocation: CGPoint) {
        self.id = id
        self.startedAt = startedAt
        self.normalizedLocation = normalizedLocation
    }
}

private struct AquariumScheduledFeedBurst {
    let burst: AquariumFeedBurst
    let dropCompletionTime: Date
    let feedingStartTime: Date
    let consumeTime: Date
}

private enum AquariumResolvedFeedStage {
    case hidden
    case consumed
    case activeDropping(progress: CGFloat)
    case queuedDropping(progress: CGFloat)
    case queuedWaiting(elapsed: TimeInterval)
    case activeFeeding(progress: CGFloat)

    var isActive: Bool {
        switch self {
        case .activeDropping, .activeFeeding:
            return true
        default:
            return false
        }
    }
}

private struct AquariumResolvedFeedBurst {
    let scheduled: AquariumScheduledFeedBurst
    let stage: AquariumResolvedFeedStage
}

private func scheduleFeedBursts(_ feedBursts: [AquariumFeedBurst]) -> [AquariumScheduledFeedBurst] {
    let orderedBursts = feedBursts.enumerated()
        .sorted { lhs, rhs in
            if lhs.element.startedAt == rhs.element.startedAt {
                return lhs.offset < rhs.offset
            }
            return lhs.element.startedAt < rhs.element.startedAt
        }
        .map(\.element)

    return orderedBursts.map { burst in
        let dropCompletionTime = burst.startedAt.addingTimeInterval(AquariumFeedBurst.dropDuration)
        let feedingStartTime = max(dropCompletionTime, burst.feedingStartsAt ?? dropCompletionTime)
        return AquariumScheduledFeedBurst(
            burst: burst,
            dropCompletionTime: dropCompletionTime,
            feedingStartTime: feedingStartTime,
            consumeTime: feedingStartTime.addingTimeInterval(AquariumFeedBurst.grazeDuration)
        )
    }
}

private func resolveFeedBursts(_ feedBursts: [AquariumFeedBurst], at date: Date) -> [AquariumResolvedFeedBurst] {
    scheduleFeedBursts(feedBursts).map { scheduled in
        let burst = scheduled.burst

        let stage: AquariumResolvedFeedStage
        if date < burst.startedAt {
            stage = .hidden
        } else if date >= scheduled.consumeTime {
            stage = .consumed
        } else if date < scheduled.dropCompletionTime {
            let progress = CGFloat(
                min(max(date.timeIntervalSince(burst.startedAt) / AquariumFeedBurst.dropDuration, 0), 1)
            )
            stage = scheduled.feedingStartTime <= scheduled.dropCompletionTime
            ? .activeDropping(progress: progress)
            : .queuedDropping(progress: progress)
        } else if date < scheduled.feedingStartTime {
            stage = .queuedWaiting(elapsed: date.timeIntervalSince(scheduled.dropCompletionTime))
        } else {
            let progress = CGFloat(
                min(max(date.timeIntervalSince(scheduled.feedingStartTime) / AquariumFeedBurst.grazeDuration, 0), 1)
            )
            stage = .activeFeeding(progress: progress)
        }

        return AquariumResolvedFeedBurst(scheduled: scheduled, stage: stage)
    }
}

private func pellets(for resolvedBurst: AquariumResolvedFeedBurst) -> [AquariumFoodPellet] {
    let burst = resolvedBurst.scheduled.burst

    return (0..<3).compactMap { index in
        let spread = CGFloat(index - 1) * 0.024
        let x = min(
            max(
                burst.xFraction + spread,
                AquariumFeedBurst.horizontalDropBounds.lowerBound
            ),
            AquariumFeedBurst.horizontalDropBounds.upperBound
        )
        let restingDepth = 0.50 + CGFloat(index) * 0.07
        let restingY = min(0.76, 0.08 + restingDepth)
        let bobSeed = Double(index) * 0.8

        let y: CGFloat
        let visibility: CGFloat
        let attraction: CGFloat

        switch resolvedBurst.stage {
        case let .activeDropping(progress):
            let easedDrop = CGFloat(1 - pow(1 - progress, 2.2))
            y = min(0.76, 0.08 + easedDrop * restingDepth)
            visibility = 1
            attraction = 0.40 + progress * 0.30
        case let .queuedDropping(progress):
            let easedDrop = CGFloat(1 - pow(1 - progress, 2.0))
            y = min(0.76, 0.08 + easedDrop * restingDepth)
            visibility = 0.96
            attraction = 0.14 + progress * 0.06
        case let .queuedWaiting(elapsed):
            y = restingY + CGFloat(sin(elapsed * 2.6 + bobSeed)) * 0.005
            visibility = 0.92
            attraction = 0.12
        case let .activeFeeding(progress):
            let nibbleAmount = 0.012 - progress * 0.006
            y = restingY + CGFloat(sin(Double(progress) * .pi * 3 + bobSeed)) * nibbleAmount
            visibility = max(0.18, 0.96 - progress * 0.58)
            attraction = 0.42 + smoothStep(from: 0.05, to: 0.72, value: progress) * 0.42
        case .hidden, .consumed:
            return nil
        }

        let baseScale: CGFloat = index == 1 ? 1.0 : 0.84
        return AquariumFoodPellet(
            xFraction: x,
            yFraction: y,
            scale: baseScale * visibility,
            attraction: attraction
        )
    }
}

private func foodResponse(
    for resolvedBurst: AquariumResolvedFeedBurst,
    in size: CGSize
) -> FoodResponse? {
    let activePellets = pellets(for: resolvedBurst)
    guard !activePellets.isEmpty else { return nil }

    let xFraction = activePellets.map(\.xFraction).reduce(0, +) / CGFloat(activePellets.count)
    let yFraction = activePellets.map(\.yFraction).reduce(0, +) / CGFloat(activePellets.count)
    let attraction = activePellets.map(\.attraction).reduce(0, +) / CGFloat(activePellets.count)
    let depthProgress = smoothStep(from: 0.18, to: 0.74, value: yFraction)
    let freshness = smoothStep(from: 0.02, to: 0.82, value: attraction)
    let strength = min(0.92, depthProgress * freshness)

    guard strength > 0.008 else { return nil }

    return FoodResponse(
        anchor: CGPoint(
            x: size.width * xFraction,
            y: size.height * yFraction
        ),
        strength: strength
    )
}

private func smoothStep(from lower: CGFloat, to upper: CGFloat, value: CGFloat) -> CGFloat {
    guard upper > lower else { return 0 }
    let t = min(max((value - lower) / (upper - lower), 0), 1)
    return t * t * (3 - 2 * t)
}

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
        ZStack {
            AquariumBodyAura(style: configuration.vesselStyle)

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
        }
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

                AquariumCausticPrismField(
                    colors: sceneAccentColors + sceneTone.accentColors,
                    phase: phase
                )
                .opacity(sceneTone == .night ? 0.18 : 0.28)
                .blendMode(.screen)
                .mask(
                    WaterSurfaceShape(
                        level: waterLevel,
                        waveShift: 0.02 * sin(phase * 1.7)
                    )
                )

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

                AquariumWaterlineSheen(level: waterLevel)
                    .opacity(sceneTone == .night ? 0.22 : 0.34)

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

                    if !configuration.resolvedCompanions.isEmpty {
                        companionView(in: size)
                    }

                    if let visitor {
                        rareVisitorView(visitor)
                    }

                    ForEach(Array(layouts.enumerated()), id: \.offset) { _, layout in
                        FishSprite(
                            species: layout.species,
                            vitality: petSnapshot.colorStrength,
                            isAlive: petSnapshot.isAlive,
                            bodyOvalScaleY: petSnapshot.bodyOvalScaleY
                        )
                        .scaleEffect(layout.spriteScale)
                        .frame(
                            width: layout.size.width,
                            height: layout.size.height
                        )
                        .drawingGroup()
                        .scaleEffect(x: layout.isMirrored ? -1 : 1, y: 1)
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
        if petSnapshot.mood == .burst {
            return []
        }

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
        let laneWidth = size.width * (isCompactFormat ? 0.076 : (isAppIconFormat ? 0.064 : 0.096)) * personality.horizontalRangeMultiplier
        let verticalRange = size.height * (isCompactFormat ? 0.044 : (isAppIconFormat ? 0.038 : 0.058)) * personality.verticalRangeMultiplier

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

        var layouts = (0..<count).map { index in
            let species = speciesLineup[index]
            let spriteScale = visualSpriteScale(for: species)
            let motionScale = personality.motionScale * sceneTone.motionScale
            let burstPulse = 0.86 + 0.44 * pow(max(0, sin(phase * 0.62 + Double(index) * 1.9)), 2)
            let effectiveMotionScale = motionScale * burstPulse
            let cruisePhase = phase * effectiveMotionScale * (0.50 + Double(index) * 0.06) + Double(index) * 1.7
            let meanderPhase = phase * effectiveMotionScale * (1.02 + Double(index) * 0.09) + Double(index) * 2.4
            let bobPhase = phase * effectiveMotionScale * (0.82 + Double(index) * 0.07) + Double(index) * 1.2
            let tiltPhase = phase * effectiveMotionScale * (1.28 + Double(index) * 0.05) + Double(index) * 0.9
            let driftScale = petSnapshot.driftIntensity * personality.driftIntensityMultiplier
            let sweep = CGFloat(sin(cruisePhase) * 0.74 + sin(meanderPhase) * 0.26)
            let bob = CGFloat(sin(bobPhase) * 0.76 + cos(tiltPhase) * 0.24)
            let idlePosition = CGPoint(
                x: size.width * baseX[index] + sweep * laneWidth * driftScale,
                y: size.height * baseY[index] + bob * verticalRange * driftScale
            )
            let width = size.width * scales[index] * formatScale
            let height = width * 0.72
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
                isMirrored: petSnapshot.isAlive ? heading > 0 : index % 2 == 0,
                isBaby: false
            )
        }

        if let babySpecies = petSnapshot.babySpecies, petSnapshot.isAlive {
            let spriteScale = visualSpriteScale(for: babySpecies) * 0.58
            let babyPhase = phase * personality.motionScale * 0.94 + 5.1
            let babyPosition = clampedFishPosition(
                CGPoint(
                    x: size.width * 0.54 + CGFloat(sin(babyPhase)) * size.width * 0.07,
                    y: size.height * 0.57 + CGFloat(cos(babyPhase * 1.4)) * size.height * 0.03
                ),
                species: babySpecies,
                spriteScale: spriteScale,
                size: size,
                waterLevel: waterLevel
            )
            let babyWidth = size.width * (isCompactFormat ? 0.13 : (isAppIconFormat ? 0.20 : 0.16)) * formatScale

            layouts.append(
                FishLayout(
                    species: babySpecies,
                    position: babyPosition,
                    size: CGSize(
                        width: babyWidth * (0.88 + CGFloat(petSnapshot.fullnessProgress) * 0.06),
                        height: babyWidth * 0.66
                    ),
                    spriteScale: isAppIconFormat ? 2.3 : spriteScale,
                    rotation: Double(sin(babyPhase * 1.2)) * 8,
                    isMirrored: cos(babyPhase) > 0,
                    isBaby: true
                )
            )
        }

        return layouts
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
        let layouts = companionLayouts(in: size)

        ForEach(Array(layouts.enumerated()), id: \.offset) { _, layout in
            CompanionSprite(
                style: layout.style,
                accent: accent,
                secondary: secondary,
                substrateHighlight: configuration.substrate.accentColors[1]
            )
            .frame(width: layout.renderSize.width, height: layout.renderSize.height)
            .rotationEffect(.degrees(layout.rotation))
            .scaleEffect(x: layout.isMirrored ? -1 : 1, y: 1)
            .position(layout.position)
        }
    }

    private func companionLayouts(in size: CGSize) -> [CompanionLayout] {
        let companions = configuration.resolvedCompanions
        return companions.enumerated().map { index, style in
            companionLayout(for: style, index: index, count: companions.count, in: size)
        }
    }

    private func companionLayout(for style: CompanionStyle, index: Int, count: Int, in size: CGSize) -> CompanionLayout {
        let metrics: (
            baseX: CGFloat,
            baseY: CGFloat,
            range: CGFloat,
            stepLift: CGFloat,
            speed: Double,
            offset: Double,
            naturalFacingRight: Bool
        )

        switch style {
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

        let slotOffset = count == 1
        ? 0
        : CGFloat(index) - CGFloat(count - 1) * 0.5
        let motionPhase = phase * metrics.speed + metrics.offset + Double(index) * 0.9
        let horizontalDrift = CGFloat(sin(motionPhase))
        let lift = abs(CGFloat(sin(motionPhase * 1.9))) * size.height * metrics.stepLift
        let movingRight = cos(motionPhase) > 0
        let isMirrored = metrics.naturalFacingRight ? !movingRight : movingRight
        let rotationStrength: CGFloat

        switch style {
        case .shrimp:
            rotationStrength = 4.8
        case .crab:
            rotationStrength = 2.6
        case .seaCucumber, .nudibranchFlame, .nudibranchRibbon:
            rotationStrength = 1.4
        default:
            rotationStrength = 1.8
        }

        let renderSize = companionRenderSize(for: style, in: size)
        let proposedPosition = CGPoint(
            x: size.width * metrics.baseX + slotOffset * size.width * 0.16 + horizontalDrift * size.width * metrics.range,
            y: size.height * metrics.baseY - lift
        )

        return CompanionLayout(
            style: style,
            position: clampedCompanionPosition(proposedPosition, renderSize: renderSize, in: size),
            renderSize: renderSize,
            isMirrored: isMirrored,
            rotation: Double(horizontalDrift * rotationStrength)
        )
    }

    private func clampedCompanionPosition(_ position: CGPoint, renderSize: CGSize, in size: CGSize) -> CGPoint {
        let normalizedY = min(max(position.y / max(size.height, 1), 0), 1)
        let orbCurveBoost = configuration.vesselStyle == .orb
        ? abs(normalizedY - 0.52) * size.width * 0.15
        : 0
        let sidePadding: CGFloat = configuration.vesselStyle == .orb ? 6 : 4
        let xMargin = renderSize.width * 0.5 + sidePadding + orbCurveBoost
        let minY = renderSize.height * 0.5 + 2
        let maxY = size.height - renderSize.height * 0.42

        return CGPoint(
            x: min(max(position.x, xMargin), size.width - xMargin),
            y: min(max(position.y, minY), maxY)
        )
    }

    private func companionRenderSize(for style: CompanionStyle, in size: CGSize) -> CGSize {
        switch style {
        case .none:
            return .zero
        case .snail:
            return CGSize(width: size.width * 0.13, height: size.width * 0.10)
        case .shrimp:
            return CGSize(width: size.width * 0.15, height: size.width * 0.10)
        case .crab:
            return CGSize(width: size.width * 0.16, height: size.width * 0.11)
        case .seaCucumber:
            return CGSize(width: size.width * 0.22, height: size.width * 0.10)
        case .nudibranchFlame:
            return CGSize(width: size.width * 0.23, height: size.width * 0.11)
        case .nudibranchRibbon:
            return CGSize(width: size.width * 0.22, height: size.width * 0.11)
        }
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
    let isBaby: Bool
}

private struct BurstFishVisual {
    let species: FishSpecies
    let scenePosition: CGPoint
    let renderSize: CGSize
    let rotation: CGFloat
    let isMirrored: Bool
}

private struct BurstAnimationState {
    let burstID: UUID
    let startedAt: TimeInterval
    let fishVisuals: [BurstFishVisual]
    let bodyOvalScaleY: CGFloat
}

private struct RecentFeedHandoff {
    let response: FoodResponse
    let startedAt: Date
    let duration: TimeInterval
}

private struct CompanionLayout {
    let style: CompanionStyle
    let position: CGPoint
    let renderSize: CGSize
    let isMirrored: Bool
    let rotation: Double
}

private struct ThoughtLayout {
    let text: String
    let position: CGPoint
    let pointsToTrailing: Bool
}

private enum RareVisitorKind: Hashable {
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

    var hashToken: Int {
        switch self {
        case .dawn:
            return 0
        case .day:
            return 1
        case .dusk:
            return 2
        case .night:
            return 3
        }
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
    @Environment(\.colorScheme) private var colorScheme

    let configuration: AquariumConfiguration
    let style: AquariumVesselStyle

    private var bodyShape: AquariumBodyShape {
        AquariumBodyShape(style: style)
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                bodyShape
                    .fill(
                        AngularGradient(
                            colors: configuration.decoration.accentColors + configuration.fishPalette + [Color.clear],
                            center: .center
                        )
                    )
                    .scaleEffect(style == .orb ? 1.04 : 1.02)
                    .blur(radius: size.width * 0.05)
                    .offset(y: size.height * 0.16)
                    .opacity(style == .orb ? 0.34 : 0.28)
                    .blendMode(.screen)
                    .mask(
                        bodyShape
                            .scaleEffect(style == .orb ? 1.08 : 1.04)
                    )

                bodyShape
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
                        lineWidth: style == .orb ? 4 : 5
                    )
                    .blur(radius: style == .orb ? 12 : 14)
                    .mask(
                        bodyShape
                            .fill(
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
                    )
                    .opacity(colorScheme == .dark ? 0.65 : 0.40)
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
    let vitality: Double
    let isAlive: Bool
    let bodyOvalScaleY: CGFloat

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
                        .frame(width: species.bodyWidth, height: species.bodyHeight * bodyOvalScaleY)
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
    }
}

private struct CompanionSprite: View {
    let style: CompanionStyle
    let accent: Color
    let secondary: Color
    let substrateHighlight: Color

    var body: some View {
        Group {
            switch style {
            case .none:
                EmptyView()
            case .snail:
                SnailSprite(accent: accent)
            case .shrimp:
                ShrimpSprite(shell: accent, highlight: secondary)
            case .crab:
                CrabSprite(shell: accent, highlight: secondary)
            case .seaCucumber:
                SeaCucumberSprite(bodyColor: accent, underside: secondary, highlight: substrateHighlight)
            case .nudibranchFlame:
                NudibranchSprite(variant: .flame)
            case .nudibranchRibbon:
                NudibranchSprite(variant: .ribbon)
            }
        }
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

private struct AquariumCausticPrismField: View {
    let colors: [Color]
    let phase: Double

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let lead = colors[0]
            let mid = colors[1]
            let accent = colors[2]

            ZStack {
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.34),
                                lead.opacity(0.20),
                                Color.clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size.width * 0.62, height: size.height * 0.14)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -size.width * 0.10, y: -size.height * 0.08)

                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [
                                mid.opacity(0.20),
                                accent.opacity(0.15),
                                Color.clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size.width * 0.50, height: size.height * 0.12)
                    .rotationEffect(.degrees(18))
                    .offset(
                        x: size.width * 0.18,
                        y: size.height * (-0.01 + CGFloat(sin(phase * 0.7)) * 0.01)
                    )

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.26),
                                Color.white.opacity(0.02),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size.width * 0.54, height: size.height * 0.018)
                    .blur(radius: 8)
                    .offset(
                        x: size.width * (0.02 + CGFloat(sin(phase * 0.9)) * 0.015),
                        y: -size.height * 0.12
                    )
            }
            .blur(radius: size.width * 0.012)
        }
    }
}

private struct AquariumWaterlineSheen: View {
    let level: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let y = size.height * (1 - level)

            ZStack {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.44),
                                Color.white.opacity(0.02),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size.width * 0.72, height: max(2, size.height * 0.020))
                    .blur(radius: 10)
                    .position(x: size.width * 0.48, y: y - size.height * 0.030)

                Ellipse()
                    .fill(Color.white.opacity(0.30))
                    .frame(width: size.width * 0.11, height: size.height * 0.028)
                    .blur(radius: 5)
                    .position(x: size.width * 0.22, y: y - size.height * 0.045)
            }
            .blendMode(.screen)
        }
        .allowsHitTesting(false)
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
        case .burst:
            return "💥"
        case .critical:
            return self == .greedy ? "🍽️" : "😫"
        case .hungry:
            return self == .shy ? "🥺" : "🍤"
        case .stuffed:
            return self == .greedy ? "😵" : "🍽️"
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

private struct AquariumBodyAura: View {
    @Environment(\.colorScheme) private var colorScheme

    let style: AquariumVesselStyle

    private var bodyShape: AquariumBodyShape {
        AquariumBodyShape(style: style)
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let baseShadowOpacity = colorScheme == .dark ? 0.34 : 0.045
            let colorBloomOpacity = colorScheme == .dark ? 0.0 : 0.02
            let lift = style == .orb
            ? (colorScheme == .dark ? 0.42 : 0.52)
            : (colorScheme == .dark ? 0.34 : 0.44)
            let verticalScale = style == .orb
            ? (colorScheme == .dark ? 0.30 : 0.20)
            : (colorScheme == .dark ? 0.24 : 0.16)

            ZStack {
                if colorScheme == .dark {
                    bodyShape
                        .fill(Color.white.opacity(0.16))
                        .blur(radius: size.width * 0.020)
                        .scaleEffect(1.02)
                }

                bodyShape
                    .fill(Color.black.opacity(baseShadowOpacity))
                    .blur(radius: size.width * (colorScheme == .dark ? 0.10 : 0.085))
                    .scaleEffect(x: 0.92, y: verticalScale, anchor: .bottom)
                    .offset(y: size.height * lift)

                if colorBloomOpacity > 0 {
                    bodyShape
                        .fill(Color(red: 0.62, green: 0.70, blue: 0.86).opacity(colorBloomOpacity))
                        .blur(radius: size.width * 0.14)
                        .scaleEffect(x: 0.96, y: 0.34, anchor: .bottom)
                        .offset(y: size.height * (lift - 0.02))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#if canImport(SpriteKit) && canImport(UIKit)
struct SpriteKitAquariumSceneView: View {
    let profile: BowlProfile
    let configuration: AquariumConfiguration
    let format: AquariumDisplayFormat
    let feedBursts: [AquariumFeedBurst]
    let tapRipples: [AquariumTapRipple]
    let phaseOffset: Double
    let isPaused: Bool
    let onFeedBurstConsumed: AquariumFeedBurstConsumedHandler

    var body: some View {
        GeometryReader { _ in
            AquariumSpriteRepresentable(
                profile: profile,
                configuration: configuration,
                format: format,
                feedBursts: feedBursts,
                tapRipples: tapRipples,
                phaseOffset: phaseOffset,
                isPaused: isPaused,
                onFeedBurstConsumed: onFeedBurstConsumed
            )
            .padding(format.bodyInset)
            .clipShape(AquariumBodyShape(style: configuration.vesselStyle))
        }
        .aspectRatio(format.aspectRatio, contentMode: .fit)
    }
}

@MainActor
private struct AquariumSpriteRepresentable: UIViewRepresentable {
    let profile: BowlProfile
    let configuration: AquariumConfiguration
    let format: AquariumDisplayFormat
    let feedBursts: [AquariumFeedBurst]
    let tapRipples: [AquariumTapRipple]
    let phaseOffset: Double
    let isPaused: Bool
    let onFeedBurstConsumed: AquariumFeedBurstConsumedHandler

    func makeCoordinator() -> AquariumSpriteCoordinator {
        AquariumSpriteCoordinator(
            profile: profile,
            configuration: configuration,
            format: format,
            feedBursts: feedBursts,
            tapRipples: tapRipples,
            phaseOffset: phaseOffset,
            onFeedBurstConsumed: onFeedBurstConsumed
        )
    }

    func makeUIView(context: Context) -> SKView {
        let view = SKView(frame: .zero)
        view.allowsTransparency = true
        view.backgroundColor = .clear
        view.isOpaque = false
        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = true
        view.preferredFramesPerSecond = 60
        view.isPaused = isPaused
        context.coordinator.attach(view: view)
        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        context.coordinator.update(
            profile: profile,
            configuration: configuration,
            format: format,
            feedBursts: feedBursts,
            tapRipples: tapRipples,
            phaseOffset: phaseOffset,
            isPaused: isPaused,
            view: uiView
        )
    }
}

@MainActor
private final class AquariumSpriteCoordinator {
    let scene: AquariumSpriteScene

    init(
        profile: BowlProfile,
        configuration: AquariumConfiguration,
        format: AquariumDisplayFormat,
        feedBursts: [AquariumFeedBurst],
        tapRipples: [AquariumTapRipple],
        phaseOffset: Double,
        onFeedBurstConsumed: @escaping AquariumFeedBurstConsumedHandler
    ) {
        scene = AquariumSpriteScene(
            profile: profile,
            configuration: configuration,
            format: format,
            feedBursts: feedBursts,
            tapRipples: tapRipples,
            phaseOffset: phaseOffset,
            onFeedBurstConsumed: onFeedBurstConsumed
        )
    }

    func attach(view: SKView) {
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        scene.size = view.bounds.size
        if view.scene !== scene {
            view.presentScene(scene)
        }
        scene.prepareInitialFrameIfNeeded(referenceDate: .now)
    }

    func update(
        profile: BowlProfile,
        configuration: AquariumConfiguration,
        format: AquariumDisplayFormat,
        feedBursts: [AquariumFeedBurst],
        tapRipples: [AquariumTapRipple],
        phaseOffset: Double,
        isPaused: Bool,
        view: SKView
    ) {
        scene.apply(
            profile: profile,
            configuration: configuration,
            format: format,
            feedBursts: feedBursts,
            tapRipples: tapRipples,
            phaseOffset: phaseOffset
        )
        scene.setRenderPaused(isPaused)
        view.isPaused = isPaused
        view.preferredFramesPerSecond = isPaused ? 30 : min(60, view.window?.windowScene?.screen.maximumFramesPerSecond ?? 60)
        scene.size = view.bounds.size
        if view.scene !== scene {
            view.presentScene(scene)
        }
        scene.prepareInitialFrameIfNeeded(referenceDate: .now)
    }
}

private final class AquariumSpriteScene: SKScene {
    private static var bubbleTextureCache: [Int: SKTexture] = [:]
    private static var pelletTextureCache: [Int: SKTexture] = [:]
    private static var rippleTextureCache: [Int: SKTexture] = [:]
    private static var fishTextureCache: [AquariumSpriteFishTextureKey: SKTexture] = [:]
    private static var companionTextureCache: [AquariumSpriteCompanionTextureKey: SKTexture] = [:]
    private static var visitorTextureCache: [AquariumSpriteVisitorTextureKey: SKTexture] = [:]
    private static var thoughtTextureCache: [AquariumSpriteThoughtTextureKey: SKTexture] = [:]

    private var profile: BowlProfile
    private var configuration: AquariumConfiguration
    private var format: AquariumDisplayFormat
    private var feedBursts: [AquariumFeedBurst]
    private var tapRipples: [AquariumTapRipple]
    private var phaseOffset: Double

    private var lastTextureSignature: AquariumSpriteTextureSignature?
    private var bubbleTexture: SKTexture?
    private var pelletTexture: SKTexture?
    private var rippleTexture: SKTexture?
    private var fishTextures: [FishSpecies: SKTexture] = [:]
    private var companionTextures: [CompanionStyle: SKTexture] = [:]
    private var visitorTextures: [RareVisitorKind: SKTexture] = [:]
    private var thoughtTextures: [String: SKTexture] = [:]

    private var bubbleNodes: [SKSpriteNode] = []
    private var pelletNodes: [SKSpriteNode] = []
    private var rippleNodes: [AquariumSpriteRippleNode] = []
    private var fishNodes: [SKNode] = []
    private var burstShockwaveNodes: [SKSpriteNode] = []
    private var companionNodes: [SKSpriteNode] = []
    private var visitorNode: SKSpriteNode?
    private var fishThoughtNodes: [SKSpriteNode] = []
    private var visitorThoughtNode: SKSpriteNode?
    private var burstFlashNode: SKSpriteNode?
    private var animationElapsed: TimeInterval = 0
    private var lastUpdateTimestamp: TimeInterval?
    private var lastFrameDuration: TimeInterval = 1.0 / 60.0
    private var renderPaused = false
    private let animationEpoch = Date()
    private var hasRenderedInitialFrame = false
    private var feedBurstStartTimes: [UUID: TimeInterval] = [:]
    private var feedBurstFeedingStartTimes: [UUID: TimeInterval] = [:]
    private var tapRippleStartTimes: [UUID: TimeInterval] = [:]
    private var consumedFeedBurstIDs: Set<UUID> = []
    private var activeBurstAnimation: BurstAnimationState?
    private var recentFeedHandoff: RecentFeedHandoff?
    private var lastRenderedFoodResponse: FoodResponse?
    private var lastRenderedFishVisuals: [BurstFishVisual] = []
    private var onFeedBurstConsumed: AquariumFeedBurstConsumedHandler

    private static let fishSpriteChildName = "fishSprite"
    private static let fishVerticalStretchNodeName = "fishVerticalStretch"

    init(
        profile: BowlProfile,
        configuration: AquariumConfiguration,
        format: AquariumDisplayFormat,
        feedBursts: [AquariumFeedBurst],
        tapRipples: [AquariumTapRipple],
        phaseOffset: Double,
        onFeedBurstConsumed: @escaping AquariumFeedBurstConsumedHandler
    ) {
        self.profile = profile
        self.configuration = configuration
        self.format = format
        self.feedBursts = feedBursts
        self.tapRipples = tapRipples
        self.phaseOffset = phaseOffset
        self.onFeedBurstConsumed = onFeedBurstConsumed
        super.init(size: .zero)
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(
        profile: BowlProfile,
        configuration: AquariumConfiguration,
        format: AquariumDisplayFormat,
        feedBursts: [AquariumFeedBurst],
        tapRipples: [AquariumTapRipple],
        phaseOffset: Double
    ) {
        self.profile = profile
        self.configuration = configuration
        self.format = format
        self.feedBursts = feedBursts
        self.tapRipples = tapRipples
        self.phaseOffset = phaseOffset
        syncAnimationAnchors(referenceDate: .now)
        rebuildTexturesIfNeeded(scale: effectiveScale)
    }

    func setRenderPaused(_ paused: Bool) {
        if renderPaused != paused, !paused {
            lastUpdateTimestamp = nil
        }
        renderPaused = paused
        isPaused = paused
    }

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        prepareInitialFrameIfNeeded(referenceDate: .now)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        rebuildTexturesIfNeeded(scale: effectiveScale)
        hasRenderedInitialFrame = false
        prepareInitialFrameIfNeeded(referenceDate: .now)
    }

    override func update(_ currentTime: TimeInterval) {
        guard size.width > 1, size.height > 1 else { return }

        rebuildTexturesIfNeeded(scale: effectiveScale)

        if let lastUpdateTimestamp {
            let delta = max(0, min(currentTime - lastUpdateTimestamp, 1.0 / 20.0))
            animationElapsed += delta
            lastFrameDuration = delta
        } else {
            lastFrameDuration = 1.0 / 60.0
        }
        lastUpdateTimestamp = currentTime

        renderCurrentFrame(referenceDate: .now)
        flushConsumedFeedBurstsIfNeeded()
    }

    func renderCurrentFrame(referenceDate: Date) {
        guard size.width > 1, size.height > 1 else { return }

        let phase = animationElapsed / 4.1 + phaseOffset
        let snapshot = profile.petSnapshot(at: referenceDate)
        let animationDate = animationEpoch.addingTimeInterval(animationElapsed)
        let sceneFeedBursts = sceneTimedFeedBursts()
        let baseResolver = AquariumMetalMotionResolver(
            configuration: configuration,
            format: format,
            phase: phase,
            petSnapshot: snapshot,
            feedBursts: sceneFeedBursts,
            tapRipples: sceneTimedTapRipples(),
            animationDate: animationDate,
            size: size
        )
        let effectiveFoodResponse = blendedFoodResponse(
            current: baseResolver.activeFoodResponse(),
            at: animationDate
        )
        let resolver = AquariumMetalMotionResolver(
            configuration: configuration,
            format: format,
            phase: phase,
            petSnapshot: snapshot,
            feedBursts: sceneFeedBursts,
            tapRipples: sceneTimedTapRipples(),
            animationDate: animationDate,
            focusedFoodResponse: effectiveFoodResponse,
            size: size
        )
        let fishLayouts = resolver.fishLayouts()
        let burstProgress = activeBurstAnimation.map { burstAnimationProgress(for: $0) }
        lastRenderedFoodResponse = effectiveFoodResponse

        syncBubbles(with: resolver.bubbles())
        syncRipples(with: resolver.ripples())
        syncPellets(with: activeBurstAnimation == nil ? resolver.foodPellets() : [])
        syncVisitor(with: resolver.rareVisitor())
        syncCompanions(with: resolver.companionLayouts())

        if let activeBurstAnimation, let burstProgress {
            syncFishBurstAnimation(
                activeBurstAnimation,
                progress: burstProgress
            )
            syncFishThoughts(with: [])
            syncVisitorThought(with: nil)
            syncBurstOverlay(progress: burstProgress, fishVisuals: activeBurstAnimation.fishVisuals)
        } else {
            lastRenderedFishVisuals = syncFish(with: fishLayouts, using: resolver, snapshot: snapshot)
            syncFishThoughts(with: resolver.fishThoughtBubbles())
            syncVisitorThought(with: resolver.visitorThoughtBubble())
            syncBurstOverlay(progress: nil, fishVisuals: [])
        }

        hasRenderedInitialFrame = true
    }

    func prepareInitialFrameIfNeeded(referenceDate: Date) {
        guard !hasRenderedInitialFrame else { return }
        renderCurrentFrame(referenceDate: referenceDate)
    }

    private func rebuildTexturesIfNeeded(scale: CGFloat) {
        let scaleBucket = Int(max(2, scale) * 10)
        let signature = AquariumSpriteTextureSignature(
            configuration: configuration,
            scaleBucket: scaleBucket
        )
        guard signature != lastTextureSignature else { return }

        let resolvedScale = max(2, scale)

        guard
            let nextBubbleTexture = Self.cachedTexture(
                cache: &Self.bubbleTextureCache,
                key: scaleBucket,
                build: { [self] in
                    makeTexture(size: CGSize(width: 26, height: 26), scale: resolvedScale, content: {
                        AquariumMetalBubbleSpriteView()
                    })
                }
            ),
            let nextPelletTexture = Self.cachedTexture(
                cache: &Self.pelletTextureCache,
                key: scaleBucket,
                build: { [self] in
                    makeTexture(size: CGSize(width: 16, height: 16), scale: resolvedScale, content: {
                        AquariumMetalPelletSpriteView()
                    })
                }
            ),
            let nextRippleTexture = Self.cachedTexture(
                cache: &Self.rippleTextureCache,
                key: scaleBucket,
                build: { [self] in
                    makeTexture(size: CGSize(width: 120, height: 120), scale: resolvedScale, content: {
                        AquariumMetalRippleSpriteView()
                    })
                }
            )
        else {
            return
        }

        var nextFishTextures: [FishSpecies: SKTexture] = [:]
        for species in configuration.uniqueFishSpecies {
            let key = AquariumSpriteFishTextureKey(species: species, scaleBucket: scaleBucket)
            if let texture = Self.cachedTexture(
                cache: &Self.fishTextureCache,
                key: key,
                build: { [self] in
                    let canvas = AquariumMetalMotionResolver.textureCanvasSize(for: species)
                    return makeTexture(size: canvas, scale: resolvedScale, content: {
                        FishSprite(
                            species: species,
                            vitality: 1,
                            isAlive: true,
                            bodyOvalScaleY: 1
                        )
                        .frame(width: canvas.width, height: canvas.height)
                    })
                }
            ) {
                nextFishTextures[species] = texture
            }
        }
        guard nextFishTextures.count == configuration.uniqueFishSpecies.count else {
            return
        }

        var nextCompanionTextures: [CompanionStyle: SKTexture] = [:]
        for companion in Set(configuration.resolvedCompanions) {
            let key = AquariumSpriteCompanionTextureKey(
                configurationHash: configuration.hashValue,
                companion: companion,
                scaleBucket: scaleBucket
            )
            if let texture = Self.cachedTexture(
                cache: &Self.companionTextureCache,
                key: key,
                build: { [self] in
                    let canvas = AquariumMetalMotionResolver.textureCanvasSize(for: companion)
                    return makeTexture(size: canvas, scale: resolvedScale, content: {
                        AquariumMetalCompanionSnapshotView(
                            companion: companion,
                            accent: configuration.decoration.accentColors.first ?? configuration.substrate.accentColors.first ?? .orange,
                            secondary: configuration.fishPalette.last ?? .white,
                            substrateHighlight: configuration.substrate.accentColors[1],
                            canvasSize: canvas
                        )
                    })
                }
            ) {
                nextCompanionTextures[companion] = texture
            } else {
                return
            }
        }

        var nextVisitorTextures: [RareVisitorKind: SKTexture] = [:]
        if let moonJellyTexture = Self.cachedTexture(
            cache: &Self.visitorTextureCache,
            key: AquariumSpriteVisitorTextureKey(kind: .moonJelly, scaleBucket: scaleBucket),
            build: { [self] in
                makeTexture(size: CGSize(width: 36, height: 42), scale: resolvedScale, content: {
                    MoonJellyVisitor()
                        .frame(width: 36, height: 42)
                })
            }
        ) {
            nextVisitorTextures[.moonJelly] = moonJellyTexture
        }
        if let seaAngelTexture = Self.cachedTexture(
            cache: &Self.visitorTextureCache,
            key: AquariumSpriteVisitorTextureKey(kind: .seaAngel, scaleBucket: scaleBucket),
            build: { [self] in
                makeTexture(size: CGSize(width: 34, height: 28), scale: resolvedScale, content: {
                    SeaAngelVisitor()
                        .frame(width: 34, height: 28)
                })
            }
        ) {
            nextVisitorTextures[.seaAngel] = seaAngelTexture
        }

        var nextThoughtTextures: [String: SKTexture] = [:]
        let thoughtTexts = ["🍽️", "😫", "🥺", "🍤", "😵", "💥", "💤", "✨", "⚡️", "🌙", "🫧", "💭", "☁️", "🪽"]
        for text in thoughtTexts {
            for pointsToTrailing in [false, true] {
                let key = "\(text)|\(pointsToTrailing)"
                let cacheKey = AquariumSpriteThoughtTextureKey(
                    text: text,
                    pointsToTrailing: pointsToTrailing,
                    scaleBucket: scaleBucket
                )
                if let texture = Self.cachedTexture(
                    cache: &Self.thoughtTextureCache,
                    key: cacheKey,
                    build: { [self] in
                        makeTexture(size: CGSize(width: 56, height: 34), scale: resolvedScale, content: {
                            ThoughtBubble(text: text, pointsToTrailing: pointsToTrailing)
                                .frame(width: 56, height: 34)
                        })
                    }
                ) {
                    nextThoughtTextures[key] = texture
                }
            }
        }

        bubbleTexture = nextBubbleTexture
        pelletTexture = nextPelletTexture
        rippleTexture = nextRippleTexture
        fishTextures = nextFishTextures
        companionTextures = nextCompanionTextures
        visitorTextures = nextVisitorTextures
        thoughtTextures = nextThoughtTextures
        lastTextureSignature = signature

        // Force node textures to refresh immediately when the tank config changes.
        for node in bubbleNodes {
            node.texture = bubbleTexture
        }
        for node in pelletNodes {
            node.texture = pelletTexture
        }
        for node in rippleNodes {
            node.updateTextures(ringTexture: rippleTexture, bubbleTexture: bubbleTexture)
        }
    }

    private var effectiveScale: CGFloat {
        view?.window?.screen.scale ?? view?.contentScaleFactor ?? 3
    }

    private func syncAnimationAnchors(referenceDate: Date) {
        let activeFeedIDs = Set(feedBursts.map(\.id))
        feedBurstStartTimes = feedBurstStartTimes.filter { activeFeedIDs.contains($0.key) }
        feedBurstFeedingStartTimes = feedBurstFeedingStartTimes.filter { activeFeedIDs.contains($0.key) }
        consumedFeedBurstIDs = consumedFeedBurstIDs.filter { activeFeedIDs.contains($0) }
        for burst in feedBursts where feedBurstStartTimes[burst.id] == nil {
            feedBurstStartTimes[burst.id] = animationElapsed + max(0, burst.startedAt.timeIntervalSince(referenceDate))
        }
        var previousConsumeTime: TimeInterval?
        for burst in feedBursts {
            guard let startTime = feedBurstStartTimes[burst.id] else { continue }
            let defaultFeedingStartTime = max(
                startTime + AquariumFeedBurst.dropDuration,
                previousConsumeTime ?? startTime + AquariumFeedBurst.dropDuration
            )
            let feedingStartTime = max(
                feedBurstFeedingStartTimes[burst.id] ?? defaultFeedingStartTime,
                startTime + AquariumFeedBurst.dropDuration
            )
            feedBurstFeedingStartTimes[burst.id] = feedingStartTime
            previousConsumeTime = feedingStartTime + AquariumFeedBurst.grazeDuration
        }

        let activeRippleIDs = Set(tapRipples.map(\.id))
        tapRippleStartTimes = tapRippleStartTimes.filter { activeRippleIDs.contains($0.key) }
        for ripple in tapRipples where tapRippleStartTimes[ripple.id] == nil {
            tapRippleStartTimes[ripple.id] = animationElapsed
        }
    }

    private func flushConsumedFeedBurstsIfNeeded() {
        if let activeBurstAnimation {
            if burstAnimationProgress(for: activeBurstAnimation) >= 1 {
                self.activeBurstAnimation = nil
            }
        }

        let sceneFeedBursts = sceneTimedFeedBursts()
        let scheduledBursts = scheduleFeedBursts(sceneFeedBursts)
        guard let dueIndex = scheduledBursts.firstIndex(where: {
            !consumedFeedBurstIDs.contains($0.burst.id) && animationEpoch.addingTimeInterval(animationElapsed) >= $0.consumeTime
        }) else {
            return
        }

        let scheduledBurst = scheduledBursts[dueIndex]
        guard consumedFeedBurstIDs.insert(scheduledBurst.burst.id).inserted else { return }

        let burstWouldPop = profile.willBurstOnNextFeed(at: scheduledBurst.consumeTime)
        if burstWouldPop {
            recentFeedHandoff = nil
            startBurstAnimation(
                for: scheduledBurst,
                snapshot: profile.petSnapshot(at: scheduledBurst.consumeTime)
            )
            DispatchQueue.main.async { [onFeedBurstConsumed] in
                onFeedBurstConsumed(scheduledBurst.burst.id)
            }
            return
        }

        if let lastRenderedFoodResponse {
            let hasPendingSuccessor = dueIndex < scheduledBursts.index(before: scheduledBursts.endIndex)
            recentFeedHandoff = RecentFeedHandoff(
                response: lastRenderedFoodResponse,
                startedAt: scheduledBurst.consumeTime,
                duration: hasPendingSuccessor
                ? AquariumFeedBurst.handoffBlendDuration
                : AquariumFeedBurst.returnBlendDuration
            )
        }

        DispatchQueue.main.async { [onFeedBurstConsumed] in
            onFeedBurstConsumed(scheduledBurst.burst.id)
        }
    }

    private func startBurstAnimation(
        for scheduledBurst: AquariumScheduledFeedBurst,
        snapshot: AquariumPetSnapshot
    ) {
        activeBurstAnimation = BurstAnimationState(
            burstID: scheduledBurst.burst.id,
            startedAt: scheduledBurst.consumeTime.timeIntervalSince(animationEpoch),
            fishVisuals: lastRenderedFishVisuals,
            bodyOvalScaleY: snapshot.bodyOvalScaleY
        )
        syncPellets(with: [])
        syncFishThoughts(with: [])
        syncVisitorThought(with: nil)
        hasRenderedInitialFrame = true
    }

    private func sceneTimedFeedBursts() -> [AquariumFeedBurst] {
        feedBursts.map { burst in
            let startTime = feedBurstStartTimes[burst.id] ?? animationElapsed
            return AquariumFeedBurst(
                id: burst.id,
                startedAt: animationEpoch.addingTimeInterval(startTime),
                xFraction: burst.xFraction,
                feedingStartsAt: animationEpoch.addingTimeInterval(
                    feedBurstFeedingStartTimes[burst.id]
                    ?? startTime + AquariumFeedBurst.dropDuration
                )
            )
        }
    }

    private func sceneTimedTapRipples() -> [AquariumTapRipple] {
        tapRipples.map { ripple in
            AquariumTapRipple(
                id: ripple.id,
                startedAt: animationEpoch.addingTimeInterval(tapRippleStartTimes[ripple.id] ?? animationElapsed),
                normalizedLocation: ripple.normalizedLocation
            )
        }
    }

    private func syncBubbles(with bubbles: [AquariumDynamicBubble]) {
        syncNodeCount(&bubbleNodes, desiredCount: bubbles.count) {
            let node = SKSpriteNode(texture: bubbleTexture)
            node.zPosition = 10
            return node
        }

        for (index, bubble) in bubbles.enumerated() {
            let node = bubbleNodes[index]
            node.texture = bubbleTexture
            node.position = scenePoint(from: bubble.position)
            node.size = CGSize(width: bubble.size, height: bubble.size)
            node.alpha = bubble.opacity
            node.isHidden = false
        }
    }

    private func syncPellets(with pellets: [AquariumFoodPellet]) {
        let visiblePellets = pellets.filter { $0.scale > 0.001 }
        syncNodeCount(&pelletNodes, desiredCount: visiblePellets.count) {
            let node = SKSpriteNode(texture: pelletTexture)
            node.zPosition = 22
            return node
        }

        for (index, pellet) in visiblePellets.enumerated() {
            let node = pelletNodes[index]
            let pelletSize = 9 * pellet.scale
            node.texture = pelletTexture
            node.position = scenePoint(
                from: CGPoint(x: size.width * pellet.xFraction, y: size.height * pellet.yFraction)
            )
            node.size = CGSize(width: pelletSize, height: pelletSize)
            node.alpha = min(1, pellet.scale * 1.3)
            node.isHidden = false
        }
    }

    private func syncRipples(with ripples: [AquariumVisibleTapRipple]) {
        syncNodeCount(&rippleNodes, desiredCount: ripples.count) {
            let node = AquariumSpriteRippleNode(ringTexture: rippleTexture, bubbleTexture: bubbleTexture)
            node.zPosition = 12
            return node
        }

        for (index, ripple) in ripples.enumerated() {
            rippleNodes[index].update(ripple: ripple, sceneHeight: size.height)
        }
    }

    private func syncVisitor(with visitor: RareVisitorLayout?) {
        guard let visitor else {
            visitorNode?.removeFromParent()
            visitorNode = nil
            return
        }

        let texture = visitorTextures[visitor.kind]
        let node: SKSpriteNode

        if let existing = visitorNode {
            node = existing
        } else {
            node = SKSpriteNode(texture: texture)
            node.zPosition = 28
            addChild(node)
            visitorNode = node
        }

        node.texture = texture
        node.position = scenePoint(from: visitor.position)
        node.size = visitor.kind == .moonJelly
        ? CGSize(width: 30 * visitor.scale, height: 36 * visitor.scale)
        : CGSize(width: 28 * visitor.scale, height: 22 * visitor.scale)
        node.alpha = 1
        node.isHidden = false
    }

    private func syncCompanions(with layouts: [CompanionLayout]) {
        syncNodeCount(&companionNodes, desiredCount: layouts.count) {
            let node = SKSpriteNode(color: .clear, size: .zero)
            node.zPosition = 30
            return node
        }

        for (index, layout) in layouts.enumerated() {
            let node = companionNodes[index]
            node.texture = companionTextures[layout.style]
            node.position = scenePoint(from: layout.position)
            node.size = layout.renderSize
            node.zRotation = -CGFloat(layout.rotation) * .pi / 180
            node.xScale = layout.isMirrored ? -1 : 1
            node.yScale = 1
            node.alpha = 1
            node.isHidden = false
        }
    }

    private func syncFish(
        with layouts: [FishLayout],
        using resolver: AquariumMetalMotionResolver,
        snapshot: AquariumPetSnapshot
    ) -> [BurstFishVisual] {
        syncNodeCount(&fishNodes, desiredCount: layouts.count) {
            let root = SKNode()
            root.zPosition = 32
            let vertical = SKNode()
            vertical.name = Self.fishVerticalStretchNodeName
            let sprite = SKSpriteNode(color: .clear, size: .zero)
            sprite.name = Self.fishSpriteChildName
            vertical.addChild(sprite)
            root.addChild(vertical)
            return root
        }

        let frameDuration = max(1.0 / 120.0, min(lastFrameDuration, 1.0 / 15.0))
        let hasFoodTarget = resolver.focusedFoodResponse != nil || resolver.activeFoodResponse() != nil
        let anticipationAmount = resolver.activeDropExcitement()
        let maxTravelDistance = CGFloat(frameDuration) * (
            hasFoodTarget
            ? 260
            : 120 + 70 * anticipationAmount
        )
        let maxRotationStep = CGFloat(frameDuration) * (
            hasFoodTarget
            ? .pi * 2.2
            : .pi * (1.2 + 0.6 * anticipationAmount)
        )
        var renderedVisuals: [BurstFishVisual] = []
        renderedVisuals.reserveCapacity(layouts.count)

        for (index, layout) in layouts.enumerated() {
            let root = fishNodes[index]
            guard let vertical = root.childNode(withName: Self.fishVerticalStretchNodeName) else { continue }
            guard let sprite = vertical.childNode(withName: Self.fishSpriteChildName) as? SKSpriteNode else { continue }
            let frame = resolver.fishRenderRect(for: layout)
            let targetPosition = scenePoint(from: CGPoint(x: frame.midX, y: frame.midY))
            let targetRotation = -CGFloat(layout.rotation) * .pi / 180
            let hasInitializedMotion = (root.userData?["motionInitialized"] as? Bool) == true

            if hasInitializedMotion {
                root.position = movePoint(root.position, toward: targetPosition, maxDistance: maxTravelDistance)
                root.zRotation = moveAngle(root.zRotation, toward: targetRotation, maxStep: maxRotationStep)
            } else {
                root.position = targetPosition
                root.zRotation = targetRotation
                let userData = root.userData ?? NSMutableDictionary()
                userData["motionInitialized"] = true
                root.userData = userData
            }

            root.isHidden = false
            vertical.xScale = 1
            vertical.yScale = snapshot.bodyOvalScaleY
            sprite.texture = fishTextures[layout.species]
            sprite.position = .zero
            sprite.zRotation = 0
            sprite.size = frame.size
            sprite.alpha = snapshot.isAlive ? 1 : 0.62
            sprite.color = UIColor(white: snapshot.colorStrength, alpha: 1)
            sprite.colorBlendFactor = snapshot.isAlive ? 0 : 0.18
            sprite.xScale = layout.isMirrored ? -1 : 1
            sprite.yScale = 1
            sprite.isHidden = false

            renderedVisuals.append(
                BurstFishVisual(
                    species: layout.species,
                    scenePosition: root.position,
                    renderSize: sprite.size,
                    rotation: root.zRotation,
                    isMirrored: layout.isMirrored
                )
            )
        }

        return renderedVisuals
    }

    private func burstAnimationProgress(for state: BurstAnimationState) -> CGFloat {
        CGFloat(min(max((animationElapsed - state.startedAt) / AquariumFeedBurst.burstAnimationDuration, 0), 1))
    }

    private func smoothStep(from lower: CGFloat, to upper: CGFloat, value: CGFloat) -> CGFloat {
        guard upper > lower else { return 0 }
        let t = min(max((value - lower) / (upper - lower), 0), 1)
        return t * t * (3 - 2 * t)
    }

    private func syncFishBurstAnimation(
        _ state: BurstAnimationState,
        progress: CGFloat
    ) {
        syncNodeCount(&fishNodes, desiredCount: state.fishVisuals.count) {
            let root = SKNode()
            root.zPosition = 32
            let vertical = SKNode()
            vertical.name = Self.fishVerticalStretchNodeName
            let sprite = SKSpriteNode(color: .clear, size: .zero)
            sprite.name = Self.fishSpriteChildName
            vertical.addChild(sprite)
            root.addChild(vertical)
            return root
        }

        let inflatePhase = smoothStep(from: 0.0, to: 0.22, value: progress)
        let vanishPhase = smoothStep(from: 0.14, to: 0.96, value: progress)

        for (index, visual) in state.fishVisuals.enumerated() {
            let root = fishNodes[index]
            guard let vertical = root.childNode(withName: Self.fishVerticalStretchNodeName) else { continue }
            guard let sprite = vertical.childNode(withName: Self.fishSpriteChildName) as? SKSpriteNode else { continue }
            root.position = visual.scenePosition
            root.zRotation = visual.rotation
            root.isHidden = false
            vertical.xScale = 1
            vertical.yScale = state.bodyOvalScaleY
            sprite.texture = fishTextures[visual.species]
            sprite.position = .zero
            sprite.zRotation = 0
            sprite.xScale = visual.isMirrored ? -1 : 1
            sprite.yScale = 1

            let widthScale = 1 + inflatePhase * 0.16 + vanishPhase * 0.44
            let heightScale = 1 + inflatePhase * 0.22 + vanishPhase * 0.30
            sprite.size = CGSize(
                width: visual.renderSize.width * widthScale,
                height: visual.renderSize.height * heightScale
            )
            sprite.alpha = max(0, 1 - vanishPhase * 1.18)
            sprite.color = UIColor(
                red: 1.0,
                green: 0.96 - CGFloat(progress) * 0.18,
                blue: 0.92 - CGFloat(progress) * 0.34,
                alpha: 1
            )
            sprite.colorBlendFactor = 0.08 + vanishPhase * 0.54
            sprite.isHidden = sprite.alpha <= 0.01
        }

        while fishNodes.count > state.fishVisuals.count {
            let node = fishNodes.removeLast()
            node.removeFromParent()
        }
    }

    private func arcedFoodHandoffPoint(
        from source: CGPoint,
        to destination: CGPoint,
        progress: CGFloat
    ) -> CGPoint {
        let clampedProgress = min(max(progress, 0), 1)
        let distance = hypot(destination.x - source.x, destination.y - source.y)
        guard distance > 0.5 else {
            return CGPoint(
                x: source.x + (destination.x - source.x) * clampedProgress,
                y: source.y + (destination.y - source.y) * clampedProgress
            )
        }

        let lift = min(
            size.height * 0.085,
            max(size.height * 0.022, distance * 0.18)
        )
        let controlPoint = CGPoint(
            x: (source.x + destination.x) * 0.5,
            y: min(source.y, destination.y) - lift
        )
        let inverseProgress = 1 - clampedProgress

        return CGPoint(
            x: inverseProgress * inverseProgress * source.x
                + 2 * inverseProgress * clampedProgress * controlPoint.x
                + clampedProgress * clampedProgress * destination.x,
            y: inverseProgress * inverseProgress * source.y
                + 2 * inverseProgress * clampedProgress * controlPoint.y
                + clampedProgress * clampedProgress * destination.y
        )
    }

    private func blendedFoodResponse(current: FoodResponse?, at date: Date) -> FoodResponse? {
        guard let recentFeedHandoff else { return current }

        let elapsed = max(0, date.timeIntervalSince(recentFeedHandoff.startedAt))
        let progress = CGFloat(min(max(elapsed / recentFeedHandoff.duration, 0), 1))

        if progress >= 1 {
            self.recentFeedHandoff = nil
            return current
        }

        let easedProgress = smoothStep(from: 0, to: 1, value: progress)

        guard let current else {
            let remainingStrength = max(0, recentFeedHandoff.response.strength * (1 - easedProgress))
            guard remainingStrength > 0.001 else { return nil }
            return FoodResponse(
                anchor: recentFeedHandoff.response.anchor,
                strength: remainingStrength
            )
        }

        return FoodResponse(
            anchor: arcedFoodHandoffPoint(
                from: recentFeedHandoff.response.anchor,
                to: current.anchor,
                progress: easedProgress
            ),
            strength: recentFeedHandoff.response.strength
            + (current.strength - recentFeedHandoff.response.strength) * easedProgress
        )
    }

    private func movePoint(_ current: CGPoint, toward target: CGPoint, maxDistance: CGFloat) -> CGPoint {
        let dx = target.x - current.x
        let dy = target.y - current.y
        let distance = hypot(dx, dy)

        guard distance > 0.001 else { return target }
        guard distance > maxDistance, maxDistance > 0 else { return target }

        let progress = maxDistance / distance
        return CGPoint(
            x: current.x + dx * progress,
            y: current.y + dy * progress
        )
    }

    private func moveAngle(_ current: CGFloat, toward target: CGFloat, maxStep: CGFloat) -> CGFloat {
        var delta = target - current
        while delta > .pi {
            delta -= .pi * 2
        }
        while delta < -.pi {
            delta += .pi * 2
        }

        guard abs(delta) > maxStep, maxStep > 0 else { return target }
        return current + (delta > 0 ? maxStep : -maxStep)
    }

    private func syncBurstOverlay(progress: CGFloat?, fishVisuals: [BurstFishVisual]) {
        let flashNode: SKSpriteNode
        if let existing = burstFlashNode {
            flashNode = existing
        } else {
            let node = SKSpriteNode(color: .white, size: .zero)
            node.zPosition = 30
            node.isUserInteractionEnabled = false
            addChild(node)
            burstFlashNode = node
            flashNode = node
        }

        guard let progress else {
            flashNode.alpha = 0
            flashNode.isHidden = true
            syncNodeCount(&burstShockwaveNodes, desiredCount: 0) {
                let node = SKSpriteNode(texture: rippleTexture)
                node.zPosition = 34
                return node
            }
            return
        }

        flashNode.isHidden = false
        flashNode.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        flashNode.size = size
        flashNode.color = UIColor(red: 1.0, green: 0.91, blue: 0.86, alpha: 1)
        flashNode.alpha = max(0, 0.24 * (1 - progress) + 0.10 * smoothStep(from: 0.18, to: 1, value: progress))

        syncNodeCount(&burstShockwaveNodes, desiredCount: fishVisuals.count) {
            let node = SKSpriteNode(texture: rippleTexture)
            node.zPosition = 34
            return node
        }

        let ringProgress = smoothStep(from: 0.06, to: 0.92, value: progress)
        for (index, visual) in fishVisuals.enumerated() {
            let node = burstShockwaveNodes[index]
            let ringSize = max(visual.renderSize.width, visual.renderSize.height) * (0.72 + ringProgress * 1.65)
            node.texture = rippleTexture
            node.position = visual.scenePosition
            node.size = CGSize(width: ringSize, height: ringSize)
            node.alpha = max(0, 0.92 * (1 - ringProgress))
            node.color = UIColor(red: 1.0, green: 0.96, blue: 0.98, alpha: 1)
            node.colorBlendFactor = 0.52
            node.isHidden = node.alpha <= 0.01
        }
    }

    private func syncFishThoughts(with thoughts: [ThoughtLayout]) {
        syncNodeCount(&fishThoughtNodes, desiredCount: thoughts.count) {
            let node = SKSpriteNode(color: .clear, size: CGSize(width: 42, height: 28))
            node.zPosition = 40
            return node
        }

        for (index, thought) in thoughts.enumerated() {
            let node = fishThoughtNodes[index]
            node.texture = thoughtTextures["\(thought.text)|\(thought.pointsToTrailing)"]
            node.position = scenePoint(from: thought.position)
            node.size = CGSize(width: 42, height: 28)
            node.alpha = 1
            node.isHidden = false
        }
    }

    private func syncVisitorThought(with thought: ThoughtLayout?) {
        guard let thought else {
            visitorThoughtNode?.removeFromParent()
            visitorThoughtNode = nil
            return
        }

        let node: SKSpriteNode
        if let existing = visitorThoughtNode {
            node = existing
        } else {
            node = SKSpriteNode(color: .clear, size: CGSize(width: 42, height: 28))
            node.zPosition = 41
            addChild(node)
            visitorThoughtNode = node
        }

        node.texture = thoughtTextures["\(thought.text)|\(thought.pointsToTrailing)"]
        node.position = scenePoint(from: thought.position)
        node.size = CGSize(width: 42, height: 28)
        node.alpha = 1
        node.isHidden = false
    }

    private func scenePoint(from point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: size.height - point.y)
    }

    private func syncNodeCount<T: SKNode>(
        _ nodes: inout [T],
        desiredCount: Int,
        create: () -> T
    ) {
        while nodes.count < desiredCount {
            let node = create()
            addChild(node)
            nodes.append(node)
        }

        while nodes.count > desiredCount {
            let node = nodes.removeLast()
            node.removeFromParent()
        }
    }

    private func makeTexture<V: View>(size: CGSize, scale: CGFloat, @ViewBuilder content: () -> V) -> SKTexture? {
        let snapshotContent = content()
            .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: snapshotContent)
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(size)

        guard let image = renderer.uiImage else { return nil }

        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }

    private static func cachedTexture<K: Hashable>(
        cache: inout [K: SKTexture],
        key: K,
        build: () -> SKTexture?
    ) -> SKTexture? {
        if let texture = cache[key] {
            return texture
        }

        guard let texture = build() else {
            return nil
        }

        cache[key] = texture
        return texture
    }
}

private final class AquariumSpriteRippleNode: SKNode {
    private let ringNode: SKSpriteNode
    private let bubbleNodes: [SKSpriteNode]

    init(ringTexture: SKTexture?, bubbleTexture: SKTexture?) {
        ringNode = SKSpriteNode(texture: ringTexture)
        ringNode.zPosition = 0

        bubbleNodes = (0..<3).map { _ in
            let node = SKSpriteNode(texture: bubbleTexture)
            node.zPosition = 1
            return node
        }

        super.init()
        isUserInteractionEnabled = false
        addChild(ringNode)
        bubbleNodes.forEach(addChild)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateTextures(ringTexture: SKTexture?, bubbleTexture: SKTexture?) {
        ringNode.texture = ringTexture
        for node in bubbleNodes {
            node.texture = bubbleTexture
        }
    }

    func update(ripple: AquariumVisibleTapRipple, sceneHeight: CGFloat) {
        position = CGPoint(x: ripple.position.x, y: sceneHeight - ripple.position.y)

        let ringSize = 18 + ripple.progress * 92
        let opacity = max(0, 1 - ripple.progress)
        ringNode.size = CGSize(width: ringSize, height: ringSize)
        ringNode.alpha = 0.76 * opacity

        for (index, node) in bubbleNodes.enumerated() {
            let bubbleSize = max(2.6, 6 - ripple.progress * 2.2 + CGFloat(index))
            let bubbleX = CGFloat(index - 1) * (10 + ripple.progress * 8)
            let bubbleYOffset = -14 - ripple.progress * (18 + CGFloat(index) * 8)
            node.position = CGPoint(x: bubbleX, y: -bubbleYOffset)
            node.size = CGSize(width: bubbleSize, height: bubbleSize)
            node.alpha = 0.24 * opacity
        }
    }
}

private struct AquariumSpriteTextureSignature: Hashable {
    let configuration: AquariumConfiguration
    let scaleBucket: Int
}

private struct AquariumSpriteFishTextureKey: Hashable {
    let species: FishSpecies
    let scaleBucket: Int
}

private struct AquariumSpriteCompanionTextureKey: Hashable {
    let configurationHash: Int
    let companion: CompanionStyle
    let scaleBucket: Int
}

private struct AquariumSpriteVisitorTextureKey: Hashable {
    let kind: RareVisitorKind
    let scaleBucket: Int
}

private struct AquariumSpriteThoughtTextureKey: Hashable {
    let text: String
    let pointsToTrailing: Bool
    let scaleBucket: Int
}
#endif

#if canImport(MetalKit) && canImport(UIKit)
struct MetalAquariumSceneView: View {
    let profile: BowlProfile
    let configuration: AquariumConfiguration
    let format: AquariumDisplayFormat
    let feedBursts: [AquariumFeedBurst]
    let tapRipples: [AquariumTapRipple]
    let phaseOffset: Double

    var body: some View {
        GeometryReader { geometry in
            AquariumMetalRepresentable(
                profile: profile,
                configuration: configuration,
                format: format,
                feedBursts: feedBursts,
                tapRipples: tapRipples,
                phaseOffset: phaseOffset
            )
            .padding(format.bodyInset)
            .clipShape(AquariumBodyShape(style: configuration.vesselStyle))
        }
        .aspectRatio(format.aspectRatio, contentMode: .fit)
    }
}

struct AquariumStaticBackdropView: View {
    let configuration: AquariumConfiguration
    let format: AquariumDisplayFormat
    let phase: Double
    let petSnapshot: AquariumPetSnapshot
    var showsDecoration: Bool = true

    var body: some View {
        GeometryReader { _ in
            ZStack {
                AquariumMetalBackdropSnapshotView(
                    configuration: configuration,
                    format: format,
                    phase: phase,
                    petSnapshot: petSnapshot,
                    showsDecoration: showsDecoration
                )

                AquariumMetalOverlaySnapshotView(configuration: configuration)
            }
            .padding(format.bodyInset)
        }
        .aspectRatio(format.aspectRatio, contentMode: .fit)
    }
}

struct AquariumDecorationForegroundOverlayView: View {
    let configuration: AquariumConfiguration
    let format: AquariumDisplayFormat
    let phase: Double

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let waterLevel = configuration.vesselStyle == .orb ? 0.75 : 0.80

            DecorationLayer(decoration: configuration.decoration)
                .mask(
                    WaterSurfaceShape(
                        level: waterLevel,
                        waveShift: 0.02 * sin(phase * 1.7)
                    )
                )
                .padding(format.bodyInset)
                .frame(width: size.width, height: size.height)
        }
        .allowsHitTesting(false)
        .aspectRatio(format.aspectRatio, contentMode: .fit)
    }
}

private struct AquariumMetalRepresentable: UIViewRepresentable {
    let profile: BowlProfile
    let configuration: AquariumConfiguration
    let format: AquariumDisplayFormat
    let feedBursts: [AquariumFeedBurst]
    let tapRipples: [AquariumTapRipple]
    let phaseOffset: Double

    func makeCoordinator() -> AquariumMetalCoordinator {
        AquariumMetalCoordinator(
            profile: profile,
            configuration: configuration,
            format: format,
            feedBursts: feedBursts,
            tapRipples: tapRipples,
            phaseOffset: phaseOffset
        )
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.coordinator.device)
        view.delegate = context.coordinator
        view.framebufferOnly = true
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        view.autoResizeDrawable = true
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0, 0, 0, 0)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.layer.isOpaque = false
        context.coordinator.attach(view: view)
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.update(
            profile: profile,
            configuration: configuration,
            format: format,
            feedBursts: feedBursts,
            tapRipples: tapRipples,
            phaseOffset: phaseOffset,
            view: uiView
        )
    }
}

@MainActor
private final class AquariumMetalCoordinator: NSObject, MTKViewDelegate {
    let device: MTLDevice

    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let samplerState: MTLSamplerState
    private let textureLoader: MTKTextureLoader

    private var profile: BowlProfile
    private var configuration: AquariumConfiguration
    private var format: AquariumDisplayFormat
    private var feedBursts: [AquariumFeedBurst]
    private var tapRipples: [AquariumTapRipple]
    private var phaseOffset: Double

    private weak var view: MTKView?
    nonisolated(unsafe) private var displayLink: CADisplayLink?
    private var whiteMaskTexture: MTLTexture?
    private var bubbleTexture: MTLTexture?
    private var pelletTexture: MTLTexture?
    private var rippleTexture: MTLTexture?
    private var fishTextures: [FishSpecies: MTLTexture] = [:]
    private var companionTextures: [CompanionStyle: MTLTexture] = [:]
    private var visitorTextures: [RareVisitorKind: MTLTexture] = [:]
    private var thoughtTextures: [String: MTLTexture] = [:]
    private var lastStaticSignature: AquariumMetalStaticSignature?

    init(
        profile: BowlProfile,
        configuration: AquariumConfiguration,
        format: AquariumDisplayFormat,
        feedBursts: [AquariumFeedBurst],
        tapRipples: [AquariumTapRipple],
        phaseOffset: Double
    ) {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue()
        else {
            fatalError("Metal is required for the live aquarium scene.")
        }

        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        self.profile = profile
        self.configuration = configuration
        self.format = format
        self.feedBursts = feedBursts
        self.tapRipples = tapRipples
        self.phaseOffset = phaseOffset

        do {
            let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "aquariumVertex")
            descriptor.fragmentFunction = library.makeFunction(name: "aquariumFragment")
            descriptor.vertexDescriptor = Self.vertexDescriptor
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].rgbBlendOperation = .add
            descriptor.colorAttachments[0].alphaBlendOperation = .add
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            self.pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Unable to create Metal pipeline: \(error)")
        }

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .notMipmapped
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        self.samplerState = device.makeSamplerState(descriptor: samplerDescriptor)!

        super.init()
        startDisplayLinkIfNeeded()
    }

    func attach(view: MTKView) {
        self.view = view
        startDisplayLinkIfNeeded()
    }

    func update(
        profile: BowlProfile,
        configuration: AquariumConfiguration,
        format: AquariumDisplayFormat,
        feedBursts: [AquariumFeedBurst],
        tapRipples: [AquariumTapRipple],
        phaseOffset: Double,
        view: MTKView
    ) {
        self.profile = profile
        self.configuration = configuration
        self.format = format
        self.feedBursts = feedBursts
        self.tapRipples = tapRipples
        self.phaseOffset = phaseOffset
        self.view = view
        startDisplayLinkIfNeeded()
        rebuildStaticTexturesIfNeeded(for: view, date: .now)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        rebuildStaticTexturesIfNeeded(for: view, date: .now)
    }

    func draw(in view: MTKView) {
        guard
            let descriptor = view.currentRenderPassDescriptor,
            let drawable = view.currentDrawable
        else {
            return
        }

        let now = Date.now
        rebuildStaticTexturesIfNeeded(for: view, date: now)
        let phase = now.timeIntervalSinceReferenceDate / 4.1 + phaseOffset
        let snapshot = profile.petSnapshot(at: now)
        let resolver = AquariumMetalMotionResolver(
            configuration: configuration,
            format: format,
            phase: phase,
            petSnapshot: snapshot,
            feedBursts: feedBursts,
            tapRipples: tapRipples,
            size: view.bounds.size
        )

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        var uniforms = AquariumMetalUniforms(
            viewportSize: SIMD2(Float(max(view.bounds.width, 1)), Float(max(view.bounds.height, 1)))
        )

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentSamplerState(samplerState, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<AquariumMetalUniforms>.stride, index: 1)

        guard let whiteMaskTexture else {
            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
            return
        }

        if let bubbleTexture {
            for bubble in resolver.bubbles() {
                let size = CGSize(width: bubble.size, height: bubble.size)
                drawQuad(
                    encoder: encoder,
                    texture: bubbleTexture,
                    maskTexture: whiteMaskTexture,
                    frame: CGRect(
                        x: bubble.position.x - size.width * 0.5,
                        y: bubble.position.y - size.height * 0.5,
                        width: size.width,
                        height: size.height
                    ),
                    tint: SIMD4(1, 1, 1, Float(bubble.opacity))
                )
            }
        }

        if let rippleTexture, let bubbleTexture {
            for ripple in resolver.ripples() {
                let ringSize = 18 + ripple.progress * 92
                let opacity = max(0, 1 - ripple.progress)
                drawQuad(
                    encoder: encoder,
                    texture: rippleTexture,
                    maskTexture: whiteMaskTexture,
                    frame: CGRect(
                        x: ripple.position.x - ringSize * 0.5,
                        y: ripple.position.y - ringSize * 0.5,
                        width: ringSize,
                        height: ringSize
                    ),
                    tint: SIMD4(1, 1, 1, Float(0.76 * opacity))
                )

                for index in 0..<3 {
                    let bubbleSize = max(2.6, 6 - ripple.progress * 2.2 + CGFloat(index))
                    let bubbleX = CGFloat(index - 1) * (10 + ripple.progress * 8)
                    let bubbleY = -14 - ripple.progress * (18 + CGFloat(index) * 8)
                    drawQuad(
                            encoder: encoder,
                            texture: bubbleTexture,
                            maskTexture: whiteMaskTexture,
                        frame: CGRect(
                            x: ripple.position.x + bubbleX - bubbleSize * 0.5,
                            y: ripple.position.y + bubbleY - bubbleSize * 0.5,
                            width: bubbleSize,
                            height: bubbleSize
                        ),
                        tint: SIMD4(1, 1, 1, Float(0.24 * opacity))
                    )
                }
            }
        }

        if let pelletTexture {
            for pellet in resolver.foodPellets() where pellet.scale > 0.001 {
                let pelletSize = 9 * pellet.scale
                drawQuad(
                    encoder: encoder,
                    texture: pelletTexture,
                    maskTexture: whiteMaskTexture,
                    frame: CGRect(
                        x: view.bounds.width * pellet.xFraction - pelletSize * 0.5,
                        y: view.bounds.height * pellet.yFraction - pelletSize * 0.5,
                        width: pelletSize,
                        height: pelletSize
                    ),
                    tint: SIMD4(1, 1, 1, Float(min(1, pellet.scale * 1.3)))
                )
            }
        }

        if let visitor = resolver.rareVisitor(),
           let texture = visitorTextures[visitor.kind] {
            let size = visitor.kind == .moonJelly
            ? CGSize(width: 30 * visitor.scale, height: 36 * visitor.scale)
            : CGSize(width: 28 * visitor.scale, height: 22 * visitor.scale)
            drawQuad(
                encoder: encoder,
                texture: texture,
                maskTexture: whiteMaskTexture,
                frame: CGRect(
                    x: visitor.position.x - size.width * 0.5,
                    y: visitor.position.y - size.height * 0.5,
                    width: size.width,
                    height: size.height
                )
            )
        }

        for layout in resolver.companionLayouts() {
            guard let texture = companionTextures[layout.style] else { continue }
            drawQuad(
                encoder: encoder,
                texture: texture,
                maskTexture: whiteMaskTexture,
                frame: CGRect(
                    x: layout.position.x - layout.renderSize.width * 0.5,
                    y: layout.position.y - layout.renderSize.height * 0.5,
                    width: layout.renderSize.width,
                    height: layout.renderSize.height
                ),
                rotation: CGFloat(layout.rotation) * .pi / 180,
                mirrored: layout.isMirrored
            )
        }

        for layout in resolver.fishLayouts() {
            guard let texture = fishTextures[layout.species] else { continue }
            let frame = resolver.fishRenderRect(for: layout)
            let ovalScaleY = max(0.5, min(1.8, CGFloat(snapshot.bodyOvalScaleY)))
            let adjustedHeight = frame.height * ovalScaleY
            let adjustedFrame = CGRect(
                x: frame.minX,
                y: frame.midY - adjustedHeight * 0.5,
                width: frame.width,
                height: adjustedHeight
            )
            let alpha: Float = snapshot.isAlive ? 1 : 0.62
            let tintStrength = Float(snapshot.colorStrength)
            drawQuad(
                encoder: encoder,
                texture: texture,
                maskTexture: whiteMaskTexture,
                frame: adjustedFrame,
                rotation: CGFloat(layout.rotation) * .pi / 180,
                mirrored: layout.isMirrored,
                tint: SIMD4(tintStrength, tintStrength, tintStrength, alpha)
            )
        }

        for thought in resolver.fishThoughtBubbles() {
            if let texture = textureForThought(text: thought.text, pointsToTrailing: thought.pointsToTrailing, scale: view.contentScaleFactor) {
                let size = CGSize(width: 42, height: 28)
                drawQuad(
                    encoder: encoder,
                    texture: texture,
                    maskTexture: whiteMaskTexture,
                    frame: CGRect(
                        x: thought.position.x - size.width * 0.5,
                        y: thought.position.y - size.height * 0.5,
                        width: size.width,
                        height: size.height
                    )
                )
            }
        }

        if let visitorThought = resolver.visitorThoughtBubble(),
           let texture = textureForThought(text: visitorThought.text, pointsToTrailing: visitorThought.pointsToTrailing, scale: view.contentScaleFactor) {
            let size = CGSize(width: 42, height: 28)
            drawQuad(
                encoder: encoder,
                texture: texture,
                maskTexture: whiteMaskTexture,
                frame: CGRect(
                    x: visitorThought.position.x - size.width * 0.5,
                    y: visitorThought.position.y - size.height * 0.5,
                    width: size.width,
                    height: size.height
                )
            )
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    deinit {
        displayLink?.invalidate()
    }

    @objc
    private func stepDisplayLink() {
        guard let view else { return }
        guard view.window != nil else { return }
        view.draw()
    }

    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(stepDisplayLink))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 24, preferred: 24)
        } else {
            link.preferredFramesPerSecond = 24
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func rebuildStaticTexturesIfNeeded(for view: MTKView, date: Date) {
        let pointSize = view.bounds.size
        guard pointSize.width > 1, pointSize.height > 1 else { return }

        let scale = max(2, view.contentScaleFactor)
        let tone = AquariumSceneTone(at: date)
        let snapshot = profile.petSnapshot(at: date)
        let signature = AquariumMetalStaticSignature(
            configuration: configuration,
            format: format,
            toneBucket: tone.hashToken,
            isAlive: snapshot.isAlive,
            colorBucket: Int(snapshot.colorStrength * 10),
            widthBucket: Int(pointSize.width * scale),
            heightBucket: Int(pointSize.height * scale)
        )

        guard signature != lastStaticSignature else { return }

        guard let nextWhiteMaskTexture = makeTexture(size: CGSize(width: 2, height: 2), scale: 1, content: {
            Color.white
        }) else {
            return
        }

        let nextBubbleTexture = makeTexture(size: CGSize(width: 26, height: 26), scale: scale) {
            AquariumMetalBubbleSpriteView()
        }

        let nextPelletTexture = makeTexture(size: CGSize(width: 16, height: 16), scale: scale) {
            AquariumMetalPelletSpriteView()
        }

        let nextRippleTexture = makeTexture(size: CGSize(width: 120, height: 120), scale: scale) {
            AquariumMetalRippleSpriteView()
        }

        var nextFishTextures: [FishSpecies: MTLTexture] = [:]
        for species in configuration.uniqueFishSpecies {
            let canvas = AquariumMetalMotionResolver.textureCanvasSize(for: species)
            if let texture = makeTexture(size: canvas, scale: scale, content: {
                FishSprite(
                    species: species,
                    vitality: 1,
                    isAlive: true,
                    bodyOvalScaleY: 1
                )
                .frame(width: canvas.width, height: canvas.height)
            }) {
                nextFishTextures[species] = texture
            }
        }
        guard nextFishTextures.count == configuration.uniqueFishSpecies.count else {
            return
        }

        var nextCompanionTextures: [CompanionStyle: MTLTexture] = [:]
        for companion in Set(configuration.resolvedCompanions) {
            let canvas = AquariumMetalMotionResolver.textureCanvasSize(for: companion)
            nextCompanionTextures[companion] = makeTexture(size: canvas, scale: scale) {
                AquariumMetalCompanionSnapshotView(
                    companion: companion,
                    accent: configuration.decoration.accentColors.first ?? configuration.substrate.accentColors.first ?? .orange,
                    secondary: configuration.fishPalette.last ?? .white,
                    substrateHighlight: configuration.substrate.accentColors[1],
                    canvasSize: canvas
                )
            }
            guard nextCompanionTextures[companion] != nil else {
                return
            }
        }

        var nextVisitorTextures: [RareVisitorKind: MTLTexture] = [:]
        if let moonJellyTexture = makeTexture(size: CGSize(width: 36, height: 42), scale: scale, content: {
            MoonJellyVisitor()
                .frame(width: 36, height: 42)
        }) {
            nextVisitorTextures[.moonJelly] = moonJellyTexture
        }
        if let seaAngelTexture = makeTexture(size: CGSize(width: 34, height: 28), scale: scale, content: {
            SeaAngelVisitor()
                .frame(width: 34, height: 28)
        }) {
            nextVisitorTextures[.seaAngel] = seaAngelTexture
        }

        var nextThoughtTextures: [String: MTLTexture] = [:]
        let thoughtTexts = ["🍽️", "😫", "🥺", "🍤", "💤", "✨", "⚡️", "🌙", "🫧", "💭", "☁️", "🪽"]
        for text in thoughtTexts {
            for pointsToTrailing in [false, true] {
                let key = "\(text)|\(pointsToTrailing)"
                nextThoughtTextures[key] = makeTexture(size: CGSize(width: 56, height: 34), scale: scale) {
                    ThoughtBubble(text: text, pointsToTrailing: pointsToTrailing)
                        .frame(width: 56, height: 34)
                }
            }
        }

        whiteMaskTexture = nextWhiteMaskTexture
        bubbleTexture = nextBubbleTexture
        pelletTexture = nextPelletTexture
        rippleTexture = nextRippleTexture
        fishTextures = nextFishTextures
        companionTextures = nextCompanionTextures
        visitorTextures = nextVisitorTextures
        thoughtTextures = nextThoughtTextures
        lastStaticSignature = signature
    }

    private func textureForThought(text: String, pointsToTrailing: Bool, scale: CGFloat) -> MTLTexture? {
        let key = "\(text)|\(pointsToTrailing)"
        return thoughtTextures[key]
    }

    private func makeTexture<V: View>(size: CGSize, scale: CGFloat, @ViewBuilder content: () -> V) -> MTLTexture? {
        let snapshotContent = content()
            .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: snapshotContent)
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(size)

        guard let cgImage = renderer.cgImage else { return nil }

        return try? textureLoader.newTexture(
            cgImage: cgImage,
            options: [
                MTKTextureLoader.Option.SRGB: false,
                MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            ]
        )
    }

    private func drawQuad(
        encoder: MTLRenderCommandEncoder,
        texture: MTLTexture,
        maskTexture: MTLTexture,
        frame: CGRect,
        rotation: CGFloat = 0,
        mirrored: Bool = false,
        tint: SIMD4<Float> = SIMD4(1, 1, 1, 1)
    ) {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let halfWidth = frame.width * 0.5
        let halfHeight = frame.height * 0.5
        let localCorners = [
            CGPoint(x: -halfWidth, y: -halfHeight),
            CGPoint(x: halfWidth, y: -halfHeight),
            CGPoint(x: -halfWidth, y: halfHeight),
            CGPoint(x: halfWidth, y: -halfHeight),
            CGPoint(x: halfWidth, y: halfHeight),
            CGPoint(x: -halfWidth, y: halfHeight),
        ]
        let leftUV: Float = mirrored ? 1 : 0
        let rightUV: Float = mirrored ? 0 : 1
        let texCoords = [
            SIMD2(leftUV, 0),
            SIMD2(rightUV, 0),
            SIMD2(leftUV, 1),
            SIMD2(rightUV, 0),
            SIMD2(rightUV, 1),
            SIMD2(leftUV, 1),
        ]

        let cosTheta = cos(rotation)
        let sinTheta = sin(rotation)

        var vertices: [AquariumMetalVertex] = []
        vertices.reserveCapacity(6)

        for (index, point) in localCorners.enumerated() {
            let rotated = CGPoint(
                x: point.x * cosTheta - point.y * sinTheta,
                y: point.x * sinTheta + point.y * cosTheta
            )
            let absolute = CGPoint(x: center.x + rotated.x, y: center.y + rotated.y)
            vertices.append(
                AquariumMetalVertex(
                    position: SIMD2(Float(absolute.x), Float(absolute.y)),
                    texCoord: texCoords[index],
                    color: tint
                )
            )
        }

        encoder.setVertexBytes(
            vertices,
            length: MemoryLayout<AquariumMetalVertex>.stride * vertices.count,
            index: 0
        )
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentTexture(maskTexture, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    }

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position [[attribute(0)]];
        float2 texCoord [[attribute(1)]];
        float4 color [[attribute(2)]];
    };

    struct Uniforms {
        float2 viewportSize;
    };

    struct VertexOut {
        float4 position [[position]];
        float2 texCoord;
        float4 color;
        float2 screenUV;
    };

    vertex VertexOut aquariumVertex(VertexIn in [[stage_in]], constant Uniforms& uniforms [[buffer(1)]]) {
        VertexOut out;
        float2 normalized = float2(
            (in.position.x / uniforms.viewportSize.x) * 2.0 - 1.0,
            1.0 - (in.position.y / uniforms.viewportSize.y) * 2.0
        );
        out.position = float4(normalized, 0.0, 1.0);
        out.texCoord = in.texCoord;
        out.color = in.color;
        out.screenUV = float2(
            in.position.x / uniforms.viewportSize.x,
            in.position.y / uniforms.viewportSize.y
        );
        return out;
    }

    fragment half4 aquariumFragment(
        VertexOut in [[stage_in]],
        texture2d<half> colorTexture [[texture(0)]],
        texture2d<half> maskTexture [[texture(1)]],
        sampler textureSampler [[sampler(0)]]
    ) {
        constexpr sampler maskSampler(coord::normalized, address::clamp_to_edge, filter::linear);
        half4 colorSample = colorTexture.sample(textureSampler, in.texCoord) * half4(in.color);
        half mask = maskTexture.sample(maskSampler, in.screenUV).a;
        return half4(colorSample.rgb, colorSample.a * mask);
    }
    """

    private static let vertexDescriptor: MTLVertexDescriptor = {
        let descriptor = MTLVertexDescriptor()

        descriptor.attributes[0].format = .float2
        descriptor.attributes[0].offset = 0
        descriptor.attributes[0].bufferIndex = 0

        descriptor.attributes[1].format = .float2
        descriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
        descriptor.attributes[1].bufferIndex = 0

        descriptor.attributes[2].format = .float4
        descriptor.attributes[2].offset = MemoryLayout<SIMD2<Float>>.stride * 2
        descriptor.attributes[2].bufferIndex = 0

        descriptor.layouts[0].stride = MemoryLayout<AquariumMetalVertex>.stride
        descriptor.layouts[0].stepFunction = .perVertex

        return descriptor
    }()
}

private struct AquariumMetalStaticSignature: Hashable {
    let configuration: AquariumConfiguration
    let format: AquariumDisplayFormat
    let toneBucket: Int
    let isAlive: Bool
    let colorBucket: Int
    let widthBucket: Int
    let heightBucket: Int
}

private struct AquariumMetalVertex {
    let position: SIMD2<Float>
    let texCoord: SIMD2<Float>
    let color: SIMD4<Float>
}

private struct AquariumMetalUniforms {
    var viewportSize: SIMD2<Float>
}

private struct AquariumMetalMotionResolver {
    let configuration: AquariumConfiguration
    let format: AquariumDisplayFormat
    let phase: Double
    let petSnapshot: AquariumPetSnapshot
    let feedBursts: [AquariumFeedBurst]
    let tapRipples: [AquariumTapRipple]
    let animationDate: Date?
    let focusedFoodResponse: FoodResponse?
    let size: CGSize

    init(
        configuration: AquariumConfiguration,
        format: AquariumDisplayFormat,
        phase: Double,
        petSnapshot: AquariumPetSnapshot,
        feedBursts: [AquariumFeedBurst],
        tapRipples: [AquariumTapRipple],
        animationDate: Date? = nil,
        focusedFoodResponse: FoodResponse? = nil,
        size: CGSize
    ) {
        self.configuration = configuration
        self.format = format
        self.phase = phase
        self.petSnapshot = petSnapshot
        self.feedBursts = feedBursts
        self.tapRipples = tapRipples
        self.animationDate = animationDate
        self.focusedFoodResponse = focusedFoodResponse
        self.size = size
    }

    private var waterLevel: CGFloat {
        configuration.vesselStyle == .orb ? 0.75 : 0.80
    }

    private var tone: AquariumSceneTone {
        AquariumSceneTone(at: petSnapshot.date)
    }

    private var motionDate: Date {
        animationDate ?? petSnapshot.date
    }

    func foodPellets() -> [AquariumFoodPellet] {
        resolveFeedBursts(feedBursts, at: motionDate).flatMap(pellets(for:))
    }

    func ripples() -> [AquariumVisibleTapRipple] {
        tapRipples.compactMap { ripple in
            let elapsed = motionDate.timeIntervalSince(ripple.startedAt)
            guard elapsed >= 0, elapsed <= 1.18 else { return nil }
            return AquariumVisibleTapRipple(
                position: CGPoint(
                    x: size.width * ripple.normalizedLocation.x,
                    y: size.height * ripple.normalizedLocation.y
                ),
                progress: CGFloat(min(max(elapsed / 1.18, 0), 1))
            )
        }
    }

    func bubbles() -> [AquariumDynamicBubble] {
        let count = max(4, Int(round(7 * petSnapshot.bubbleIntensity * tone.bubbleStrength)))
        let waterTop = size.height * (1 - waterLevel)
        let waterHeight = size.height * waterLevel

        return (0..<count).map { index in
            let seed = Double(abs(configuration.hashValue &+ index * 47) % 1000) / 1000
            let rise = CGFloat((phase * (0.09 + seed * 0.06) + Double(index) * 0.17).truncatingRemainder(dividingBy: 1))
            let x = size.width * (0.18 + CGFloat(seed) * 0.64 + CGFloat(sin(phase * 0.24 + Double(index))) * 0.04)
            let y = waterTop + (1 - rise) * waterHeight
            let radius = 4.5 + CGFloat(index % 3) * 2.8 + CGFloat(seed) * 3
            let opacity = 0.16 + CGFloat(1 - rise) * 0.28
            return AquariumDynamicBubble(
                position: CGPoint(x: min(max(x, size.width * 0.12), size.width * 0.88), y: y),
                size: radius * 2,
                opacity: opacity
            )
        }
    }

    func fishLayouts() -> [FishLayout] {
        if petSnapshot.mood == .burst {
            return []
        }

        let speciesLineup = configuration.resolvedFishSpecies
        let count = speciesLineup.count
        let isCompactFormat = format == .widgetSmall
        let isAppIconFormat = format == .appIcon
        let personality = configuration.personality
        let formatScale: CGFloat = isCompactFormat ? 0.82 : (isAppIconFormat ? 1.58 : 1.0)
        let baseX: [CGFloat]
        let baseY: [CGFloat]
        let scales: [CGFloat]
        let activeFeedBurst = activeResolvedFeedBurst()
        let activeFoodResponse = focusedFoodResponse ?? self.activeFoodResponse()
        let dropExcitement = activeDropExcitement()
        let laneWidth = size.width * (isCompactFormat ? 0.076 : (isAppIconFormat ? 0.064 : 0.096)) * personality.horizontalRangeMultiplier
        let verticalRange = size.height * (isCompactFormat ? 0.044 : (isAppIconFormat ? 0.038 : 0.058)) * personality.verticalRangeMultiplier

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

        var layouts = (0..<count).map { index in
            let species = speciesLineup[index]
            let spriteScale = visualSpriteScale(for: species)
            let motionScale = personality.motionScale * tone.motionScale
            let burstPulse = 0.86 + 0.44 * pow(max(0, sin(phase * 0.62 + Double(index) * 1.9)), 2)
            let effectiveMotionScale = motionScale * burstPulse
            let cruisePhase = phase * effectiveMotionScale * (0.50 + Double(index) * 0.06) + Double(index) * 1.7
            let meanderPhase = phase * effectiveMotionScale * (1.02 + Double(index) * 0.09) + Double(index) * 2.4
            let bobPhase = phase * effectiveMotionScale * (0.82 + Double(index) * 0.07) + Double(index) * 1.2
            let tiltPhase = phase * effectiveMotionScale * (1.28 + Double(index) * 0.05) + Double(index) * 0.9
            let driftScale = petSnapshot.driftIntensity * personality.driftIntensityMultiplier
            let sweep = CGFloat(sin(cruisePhase) * 0.74 + sin(meanderPhase) * 0.26)
            let bob = CGFloat(sin(bobPhase) * 0.76 + cos(tiltPhase) * 0.24)
            let idlePosition = CGPoint(
                x: size.width * baseX[index] + sweep * laneWidth * driftScale,
                y: size.height * baseY[index] + bob * verticalRange * driftScale
            )
            let width = size.width * scales[index] * formatScale
            let height = width * 0.72
            let idleHeading = cos(cruisePhase) * 0.72 + cos(meanderPhase) * 0.28
            let foodInterest = activeFoodResponse.map {
                min(0.96, interestStrength($0.strength, index: index, count: count) * personality.foodInterestMultiplier)
            } ?? 0
            let baseFoodTarget = activeFoodResponse.map {
                foodTargetPosition(from: $0.anchor, index: index, count: count)
            } ?? idlePosition
            let baseApproachStrength = smoothStep(from: 0.0, to: 0.80, value: foodInterest)
            let centerOffset = CGFloat(index) - CGFloat(count - 1) * 0.5
            let biteHoldTarget = CGPoint(
                x: baseFoodTarget.x + centerOffset * size.width * 0.004,
                y: baseFoodTarget.y
            )
            let orbitTarget = CGPoint(
                x: baseFoodTarget.x + sweep * laneWidth * max(0.12, 0.42 - baseApproachStrength * 0.26) * max(0.38, driftScale),
                y: baseFoodTarget.y + bob * verticalRange * max(0.10, 0.30 - baseApproachStrength * 0.18) * max(0.38, driftScale)
            )
            let anticipationPhase = phase * effectiveMotionScale * (1.72 + Double(index) * 0.08) + Double(index) * 2.1
            let anticipationSweep = CGFloat(
                sin(anticipationPhase) * 0.68
                + cos(anticipationPhase * 1.86 + 0.7) * 0.32
            )
            let anticipationBob = CGFloat(
                cos(anticipationPhase * 1.28 + 0.4) * 0.58
                + sin(anticipationPhase * 2.14 + 1.3) * 0.42
            )
            let anticipationTarget = CGPoint(
                x: idlePosition.x
                    + anticipationSweep
                    * laneWidth
                    * (0.20 + dropExcitement * 0.46)
                    * max(0.42, driftScale),
                y: idlePosition.y
                    + anticipationBob
                    * verticalRange
                    * (0.16 + dropExcitement * 0.34)
                    * max(0.42, driftScale)
                    - size.height * 0.010 * dropExcitement
            )

            let baseLandingBlend = smoothStep(from: 0.52, to: 0.90, value: baseApproachStrength)

            let (targetPosition, approachStrength): (CGPoint, CGFloat)
            if activeFoodResponse != nil,
               case let .activeFeeding(progress)? = activeFeedBurst?.stage,
               focusedFoodResponse == nil {
                let nibbleProgress = smoothStep(from: 0.08, to: 0.32, value: progress)
                let nibbleFade = smoothStep(from: 0.16, to: 0.40, value: progress)
                    * (1 - smoothStep(from: 0.62, to: 0.95, value: progress))
                let nibblePhase = phase * 7.8 + Double(index) * 0.85
                let nibbleX = centerOffset * size.width * 0.004
                    + CGFloat(cos(nibblePhase)) * size.width * 0.003 * nibbleFade
                let nibbleY = CGFloat(sin(nibblePhase)) * size.height * 0.004 * nibbleFade
                targetPosition = CGPoint(
                    x: biteHoldTarget.x + nibbleX - centerOffset * size.width * 0.004,
                    y: biteHoldTarget.y + nibbleY
                )
                approachStrength = max(baseApproachStrength, 0.97 + nibbleProgress * 0.03)
            } else if dropExcitement > 0 {
                targetPosition = anticipationTarget
                approachStrength = smoothStep(from: 0.0, to: 0.84, value: dropExcitement) * 0.86
            } else {
                targetPosition = CGPoint(
                    x: orbitTarget.x + (biteHoldTarget.x - orbitTarget.x) * baseLandingBlend,
                    y: orbitTarget.y + (biteHoldTarget.y - orbitTarget.y) * baseLandingBlend
                )
                approachStrength = baseApproachStrength
            }

            let unclampedLivePosition = CGPoint(
                x: idlePosition.x + (targetPosition.x - idlePosition.x) * approachStrength,
                y: idlePosition.y + (targetPosition.y - idlePosition.y) * approachStrength
            )
            let livePosition = clampedFishPosition(
                unclampedLivePosition,
                species: species,
                spriteScale: spriteScale
            )
            let targetHeading = max(-1, min(1, Double((targetPosition.x - idlePosition.x) / max(size.width * 0.18, 1))))
            let heading = idleHeading * Double(1 - approachStrength) + targetHeading * Double(approachStrength)
            let deadPosition = clampedFishPosition(
                CGPoint(
                    x: size.width * min(max(baseX[index], 0.28), 0.72),
                    y: size.height * (0.77 + CGFloat(index) * 0.04)
                ),
                species: species,
                spriteScale: spriteScale
            )

            return FishLayout(
                species: species,
                position: petSnapshot.isAlive ? livePosition : deadPosition,
                size: CGSize(width: width, height: height),
                spriteScale: isAppIconFormat ? 3.6 : spriteScale,
                rotation: petSnapshot.isAlive
                ? Double(-4 + index * 4) + heading * 10 + Double(bob) * 6 * Double(driftScale)
                : Double(76 - index * 9),
                isMirrored: petSnapshot.isAlive ? heading > 0 : index % 2 == 0,
                isBaby: false
            )
        }

        if let babySpecies = petSnapshot.babySpecies, petSnapshot.isAlive {
            let spriteScale = visualSpriteScale(for: babySpecies) * 0.58
            let babyPhase = phase * personality.motionScale * 0.94 + 5.1
            let babyPosition = clampedFishPosition(
                CGPoint(
                    x: size.width * 0.54 + CGFloat(sin(babyPhase)) * size.width * 0.07,
                    y: size.height * 0.57 + CGFloat(cos(babyPhase * 1.4)) * size.height * 0.03
                ),
                species: babySpecies,
                spriteScale: spriteScale
            )
            let babyWidth = size.width * (isCompactFormat ? 0.13 : (isAppIconFormat ? 0.20 : 0.16)) * formatScale

            layouts.append(
                FishLayout(
                    species: babySpecies,
                    position: babyPosition,
                    size: CGSize(
                        width: babyWidth * (0.88 + CGFloat(petSnapshot.fullnessProgress) * 0.06),
                        height: babyWidth * 0.66
                    ),
                    spriteScale: isAppIconFormat ? 2.3 : spriteScale,
                    rotation: Double(sin(babyPhase * 1.2)) * 8,
                    isMirrored: cos(babyPhase) > 0,
                    isBaby: true
                )
            )
        }

        return layouts
    }

    func fishRenderRect(for layout: FishLayout) -> CGRect {
        let extents = fishSpriteExtents(for: layout.species, spriteScale: layout.spriteScale)
        return CGRect(
            x: layout.position.x - extents.halfWidth,
            y: layout.position.y - extents.top,
            width: extents.halfWidth * 2,
            height: extents.top + extents.bottom
        )
    }

    func companionLayouts() -> [CompanionLayout] {
        let companions = configuration.resolvedCompanions
        return companions.enumerated().map { index, style in
            companionLayout(for: style, index: index, count: companions.count)
        }
    }

    private func companionLayout(for style: CompanionStyle, index: Int, count: Int) -> CompanionLayout {
        let metrics: (
            baseX: CGFloat,
            baseY: CGFloat,
            range: CGFloat,
            stepLift: CGFloat,
            speed: Double,
            offset: Double,
            naturalFacingRight: Bool
        )

        switch style {
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

        let slotOffset = count == 1
        ? 0
        : CGFloat(index) - CGFloat(count - 1) * 0.5
        let motionPhase = phase * metrics.speed + metrics.offset + Double(index) * 0.9
        let horizontalDrift = CGFloat(sin(motionPhase))
        let lift = abs(CGFloat(sin(motionPhase * 1.9))) * size.height * metrics.stepLift
        let movingRight = cos(motionPhase) > 0
        let isMirrored = metrics.naturalFacingRight ? !movingRight : movingRight
        let rotationStrength: CGFloat

        switch style {
        case .shrimp:
            rotationStrength = 4.8
        case .crab:
            rotationStrength = 2.6
        case .seaCucumber, .nudibranchFlame, .nudibranchRibbon:
            rotationStrength = 1.4
        default:
            rotationStrength = 1.8
        }

        let renderSize = companionRenderSize(for: style)
        let proposedPosition = CGPoint(
            x: size.width * metrics.baseX + slotOffset * size.width * 0.16 + horizontalDrift * size.width * metrics.range,
            y: size.height * metrics.baseY - lift
        )

        return CompanionLayout(
            style: style,
            position: clampedCompanionPosition(proposedPosition, renderSize: renderSize),
            renderSize: renderSize,
            isMirrored: isMirrored,
            rotation: Double(horizontalDrift * rotationStrength)
        )
    }

    private func clampedCompanionPosition(_ position: CGPoint, renderSize: CGSize) -> CGPoint {
        let normalizedY = min(max(position.y / max(size.height, 1), 0), 1)
        let orbCurveBoost = configuration.vesselStyle == .orb
        ? abs(normalizedY - 0.52) * size.width * 0.15
        : 0
        let sidePadding: CGFloat = configuration.vesselStyle == .orb ? 6 : 4
        let xMargin = renderSize.width * 0.5 + sidePadding + orbCurveBoost
        let minY = renderSize.height * 0.5 + 2
        let maxY = size.height - renderSize.height * 0.42

        return CGPoint(
            x: min(max(position.x, xMargin), size.width - xMargin),
            y: min(max(position.y, minY), maxY)
        )
    }

    func companionRenderSize(for style: CompanionStyle) -> CGSize {
        switch style {
        case .none:
            return .zero
        case .snail:
            return CGSize(width: size.width * 0.13, height: size.width * 0.10)
        case .shrimp:
            return CGSize(width: size.width * 0.15, height: size.width * 0.10)
        case .crab:
            return CGSize(width: size.width * 0.16, height: size.width * 0.11)
        case .seaCucumber:
            return CGSize(width: size.width * 0.22, height: size.width * 0.10)
        case .nudibranchFlame:
            return CGSize(width: size.width * 0.23, height: size.width * 0.11)
        case .nudibranchRibbon:
            return CGSize(width: size.width * 0.22, height: size.width * 0.11)
        }
    }

    func rareVisitor() -> RareVisitorLayout? {
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

    func visitorThoughtBubble() -> ThoughtLayout? {
        guard format != .widgetSmall, let visitor = rareVisitor() else { return nil }

        return ThoughtLayout(
            text: visitor.kind == .moonJelly ? "✨" : "🪽",
            position: CGPoint(x: visitor.position.x, y: visitor.position.y - 16),
            pointsToTrailing: visitor.kind == .seaAngel
        )
    }

    func fishThoughtBubbles() -> [ThoughtLayout] {
        let layouts = fishLayouts()
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
                text: configuration.personality.thoughtText(mood: petSnapshot.mood, tone: tone),
                position: CGPoint(
                    x: layout.position.x + horizontalOffset,
                    y: layout.position.y - extents.top - 14
                ),
                pointsToTrailing: layout.isMirrored
            )
        ]
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

    private func clampedFishPosition(_ position: CGPoint, species: FishSpecies, spriteScale: CGFloat) -> CGPoint {
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

    private func settledFoodResponse(for burst: AquariumFeedBurst) -> FoodResponse {
        let settledYFractions = (0..<3).map { index in
            min(0.76, 0.08 + 0.50 + CGFloat(index) * 0.07)
        }
        let averageY = settledYFractions.reduce(0, +) / CGFloat(settledYFractions.count)

        return FoodResponse(
            anchor: CGPoint(
                x: size.width * burst.xFraction,
                y: size.height * averageY
            ),
            strength: 0.90
        )
    }

    private func activeResolvedFeedBurst() -> AquariumResolvedFeedBurst? {
        resolveFeedBursts(feedBursts, at: motionDate)
            .first(where: { $0.stage.isActive })
    }

    func activeFoodResponse() -> FoodResponse? {
        guard let activeBurst = activeResolvedFeedBurst() else { return nil }
        guard case .activeFeeding = activeBurst.stage else { return nil }
        return settledFoodResponse(for: activeBurst.scheduled.burst)
    }

    func activeDropExcitement() -> CGFloat {
        guard focusedFoodResponse == nil,
              let activeBurst = activeResolvedFeedBurst() else { return 0 }
        guard case let .activeDropping(progress) = activeBurst.stage else { return 0 }
        return smoothStep(from: 0.06, to: 0.92, value: progress)
    }

    private func foodTargetPosition(from anchor: CGPoint, index: Int, count: Int) -> CGPoint {
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

    static func textureCanvasSize(for species: FishSpecies) -> CGSize {
        let resolver = AquariumMetalMotionResolver(
            configuration: .hero,
            format: .widgetLarge,
            phase: 0,
            petSnapshot: .decorative(at: .now),
            feedBursts: [],
            tapRipples: [],
            size: CGSize(width: 200, height: 200)
        )
        let extents = resolver.fishSpriteExtents(for: species, spriteScale: 1)
        return CGSize(width: extents.halfWidth * 2 + 12, height: extents.top + extents.bottom + 12)
    }

    static func textureCanvasSize(for companion: CompanionStyle) -> CGSize {
        switch companion {
        case .none:
            return .zero
        case .snail:
            return CGSize(width: 40, height: 30)
        case .shrimp:
            return CGSize(width: 48, height: 28)
        case .crab:
            return CGSize(width: 54, height: 34)
        case .seaCucumber:
            return CGSize(width: 62, height: 28)
        case .nudibranchFlame:
            return CGSize(width: 68, height: 32)
        case .nudibranchRibbon:
            return CGSize(width: 64, height: 32)
        }
    }
}

private struct AquariumDynamicBubble {
    let position: CGPoint
    let size: CGFloat
    let opacity: CGFloat
}

private struct AquariumVisibleTapRipple {
    let position: CGPoint
    let progress: CGFloat
}

private struct AquariumMetalBackdropSnapshotView: View {
    let configuration: AquariumConfiguration
    let format: AquariumDisplayFormat
    let phase: Double
    let petSnapshot: AquariumPetSnapshot
    var showsDecoration: Bool = true

    private var bodyShape: AquariumBodyShape {
        AquariumBodyShape(style: configuration.vesselStyle)
    }

    var body: some View {
        ZStack {
            AquariumBodyAura(style: configuration.vesselStyle)

            bodyShape
                .fill(Color.white.opacity(0.08))
                .overlay {
                    AquariumMetalStaticInteriorView(
                        configuration: configuration,
                        format: format,
                        phase: phase,
                        petSnapshot: petSnapshot,
                        showsDecoration: showsDecoration
                    )
                }
                .clipShape(bodyShape)
        }
    }
}

private struct AquariumMetalOverlaySnapshotView: View {
    let configuration: AquariumConfiguration

    private var bodyShape: AquariumBodyShape {
        AquariumBodyShape(style: configuration.vesselStyle)
    }

    var body: some View {
        ZStack {
            AquariumRefractionOverlay(
                configuration: configuration,
                style: configuration.vesselStyle
            )

            bodyShape
                .stroke(Color.white.opacity(0.82), lineWidth: 1.2)

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
}

private struct AquariumMetalMaskSnapshotView: View {
    let style: AquariumVesselStyle

    var body: some View {
        AquariumBodyShape(style: style)
            .fill(Color.white)
    }
}

private struct AquariumMetalStaticInteriorView: View {
    let configuration: AquariumConfiguration
    let format: AquariumDisplayFormat
    let phase: Double
    let petSnapshot: AquariumPetSnapshot
    var showsDecoration: Bool = true

    private var sceneAccentColors: [Color] {
        configuration.substrate.accentColors + configuration.decoration.accentColors + configuration.fishPalette
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let waterLevel = configuration.vesselStyle == .orb ? 0.75 : 0.80
            let sceneTone = AquariumSceneTone(at: petSnapshot.date)

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

                AquariumCausticPrismField(
                    colors: sceneAccentColors + sceneTone.accentColors,
                    phase: phase
                )
                .opacity(sceneTone == .night ? 0.18 : 0.28)
                .blendMode(.screen)
                .mask(
                    WaterSurfaceShape(
                        level: waterLevel,
                        waveShift: 0.02 * sin(phase * 1.7)
                    )
                )

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

                AquariumWaterlineSheen(level: waterLevel)
                    .opacity(sceneTone == .night ? 0.22 : 0.34)

                ZStack {
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

                    if showsDecoration {
                        DecorationLayer(decoration: configuration.decoration)
                    }
                }
                .mask(
                    WaterSurfaceShape(
                        level: waterLevel,
                        waveShift: 0.02 * sin(phase * 1.7)
                    )
                )

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
}

private struct AquariumMetalCompanionSnapshotView: View {
    let companion: CompanionStyle
    let accent: Color
    let secondary: Color
    let substrateHighlight: Color
    let canvasSize: CGSize

    var body: some View {
        CompanionSprite(
            style: companion,
            accent: accent,
            secondary: secondary,
            substrateHighlight: substrateHighlight
        )
        .frame(width: canvasSize.width, height: canvasSize.height)
    }
}

private struct AquariumMetalBubbleSpriteView: View {
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.72),
                        Color.white.opacity(0.16),
                        Color.clear,
                    ],
                    center: .topLeading,
                    startRadius: 1,
                    endRadius: 16
                )
            )
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.46), lineWidth: 1)
            }
    }
}

private struct AquariumMetalPelletSpriteView: View {
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.84, blue: 0.54),
                        Color(red: 0.82, green: 0.61, blue: 0.26),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.28), lineWidth: 0.8)
            }
    }
}

private struct AquariumMetalRippleSpriteView: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.54), lineWidth: 2.2)

            Circle()
                .stroke(Color.white.opacity(0.22), lineWidth: 1.2)
                .padding(18)
        }
    }
}
#endif
