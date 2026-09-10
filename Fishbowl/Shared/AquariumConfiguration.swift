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
    case sunsetRasbora
    case glassGold
    case neonGuppy
    case emberTetra
    case opalAngelfish
    case leopardShark
    case velvetDiscus
    case silverArowana
    case humpbackWhale
    case moonStingray
    case ribbonEel
    case pearlSeahorse
    case crystalPuffer
    case sunburstButterfly
    case mandarinDragonet
    case blueTang
    case glassSailfish
    case leafySeaDragon

    var id: Self { self }

    var title: String {
        switch self {
        case .royalBetta:
            return "Royal Betta"
        case .moonKoi:
            return "Moon Koi"
        case .sunsetRasbora:
            return "Sunset Rasbora"
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
        case .velvetDiscus:
            return "Velvet Discus"
        case .silverArowana:
            return "Silver Arowana"
        case .humpbackWhale:
            return "Humpback Whale"
        case .moonStingray:
            return "Moon Stingray"
        case .ribbonEel:
            return "Ribbon Eel"
        case .pearlSeahorse:
            return "Pearl Seahorse"
        case .crystalPuffer:
            return "Crystal Puffer"
        case .sunburstButterfly:
            return "Sunburst Butterflyfish"
        case .mandarinDragonet:
            return "Mandarin Dragonet"
        case .blueTang:
            return "Blue Tang"
        case .glassSailfish:
            return "Glass Sailfish"
        case .leafySeaDragon:
            return "Leafy Sea Dragon"
        }
    }

    var summary: String {
        switch self {
        case .royalBetta:
            return "Cobalt glass with soft, flowing fins."
        case .moonKoi:
            return "Pearl glass with coral and ink inclusions."
        case .sunsetRasbora:
            return "Amber glass wrapped in fine pearl bands."
        case .glassGold:
            return "Champagne glass and translucent gold fins."
        case .neonGuppy:
            return "Turquoise glass with ribbons of rose."
        case .emberTetra:
            return "A slender silhouette in ember and gold."
        case .opalAngelfish:
            return "Tall opal fins with delicate blue bands."
        case .leopardShark:
            return "A tiny spotted shark with sleek silver movement."
        case .velvetDiscus:
            return "Amethyst glass with flowing gold ribbons."
        case .silverArowana:
            return "A long, quiet silhouette in silver glass."
        case .humpbackWhale:
            return "Cobalt glass with an opal belly and sweeping flippers."
        case .moonStingray:
            return "An opal ray with rippling wings and a trailing glass ribbon."
        case .ribbonEel:
            return "A winding cobalt ribbon edged in honey gold."
        case .pearlSeahorse:
            return "Rose and champagne glass with a softly curled tail."
        case .crystalPuffer:
            return "A round honey-glass puffer with tiny opal fins."
        case .sunburstButterfly:
            return "Lemon glass, pearl bands, and an elegant ink eye stripe."
        case .mandarinDragonet:
            return "Turquoise glass traced with flowing tangerine ribbons."
        case .blueTang:
            return "Sapphire glass with a bright lemon tail."
        case .glassSailfish:
            return "A silver-blue swimmer with a broad translucent sail."
        case .leafySeaDragon:
            return "Jade glass with a winding tail and broad champagne-edged leaves."
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
        case .sunsetRasbora:
            return [
                Color(red: 0.92, green: 0.22, blue: 0.34),
                Color(red: 1.00, green: 0.50, blue: 0.31),
                Color(red: 1.00, green: 0.83, blue: 0.52),
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
        case .velvetDiscus:
            return [
                Color(red: 0.31, green: 0.20, blue: 0.45),
                Color(red: 0.58, green: 0.39, blue: 0.74),
                Color(red: 0.91, green: 0.84, blue: 0.98),
            ]
        case .silverArowana:
            return [
                Color(red: 0.34, green: 0.39, blue: 0.46),
                Color(red: 0.71, green: 0.80, blue: 0.88),
                Color(red: 0.93, green: 0.97, blue: 1.00),
            ]
        case .humpbackWhale:
            return [
                Color(red: 0.16, green: 0.22, blue: 0.31),
                Color(red: 0.37, green: 0.54, blue: 0.67),
                Color(red: 0.92, green: 0.96, blue: 0.98),
            ]
        case .moonStingray:
            return [Color(red: 0.38, green: 0.67, blue: 0.78), Color(red: 0.78, green: 0.91, blue: 0.94), Color(red: 0.96, green: 0.89, blue: 0.75)]
        case .ribbonEel:
            return [Color(red: 0.02, green: 0.18, blue: 0.65), Color(red: 0.04, green: 0.55, blue: 0.79), Color(red: 0.98, green: 0.76, blue: 0.24)]
        case .pearlSeahorse:
            return [Color(red: 0.76, green: 0.25, blue: 0.38), Color(red: 0.96, green: 0.64, blue: 0.55), Color(red: 0.99, green: 0.9, blue: 0.74)]
        case .crystalPuffer:
            return [Color(red: 0.78, green: 0.42, blue: 0.1), Color(red: 0.99, green: 0.76, blue: 0.34), Color(red: 0.97, green: 0.94, blue: 0.8)]
        case .sunburstButterfly:
            return [Color(red: 0.96, green: 0.66, blue: 0.06), Color(red: 0.99, green: 0.89, blue: 0.46), Color(red: 0.95, green: 0.96, blue: 0.9)]
        case .mandarinDragonet:
            return [Color(red: 0.01, green: 0.46, blue: 0.53), Color(red: 0.04, green: 0.76, blue: 0.74), Color(red: 0.96, green: 0.34, blue: 0.1)]
        case .blueTang:
            return [Color(red: 0.015, green: 0.07, blue: 0.64), Color(red: 0.06, green: 0.39, blue: 0.96), Color(red: 0.99, green: 0.87, blue: 0.12)]
        case .glassSailfish:
            return [Color(red: 0.035, green: 0.25, blue: 0.4), Color(red: 0.19, green: 0.62, blue: 0.72), Color(red: 0.84, green: 0.93, blue: 0.96)]
        case .leafySeaDragon:
            return [Color(red: 0.13, green: 0.39, blue: 0.24), Color(red: 0.47, green: 0.77, blue: 0.52), Color(red: 0.95, green: 0.83, blue: 0.51)]
        }
    }

    var bodyWidth: CGFloat {
        switch self {
        case .royalBetta:
            return 46
        case .moonKoi:
            return 50
        case .sunsetRasbora:
            return 39
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
        case .velvetDiscus:
            return 42
        case .silverArowana:
            return 58
        case .humpbackWhale:
            return 66
        case .moonStingray:
            return 54
        case .ribbonEel:
            return 76
        case .pearlSeahorse:
            return 28
        case .crystalPuffer:
            return 39
        case .sunburstButterfly:
            return 40
        case .mandarinDragonet:
            return 45
        case .blueTang:
            return 44
        case .glassSailfish:
            return 70
        case .leafySeaDragon:
            return 58
        }
    }

    var bodyHeight: CGFloat {
        switch self {
        case .royalBetta:
            return 28
        case .moonKoi:
            return 30
        case .sunsetRasbora:
            return 19
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
        case .velvetDiscus:
            return 34
        case .silverArowana:
            return 17
        case .humpbackWhale:
            return 23
        case .moonStingray:
            return 34
        case .ribbonEel:
            return 15
        case .pearlSeahorse:
            return 48
        case .crystalPuffer:
            return 35
        case .sunburstButterfly:
            return 37
        case .mandarinDragonet:
            return 24
        case .blueTang:
            return 33
        case .glassSailfish:
            return 21
        case .leafySeaDragon:
            return 24
        }
    }

    var tailScale: CGFloat {
        switch self {
        case .royalBetta:
            return 1.18
        case .moonKoi:
            return 0.88
        case .sunsetRasbora:
            return 0.86
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
        case .velvetDiscus:
            return 0.62
        case .silverArowana:
            return 0.74
        case .humpbackWhale:
            return 1.04
        case .moonStingray:
            return 0.48
        case .ribbonEel:
            return 0.45
        case .pearlSeahorse:
            return 0.52
        case .crystalPuffer:
            return 0.6
        case .sunburstButterfly:
            return 0.72
        case .mandarinDragonet:
            return 1.02
        case .blueTang:
            return 0.81
        case .glassSailfish:
            return 0.86
        case .leafySeaDragon:
            return 0.78
        }
    }

    var finHeightMultiplier: CGFloat {
        switch self {
        case .royalBetta:
            return 1.0
        case .moonKoi:
            return 0.86
        case .sunsetRasbora:
            return 0.68
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
        case .velvetDiscus:
            return 0.82
        case .silverArowana:
            return 0.56
        case .humpbackWhale:
            return 0.46
        case .moonStingray:
            return 0.66
        case .ribbonEel:
            return 0.48
        case .pearlSeahorse:
            return 0.54
        case .crystalPuffer:
            return 0.58
        case .sunburstButterfly:
            return 1.1
        case .mandarinDragonet:
            return 1.08
        case .blueTang:
            return 0.88
        case .glassSailfish:
            return 1.4
        case .leafySeaDragon:
            return 1.38
        }
    }

    var isPremium: Bool {
        switch self {
        case .royalBetta, .moonKoi, .neonGuppy, .emberTetra:
            return false
        case .sunsetRasbora, .glassGold, .opalAngelfish, .leopardShark, .velvetDiscus, .silverArowana, .humpbackWhale,
             .moonStingray, .ribbonEel, .pearlSeahorse, .crystalPuffer, .sunburstButterfly, .mandarinDragonet, .blueTang, .glassSailfish, .leafySeaDragon:
            return true
        }
    }

    var freeFallback: FishSpecies {
        switch self {
        case .sunsetRasbora:
            return .emberTetra
        case .glassGold:
            return .emberTetra
        case .opalAngelfish:
            return .royalBetta
        case .leopardShark:
            return .emberTetra
        case .velvetDiscus:
            return .moonKoi
        case .silverArowana:
            return .moonKoi
        case .humpbackWhale:
            return .moonKoi
        case .moonStingray, .ribbonEel, .pearlSeahorse, .crystalPuffer, .sunburstButterfly, .mandarinDragonet, .blueTang, .glassSailfish, .leafySeaDragon:
            return .moonKoi
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
            .sunsetRasbora: DisplayRepresentation(title: "Sunset Rasbora"),
            .glassGold: DisplayRepresentation(title: "Glass Goldfish"),
            .neonGuppy: DisplayRepresentation(title: "Neon Guppy"),
            .emberTetra: DisplayRepresentation(title: "Ember Tetra"),
            .opalAngelfish: DisplayRepresentation(title: "Opal Angelfish"),
            .leopardShark: DisplayRepresentation(title: "Leopard Shark"),
            .velvetDiscus: DisplayRepresentation(title: "Velvet Discus"),
            .silverArowana: DisplayRepresentation(title: "Silver Arowana"),
            .humpbackWhale: DisplayRepresentation(title: "Humpback Whale"),
            .moonStingray: DisplayRepresentation(title: "Moon Stingray"),
            .ribbonEel: DisplayRepresentation(title: "Ribbon Eel"),
            .pearlSeahorse: DisplayRepresentation(title: "Pearl Seahorse"),
            .crystalPuffer: DisplayRepresentation(title: "Crystal Puffer"),
            .sunburstButterfly: DisplayRepresentation(title: "Sunburst Butterflyfish"),
            .mandarinDragonet: DisplayRepresentation(title: "Mandarin Dragonet"),
            .blueTang: DisplayRepresentation(title: "Blue Tang"),
            .glassSailfish: DisplayRepresentation(title: "Glass Sailfish"),
            .leafySeaDragon: DisplayRepresentation(title: "Leafy Sea Dragon"),

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
            return "Lively, curious movement."
        case .shy:
            return "A quiet, unhurried swimmer."
        case .greedy:
            return "A lively, eager swimmer."
        case .dreamy:
            return "Slow, floating movement."
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
    case miniSubmarine
    case seaUrchin

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
        case .miniSubmarine:
            return "Mini Submarine"
        case .seaUrchin:
            return "Sea Urchin"
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
        case .miniSubmarine:
            return "Submarine"
        case .seaUrchin:
            return "Sea Urchin"
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
            return "A smooth emerald glass sculpture."
        case .nudibranchFlame:
            return "A vivid violet nudibranch with flame-orange frills."
        case .nudibranchRibbon:
            return "A striped collector nudibranch with orange ribbon edges."
        case .miniSubmarine:
            return "A tiny amber explorer that cruises, hovers, and turns its propeller."
        case .seaUrchin:
            return "Amethyst glass with short rounded spines and an unhurried crawl."
        }
    }

    var isPremium: Bool {
        switch self {
        case .none, .snail:
            return false
        case .shrimp, .crab, .seaCucumber, .nudibranchFlame, .nudibranchRibbon, .miniSubmarine, .seaUrchin:
            return true
        }
    }

    var freeFallback: CompanionStyle {
        switch self {
        case .shrimp, .crab, .seaCucumber, .nudibranchFlame, .nudibranchRibbon, .miniSubmarine, .seaUrchin:
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
            .miniSubmarine: DisplayRepresentation(title: "Mini Submarine"),
            .seaUrchin: DisplayRepresentation(title: "Sea Urchin"),
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
            return "Moon Sand"
        }
    }

    var summary: String {
        switch self {
        case .pearlSand:
            return "Soft ivory sand, gently lit from above."
        case .obsidianSand:
            return "Smooth charcoal sand."
        case .coralBloom:
            return "Fine sand with a soft blush tint."
        case .moonGravel:
            return "Smooth silver sand with a cool pearl tint."
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
            .moonGravel: DisplayRepresentation(title: "Moon Sand"),
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
            return "Layered rose and seafoam glass coral with softly curled edges."
        case .riverRocks:
            return "Three smooth glass stones, grouped on an open sand bed."
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
                Color(red: 0.88, green: 0.39, blue: 0.43),
                Color(red: 0.99, green: 0.69, blue: 0.52),
                Color(red: 0.39, green: 0.78, blue: 0.65),
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
    case pearlShell
    case seaFan

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
        case .pearlShell:
            return "Pearl Shell"
        case .seaFan:
            return "Sea Fan"
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
        case .pearlShell:
            return "Pearl Shell"
        case .seaFan:
            return "Sea Fan"
        }
    }

    var summary: String {
        switch self {
        case .none:
            return "Keep the scene open and understated."
        case .bubbleStone:
            return "A soft bubbling accent that anchors the bowl."
        case .driftwoodArch:
            return "A flowing arch of amber glass with a warm golden thread."
        case .moonLantern:
            return "A warm light held in a clear glass orb."
        case .kelp:
            return "Broad, rounded glass fronds that sway gently."
        case .pearlShell:
            return "An open champagne shell cradling a luminous pearl."
        case .seaFan:
            return "A broad seafoam glass fan with lilac edges and soft folds."
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
        case .pearlShell:
            return [Color(red: 0.88, green: 0.60, blue: 0.63), Color(red: 0.98, green: 0.86, blue: 0.74), Color(red: 0.96, green: 0.97, blue: 0.93)]
        case .seaFan:
            return [Color(red: 0.14, green: 0.61, blue: 0.53), Color(red: 0.58, green: 0.81, blue: 0.76), Color(red: 0.69, green: 0.57, blue: 0.83)]
        }
    }

    var isPremium: Bool {
        switch self {
        case .none, .bubbleStone:
            return false
        case .driftwoodArch, .moonLantern, .kelp, .pearlShell, .seaFan:
            return true
        }
    }

    var freeFallback: FeaturePieceStyle {
        switch self {
        case .driftwoodArch, .moonLantern, .kelp, .pearlShell, .seaFan:
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
            .pearlShell: DisplayRepresentation(title: "Pearl Shell"),
            .seaFan: DisplayRepresentation(title: "Sea Fan"),
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

enum AquariumTheme: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case ivory, blue, red, neonJungle, lagoon, roseQuartz, sunset, midnight

    var id: Self { self }
    static let wallColors: [Self] = [.ivory, .blue, .red]
    static let palettes: [Self] = [.neonJungle, .lagoon, .roseQuartz, .sunset, .midnight]

    var title: String {
        switch self {
        case .ivory: "Ivory"
        case .blue: "Blue"
        case .red: "Red"
        case .neonJungle: "Neon Jungle"
        case .lagoon: "Lagoon"
        case .roseQuartz: "Rose Quartz"
        case .sunset: "Sunset"
        case .midnight: "Midnight"
        }
    }

    var summary: String {
        switch self {
        case .ivory: "Warm white"
        case .blue: "Clear cobalt"
        case .red: "Deep cherry"
        case .neonJungle: "Pink tiger stripes on green"
        case .lagoon: "Turquoise & seafoam"
        case .roseQuartz: "Blush & lilac"
        case .sunset: "Soft yellow spots on orange"
        case .midnight: "Indigo & violet"
        }
    }

    var prefersLightControls: Bool { [.blue, .red, .neonJungle, .lagoon, .midnight].contains(self) }

    /// Linear RGB, shared by the Metal renderer and the editor's color swatches.
    /// lower.w controls wall glow; upper.w enables coordinated lights; key.w
    /// blends tiger stripes onto the walls; fill.w blends soft sunset spots.
    var palette: AquariumThemePalette {
        switch self {
        case .ivory:
            .init(lower: SIMD4(0.43, 0.45, 0.42, 0), upper: SIMD4(0.88, 0.86, 0.79, 0),
                  key: SIMD4(1, 0.95, 0.82, 0), fill: SIMD4(0.70, 0.88, 1, 0))
        case .blue:
            .init(lower: SIMD4(0.016, 0.055, 0.20, 0), upper: SIMD4(0.10, 0.28, 0.66, 1),
                  key: SIMD4(0.62, 0.82, 1, 0), fill: SIMD4(0.22, 0.48, 1, 0))
        case .red:
            .init(lower: SIMD4(0.19, 0.009, 0.022, 0), upper: SIMD4(0.62, 0.075, 0.070, 1),
                  key: SIMD4(1, 0.68, 0.56, 0), fill: SIMD4(1, 0.19, 0.32, 0))
        case .neonJungle:
            .init(lower: SIMD4(0.018, 0.19, 0.028, 0.16), upper: SIMD4(0.13, 0.58, 0.085, 1),
                  key: SIMD4(1, 0.012, 0.30, 1), fill: SIMD4(0.16, 1, 0.065, 0))
        case .lagoon:
            .init(lower: SIMD4(0.004, 0.040, 0.047, 0.06), upper: SIMD4(0.070, 0.27, 0.24, 0.45),
                  key: SIMD4(1, 0.88, 0.65, 0), fill: SIMD4(0.34, 0.78, 0.85, 0))
        case .roseQuartz:
            .init(lower: SIMD4(0.30, 0.16, 0.25, 0.17), upper: SIMD4(0.73, 0.47, 0.54, 1),
                  key: SIMD4(1, 0.49, 0.57, 0), fill: SIMD4(0.52, 0.32, 1, 0))
        case .sunset:
            .init(lower: SIMD4(0.36, 0.063, 0.012, 0.18), upper: SIMD4(0.86, 0.29, 0.063, 1),
                  key: SIMD4(1, 0.40, 0.10, 0), fill: SIMD4(1, 0.88, 0.10, 1))
        case .midnight:
            .init(lower: SIMD4(0.006, 0.011, 0.035, 0.12), upper: SIMD4(0.035, 0.045, 0.15, 1),
                  key: SIMD4(0.25, 0.38, 1, 0), fill: SIMD4(0.66, 0.16, 1, 0))
        }
    }

    var swatchColors: [Color] {
        let p = palette
        func color(_ v: SIMD4<Float>) -> Color {
            Color(.sRGBLinear, red: Double(v.x), green: Double(v.y), blue: Double(v.z), opacity: 1)
        }
        return Self.wallColors.contains(self) || self == .neonJungle || self == .sunset ? [color(p.upper), color(p.lower)]
            : [color(p.key), color(p.upper), color(p.fill)]
    }
}

struct AquariumThemePalette: Equatable, Sendable {
    var lower: SIMD4<Float>
    var upper: SIMD4<Float>
    var key: SIMD4<Float>
    var fill: SIMD4<Float>

    func blended(toward other: Self, amount: Float) -> Self {
        .init(lower: lower + (other.lower - lower) * amount,
              upper: upper + (other.upper - upper) * amount,
              key: key + (other.key - key) * amount,
              fill: fill + (other.fill - fill) * amount)
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
    var featurePieces: [FeaturePieceStyle]
    var theme: AquariumTheme

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
        featurePiece: FeaturePieceStyle,
        featurePieces: [FeaturePieceStyle]? = nil,
        theme: AquariumTheme = .ivory
    ) {
        self.vesselStyle = vesselStyle
        self.fishSpecies = fishSpecies
        self.fishCount = fishCount
        self.additionalFishSpecies = additionalFishSpecies
        self.personality = personality
        self.companions = Self.normalizedCompanions(companions ?? [companion])
        self.substrate = substrate
        self.decoration = decoration
        self.featurePieces = Self.normalizedFeatures(featurePieces ?? [featurePiece])
        self.theme = theme
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
        case featurePieces
        case theme
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Older bowls and themes added by a newer app still load safely.
        theme = AquariumTheme(rawValue: try container.decodeIfPresent(String.self, forKey: .theme) ?? "") ?? .ivory
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
        if let raws = try container.decodeIfPresent([String].self, forKey: .featurePieces) {
            featurePieces = Self.normalizedFeatures(raws.compactMap { FeaturePieceStyle(persistedRawValue: $0) })
        } else if let raw = try container.decodeIfPresent(String.self, forKey: .featurePiece) {
            featurePieces = Self.normalizedFeatures([FeaturePieceStyle(persistedRawValue: raw) ?? .none])
        } else {
            featurePieces = []
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
        try container.encode(resolvedFeaturePieces, forKey: .featurePieces)
        try container.encode(theme, forKey: .theme)
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

    /// Legacy single-piece callers replace the full selection.
    var featurePiece: FeaturePieceStyle {
        get { resolvedFeaturePieces.first ?? .none }
        set { featurePieces = Self.normalizedFeatures([newValue]) }
    }

    var resolvedFeaturePieces: [FeaturePieceStyle] {
        Self.normalizedFeatures(featurePieces)
    }

    static func normalizedFeatures(_ pieces: [FeaturePieceStyle]) -> [FeaturePieceStyle] {
        Array(pieces.filter { $0 != .none }.prefix(2))
    }

    func feature(at slot: Int) -> FeaturePieceStyle {
        resolvedFeaturePieces.indices.contains(slot) ? resolvedFeaturePieces[slot] : .none
    }

    mutating func setFeature(_ feature: FeaturePieceStyle, at slot: Int) {
        guard (0..<2).contains(slot) else { return }
        var pieces = resolvedFeaturePieces
        if pieces.indices.contains(slot) {
            if feature == .none { pieces.remove(at: slot) } else { pieces[slot] = feature }
        } else if feature != .none { pieces.append(feature) }
        featurePieces = Self.normalizedFeatures(pieces)
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
        parts += resolvedFeaturePieces.map(\.shortTitle)
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
            featurePiece: featurePiece.freeFallback,
            featurePieces: resolvedFeaturePieces.map(\.freeFallback),
            theme: theme
        )
    }

    var requiresPremiumUnlock: Bool {
        vesselStyle.isPremium
        || fishSpecies.isPremium
        || resolvedCompanions.contains(where: \.isPremium)
        || substrate.isPremium
        || decoration.isPremium
        || resolvedFeaturePieces.contains(where: \.isPremium)
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
