import Foundation
import simd
import Metal

@main
struct AquariumCatalogCheck {
    static func main() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { fatalError("Metal device is required for the catalog check") }
        let library = try device.makeLibrary(source: AquariumDepthShaders.source, options: nil)
        for name in ["aquariumDepthVertex", "aquariumDepthFragment", "aquariumOpticsFragment"] {
            precondition(library.makeFunction(name: name) != nil, "Missing Metal entry point: \(name)")
        }
        func verify(_ mesh: AquariumMeshData, name: String) {
            precondition(!mesh.indices.isEmpty, "Missing model: \(name)")
            precondition(mesh.indices.count.isMultiple(of: 3))
            precondition(mesh.indices.allSatisfy { Int($0) < mesh.vertices.count }, "Invalid indices: \(name)")
            for v in mesh.vertices {
                precondition([v.position.x, v.position.y, v.position.z, v.normal.x, v.normal.y, v.normal.z, v.uv.z, v.uv.w, v.motion.x, v.motion.y, v.motion.z, v.motion.w].allSatisfy(\.isFinite), "Nonfinite model: \(name)")
                precondition(abs(simd_length(v.normal.xyz) - 1) < 0.02, "Invalid glass normal: \(name)")
                precondition(v.uv.w >= 0, "Invalid glass thickness: \(name)")
            }
        }
        precondition(Set(FishSpecies.allCases.map(\.glassID)).count == FishSpecies.allCases.count)
        var silhouettes = Set<String>()
        for species in FishSpecies.allCases {
            let body = AquariumCatalog.body(species)
            verify(body, name: species.rawValue)
            verify(AquariumCatalog.fins(species), name: "\(species.rawValue) fins")
            verify(AquariumCatalog.features(species), name: "\(species.rawValue) eyes")
            let low = body.vertices.map(\.position.x).min()!, high = body.vertices.map(\.position.y).max()!
            silhouettes.insert("\(low),\(high)")
            for count in FishCount.allCases {
                for foodX: Float in [0.15, 0.85] {
                    var dynamics = AquariumDynamics()
                    let population: Float = count == .solo ? 1 : (count == .duet ? 0.75 : 0.65)
                    dynamics.mouthReach = species.glassMouth.x * species.glassScale * population
                    dynamics.mouthHeight = species.glassMouth.y * species.glassScale * population
                    precondition(dynamics.feed(at: foodX))
                    for _ in 0..<215 { dynamics.step(delta: 1.0 / 60) }
                    let food = dynamics.foodPosition!
                    let reach = foodX > 0.5 ? dynamics.mouthReach : -dynamics.mouthReach
                    precondition(abs(dynamics.fish.x + reach - food.x) < 0.002, "Scaled fish misses food: \(species)")
                    precondition(abs(dynamics.fish.y + dynamics.mouthHeight - food.y) < 0.002, "Upright fish misses food: \(species)")
                }
            }
        }
        precondition(silhouettes.count == FishSpecies.allCases.count, "Species must have distinct silhouettes")
        for companion in CompanionStyle.allCases where companion != .none {
            let mesh = AquariumCatalog.companion(companion)
            verify(mesh, name: companion.rawValue)
            let floor = mesh.vertices.map(\.position.y).min()!
            precondition(floor > -0.016 && floor < 0.024, "Companion does not meet the sand: \(companion)")
            if companion == .miniSubmarine {
                precondition(mesh.vertices.contains { $0.motion.w == 70 }, "Missing submarine propeller")
                let width = mesh.vertices.map(\.position.x).max()! - mesh.vertices.map(\.position.x).min()!
                precondition(width < 0.36, "Submarine must stay miniature")
                precondition(companion.isPremium && !companion.freeFallback.isPremium)
                var config = AquariumConfiguration.murano.sanitizedForFreeTier()
                config.companions = [.miniSubmarine]
                let decoded = try JSONDecoder().decode(AquariumConfiguration.self, from: JSONEncoder().encode(config))
                precondition(decoded.companions == [.miniSubmarine] && decoded.requiresPremiumUnlock)
                precondition(!decoded.sanitizedForFreeTier().requiresPremiumUnlock)
            }
            if companion == .seaUrchin {
                precondition(mesh.vertices.contains { $0.motion.w >= 80 && $0.motion.w < 85 }, "Missing urchin feet")
                precondition(mesh.vertices.contains { $0.motion.w >= 90 && $0.motion.w < 95 }, "Missing urchin spine articulation")
                precondition(companion.isPremium && !companion.freeFallback.isPremium)
                var config = AquariumConfiguration.murano.sanitizedForFreeTier()
                config.companions = [.seaUrchin]
                let decoded = try JSONDecoder().decode(AquariumConfiguration.self, from: JSONEncoder().encode(config))
                precondition(decoded.companions == [.seaUrchin] && decoded.requiresPremiumUnlock)
                precondition(!decoded.sanitizedForFreeTier().requiresPremiumUnlock)
            }
            if companion == .crab {
                precondition(Set(mesh.vertices.map(\.motion.w)).isSuperset(of: [10, 11, 12, 13, 14, 15, 30]), "Missing articulated crab legs/claws")
            }
            if companion == .shrimp {
                precondition(Set(mesh.vertices.map(\.motion.w)).isSuperset(of: [40, 41, 42, 43, 44, 45, 50, 60]), "Missing shrimp legs, antennae, or tail")
            }
        }
        for decoration in DecorationStyle.allCases {
            let mesh = AquariumCatalog.decoration(decoration)
            if decoration == .minimal { precondition(mesh.indices.isEmpty) }
            else { verify(mesh, name: decoration.rawValue) }
            if decoration == .coralGarden {
                let roseFloor = mesh.vertices.filter { $0.uv.z == 7 || $0.uv.z == 12 }.map(\.position.y).min()!
                let seafoamFloor = mesh.vertices.filter { $0.uv.z == 2 || $0.uv.z == 13 }.map(\.position.y).min()!
                precondition(abs(roseFloor - seafoamFloor) < 0.004,
                             "Coral colonies have mismatched ground contacts: \(roseFloor), \(seafoamFloor)")
            }
        }
        for feature in FeaturePieceStyle.allCases {
            let mesh = AquariumCatalog.feature(feature)
            if feature == .none { precondition(mesh.indices.isEmpty) }
            else { verify(mesh, name: feature.rawValue) }
        }
        for species in FishSpecies.allCases {
            var config = AquariumConfiguration.murano
            config.fishSpecies = species
            config.fishCount = .trio
            config.additionalFishSpecies = [.moonKoi, .opalAngelfish]
            config.companions = [.snail, .shrimp, .nudibranchRibbon]
            let decoded = try JSONDecoder().decode(AquariumConfiguration.self, from: JSONEncoder().encode(config))
            precondition(decoded == config && decoded.resolvedFishSpecies == [species, .moonKoi, .opalAngelfish])
        }
        let newFish: [FishSpecies] = [.moonStingray, .ribbonEel, .pearlSeahorse, .crystalPuffer,
            .sunburstButterfly, .mandarinDragonet, .blueTang, .glassSailfish, .leafySeaDragon]
        precondition(FishSpecies.allCases.count == 20 && newFish.count == 9)
        for fish in newFish {
            precondition(fish.isPremium && !fish.freeFallback.isPremium)
            var config = AquariumConfiguration.murano.sanitizedForFreeTier()
            config.fishSpecies = fish
            precondition(config.requiresPremiumUnlock)
            precondition(!config.sanitizedForFreeTier().requiresPremiumUnlock)
            config.fishSpecies = .moonKoi
            config.fishCount = .duet
            config.additionalFishSpecies = [fish]
            precondition(config.requiresPremiumUnlock)
            precondition(!config.sanitizedForFreeTier().resolvedFishSpecies.contains(fish))
            precondition(FishSpecies.caseDisplayRepresentations[fish] != nil)
        }
        for prop in [FeaturePieceStyle.pearlShell, .seaFan] {
            var config = AquariumConfiguration.murano.sanitizedForFreeTier()
            config.featurePiece = prop
            let decoded = try JSONDecoder().decode(AquariumConfiguration.self, from: JSONEncoder().encode(config))
            precondition(decoded.featurePiece == prop && decoded.requiresPremiumUnlock)
            precondition(!decoded.sanitizedForFreeTier().requiresPremiumUnlock)
            precondition(FeaturePieceStyle.caseDisplayRepresentations[prop] != nil)
        }
        // Keep the pre-existing migration for the retired, pre-glass seahorse ID.
        let legacySeahorse = try JSONDecoder().decode(FishSpecies.self, from: Data("\"seahorse\"".utf8))
        precondition(legacySeahorse == .moonKoi)
        var themeEncodings = Set<Data>()
        for theme in AquariumTheme.allCases {
            var config = AquariumConfiguration.murano
            config.theme = theme
            let encoded = try JSONEncoder().encode(config)
            themeEncodings.insert(encoded)
            let decoded = try JSONDecoder().decode(AquariumConfiguration.self, from: encoded)
            precondition(decoded == config && decoded.theme == theme, "Theme lost when saving")
            precondition(config.sanitizedForFreeTier().theme == theme, "Free-tier save loses theme")
            var legacy = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
            legacy.removeValue(forKey: "theme")
            let old = try JSONDecoder().decode(AquariumConfiguration.self, from: JSONSerialization.data(withJSONObject: legacy))
            precondition(old.theme == .ivory && old.fishSpecies == config.fishSpecies, "Old bowls no longer load")
            legacy["theme"] = "future-theme"
            let future = try JSONDecoder().decode(AquariumConfiguration.self, from: JSONSerialization.data(withJSONObject: legacy))
            precondition(future.theme == .ivory, "Unknown theme should preserve the bowl")
            let p = theme.palette
            for color in [p.lower, p.upper, p.key, p.fill] {
                for i in 0..<4 { precondition(color[i].isFinite && color[i] >= 0 && color[i] <= 1) }
            }
            precondition(p.blended(toward: AquariumTheme.ivory.palette, amount: 0) == p)
            let end = p.blended(toward: p, amount: 1)
            precondition(end == p)
        }
        precondition(themeEncodings.count == AquariumTheme.allCases.count, "Theme snapshots need distinct cache keys")
        print("PASS: all 8 theme save round trips, old and unknown-theme fallbacks, free-tier retention, distinct encoded cache identities, finite lighting colors")
        print("PASS: all \(FishSpecies.allCases.count) fish and their fins/eyes, \(CompanionStyle.allCases.count - 1) companions, every decoration/feature, glass normals/thickness, sand contacts, scaled feeding alignment, mixed-species save round trips")
    }
}
