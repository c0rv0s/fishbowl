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

enum FishSpecies: String, CaseIterable, Codable, Hashable, Identifiable, Sendable, AppEnum {
    case royalBetta
    case moonKoi
    case glassGold
    case neonGuppy
    case emberTetra
    case opalAngelfish

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

enum AquariumDisplayFormat: String, CaseIterable, Identifiable, Sendable {
    case studioHero
    case widgetSmall
    case widgetMedium
    case widgetLarge

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
        }
    }
}

struct AquariumConfiguration: Hashable, Codable, Sendable {
    var vesselStyle: AquariumVesselStyle
    var fishSpecies: FishSpecies
    var fishCount: FishCount
    var companion: CompanionStyle
    var substrate: SubstrateStyle
    var decoration: DecorationStyle

    static let hero = AquariumConfiguration(
        vesselStyle: .orb,
        fishSpecies: .royalBetta,
        fishCount: .duet,
        companion: .shrimp,
        substrate: .coralBloom,
        decoration: .coralGarden
    )

    static let curatedPresets: [AquariumConfiguration] = [
        .hero,
        AquariumConfiguration(
            vesselStyle: .gallery,
            fishSpecies: .glassGold,
            fishCount: .solo,
            companion: .none,
            substrate: .pearlSand,
            decoration: .glassPearls
        ),
        AquariumConfiguration(
            vesselStyle: .panorama,
            fishSpecies: .moonKoi,
            fishCount: .trio,
            companion: .crab,
            substrate: .moonGravel,
            decoration: .riverRocks
        ),
    ]

    var descriptor: String {
        "\(fishCount.title) \(fishSpecies.title)"
    }

    var detailLine: String {
        var parts = [substrate.title, decoration.title]
        if companion != .none {
            parts.append(companion.shortTitle)
        }
        return parts.joined(separator: " • ")
    }
}
