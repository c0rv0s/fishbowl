import Foundation
import simd

@main
struct AquariumDynamicsCheck {
    static func main() {
        var scene = AquariumDynamics()
        scene.drag = SIMD2(100, -100)
        for _ in 0..<180 { scene.step(delta: 1.0 / 60) }
        precondition(abs(scene.camera.x) <= 1 && abs(scene.camera.y) <= 1, "Camera must stay inside its viewing window")
        precondition(scene.feed(at: 100), "First feed should be accepted")
        precondition(!scene.feed(at: 0), "A second tap must not stack feeding sequences")
        precondition(scene.foodX <= 0.67, "Food must stay inside the aquarium")
        for _ in 0..<240 { scene.step(delta: 1.0 / 60) }
        precondition(scene.mealsConsumed == 1 && !scene.isFeeding, "Food must be consumed exactly once")
        precondition(!scene.feed(at: 0.5), "Feeding cooldown must prevent immediate overfeeding")
        for _ in 0..<240 { scene.step(delta: 1.0 / 60) }
        precondition(scene.feed(at: 0.5), "Feeding should recover after cooldown")

        scene.reduceMotion = true
        for _ in 0..<180 { scene.step(delta: 1.0 / 60) }
        precondition(simd_length(scene.camera) < 0.0001, "Reduce Motion must stop camera movement")
        let before = scene.time
        scene.step(delta: .nan)
        precondition(scene.time == before, "Invalid timing must not poison the simulation")

        var sixty = AquariumDynamics(), thirty = AquariumDynamics()
        sixty.drag = SIMD2(0.6, 0.3); thirty.drag = sixty.drag
        for _ in 0..<60 { sixty.step(delta: 1.0 / 60) }
        for _ in 0..<30 { thirty.step(delta: 1.0 / 30) }
        precondition(simd_distance(sixty.camera, thirty.camera) < 0.00001, "Camera response must not depend on refresh rate")

        func projectedX(_ point: SIMD3<Float>, offset: Float) -> Float {
            let p = AquariumCamera.viewProjection(aspect: 0.46, offset: SIMD2(offset, 0)) * SIMD4(point, 1)
            return p.x / p.w
        }
        let near = abs(projectedX(SIMD3(0, 0, 0.7), offset: 1) - projectedX(SIMD3(0, 0, 0.7), offset: -1))
        let far = abs(projectedX(SIMD3(0, 0, -0.5), offset: 1) - projectedX(SIMD3(0, 0, -0.5), offset: -1))
        precondition(abs(near - far) > 0.1, "Objects at different depths must move independently behind the viewing window")
        func projectedY(_ point: SIMD3<Float>, offset: Float) -> Float {
            let p = AquariumCamera.viewProjection(aspect: 0.46, offset: SIMD2(0, offset)) * SIMD4(point, 1)
            return p.y / p.w
        }
        let nearVertical = abs(projectedY(SIMD3(0, 0, 0.7), offset: 1) - projectedY(SIMD3(0, 0, 0.7), offset: -1))
        let farVertical = abs(projectedY(SIMD3(0, 0, -0.5), offset: 1) - projectedY(SIMD3(0, 0, -0.5), offset: -1))
        precondition(abs(nearVertical - farVertical) > 0.05, "Up/down viewing must reveal visible depth")
        let frontPoint = SIMD3<Float>(0.3, 0.4, AquariumBowl.frontCut)
        let centerEye = AquariumCamera.position(offset: .zero)
        let sideEye = AquariumCamera.position(offset: SIMD2(1, 0))
        precondition(sideEye.x > 1.5, "A portrait phone must reveal substantially more of the sides than the old 0.64 travel")
        precondition(AquariumCamera.position(offset: SIMD2(0, 1)).y - centerEye.y > 0.85,
                     "Vertical tilt must also have room to look farther into the bowl")
        precondition(abs(projectedX(frontPoint, offset: 1) - projectedX(frontPoint, offset: -1)) < 0.00001, "The flat viewing window must stay fixed during horizontal tilt")
        precondition(abs(projectedY(frontPoint, offset: 1) - projectedY(frontPoint, offset: -1)) < 0.00001, "The flat viewing window must stay fixed during vertical tilt")
        for aspect: Float in [0.94, 1.3, 2.14] {
            let preview = AquariumCamera.viewProjection(aspect: aspect, offset: .zero, preview: true)
            let fishCenter = preview * SIMD4<Float>(0, 0.36, 0.2, 1)
            precondition(abs(fishCenter.x / fishCenter.w) < 1 && abs(fishCenter.y / fishCenter.w) < 1,
                         "The primary fish must remain visible in square and wide previews")
            let habitat = AquariumCamera.viewProjection(aspect: aspect, offset: .zero, preview: true, focusY: -1)
            let propCenter = habitat * SIMD4<Float>(0, -1.15, 0.2, 1)
            precondition(abs(propCenter.y / propCenter.w) < 1, "Habitat editing must keep the props in view")
        }
        let drag = AquariumParallax.drag(translation: SIMD2(100, 100), viewport: SIMD2(393, 852))
        precondition(abs(drag.x + drag.y) < 0.00001, "Equal finger travel must give equal parallax on both axes")
        let yaw = AquariumParallax.tilt(relativeOrientation: simd_quatf(angle: .pi / 12, axis: SIMD3(0, 1, 0)))
        let pitch = AquariumParallax.tilt(relativeOrientation: simd_quatf(angle: .pi / 12, axis: SIMD3(1, 0, 0)))
        precondition(abs(yaw.x - pitch.y) < 0.00001 && abs(pitch.y) > 0.6, "Pitch and yaw must have equal sensitivity")
        precondition(abs(yaw.y) < 0.00001 && abs(pitch.x) < 0.00001, "Tilt axes must be independent")
        let floor = AquariumGeometry.sand()
        precondition(floor.vertices.allSatisfy { AquariumBowl.contains($0.position.xyz) }, "The sand bed must stay inside the rounded bowl")
        precondition(floor.vertices.allSatisfy { $0.normal.y > 0.9 }, "The curved sand bed must face the aquarium light")
        for aspect: Float in [0.45, 0.46, 0.50] {
            for horizontal in stride(from: Float(-1), through: 1, by: 0.1) {
                for vertical in stride(from: Float(-1), through: 1, by: 0.1) {
                    let offset = SIMD2(horizontal, vertical)
                    let eye = AquariumCamera.position(offset: offset, aspect: aspect)
                    let inverse = simd_inverse(AquariumCamera.viewProjection(aspect: aspect, offset: offset))
                    for column in 0...10 {
                        let p = inverse * SIMD4(Float(column) / 5 - 1, -1, 0.5, 1)
                        let ray = simd_normalize(p.xyz / p.w - eye)
                        let hit = eye + ray * ((AquariumBowl.sandHeight - eye.y) / ray.y)
                        precondition(AquariumBowl.contains(hit, tolerance: 0), "The bottom screen edge must meet the sand through the full tilt range")
                    }
                }
            }
        }
        let glass = AquariumGeometry.bowlGlass()
        precondition(glass.vertices.allSatisfy { abs(simd_length_squared(($0.position.xyz - AquariumBowl.center) / AquariumBowl.radii) - 1) < 0.001 }, "The glass must form a continuous rounded shell")
        precondition(glass.vertices.allSatisfy { $0.position.z <= AquariumBowl.frontCut + 0.001 }, "The rounded glass must end at the flat viewing cut")
        precondition(glass.vertices.allSatisfy { simd_dot($0.normal.xyz, $0.position.xyz - AquariumBowl.center) < 0 }, "Glass normals must face into the bowl")
        let cane = AquariumGeometry.glassTube(seed: 0, radius: 0.005, rows: 40) { SIMD3(0, $0, 0) }
        let caneMiddle = cane.vertices.filter { abs($0.uv.y - 0.5) < 0.001 }
        precondition(caneMiddle.allSatisfy { abs($0.normal.y) < 0.2 }, "Fine glass reeds must retain radial normals for their highlights")
        for mesh in [AquariumGeometry.rocks(), floor, AquariumGeometry.bowlGlass(), AquariumGeometry.fishBody(), AquariumGeometry.fishFins(), AquariumGeometry.fishFeatures(), AquariumGeometry.plants(), AquariumGeometry.bubbles()] {
            precondition(mesh.indices.allSatisfy { Int($0) < mesh.vertices.count }, "Geometry indices must be valid")
            precondition(mesh.vertices.allSatisfy {
                $0.position.x.isFinite && $0.position.y.isFinite && $0.position.z.isFinite
                    && $0.normal.x.isFinite && $0.normal.y.isFinite && $0.normal.z.isFinite
            }, "Geometry must remain finite")
        }
        print("PASS: camera bounds, horizontal/vertical depth parallax, pitch/yaw mapping, equal drag sensitivity, refresh-rate independence, feeding/cooldown, Reduce Motion, finite indexed geometry")
    }
}
