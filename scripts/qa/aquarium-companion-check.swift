import Foundation
import simd

@main
struct AquariumCompanionCheck {
    static func main() {
        let started = Date()
        let styles = CompanionStyle.allCases.filter { $0 != .none }
        for decoration in DecorationStyle.allCases {
            let options = FeaturePieceStyle.allCases.filter { $0 != .none }
            let selections: [[FeaturePieceStyle]] = [[]] + options.map { [$0] }
                + options.enumerated().flatMap { i, first in options.dropFirst(i).map { [first, $0] } }
            for features in selections {
                let feature = features.map(\.rawValue).joined(separator: "+")
                let habitat = AquariumCompanionHabitat(decoration: decoration, features: features)
                let walk = habitat.walkingRoute
                precondition(walk.length > 2, "Missing walking route: \(decoration), \(feature)")
                precondition(simd_distance(walk.contacts.first!.point, walk.contacts.last!.point) < 0.001)
                let peak = walk.contacts.map(\.point.y).max()!
                if decoration == .riverRocks {
                    let rockTop = habitat.layout.decoration.mesh.vertices.map(\.position.y).max()!
                    precondition(peak > rockTop - 0.10, "Never climbs the arranged tall rock: \(feature), \(peak), top \(rockTop)")
                }
                for arch in habitat.layout.features where arch.style == .driftwoodArch {
                    let center = arch.piece.position(SIMD3(0.35, -1.50, -0.52))
                    precondition(walk.contacts.contains {
                        abs($0.point.x - center.x) < 0.15 * arch.piece.scale
                            && abs($0.point.z - center.z) < 0.10
                            && $0.point.y < -1.30
                    }, "Does not pass under the arranged arch: \(decoration), \(feature)")
                }
                for i in 0..<600 {
                    let c = walk.contact(at: walk.length * Float(i) / 600)
                    precondition(AquariumBowl.contains(c.point), "Crawler left bowl")
                    precondition(simd_length(c.normal) > 0.99, "Invalid surface normal")
                    let sand = AquariumCompanionHabitat.sandContact(SIMD2(c.point.x, c.point.z))
                    let rock = habitat.solids.nearest(to: c.point, radius: 0.06)
                    let nearest = min(abs(sand.point.y - c.point.y), rock.map { simd_distance($0.point, c.point) } ?? 1)
                    // Feet can bridge a narrow gap between two stones.
                    precondition(nearest < 0.04, "Crawler floats off surface \(nearest), \(decoration), \(feature)")
                    let swimmer = habitat.swimmingRoute.contact(at: habitat.swimmingRoute.length * Float(i) / 600)
                    precondition(AquariumBowl.contains(swimmer.point), "Shrimp left bowl")
                    precondition(!habitat.solids.intersects(swimmer.point, radius: 0.15), "Shrimp intersects a prop: \(decoration), \(feature)")
                }
                for style in styles {
                    let first = habitat.pose(style: style, index: 0, time: 0)
                    let later = habitat.pose(style: style, index: 0, time: 30)
                    precondition(simd_distance(first.position, later.position) > 0.06, "Still companion: \(style)")
                    for i in 0..<160 {
                        let p = habitat.pose(style: style, index: 0, time: Float(i) * 2.7)
                        let m = p.model(scale: 1.12)
                        precondition(abs(simd_determinant(m) - pow(1.12, 3)) < 0.001, "Invalid orientation: \(style)")
                        precondition(p.position.x.isFinite && p.gait.isFinite)
                        if style == .miniSubmarine {
                            precondition(!habitat.solids.intersects(p.position, radius: 0.18), "Submarine hits habitat: \(decoration)/\(feature) at \(p.position)")
                            precondition(AquariumBowl.contains(p.position + p.normal * 0.25), "Submarine leaves the water")
                        }
                        if style == .snail {
                            let shell = (p.position - AquariumBowl.center) / AquariumBowl.radii
                            precondition(abs(simd_length(shell) - 1) < 0.004, "Snail lost glass contact")
                            precondition(p.position.x < -0.75, "Snail should start and remain on side glass")
                            precondition(simd_dot(p.normal, p.position - AquariumBowl.center) < 0, "Snail faces into glass")
                        }
                    }
                }
                print("PASS \(decoration.rawValue)/\(feature): \(walk.contacts.count) contacts, \(String(format: "%.2f", walk.length))m route, peak \(String(format: "%.2f", peak))")
            }
        }
        let habitat = AquariumCompanionHabitat(decoration: .riverRocks, feature: .driftwoodArch)
        var restingPatterns = Set<String>()
        for style in styles {
            var resting = 0, moving = 0
            var pattern = ""
            for second in 0..<180 {
                let a = habitat.pose(style: style, index: 0, time: Float(second))
                let b = habitat.pose(style: style, index: 0, time: Float(second) + 0.1)
                pattern += a.activity == 0 ? "0" : "1"
                if a.activity == 0 && b.activity == 0 {
                    resting += 1
                    precondition(simd_distance(a.position, b.position) < 0.0001, "Resting friend still travels: \(style)")
                }
                if a.activity > 0.9 { moving += 1 }
                let before = AquariumCompanionHabitat.rhythm(style: style, index: 0, time: Float(second))
                let after = AquariumCompanionHabitat.rhythm(style: style, index: 0, time: Float(second) + 0.001)
                precondition(abs(after.activity - before.activity) < 0.003, "Abrupt start/stop")
            }
            restingPatterns.insert(pattern)
            precondition(resting > 20 && moving > 20, "Missing rest or travel periods: \(style)")
        }
        precondition(restingPatterns.count >= 5, "Friends should rest independently")
        let snail = habitat.pose(style: .snail, index: 0, time: 0)
        let projected = AquariumCamera.viewProjection(aspect: 0.46, offset: .zero) * SIMD4(snail.position, 1)
        precondition(abs(projected.x / projected.w) < 0.94, "Default snail is off screen")
        let heights = habitat.swimmingRoute.contacts.map(\.point.y)
        precondition(heights.max()! - heights.min()! > 0.4, "Shrimp needs vertical swimming")
        // Reduced motion remains on the same route, and render frequency never
        // affects a pose because the route uses elapsed simulation time.
        for style in styles {
            let slow = habitat.pose(style: style, index: 0, time: 60, reduceMotion: true)
            let regular = habitat.pose(style: style, index: 0, time: 21)
            precondition(simd_distance(slow.position, regular.position) < 0.0001)
            let t30 = (0..<300).reduce(Float(0)) { t, _ in t + 1 / 30 }
            let t60 = (0..<600).reduce(Float(0)) { t, _ in t + 1 / 60 }
            precondition(simd_distance(habitat.pose(style: style, index: 0, time: t30).position,
                                       habitat.pose(style: style, index: 0, time: t60).position) < 0.001)
        }
        print("PASS: all habitat combinations, rock climbing, arch passage, shrimp/submarine clearance, visible snail attachment, independent rests, eased starts/stops, orientation, reduced motion and 30/60 fps. \(Date().timeIntervalSince(started))s")
    }
}
