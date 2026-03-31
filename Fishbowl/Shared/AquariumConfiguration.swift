import AppIntents
import SwiftUI

enum AquariumVesselStyle: String, CaseIterable, Codable, Hashable, Identifiable, Sendable, AppEnum {
    case orb
    case gallery
    case panorama

    var id: Self { self }

    var title: String {
        switch self {
        case .orb:
            return "Orb Bowl"
        case .gallery:
            return "Gallery Tank"
        case .panorama:
            return "Panorama Tank"
        }
    }

    var summary: String {
        switch self {
        case .orb:
            return "A floating single-bowl silhouette."
        case .gallery:
            return "A softer rectangle for medium widgets."
        case .panorama:
            return "A wide tank that feels architectural."
        }
    }

    var isPremium: Bool {
        self == .panorama
    }

    var freeFallback: AquariumVesselStyle {
        switch self {
        case .panorama:
            return .gallery
        default:
            return self
        }
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Vessel")
    }

    static var caseDisplayRepresentations: [AquariumVesselStyle: DisplayRepresentation] {
        [
            .orb: DisplayRepresentation(title: "Orb Bowl"),
            .gallery: DisplayRepresentation(title: "Gallery Tank"),
            .panorama: DisplayRepresentation(title: "Panorama Tank"),
        ]
    }
}

enum FishSpecies: String, CaseIterable, Hashable, Identifiable, Sendable, AppEnum {
    case royalBetta
    case moonKoi
    case glassGold
    case neonGuppy
    case emberTetra
    case opalAngelfish
    case leopardShark

    var id: Self { self }

    var title: String {
        switch self {
        case .royalBetta:
            return "Royal Betta"
        case .moonKoi:
            return "Moon Koi"
        case .glassGold:
            return "Glass Goldfish"
        case .neonGuppy:
            return "Neon Guppy"
        case .emberTetra:
            return "Ember Tetra"
        case .opalAngelfish:
            return "Opal Angelfish"
        case .leopardShark:
            return "Leopard Shark"
        }
    }

    var summary: String {
        switch self {
        case .royalBetta:
            return "Cobalt fins with deep electric contrast."
        case .moonKoi:
            return "Pearl and coral swirls with luxury warmth."
        case .glassGold:
            return "Champagne metallic tones with soft translucency."
        case .neonGuppy:
            return "A sharper neon mix for a more graphic bowl."
        case .emberTetra:
            return "A lean ember schooler with jewel-box warmth."
        case .opalAngelfish:
            return "Tall fins and cool iridescence for a couture look."
        case .leopardShark:
            return "A tiny spotted shark with sleek silver movement."
        }
    }

    var palette: [Color] {
        switch self {
        case .royalBetta:
            return [
                Color(red: 0.06, green: 0.11, blue: 0.54),
                Color(red: 0.09, green: 0.32, blue: 0.87),
                Color(red: 0.46, green: 0.91, blue: 0.99),
            ]
        case .moonKoi:
            return [
                Color(red: 0.98, green: 0.46, blue: 0.40),
                Color(red: 0.99, green: 0.72, blue: 0.45),
                Color(red: 0.98, green: 0.93, blue: 0.89),
            ]
        case .glassGold:
            return [
                Color(red: 0.81, green: 0.57, blue: 0.23),
                Color(red: 0.98, green: 0.82, blue: 0.56),
                Color(red: 0.99, green: 0.95, blue: 0.84),
            ]
        case .neonGuppy:
            return [
                Color(red: 0.00, green: 0.62, blue: 0.78),
                Color(red: 0.36, green: 0.95, blue: 0.68),
                Color(red: 0.98, green: 0.16, blue: 0.54),
            ]
        case .emberTetra:
            return [
                Color(red: 0.77, green: 0.12, blue: 0.17),
                Color(red: 0.96, green: 0.37, blue: 0.21),
                Color(red: 1.00, green: 0.76, blue: 0.44),
            ]
        case .opalAngelfish:
            return [
                Color(red: 0.44, green: 0.53, blue: 0.86),
                Color(red: 0.72, green: 0.90, blue: 0.98),
                Color(red: 0.97, green: 0.98, blue: 1.00),
            ]
        case .leopardShark:
            return [
                Color(red: 0.28, green: 0.32, blue: 0.39),
                Color(red: 0.67, green: 0.73, blue: 0.80),
                Color(red: 0.93, green: 0.96, blue: 0.98),
            ]
        }
    }

    var bodyWidth: CGFloat {
        switch self {
        case .royalBetta:
            return 46
        case .moonKoi:
            return 50
        case .glassGold:
            return 47
        case .neonGuppy:
            return 41
        case .emberTetra:
            return 38
        case .opalAngelfish:
            return 36
        case .leopardShark:
            return 54
        }
    }

    var bodyHeight: CGFloat {
        switch self {
        case .royalBetta:
            return 28
        case .moonKoi:
            return 30
        case .glassGold:
            return 31
        case .neonGuppy:
            return 23
        case .emberTetra:
            return 20
        case .opalAngelfish:
            return 29
        case .leopardShark:
            return 18
        }
    }

    var tailScale: CGFloat {
        switch self {
        case .royalBetta:
            return 1.18
        case .moonKoi:
            return 0.88
        case .glassGold:
            return 0.96
        case .neonGuppy:
            return 1.28
        case .emberTetra:
            return 0.76
        case .opalAngelfish:
            return 1.05
        case .leopardShark:
            return 1.36
        }
    }

    var finHeightMultiplier: CGFloat {
        switch self {
        case .royalBetta:
            return 1.0
        case .moonKoi:
            return 0.86
        case .glassGold:
            return 0.92
        case .neonGuppy:
            return 0.78
        case .emberTetra:
            return 0.64
        case .opalAngelfish:
            return 1.34
        case .leopardShark:
            return 0.44
        }
    }

    var isPremium: Bool {
        switch self {
        case .royalBetta, .moonKoi, .neonGuppy, .emberTetra:
            return false
        case .glassGold, .opalAngelfish, .leopardShark:
            return true
        }
    }

    var freeFallback: FishSpecies {
        switch self {
        case .glassGold:
            return .emberTetra
        case .opalAngelfish:
            return .royalBetta
        case .leopardShark:
            return .emberTetra
        default:
            return self
        }
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Fish")
    }

    static var caseDisplayRepresentations: [FishSpecies: DisplayRepresentation] {
        [
            .royalBetta: DisplayRepresentation(title: "Royal Betta"),
            .moonKoi: DisplayRepresentation(title: "Moon Koi"),
            .glassGold: DisplayRepresentation(title: "Glass Goldfish"),
            .neonGuppy: DisplayRepresentation(title: "Neon Guppy"),
            .emberTetra: DisplayRepresentation(title: "Ember Tetra"),
            .opalAngelfish: DisplayRepresentation(title: "Opal Angelfish"),
            .leopardShark: DisplayRepresentation(title: "Leopard Shark"),
        ]
    }
}

extension FishSpecies: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if raw == "seahorse" {
            self = .moonKoi
            return
        }
        guard let value = FishSpecies(rawValue: raw) else {
            self = .royalBetta
            return
        }
        self = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum FishPersonality: String, CaseIterable, Codable, Hashable, Identifiable, Sendable, AppEnum {
    case playful
    case shy
    case greedy
    case dreamy

    var id: Self { self }

    var title: String {
        switch self {
        case .playful:
            return "Playful"
        case .shy:
            return "Shy"
        case .greedy:
            return "Greedy"
        case .dreamy:
            return "Dreamy"
        }
    }

    var summary: String {
        switch self {
        case .playful:
            return "More movement, more curiosity, more little moments."
        case .shy:
            return "Hangs back a bit and keeps a quieter rhythm."
        case .greedy:
            return "Rushes food fast and tends to hog the spotlight."
        case .dreamy:
            return "Drifts softly and feels calm, floaty, and sleepy."
        }
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Personality")
    }

    static var caseDisplayRepresentations: [FishPersonality: DisplayRepresentation] {
        [
            .playful: DisplayRepresentation(title: "Playful"),
            .shy: DisplayRepresentation(title: "Shy"),
            .greedy: DisplayRepresentation(title: "Greedy"),
            .dreamy: DisplayRepresentation(title: "Dreamy"),
        ]
    }
}

enum FishCount: String, CaseIterable, Codable, Hashable, Identifiable, Sendable, AppEnum {
    case solo
    case duet
    case trio

    var id: Self { self }

    var title: String {
        switch self {
        case .solo:
            return "Solo"
        case .duet:
            return "Duet"
        case .trio:
            return "Trio"
        }
    }

    var value: Int {
        switch self {
        case .solo:
            return 1
        case .duet:
            return 2
        case .trio:
            return 3
        }
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Count")
    }

    static var caseDisplayRepresentations: [FishCount: DisplayRepresentation] {
        [
            .solo: DisplayRepresentation(title: "Solo"),
            .duet: DisplayRepresentation(title: "Duet"),
            .trio: DisplayRepresentation(title: "Trio"),
        ]
    }
}

enum CompanionStyle: String, CaseIterable, Codable, Hashable, Identifiable, Sendable, AppEnum {
    case none
    case snail
    case shrimp
    case crab
    case seaCucumber
    case nudibranchFlame
    case nudibranchRibbon

    var id: Self { self }

    var title: String {
        switch self {
        case .none:
            return "No Companion"
        case .snail:
            return "Snail"
        case .shrimp:
            return "Shrimp"
        case .crab:
            return "Crab"
        case .seaCucumber:
            return "Sea Cucumber"
        case .nudibranchFlame:
            return "Flame Nudibranch"
        case .nudibranchRibbon:
            return "Ribbon Nudibranch"
        }
    }

    var shortTitle: String {
        switch self {
        case .none:
            return "Clean"
        case .snail:
            return "Snail"
        case .shrimp:
            return "Shrimp"
        case .crab:
            return "Crab"
        case .seaCucumber:
            return "Sea Cucumber"
        case .nudibranchFlame:
            return "Flame Nudibranch"
        case .nudibranchRibbon:
            return "Ribbon Nudibranch"
        }
    }

    var summary: String {
        switch self {
        case .none:
            return "Keep the bowl minimal and uninterrupted."
        case .snail:
            return "A slow glass-side detail near the base."
        case .shrimp:
            return "A delicate accent with more motion and color."
        case .crab:
            return "A playful bottom-dweller that anchors the scene."
        case .seaCucumber:
            return "A luxe reef-floor companion with a softer, sculptural shape."
        case .nudibranchFlame:
            return "A vivid violet nudibranch with flame-orange frills."
        case .nudibranchRibbon:
            return "A striped collector nudibranch with orange ribbon edges."
        }
    }

    var isPremium: Bool {
        switch self {
        case .none, .snail:
            return false
        case .shrimp, .crab, .seaCucumber, .nudibranchFlame, .nudibranchRibbon:
            return true
        }
    }

    var freeFallback: CompanionStyle {
        switch self {
        case .shrimp, .crab, .seaCucumber, .nudibranchFlame, .nudibranchRibbon:
            return .snail
        default:
            return self
        }
    }

    init?(persistedRawValue: String) {
        switch persistedRawValue {
        case "nudibranch":
            self = .nudibranchFlame
        default:
            self.init(rawValue: persistedRawValue)
        }
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Companion")
    }

    static var caseDisplayRepresentations: [CompanionStyle: DisplayRepresentation] {
        [
            .none: DisplayRepresentation(title: "No Companion"),
            .snail: DisplayRepresentation(title: "Snail"),
            .shrimp: DisplayRepresentation(title: "Shrimp"),
            .crab: DisplayRepresentation(title: "Crab"),
            .seaCucumber: DisplayRepresentation(title: "Sea Cucumber"),
            .nudibranchFlame: DisplayRepresentation(title: "Flame Nudibranch"),
            .nudibranchRibbon: DisplayRepresentation(title: "Ribbon Nudibranch"),
        ]
    }
}

enum SubstrateStyle: String, CaseIterable, Codable, Hashable, Identifiable, Sendable, AppEnum {
    case pearlSand
    case obsidianSand
    case coralBloom
    case moonGravel

    var id: Self { self }

    var title: String {
        switch self {
        case .pearlSand:
            return "Pearl Sand"
        case .obsidianSand:
            return "Obsidian Sand"
        case .coralBloom:
            return "Coral Bloom"
        case .moonGravel:
            return "Moon Gravel"
        }
    }

    var summary: String {
        switch self {
        case .pearlSand:
            return "Soft gold sand with a champagne finish."
        case .obsidianSand:
            return "Dark mineral bed with sharper contrast."
        case .coralBloom:
            return "Bold coral-like color at the bottom edge."
        case .moonGravel:
            return "Cool silver stones with lavender undertones."
        }
    }

    var bedColors: [Color] {
        switch self {
        case .pearlSand:
            return [
                Color(red: 0.74, green: 0.63, blue: 0.44),
                Color(red: 0.90, green: 0.82, blue: 0.63),
                Color(red: 0.98, green: 0.93, blue: 0.82),
            ]
        case .obsidianSand:
            return [
                Color(red: 0.13, green: 0.14, blue: 0.18),
                Color(red: 0.24, green: 0.26, blue: 0.31),
                Color(red: 0.40, green: 0.42, blue: 0.48),
            ]
        case .coralBloom:
            return [
                Color(red: 0.78, green: 0.14, blue: 0.26),
                Color(red: 0.97, green: 0.36, blue: 0.30),
                Color(red: 1.00, green: 0.77, blue: 0.43),
            ]
        case .moonGravel:
            return [
                Color(red: 0.56, green: 0.61, blue: 0.69),
                Color(red: 0.71, green: 0.76, blue: 0.86),
                Color(red: 0.88, green: 0.83, blue: 0.94),
            ]
        }
    }

    var accentColors: [Color] {
        switch self {
        case .pearlSand:
            return [
                Color(red: 1.00, green: 0.58, blue: 0.32),
                Color(red: 0.71, green: 0.34, blue: 0.74),
                Color(red: 0.26, green: 0.48, blue: 0.88),
            ]
        case .obsidianSand:
            return [
                Color(red: 0.23, green: 0.86, blue: 0.93),
                Color(red: 0.40, green: 0.57, blue: 0.95),
                Color(red: 0.96, green: 0.19, blue: 0.52),
            ]
        case .coralBloom:
            return [
                Color(red: 1.00, green: 0.47, blue: 0.28),
                Color(red: 0.96, green: 0.11, blue: 0.45),
                Color(red: 0.38, green: 0.48, blue: 0.97),
            ]
        case .moonGravel:
            return [
                Color(red: 0.47, green: 0.74, blue: 0.98),
                Color(red: 0.64, green: 0.50, blue: 0.95),
                Color(red: 0.94, green: 0.65, blue: 0.82),
            ]
        }
    }

    var isPremium: Bool {
        switch self {
        case .pearlSand, .obsidianSand:
            return false
        case .coralBloom, .moonGravel:
            return true
        }
    }

    var freeFallback: SubstrateStyle {
        switch self {
        case .coralBloom:
            return .obsidianSand
        case .moonGravel:
            return .pearlSand
        default:
            return self
        }
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Substrate")
    }

    static var caseDisplayRepresentations: [SubstrateStyle: DisplayRepresentation] {
        [
            .pearlSand: DisplayRepresentation(title: "Pearl Sand"),
            .obsidianSand: DisplayRepresentation(title: "Obsidian Sand"),
            .coralBloom: DisplayRepresentation(title: "Coral Bloom"),
            .moonGravel: DisplayRepresentation(title: "Moon Gravel"),
        ]
    }
}

enum DecorationStyle: String, CaseIterable, Codable, Hashable, Identifiable, Sendable, AppEnum {
    case minimal
    case coralGarden
    case riverRocks
    case glassPearls

    var id: Self { self }

    var title: String {
        switch self {
        case .minimal:
            return "Minimal"
        case .coralGarden:
            return "Coral Garden"
        case .riverRocks:
            return "River Rocks"
        case .glassPearls:
            return "Glass Pearls"
        }
    }

    var summary: String {
        switch self {
        case .minimal:
            return "A quieter floor with just the substrate and fish."
        case .coralGarden:
            return "High-color coral branches for a more lush bowl."
        case .riverRocks:
            return "Layered stones and pebbles for a grounded tank."
        case .glassPearls:
            return "Polished glass orbs for a more sculptural finish."
        }
    }

    var accentColors: [Color] {
        switch self {
        case .minimal:
            return [
                Color.white.opacity(0.9),
                Color(red: 0.75, green: 0.90, blue: 1.00),
                Color(red: 0.84, green: 0.94, blue: 0.98),
            ]
        case .coralGarden:
            return [
                Color(red: 0.99, green: 0.50, blue: 0.30),
                Color(red: 0.89, green: 0.18, blue: 0.51),
                Color(red: 0.41, green: 0.52, blue: 0.95),
            ]
        case .riverRocks:
            return [
                Color(red: 0.28, green: 0.32, blue: 0.39),
                Color(red: 0.54, green: 0.59, blue: 0.67),
                Color(red: 0.77, green: 0.80, blue: 0.87),
            ]
        case .glassPearls:
            return [
                Color(red: 0.95, green: 0.98, blue: 1.00),
                Color(red: 0.92, green: 0.83, blue: 0.68),
                Color(red: 0.73, green: 0.87, blue: 0.98),
            ]
        }
    }

    var isPremium: Bool {
        switch self {
        case .minimal, .riverRocks:
            return false
        case .coralGarden, .glassPearls:
            return true
        }
    }

    var freeFallback: DecorationStyle {
        switch self {
        case .coralGarden:
            return .minimal
        case .glassPearls:
            return .riverRocks
        default:
            return self
        }
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Decoration")
    }

    static var caseDisplayRepresentations: [DecorationStyle: DisplayRepresentation] {
        [
            .minimal: DisplayRepresentation(title: "Minimal"),
            .coralGarden: DisplayRepresentation(title: "Coral Garden"),
            .riverRocks: DisplayRepresentation(title: "River Rocks"),
            .glassPearls: DisplayRepresentation(title: "Glass Pearls"),
        ]
    }
}

enum FeaturePieceStyle: String, CaseIterable, Codable, Hashable, Identifiable, Sendable, AppEnum {
    case none
    case bubbleStone
    case driftwoodArch
    case moonLantern
    case kelp

    var id: Self { self }

    var title: String {
        switch self {
        case .none:
            return "No Feature Piece"
        case .bubbleStone:
            return "Bubble Stone"
        case .driftwoodArch:
            return "Driftwood Arch"
        case .moonLantern:
            return "Moon Lantern"
        case .kelp:
            return "Kelp"
        }
    }

    var shortTitle: String {
        switch self {
        case .none:
            return "Clean"
        case .bubbleStone:
            return "Bubble Stone"
        case .driftwoodArch:
            return "Driftwood"
        case .moonLantern:
            return "Lantern"
        case .kelp:
            return "Kelp"
        }
    }

    var summary: String {
        switch self {
        case .none:
            return "Keep the scene open and understated."
        case .bubbleStone:
            return "A soft bubbling accent that anchors the bowl."
        case .driftwoodArch:
            return "A sculptural wood curve for a more natural tank."
        case .moonLantern:
            return "A glowing orb detail with a more couture feel."
        case .kelp:
            return "Four tall kelp strands that sway up through the water."
        }
    }

    var accentColors: [Color] {
        switch self {
        case .none:
            return [Color.clear, Color.clear, Color.clear]
        case .bubbleStone:
            return [
                Color(red: 0.62, green: 0.66, blue: 0.74),
                Color(red: 0.83, green: 0.87, blue: 0.93),
                Color(red: 0.95, green: 0.98, blue: 1.00),
            ]
        case .driftwoodArch:
            return [
                Color(red: 0.43, green: 0.30, blue: 0.20),
                Color(red: 0.63, green: 0.45, blue: 0.28),
                Color(red: 0.83, green: 0.67, blue: 0.44),
            ]
        case .moonLantern:
            return [
                Color(red: 0.73, green: 0.84, blue: 0.98),
                Color(red: 0.96, green: 0.97, blue: 1.00),
                Color(red: 0.87, green: 0.90, blue: 0.99),
            ]
        case .kelp:
            return [
                Color(red: 0.13, green: 0.33, blue: 0.18),
                Color(red: 0.24, green: 0.57, blue: 0.28),
                Color(red: 0.58, green: 0.88, blue: 0.52),
            ]
        }
    }

    var isPremium: Bool {
        switch self {
        case .none, .bubbleStone:
            return false
        case .driftwoodArch, .moonLantern, .kelp:
            return true
        }
    }

    var freeFallback: FeaturePieceStyle {
        switch self {
        case .driftwoodArch, .moonLantern, .kelp:
            return .bubbleStone
        default:
            return self
        }
    }

    init?(persistedRawValue: String) {
        switch persistedRawValue {
        case "shellCluster":
            self = .kelp
        default:
            self.init(rawValue: persistedRawValue)
        }
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Feature Piece")
    }

    static var caseDisplayRepresentations: [FeaturePieceStyle: DisplayRepresentation] {
        [
            .none: DisplayRepresentation(title: "No Feature Piece"),
            .bubbleStone: DisplayRepresentation(title: "Bubble Stone"),
            .driftwoodArch: DisplayRepresentation(title: "Driftwood Arch"),
            .moonLantern: DisplayRepresentation(title: "Moon Lantern"),
            .kelp: DisplayRepresentation(title: "Kelp"),
        ]
    }
}

enum AquariumDisplayFormat: String, CaseIterable, Identifiable, Sendable {
    case studioHero
    case widgetSmall
    case widgetMedium
    case widgetLarge
    case appIcon

    var id: Self { self }

    var title: String {
        switch self {
        case .studioHero:
            return "Hero"
        case .widgetSmall:
            return "Small"
        case .widgetMedium:
            return "Medium"
        case .widgetLarge:
            return "Large"
        case .appIcon:
            return "App Icon"
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .studioHero:
            return 0.96
        case .widgetSmall:
            return 1.0
        case .widgetMedium:
            return 2.14
        case .widgetLarge:
            return 1.0
        case .appIcon:
            return 1.0
        }
    }

    var frameHeight: CGFloat {
        switch self {
        case .studioHero:
            return 360
        case .widgetSmall:
            return 164
        case .widgetMedium:
            return 164
        case .widgetLarge:
            return 214
        case .appIcon:
            return 164
        }
    }

    var bodyInset: CGFloat {
        switch self {
        case .studioHero:
            return 24
        case .widgetSmall:
            return 4
        case .widgetMedium:
            return 6
        case .widgetLarge:
            return 8
        case .appIcon:
            return 6
        }
    }
}

struct AquariumConfiguration: Hashable, Codable, Sendable {
    var vesselStyle: AquariumVesselStyle
    var fishSpecies: FishSpecies
    var fishCount: FishCount
    var additionalFishSpecies: [FishSpecies]
    var personality: FishPersonality
    var companions: [CompanionStyle]
    var substrate: SubstrateStyle
    var decoration: DecorationStyle
    var featurePiece: FeaturePieceStyle

    init(
        vesselStyle: AquariumVesselStyle,
        fishSpecies: FishSpecies,
        fishCount: FishCount,
        additionalFishSpecies: [FishSpecies] = [],
        personality: FishPersonality = .playful,
        companion: CompanionStyle = .none,
        companions: [CompanionStyle]? = nil,
        substrate: SubstrateStyle,
        decoration: DecorationStyle,
        featurePiece: FeaturePieceStyle
    ) {
        self.vesselStyle = vesselStyle
        self.fishSpecies = fishSpecies
        self.fishCount = fishCount
        self.additionalFishSpecies = additionalFishSpecies
        self.personality = personality
        self.companions = Self.normalizedCompanions(companions ?? [companion])
        self.substrate = substrate
        self.decoration = decoration
        self.featurePiece = featurePiece
    }

    enum CodingKeys: String, CodingKey {
        case vesselStyle
        case fishSpecies
        case fishCount
        case additionalFishSpecies
        case personality
        case companion
        case companions
        case substrate
        case decoration
        case featurePiece
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vesselStyle = try container.decode(AquariumVesselStyle.self, forKey: .vesselStyle)
        fishSpecies = try container.decode(FishSpecies.self, forKey: .fishSpecies)
        fishCount = try container.decode(FishCount.self, forKey: .fishCount)
        additionalFishSpecies = try container.decodeIfPresent([FishSpecies].self, forKey: .additionalFishSpecies) ?? []
        personality = try container.decodeIfPresent(FishPersonality.self, forKey: .personality) ?? .playful
        if let companionRaws = try container.decodeIfPresent([String].self, forKey: .companions) {
            companions = Self.normalizedCompanions(
                companionRaws.compactMap { CompanionStyle(persistedRawValue: $0) }
            )
        } else if let companionRaw = try container.decodeIfPresent(String.self, forKey: .companion) {
            companions = Self.normalizedCompanions([CompanionStyle(persistedRawValue: companionRaw) ?? .none])
        } else {
            companions = []
        }
        substrate = try container.decode(SubstrateStyle.self, forKey: .substrate)
        decoration = try container.decode(DecorationStyle.self, forKey: .decoration)
        if let featurePieceRaw = try container.decodeIfPresent(String.self, forKey: .featurePiece) {
            featurePiece = FeaturePieceStyle(persistedRawValue: featurePieceRaw) ?? .none
        } else {
            featurePiece = .none
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(vesselStyle, forKey: .vesselStyle)
        try container.encode(fishSpecies, forKey: .fishSpecies)
        try container.encode(fishCount, forKey: .fishCount)
        try container.encode(additionalFishSpecies, forKey: .additionalFishSpecies)
        try container.encode(personality, forKey: .personality)
        try container.encode(resolvedCompanions.map(\.rawValue), forKey: .companions)
        try container.encode(substrate, forKey: .substrate)
        try container.encode(decoration, forKey: .decoration)
        try container.encode(featurePiece, forKey: .featurePiece)
    }

    static let hero = AquariumConfiguration(
        vesselStyle: .orb,
        fishSpecies: .royalBetta,
        fishCount: .duet,
        companions: [.snail],
        substrate: .obsidianSand,
        decoration: .minimal,
        featurePiece: .bubbleStone
    )

    static let curatedPresets: [AquariumConfiguration] = [
        .hero,
        AquariumConfiguration(
            vesselStyle: .gallery,
            fishSpecies: .royalBetta,
            fishCount: .solo,
            companion: .none,
            substrate: .pearlSand,
            decoration: .riverRocks,
            featurePiece: .none
        ),
        AquariumConfiguration(
            vesselStyle: .panorama,
            fishSpecies: .moonKoi,
            fishCount: .trio,
            companions: [.crab],
            substrate: .moonGravel,
            decoration: .riverRocks,
            featurePiece: .moonLantern
        ),
    ]

    static let appIcon = AquariumConfiguration(
        vesselStyle: .orb,
        fishSpecies: .moonKoi,
        fishCount: .solo,
        companions: [],
        substrate: .moonGravel,
        decoration: .riverRocks,
        featurePiece: .bubbleStone
    )

    var resolvedFishSpecies: [FishSpecies] {
        let targetCount = max(1, fishCount.value)
        let extras = Array(additionalFishSpecies.prefix(max(0, targetCount - 1)))
        return [fishSpecies] + (0..<(targetCount - 1)).map { index in
            extras.indices.contains(index) ? extras[index] : fishSpecies
        }
    }

    var companion: CompanionStyle {
        get { resolvedCompanions.first ?? .none }
        set { companions = Self.normalizedCompanions([newValue]) }
    }

    var resolvedCompanions: [CompanionStyle] {
        Self.normalizedCompanions(companions)
    }

    var uniqueFishSpecies: [FishSpecies] {
        var seen = Set<FishSpecies>()
        return resolvedFishSpecies.filter { seen.insert($0).inserted }
    }

    var fishPalette: [Color] {
        uniqueFishSpecies.flatMap(\.palette)
    }

    var descriptor: String {
        let renderedCount = resolvedFishSpecies.count
        if uniqueFishSpecies.count > 1 {
            return "\(fishCountTitle(for: renderedCount)) Mixed Fish"
        }
        return "\(fishCountTitle(for: renderedCount)) \(fishSpecies.title)"
    }

    var detailLine: String {
        var parts: [String] = []
        if uniqueFishSpecies.count > 1 {
            parts.append(uniqueFishSpecies.map(\.title).joined(separator: " + "))
        }
        parts.append(personality.title)
        parts += [substrate.title, decoration.title]
        if featurePiece != .none {
            parts.append(featurePiece.shortTitle)
        }
        if !resolvedCompanions.isEmpty {
            parts.append(resolvedCompanions.map(\.shortTitle).joined(separator: " + "))
        }
        return parts.joined(separator: " • ")
    }

    func sanitizedForFreeTier() -> AquariumConfiguration {
        AquariumConfiguration(
            vesselStyle: vesselStyle.freeFallback,
            fishSpecies: fishSpecies.freeFallback,
            fishCount: fishCount,
            additionalFishSpecies: [],
            personality: personality,
            companions: resolvedCompanions.prefix(1).map(\.freeFallback),
            substrate: substrate.freeFallback,
            decoration: decoration.freeFallback,
            featurePiece: featurePiece.freeFallback
        )
    }

    var requiresPremiumUnlock: Bool {
        vesselStyle.isPremium
        || fishSpecies.isPremium
        || resolvedCompanions.contains(where: \.isPremium)
        || substrate.isPremium
        || decoration.isPremium
        || featurePiece.isPremium
        || uniqueFishSpecies.count > 1
        || resolvedCompanions.count > 1
    }

    private static func normalizedCompanions(_ companions: [CompanionStyle]) -> [CompanionStyle] {
        companions
            .filter { $0 != .none }
            .prefix(3)
            .map { $0 }
    }

    private func fishCountTitle(for count: Int) -> String {
        switch count {
        case 1:
            return FishCount.solo.title
        case 2:
            return FishCount.duet.title
        default:
            return FishCount.trio.title
        }
    }
}
