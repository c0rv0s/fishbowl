import Foundation
import simd

/// A bounded viewing window into the tank, independent of the rendering framework.
struct AquariumDynamics {
    private(set) var time: Float = 0
    private(set) var swimTime: Float = 0
    private(set) var camera = SIMD2<Float>.zero
    private(set) var fish = SIMD3<Float>(0.12, 0.36, 0.25)
    private(set) var heading: Float = 0
    private(set) var feedingStarted: Float?
    private(set) var mealsConsumed = 0
    private(set) var lastMealTime: Float = -100
    private(set) var foodX: Float = 0
    private var feedingOrigin = SIMD3<Float>.zero
    private var feedingFacesRight = true
    var drag = SIMD2<Float>.zero
    var tilt = SIMD2<Float>.zero
    var motionEnabled = true
    var reduceMotion = false
    var mouthReach: Float = 0.445
    var mouthHeight: Float = 0
    var swimTempo: Float = 1

    var foodAge: Float? { feedingStarted.map { time - $0 } }
    var isFeeding: Bool { feedingStarted != nil }
    var foodPosition: SIMD3<Float>? {
        guard let age = foodAge else { return nil }
        return SIMD3(foodX, 1.48 - min(age, 3.6) * 0.31, 0.35)
    }

    @discardableResult
    mutating func feed(at normalizedX: Float) -> Bool {
        guard feedingStarted == nil, time - lastMealTime >= 3 else { return false }
        foodX = (min(max(normalizedX, 0.12), 0.88) - 0.5) * 1.75
        feedingStarted = time
        feedingOrigin = fish
        feedingFacesRight = foodX >= fish.x
        return true
    }

    mutating func recenter() {
        drag = .zero
        tilt = .zero
    }

    mutating func step(delta: Float) {
        guard delta.isFinite, delta > 0 else { return }
        let dt = min(delta, 1.0 / 15.0)
        time += dt
        swimTime += dt * swimTempo
        let desired = reduceMotion ? SIMD2<Float>.zero : drag + (motionEnabled ? tilt : .zero)
        let bounded = simd_clamp(desired, SIMD2(repeating: -1), SIMD2(repeating: 1))
        camera += (bounded - camera) * (1 - exp(-dt * 4.5))

        let previous = fish
        if let age = foodAge, let target = foodPosition {
            let t = min(age / 3.6, 1)
            let eased = t * t * (3 - 2 * t)
            let mouthOffset: Float = feedingFacesRight ? mouthReach : -mouthReach
            let destination = target - SIMD3(mouthOffset, mouthHeight, 0)
            fish = feedingOrigin + (destination - feedingOrigin) * eased
            if age >= 3.6 {
                mealsConsumed += 1
                lastMealTime = time
                feedingStarted = nil
            }
        } else {
            let target = SIMD3<Float>(-0.06 + sin(swimTime * 0.15) * 0.24,
                                      0.36 + sin(swimTime * 0.23) * 0.19,
                                      0.12 + sin(swimTime * 0.12) * 0.35)
            fish += (target - fish) * (1 - exp(-dt * 0.55))
        }
        let vx = (fish.x - previous.x) / dt
        let desiredHeading: Float = isFeeding ? (feedingFacesRight ? 0 : .pi)
            : (vx < -0.012 ? .pi : (vx > 0.012 ? 0 : heading))
        var difference = desiredHeading - heading
        while difference > .pi { difference -= 2 * .pi }
        while difference < -.pi { difference += 2 * .pi }
        heading += difference * (1 - exp(-dt * 1.45))
    }
}

enum AquariumParallax {
    static func drag(translation: SIMD2<Float>, viewport: SIMD2<Float>) -> SIMD2<Float> {
        // Equal finger travel should reveal equal depth on either axis, even on a tall phone.
        let distance = max(min(viewport.x, viewport.y) * 0.65, 1)
        return SIMD2(-translation.x, translation.y) / distance
    }

    static func tilt(relativeOrientation: simd_quatf) -> SIMD2<Float> {
        let direction = relativeOrientation.act(SIMD3<Float>(0, 0, 1))
        let fullTravelAngle: Float = 22 * .pi / 180
        return SIMD2(-atan2(direction.x, direction.z),
                      atan2(direction.y, hypot(direction.x, direction.z))) / fullTravelAngle
    }
}

enum AquariumCamera {
    private static let windowBottom = AquariumBowl.sandHeight + 0.14
    private static let windowCenterY: Float = 0.015

    static func widgetProjection(aspect: Float) -> simd_float4x4 {
        let halfWidth: Float = 1.65, halfHeight = halfWidth / max(aspect, 0.5)
        let near: Float = 0.1, far: Float = 30
        let projection = simd_float4x4(columns: (
            SIMD4(1 / halfWidth, 0, 0, 0), SIMD4(0, 1 / halfHeight, 0, 0),
            SIMD4(0, 0, 1 / (near - far), 0), SIMD4(0, 0, near / (near - far), 1)))
        return projection * lookAt(eye: SIMD3(0, 0, 8), target: .zero)
    }

    static func lightViewProjection() -> simd_float4x4 {
        let r: Float = 3.5, near: Float = 0.1, far: Float = 18
        let projection = simd_float4x4(columns: (SIMD4(1/r, 0, 0, 0), SIMD4(0, 1/r, 0, 0),
                                                SIMD4(0, 0, 1/(near-far), 0), SIMD4(0, 0, near/(near-far), 1)))
        return projection * lookAt(eye: SIMD3(3.3, 6.0, 3.9), target: SIMD3(0, 0, 0))
    }

    static func position(offset: SIMD2<Float>, aspect: Float = 0.46, preview: Bool = false) -> SIMD3<Float> {
        if preview { return SIMD3(offset.x * 0.64, 0.16 + offset.y * 0.64, 4.3) }

        // A round travel envelope makes combined pitch/yaw ease around the corners.
        let travel = offset / max(1, simd_length(offset))
        let eyeY = 0.16 + travel.y * 0.90
        let eyeZ: Float = 4.3
        let halfWidth = (windowCenterY - windowBottom) * max(aspect, 0.25)

        // Find the furthest sideways viewpoint whose bottom rays still land on sand.
        // This lets a tall phone reveal much more of the curved interior without
        // exposing the glass underneath, including while looking diagonally down.
        let beyondWindow = (AquariumBowl.sandHeight - windowBottom) / (windowBottom - eyeY)
        let floorZ = AquariumBowl.frontCut + (AquariumBowl.frontCut - eyeZ) * beyondWindow
        let sectionY = (AquariumBowl.sandHeight - AquariumBowl.center.y) / AquariumBowl.radii.y
        let sectionZ = (floorZ - AquariumBowl.center.z) / AquariumBowl.radii.z
        let sandHalfWidth = AquariumBowl.radii.x * sqrt(max(0, 1 - sectionY * sectionY - sectionZ * sectionZ)) * 0.985
        let sideTravel = min(1.80, max(0, (sandHalfWidth - halfWidth * (1 + beyondWindow)) / beyondWindow))
        return SIMD3(travel.x * sideTravel, eyeY, eyeZ)
    }

    static func viewProjection(aspect: Float, offset: SIMD2<Float>, preview: Bool = false, focusY: Float? = nil) -> simd_float4x4 {
        // An off-axis projection keeps the flat front window fixed as the viewer moves.
        // The curved bowl behind that window is what reveals more of its sides.
        let eye = position(offset: offset, aspect: aspect, preview: preview)
        let distance = eye.z - AquariumBowl.frontCut
        // Keep the opening inside the sand bed so its front cut stays below the screen,
        // including at the limits of vertical and diagonal parallax.
        let floorLimit = windowBottom
        let safeAspect = max(aspect, 0.25)
        let halfWidth = preview ? min((windowCenterY - floorLimit) * safeAspect, 1.05) : (windowCenterY - floorLimit) * safeAspect
        let halfHeight = halfWidth / safeAspect
        // Wider studio cards crop into the aquarium instead of revealing its outside.
        // Habitat focus stops at the same flush sand boundary as the full-screen view.
        let requestedCenter: Float = focusY ?? (safeAspect > 1.15 ? 0.22 : floorLimit + halfHeight)
        let windowCenterY: Float = preview ? max(floorLimit + halfHeight, requestedCenter) : Self.windowCenterY
        let windowBottom = windowCenterY - halfHeight
        let near: Float = 0.05, far: Float = 30
        let left = (-halfWidth - eye.x) * near / distance
        let right = (halfWidth - eye.x) * near / distance
        let bottom = (windowBottom - eye.y) * near / distance
        let top = (windowCenterY + halfHeight - eye.y) * near / distance
        let depth = far / (near - far)
        let projection = simd_float4x4(columns: (
            SIMD4(2 * near / (right - left), 0, 0, 0),
            SIMD4(0, 2 * near / (top - bottom), 0, 0),
            SIMD4((right + left) / (right - left), (top + bottom) / (top - bottom), depth, -1),
            SIMD4(0, 0, near * depth, 0)))
        return projection * lookAt(eye: eye, target: eye + SIMD3(0, 0, -1))
    }

    static func perspective(fov: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
        let y = 1 / tan(fov / 2)
        let z = far / (near - far)
        return simd_float4x4(columns: (SIMD4(y / aspect, 0, 0, 0), SIMD4(0, y, 0, 0),
                                       SIMD4(0, 0, z, -1), SIMD4(0, 0, z * near, 0)))
    }

    static func lookAt(eye: SIMD3<Float>, target: SIMD3<Float>) -> simd_float4x4 {
        let z = simd_normalize(eye - target)
        let x = simd_normalize(simd_cross(SIMD3(0, 1, 0), z))
        let y = simd_cross(z, x)
        return simd_float4x4(columns: (SIMD4(x.x, y.x, z.x, 0), SIMD4(x.y, y.y, z.y, 0),
                                       SIMD4(x.z, y.z, z.z, 0), SIMD4(-simd_dot(x, eye), -simd_dot(y, eye), -simd_dot(z, eye), 1)))
    }

    static func model(position: SIMD3<Float>, yaw: Float = 0, scale: Float = 1) -> simd_float4x4 {
        var m = simd_float4x4(simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0)))
        m.columns.0 *= scale
        m.columns.1 *= scale
        m.columns.2 *= scale
        m.columns.3 = SIMD4(position, 1)
        return m
    }
}
