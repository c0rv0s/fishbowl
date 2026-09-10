import Foundation
import simd

@main
struct AquariumWidgetCheck {
    static func main() {
        for (aspect, round): (Float, Bool) in [(1, true), (2.14, false), (1, false)] {
            let layout = AquariumWidgetLayout(aspect: aspect, round: round)
            let projection = AquariumCamera.widgetProjection(aspect: aspect)
            func projected(_ p: SIMD4<Float>) -> SIMD2<Float> {
                let q = projection * p
                precondition(abs(q.w - 1) < 0.0001, "Widget must use orthographic projection")
                return SIMD2(q.x, q.y)
            }
            for depth: Float in [-1, 0, 1] {
                let p = projected(SIMD4(0.4, 0.2, depth, 1))
                precondition(simd_distance(p, projected(SIMD4(0.4, 0.2, 0, 1))) < 0.00001,
                             "Depth must not change the widget position or scale")
            }
            for species in FishSpecies.allCases {
                var mesh = AquariumCatalog.body(species)
                mesh.append(AquariumCatalog.fins(species)); mesh.append(AquariumCatalog.features(species))
                for count in 1...3 {
                    for index in 0..<count {
                        let model = layout.fishModel(species, index: index, count: count, baby: false)
                        for vertex in mesh.vertices {
                            let p = projected(model * vertex.position)
                            precondition(abs(p.x) < 0.94 && abs(p.y) < 0.94, "Cropped fish: \(species)")
                            if round { precondition(simd_length(p) < 0.94, "Fish crosses round widget edge: \(species)") }
                        }
                    }
                }
            }
            for decoration in DecorationStyle.allCases {
                let options = FeaturePieceStyle.allCases.filter { $0 != .none }
                let selections: [[FeaturePieceStyle]] = [[]] + options.map { [$0] }
                    + options.enumerated().flatMap { i, first in options.dropFirst(i).map { [first, $0] } }
                for selection in selections {
                    let habitat = AquariumHabitatLayout(decoration: decoration, features: selection)
                    let hasDecoration = !habitat.decoration.mesh.indices.isEmpty
                    let meshes = (hasDecoration ? [habitat.decoration.mesh] : []) + habitat.features.map { $0.piece.mesh }
                    for (index, mesh) in meshes.enumerated() {
                        let model = selection.count == 2
                            ? layout.pairedPropModel(mesh, index: index, hasDecoration: hasDecoration)
                            : layout.propModel(mesh, feature: !hasDecoration || index > 0)
                        for vertex in mesh.vertices {
                            let world = model * vertex.position
                            if world.y < layout.sandY { continue }
                            let p = projected(world)
                            precondition(abs(p.x) < 0.94 && abs(p.y) < 0.94, "Cropped habitat: \(selection)")
                            if round { precondition(simd_length(p) < 0.94, "Habitat crosses round widget edge: \(selection)") }
                        }
                    }
                }
            }
            for style in CompanionStyle.allCases where style != .none {
                for index in 0..<3 {
                    let model = layout.companionModel(style, index: index, count: 3)
                    for vertex in AquariumCatalog.companion(style).vertices {
                        let p = projected(model * vertex.position)
                        precondition(abs(p.x) < 0.94 && abs(p.y) < 0.94, "Cropped companion: \(style)")
                        if round { precondition(simd_length(p) < 0.94, "Companion crosses round widget edge") }
                    }
                }
            }
        }
        print("PASS: depth-independent straight-on projection, all \(FishSpecies.allCases.count) fish at every population, all props and all friends fit the three widget layouts")
    }
}
