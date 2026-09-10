import Foundation
import simd

@main
struct AquariumFeaturePairsCheck {
    static func main() throws {
        let encoder = JSONEncoder(), decoder = JSONDecoder()
        var config = AquariumConfiguration.murano
        config.featurePieces = [.seaFan, .pearlShell]
        let decoded = try decoder.decode(AquariumConfiguration.self, from: encoder.encode(config))
        precondition(decoded == config)
        precondition(config.detailLine.contains("Sea Fan") && config.detailLine.contains("Pearl Shell"))
        var legacy = try JSONSerialization.jsonObject(with: encoder.encode(config)) as! [String: Any]
        legacy.removeValue(forKey: "featurePieces")
        let migrated = try decoder.decode(AquariumConfiguration.self, from: JSONSerialization.data(withJSONObject: legacy))
        precondition(migrated.resolvedFeaturePieces == [.seaFan], "Legacy bowl lost its feature")
        legacy["featurePieces"] = ["unknown", "none", "pearlShell", "seaFan", "kelp"]
        let repaired = try decoder.decode(AquariumConfiguration.self, from: JSONSerialization.data(withJSONObject: legacy))
        precondition(repaired.resolvedFeaturePieces == [.pearlShell, .seaFan], "Unknown pieces or limit mishandled")
        config.setFeature(.none, at: 0)
        precondition(config.resolvedFeaturePieces == [.pearlShell], "Removing one piece removed the other")
        config.setFeature(.moonLantern, at: 1)
        precondition(config.resolvedFeaturePieces == [.pearlShell, .moonLantern])
        config.featurePiece = .seaFan
        precondition(config.resolvedFeaturePieces == [.seaFan], "Legacy setter must replace the selection")
        config = config.sanitizedForFreeTier()
        config.featurePieces = [.bubbleStone, .bubbleStone]
        precondition(!config.requiresPremiumUnlock, "Two free pieces must remain available")
        precondition(config.sanitizedForFreeTier().resolvedFeaturePieces.count == 2)
        config.featurePieces = [.bubbleStone, .seaFan]
        precondition(config.requiresPremiumUnlock, "Second piece bypasses premium gating")
        var other = config
        other.featurePieces = [.bubbleStone, .pearlShell]
        let firstData = try encoder.encode(config), otherData = try encoder.encode(other)
        precondition(firstData != otherData, "Second piece missing from snapshot identity")

        func bounds(_ mesh: AquariumMeshData) -> (SIMD3<Float>, SIMD3<Float>) {
            var low = SIMD3<Float>(repeating: .infinity), high = -low
            for v in mesh.vertices { low = simd_min(low, v.position.xyz); high = simd_max(high, v.position.xyz) }
            return (low, high)
        }
        let options = FeaturePieceStyle.allCases.filter { $0 != .none }
        var count = 0
        for decoration in DecorationStyle.allCases {
            for (i, first) in options.enumerated() {
                for second in options.dropFirst(i) {
                    let layout = AquariumHabitatLayout(decoration: decoration, features: [first, second])
                    let reversed = AquariumHabitatLayout(decoration: decoration, features: [second, first])
                    precondition(layout.features.map(\.style) == reversed.features.map(\.style))
                    let camera = AquariumCamera.viewProjection(aspect: 0.46, offset: .zero)
                    for feature in layout.features {
                        for v in feature.piece.mesh.vertices {
                            let p = camera * v.position
                            precondition(abs(p.x / p.w) < 0.98, "Feature cropped at rest: \(first)/\(second)")
                        }
                    }
                    let meshes = [layout.decoration.mesh] + layout.features.map { $0.piece.mesh }
                    for mesh in meshes where !mesh.vertices.isEmpty {
                        for v in mesh.vertices {
                            precondition(AquariumBowl.contains(v.position.xyz), "Piece leaves bowl: \(decoration)/\(first)/\(second)")
                            precondition(abs(simd_length(v.normal.xyz) - 1) < 0.02)
                        }
                    }
                    for a in meshes.indices where !meshes[a].vertices.isEmpty {
                        for b in meshes.indices where b > a && !meshes[b].vertices.isEmpty {
                            let (al, ah) = bounds(meshes[a]), (bl, bh) = bounds(meshes[b])
                            let gap = max(max(bl.x - ah.x, al.x - bh.x), max(bl.z - ah.z, al.z - bh.z))
                            precondition(gap > 0.035, "Sculptures intersect or crowd each other: \(decoration)/\(first)/\(second)")
                        }
                    }
                    count += 1
                }
            }
        }
        print("PASS: \(count) feature pairs, separated footprints, bowl containment, stable ordering, legacy migration, two-slot editing, premium gates, save and cache identities")
    }
}
