import Foundation
import simd

extension AquariumConfiguration {
    static let murano = AquariumConfiguration(vesselStyle: .orb, fishSpecies: .sunsetRasbora,
        fishCount: .solo, companion: .none, substrate: .pearlSand, decoration: .riverRocks, featurePiece: .kelp,
        theme: .lagoon)
}

extension FishSpecies {
    /// Explicit shader identifiers keep persisted catalog order independent of rendering.
    var glassID: Float {
        switch self {
        case .royalBetta: 0
        case .moonKoi: 1
        case .sunsetRasbora: 2
        case .glassGold: 3
        case .neonGuppy: 4
        case .emberTetra: 5
        case .opalAngelfish: 6
        case .leopardShark: 7
        case .velvetDiscus: 8
        case .silverArowana: 9
        case .humpbackWhale: 10
        case .moonStingray: 11
        case .ribbonEel: 12
        case .pearlSeahorse: 13
        case .crystalPuffer: 14
        case .sunburstButterfly: 15
        case .mandarinDragonet: 16
        case .blueTang: 17
        case .glassSailfish: 18
        case .leafySeaDragon: 19

        }
    }

    var glassProportions: SIMD3<Float> {
        switch self {
        case .royalBetta: SIMD3(0.91, 1.00, 0.91)
        case .moonKoi: SIMD3(1.06, 1.08, 1.06)
        case .sunsetRasbora: SIMD3(1, 1.12, 1.08)
        case .glassGold: SIMD3(0.88, 1.25, 1.16)
        case .neonGuppy: SIMD3(0.82, 0.83, 0.78)
        case .emberTetra: SIMD3(0.92, 0.78, 0.80)
        case .opalAngelfish: SIMD3(0.79, 1.72, 0.80)
        case .leopardShark: SIMD3(1.25, 0.73, 0.90)
        case .velvetDiscus: SIMD3(0.77, 1.83, 0.85)
        case .silverArowana: SIMD3(1.38, 0.72, 0.88)
        case .humpbackWhale: SIMD3(1.34, 1.18, 1.45)
        case .moonStingray, .ribbonEel, .pearlSeahorse, .crystalPuffer: SIMD3(1, 1, 1)
        case .sunburstButterfly: SIMD3(0.73, 1.96, 0.78)
        case .mandarinDragonet: SIMD3(1.05, 0.94, 1.12)
        case .blueTang: SIMD3(0.86, 1.62, 0.90)
        case .glassSailfish: SIMD3(1.26, 0.78, 0.86)
        case .leafySeaDragon: SIMD3(1, 1, 1)
        }
    }

    /// Local mouth position keeps feeding aligned for upright and long-snouted fish.
    var glassMouth: SIMD3<Float> {
        switch self {
        case .moonStingray: SIMD3(0.50, -0.025, 0)
        case .ribbonEel: SIMD3(0.558, 0, 0)
        case .pearlSeahorse: SIMD3(0.250, 0.351, 0)
        case .crystalPuffer: SIMD3(0.402, 0.005, 0)
        case .glassSailfish: SIMD3(0.85, 0.005, 0)
        case .leafySeaDragon: SIMD3(0.58, 0.25, 0)
        default: SIMD3(0.533, 0, 0)
        }
    }

    var glassScale: Float {
        switch self {
        case .moonStingray: 0.53
        case .ribbonEel: 0.49
        case .pearlSeahorse: 0.64
        case .crystalPuffer: 0.90
        case .glassSailfish: 0.60
        case .leafySeaDragon: 0.64
        case .mandarinDragonet: 0.74
        case .neonGuppy, .emberTetra: 0.78
        case .sunsetRasbora: 0.77
        case .silverArowana: 0.56
        case .leopardShark, .humpbackWhale: 0.59
        default: 0.84
        }
    }
}

extension AquariumMeshData {
    func transformed(_ transform: (SIMD3<Float>) -> SIMD3<Float>) -> AquariumMeshData {
        var result = self
        for i in result.vertices.indices { result.vertices[i].position = SIMD4(transform(vertices[i].position.xyz), 1) }
        result.recalculateNormals()
        // A transform can change winding locally at a seam. Preserve the original hemisphere.
        for i in result.vertices.indices {
            if simd_dot(result.vertices[i].normal.xyz, vertices[i].normal.xyz) < 0 { result.vertices[i].normal *= -1 }
        }
        return result
    }

    func glassTint(_ tint: Float) -> AquariumMeshData {
        var result = self
        for i in result.vertices.indices { result.vertices[i].uv.z = tint }
        return result
    }
}

/// The widget projects the same sculptures face-on, with a compact composition
/// that keeps the habitat visible at every widget aspect ratio.
struct AquariumWidgetLayout {
    let aspect: Float
    let round: Bool
    var halfWidth: Float { 1.65 }
    var halfHeight: Float { halfWidth / max(aspect, 0.5) }
    var sandY: Float { -halfHeight * 0.73 }
    var habitatBurial: Float { halfHeight * 0.01 }

    private func bounds(_ mesh: AquariumMeshData) -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        var low = SIMD3<Float>(repeating: .infinity), high = -low
        for vertex in mesh.vertices {
            low = simd_min(low, vertex.position.xyz); high = simd_max(high, vertex.position.xyz)
        }
        return (low, high)
    }

    func propModel(_ mesh: AquariumMeshData, feature: Bool) -> simd_float4x4 {
        guard !mesh.vertices.isEmpty else { return matrix_identity_float4x4 }
        let box = bounds(mesh), width = max(0.01, box.max.x - box.min.x)
        let height = max(0.01, box.max.y - box.min.y)
        let scale = min(0.96, min(halfHeight * 0.66 / height, (round ? 0.88 : 1.15) / width))
        let centerX = (box.min.x + box.max.x) * 0.5
        let targetX = halfWidth * (round ? 0.31 : 0.47) * (feature ? 1 : -1)
        return AquariumCamera.model(position: SIMD3(targetX - centerX * scale,
            sandY - habitatBurial - box.min.y * scale, -0.60), scale: scale)
    }

    func pairedPropModel(_ mesh: AquariumMeshData, index: Int, hasDecoration: Bool) -> simd_float4x4 {
        guard !mesh.vertices.isEmpty else { return matrix_identity_float4x4 }
        let box = bounds(mesh)
        let width = max(0.01, box.max.x - box.min.x)
        let height = max(0.01, box.max.y - box.min.y)
        let targetX: Float
        if hasDecoration {
            targetX = Float(index - 1) * (round ? 0.67 : 0.94)
        } else {
            targetX = (Float(index) - 0.5) * (round ? 1.06 : 1.42)
        }
        let widthLimit: Float = hasDecoration ? (round ? 0.57 : 0.80) : (round ? 0.86 : 1.10)
        let scale = min(1.12, min(widthLimit / width, halfHeight * 0.62 / height))
        return AquariumCamera.model(position: SIMD3(targetX - (box.min.x + box.max.x) * 0.5 * scale,
            sandY - habitatBurial - box.min.y * scale, -0.60), scale: scale)
    }

    func fishModel(_ species: FishSpecies, index: Int, count: Int, baby: Bool,
                   knownBounds: (min: SIMD3<Float>, max: SIMD3<Float>)? = nil) -> simd_float4x4 {
        let box = knownBounds ?? {
            var mesh = AquariumCatalog.body(species); mesh.append(AquariumCatalog.fins(species))
            return bounds(mesh)
        }()
        let width = max(0.01, box.max.x - box.min.x), height = max(0.01, box.max.y - box.min.y)
        let span: Float = count == 1 ? 1.70 : (count == 2 ? 1.12 : 0.94)
        var scale = min(span / width, halfHeight * (count == 1 ? 0.65 : 0.45) / height)
        if species == .pearlSeahorse { scale *= 0.82 }
        if baby { scale *= 0.55 }
        let anchors: [SIMD2<Float>] = count == 1 ? [SIMD2(0.04, 0.22)]
            : (count == 2 ? [SIMD2(-0.23, 0.40), SIMD2(0.26, -0.03)]
               : [SIMD2(-0.25, 0.49), SIMD2(0.29, 0.16), SIMD2(-0.06, -0.17), SIMD2(0.39, -0.33)])
        let anchor = anchors[min(index, anchors.count - 1)]
        let direction: Float = index.isMultiple(of: 2) ? -1 : 1
        let center = (box.min + box.max) * 0.5
        return AquariumCamera.model(position: SIMD3(anchor.x * halfWidth - center.x * scale * direction,
            anchor.y * halfHeight - center.y * scale, 0.25 + Float(index) * 0.08),
            yaw: direction < 0 ? .pi : 0, scale: scale)
    }

    func companionModel(_ style: CompanionStyle, index: Int, count: Int,
                        knownBounds: (min: SIMD3<Float>, max: SIMD3<Float>)? = nil) -> simd_float4x4 {
        let scale = min(1.1, halfHeight * 1.20) * (count > 1 ? 0.80 : 1)
        let swimming = style == .shrimp || style == .miniSubmarine
        let x = style == .snail ? -halfWidth * (round ? 0.43 : 0.64)
            : (count == 1 ? halfWidth * 0.11 : (-0.32 + Float(index) * 0.32) * halfWidth)
        let y: Float
        if swimming {
            y = -halfHeight * 0.28
        } else {
            let floor = (knownBounds ?? bounds(AquariumCatalog.companion(style))).min.y
            y = sandY - floor * scale
        }
        return AquariumCamera.model(position: SIMD3(x, y, 0.55), scale: scale)
    }
}

/// One arrangement supplies the visible sculptures, companion surfaces, and light positions.
struct AquariumHabitatPiece: Sendable {
    let mesh: AquariumMeshData
    let scale: Float
    let translation: SIMD3<Float>

    init(_ source: AquariumMeshData, scale: Float = 1, translation: SIMD3<Float> = .zero) {
        self.scale = scale; self.translation = translation
        var mesh = source
        if scale != 1 || translation != .zero {
            for i in mesh.vertices.indices {
                mesh.vertices[i].position = SIMD4(source.vertices[i].position.xyz * scale + translation, 1)
                mesh.vertices[i].uv.w *= scale
            }
        }
        self.mesh = mesh
    }

    func position(_ source: SIMD3<Float>) -> SIMD3<Float> { source * scale + translation }

    static func fitted(_ mesh: AquariumMeshData, at anchor: SIMD2<Float>, limits: SIMD3<Float>) -> Self {
        guard !mesh.vertices.isEmpty else { return .init(mesh) }
        var low = SIMD3<Float>(repeating: .infinity), high = -low
        for v in mesh.vertices { low = simd_min(low, v.position.xyz); high = simd_max(high, v.position.xyz) }
        let size = simd_max(high - low, SIMD3(repeating: 0.001))
        let scale = min(1, min(limits.x / size.x, min(limits.y / (high.y - AquariumBowl.sandHeight), limits.z / size.z)))
        let center = (low + high) * 0.5
        return .init(mesh, scale: scale, translation: SIMD3(anchor.x - center.x * scale,
            AquariumBowl.sandHeight * (1 - scale), anchor.y - center.z * scale))
    }
}

struct AquariumHabitatLayout: Sendable {
    let decoration: AquariumHabitatPiece
    let features: [(style: FeaturePieceStyle, piece: AquariumHabitatPiece)]

    init(decoration style: DecorationStyle, features selection: [FeaturePieceStyle]) {
        let selected = AquariumConfiguration.normalizedFeatures(selection)
        let decor = AquariumCatalog.decoration(style)
        guard selected.count == 2 else {
            decoration = .init(decor)
            features = selected.map { ($0, .init(AquariumCatalog.feature($0, decoration: style))) }
            return
        }
        // Tall pieces form a background; lower pieces sit off to the right.
        // Sorting by silhouette keeps the composition unchanged when slots are swapped.
        let order: [FeaturePieceStyle] = [.kelp, .seaFan, .driftwoodArch, .moonLantern, .pearlShell, .bubbleStone]
        let arranged = selected.sorted { order.firstIndex(of: $0)! < order.firstIndex(of: $1)! }
        decoration = .fitted(decor, at: SIMD2(-0.49, 0.25), limits: SIMD3(0.80, 0.57, 0.58))
        features = arranged.enumerated().map { index, feature in
            let lowPair = arranged.allSatisfy { $0 == .bubbleStone || $0 == .pearlShell }
            let broadPiece = feature == .kelp || feature == .seaFan || feature == .driftwoodArch
            let anchor: SIMD2<Float> = index == 0
                ? SIMD2(lowPair ? -0.10 : -0.43, -0.76)
                : SIMD2(broadPiece ? (feature == .driftwoodArch ? 0.30 : 0.34) : 0.46,
                        broadPiece ? -0.50 : -0.28)
            // Keep an arch wide enough for a crab to pass through its opening.
            let width: Float = feature == .driftwoodArch ? 0.84 : (lowPair ? 0.44 : (index == 0 ? 0.70 : 0.64))
            let limits = SIMD3<Float>(width,
                                       index == 0 ? 1.05 : 0.88, index == 0 ? 0.38 : 0.48)
            return (feature, .fitted(AquariumCatalog.feature(feature), at: anchor, limits: limits))
        }
    }
}

enum AquariumCatalog {
    static func fishPoint(_ p: SIMD3<Float>, species: FishSpecies) -> SIMD3<Float> {
        let shape = species.glassProportions
        var result = SIMD3(0.525 + (p.x - 0.525) * shape.x, p.y * shape.y, p.z * shape.z)
        if species == .humpbackWhale {
            let shoulder = exp(-pow((p.x - 0.14) * 5, 2))
            result.y += shoulder * 0.038
            result.z *= 1 + shoulder * 0.18
        }
        return result
    }

    static func body(_ species: FishSpecies) -> AquariumMeshData {
        if let sculpted = collectionBody(species) { return sculpted }
        var mesh = AquariumGeometry.fishBody().transformed { fishPoint($0, species: species) }
        for i in mesh.vertices.indices { mesh.vertices[i].uv.w *= species.glassProportions.z }
        return mesh
    }

    static func features(_ species: FishSpecies) -> AquariumMeshData {
        if let sculpted = collectionFeatures(species) { return sculpted }
        var mesh = AquariumGeometry.fishFeatures().transformed { fishPoint($0, species: species) }
        if species == .silverArowana {
            for z: Float in [-1, 1] {
                mesh.append(AquariumGeometry.glassFin(from: SIMD3(0.51, 0.005, z * 0.013),
                    to: SIMD3(0.558, 0.018, z * 0.025), width: 0.004, thickness: 0.003, seed: 2))
            }
        }
        return mesh
    }

    static func fins(_ species: FishSpecies) -> AquariumMeshData {
        if let sculpted = collectionFins(species) { return sculpted }
        if [.sunsetRasbora, .moonKoi, .emberTetra, .velvetDiscus, .silverArowana].contains(species) {
            return AquariumGeometry.fishFins(flowing: species == .sunsetRasbora).transformed { p in
                var point = p
                if species == .velvetDiscus, p.x < -0.29 { point.y *= 0.70 }
                if species == .silverArowana, p.x > -0.25 { point.y *= 0.82 }
                return fishPoint(point, species: species)
            }
        }

        var mesh = AquariumMeshData()
        let tailRoot = SIMD3<Float>(-0.245, 0.010, 0)
        if species == .leopardShark || species == .humpbackWhale {
            let whale = species == .humpbackWhale
            mesh.append(AquariumGeometry.fishFins().transformed { p in
                var point = p
                if p.x < -0.25 {
                    point.y *= whale ? 0.70 : 1.18
                    if whale {
                        let y = point.y - 0.01
                        point.y = y * 0.45 + 0.01
                        point.z += y * 1.5
                    }
                } else {
                    point.y *= 0.65
                }
                return point
            })
            mesh.append(AquariumGeometry.glassFin(from: SIMD3(-0.08, 0.08, 0),
                to: SIMD3(-0.22, whale ? 0.19 : 0.27, 0), width: whale ? 0.048 : 0.065, thickness: 0.014, seed: 1))
            for side: Float in [-1, 1] {
                mesh.append(AquariumGeometry.glassFin(from: SIMD3(0.24, -0.055, side * 0.07),
                    to: SIMD3(whale ? -0.10 : 0.02, whale ? -0.19 : -0.11, side * (whale ? 0.32 : 0.23)),
                    width: whale ? 0.047 : 0.046, thickness: 0.013, seed: 1))
            }
        } else {
            // Betta, guppy, and goldfish tails are broad, rounded fans of pulled glass.
            let spread: Float = species == .royalBetta ? 0.29 : (species == .neonGuppy ? 0.30 : 0.23)
            let length: Float = species == .royalBetta ? 0.44 : 0.39
            if species == .opalAngelfish {
                mesh.append(AquariumGeometry.fishFins().transformed { p in
                    var q = p
                    if p.x > -0.22 { q.y *= 1.12 }
                    else { q.y *= 0.75 }
                    return q
                })
            } else {
                mesh.append(AquariumGeometry.fanFin(seed: 0, thickness: 0.015) { u, v in
                    let angle = (u * 2 - 1) * Float.pi * 0.65
                    let edge = SIMD3<Float>(tailRoot.x - length * (0.48 + 0.52 * cos(angle)),
                                           0.01 + sin(angle) * spread, sin(u * .pi * 2) * 0.016)
                    return tailRoot + (edge - tailRoot) * v
                })
                mesh.append(AquariumGeometry.fanFin(seed: 1) { u, v in
                    let x = -0.21 + u * 0.53
                    let fin = pow(sin(u * .pi), 0.8)
                    return SIMD3(x - v * fin * 0.12, 0.06 + sin(u * .pi) * 0.08 + v * fin * 0.13, 0)
                })
                mesh.append(AquariumGeometry.fanFin(seed: 1) { u, v in
                    let fin = pow(sin(u * .pi), 0.8)
                    return SIMD3(-0.20 + u * 0.47 - v * fin * 0.10, -0.045 - fin * (0.05 + v * 0.085), 0)
                })
            }
            for side: Float in [-1, 1] {
                mesh.append(AquariumGeometry.glassFin(from: SIMD3(0.25, -0.015, side * 0.08),
                    to: SIMD3(0.11, -0.09, side * 0.13), width: 0.026, thickness: 0.007, seed: 2))
                if species == .opalAngelfish {
                    mesh.append(AquariumGeometry.glassTube(seed: 1, radius: 0.012, rows: 28, depthRatio: 0.6) { t in
                        SIMD3(0.17 - t * 0.17, -0.08 - t * 0.22, side * (0.03 + sin(t * .pi) * 0.016))
                    })
                }
            }
        }
        return mesh.transformed { fishPoint($0, species: species) }
    }

    static func decoration(_ style: DecorationStyle) -> AquariumMeshData {
        switch style {
        case .minimal: return AquariumMeshData()
        case .riverRocks: return AquariumGeometry.rocks()
        case .glassPearls:
            var mesh = AquariumMeshData()
            for (p, r, tint): (SIMD3<Float>, Float, Float) in [
                (SIMD3(-0.65, -1.23, -0.12), 0.27, 5),
                (SIMD3(-0.31, -1.32, 0.20), 0.18, 2),
                (SIMD3(-0.75, -1.36, 0.33), 0.14, 3)
            ] {
                mesh.append(AquariumGeometry.ellipsoid(center: p, radii: SIMD3(repeating: r), seed: tint))
            }
            return mesh
        case .coralGarden:
            return AquariumGeometry.coralGarden()
        }
    }

    static func feature(_ style: FeaturePieceStyle, decoration: DecorationStyle = .minimal) -> AquariumMeshData {
        switch style {
        case .none: return AquariumMeshData()
        case .pearlShell: return pearlShell()
        case .seaFan: return seaFan()
        case .kelp:
            let mesh = AquariumGeometry.plants()
            guard decoration == .coralGarden else { return mesh }
            return mesh.transformed { p in
                SIMD3(p.x + 0.95, -1.50 + (p.y + 1.50) * 0.88, p.z - 0.55)
            }
        case .bubbleStone:
            return AquariumGeometry.ellipsoid(center: SIMD3(0.40, -1.41, -0.33), radii: SIMD3(0.25, 0.105, 0.20), seed: 2, molten: true)
        case .driftwoodArch:
            var mesh = AquariumGeometry.glassTube(seed: 8, radius: 0.085, rows: 64, roundness: 0.16, taper: 0) { t in
                SIMD3(-0.02 + t * 0.74, -1.50 + sin(t * .pi) * 0.58, -0.52 + sin(t * .pi) * 0.04)
            }
            mesh.append(AquariumGeometry.glassTube(seed: 3, radius: 0.022, rows: 48, taper: 0) { t in
                SIMD3(-0.02 + t * 0.74, -1.50 + sin(t * .pi) * 0.56, -0.43)
            })
            return mesh
        case .moonLantern:
            var mesh = AquariumGeometry.ellipsoid(center: SIMD3(0.44, -1.41, -0.35), radii: SIMD3(0.19, 0.09, 0.15), seed: 8)
            mesh.append(AquariumGeometry.ellipsoid(center: SIMD3(0.44, -1.14, -0.35), radii: SIMD3(repeating: 0.20), seed: 10))
            mesh.append(AquariumGeometry.glassTube(seed: 5, radius: 0.018, rows: 32, taper: 0) { t in
                let a = t * Float.pi
                return SIMD3(0.44 + cos(a) * 0.24, -1.14 + sin(a) * 0.28, -0.35)
            })
            return mesh
        }
    }

    static func companion(_ style: CompanionStyle) -> AquariumMeshData {
        var mesh = AquariumMeshData()
        var joint = SIMD4<Float>.zero
        func append(_ part: AquariumMeshData) {
            var part = part
            for i in part.vertices.indices { part.vertices[i].motion = joint }
            mesh.append(part)
        }
        func oval(_ center: SIMD3<Float>, _ radii: SIMD3<Float>, _ tint: Float) {
            append(AquariumGeometry.ellipsoid(center: center, radii: radii, seed: tint, columns: 32, rows: 20))
        }
        func stem(_ from: SIMD3<Float>, _ to: SIMD3<Float>, _ bend: SIMD3<Float>, _ radius: Float, _ tint: Float) {
            append(AquariumGeometry.glassTube(seed: tint, radius: radius, rows: 28, roundness: 0.38, taper: 0.12) { t in
                from + (to - from) * t + bend * sin(t * .pi)
            })
        }
        switch style {
        case .none: break
        case .seaUrchin:
            mesh = seaUrchin()
        case .miniSubmarine:
            mesh = miniatureSubmarine().transformed { p in
                SIMD3((p.x - 0.30) * 0.50, (p.y + 1.50) * 0.50, (p.z + 0.26) * 0.50)
            }
            for i in mesh.vertices.indices where mesh.vertices[i].motion.w == 70 {
                mesh.vertices[i].motion = SIMD4(-0.15834, 0.0903, 0, 70)
            }
        case .snail:
            oval(SIMD3(0.02, 0.040, 0), SIMD3(0.17, 0.043, 0.065), 3)
            oval(SIMD3(-0.04, 0.15, 0), SIMD3(0.113, 0.132, 0.083), 6)
            for side: Float in [-1, 1] {
                mesh.append(AquariumGeometry.glassTube(seed: 3, radius: 0.010, rows: 80, taper: 0.50) { t in
                    let a = t * Float.pi * 4.6, r = 0.105 * (1 - t * 0.88)
                    return SIMD3(-0.04 + cos(a) * r, 0.15 + sin(a) * r, side * 0.079)
                })
            }
            for side: Float in [-1, 1] {
                let end = SIMD3<Float>(0.15, 0.135, side * 0.045)
                joint = SIMD4(0.105, 0.055, side * 0.025, 50)
                stem(SIMD3(0.105, 0.055, side * 0.025), end, SIMD3(-0.012, 0.01, 0), 0.008, 3)
                oval(end, SIMD3(repeating: 0.009), 11)
            }
        case .shrimp:
            stem(SIMD3(-0.14, 0.035, 0), SIMD3(0.12, 0.072, 0), SIMD3(0, 0.064, 0), 0.053, 7)
            for k: Float in [0, 1, 2, 3] {
                oval(SIMD3(-0.11 + k * 0.048, 0.065 + sin(k * 0.75) * 0.025, 0), SIMD3(0.035, 0.040, 0.049), k == 3 ? 7 : 3)
            }
            for side: Float in [-1, 1] {
                joint = .zero
                oval(SIMD3(0.119, 0.10, side * 0.033), SIMD3(repeating: 0.010), 11)
                joint = SIMD4(0.11, 0.09, side * 0.02, 50)
                stem(SIMD3(0.11, 0.09, side * 0.02), SIMD3(0.24, 0.11, side * 0.055), SIMD3(0, 0.045, 0), 0.005, 3)
                for k: Float in [0, 1, 2] {
                    joint = SIMD4(-0.04 + k * 0.05, 0.06, side * 0.018, 40 + k + (side > 0 ? 3 : 0))
                    stem(SIMD3(-0.04 + k * 0.05, 0.06, side * 0.018), SIMD3(-0.08 + k * 0.05, 0.014, side * 0.070), SIMD3(0.013, 0, side * 0.01), 0.006, 7)
                }
                joint = SIMD4(-0.12, 0.035, 0, 60)
                oval(SIMD3(-0.16, 0.025, side * 0.035), SIMD3(0.050, 0.011, 0.036), 3)
            }
        case .crab:
            oval(SIMD3(0, 0.068, 0), SIMD3(0.113, 0.064, 0.080), 4)
            for side: Float in [-1, 1] {
                for k: Float in [0, 1, 2] {
                    joint = SIMD4(side * 0.07, 0.05, -0.04 + k * 0.04, 10 + k + (side > 0 ? 3 : 0))
                    stem(SIMD3(side * 0.07, 0.05, -0.04 + k * 0.04), SIMD3(side * (0.18 - k * 0.017), 0.015, -0.07 + k * 0.064), SIMD3(side * 0.014, 0.025, 0), 0.011, 7)
                }
                joint = SIMD4(side * 0.08, 0.055, 0.045, 30)
                stem(SIMD3(side * 0.08, 0.055, 0.045), SIMD3(side * 0.16, 0.11, 0.105), SIMD3(0, 0.01, 0), 0.018, 4)
                oval(SIMD3(side * 0.155, 0.12, 0.12), SIMD3(0.043, 0.035, 0.033), 7)
                oval(SIMD3(side * 0.138, 0.146, 0.15), SIMD3(0.020, 0.019, 0.018), 3)
                joint = .zero
                oval(SIMD3(side * 0.041, 0.121, 0.055), SIMD3(repeating: 0.011), 11)
            }
        case .seaCucumber:
            oval(SIMD3(0, 0.059, 0), SIMD3(0.205, 0.058, 0.074), 1)
            for k: Float in [0, 1, 2, 3, 4] {
                oval(SIMD3(-0.14 + k * 0.064, 0.103, sin(k * 2) * 0.025), SIMD3(0.025, 0.013, 0.021), 2)
            }
        case .nudibranchFlame, .nudibranchRibbon:
            let ribbon = style == .nudibranchRibbon
            oval(SIMD3(0, 0.049, 0), SIMD3(0.17, 0.047, 0.071), ribbon ? 5 : 6)
            for side: Float in [-1, 1] {
                if ribbon {
                    stem(SIMD3(-0.14, 0.05, side * 0.055), SIMD3(0.15, 0.055, side * 0.050), SIMD3(0, 0.022, side * 0.023), 0.018, 3)
                    stem(SIMD3(-0.135, 0.085, side * 0.021), SIMD3(0.12, 0.08, side * 0.026), SIMD3(0, 0.008, 0), 0.009, 0)
                } else {
                    for k: Float in [0, 1, 2, 3, 4] {
                        let x = -0.11 + k * 0.048
                        stem(SIMD3(x, 0.059, side * 0.040), SIMD3(x - 0.02, 0.123 + sin(k) * 0.025, side * 0.063), SIMD3(-0.01, 0.005, side * 0.012), 0.020, 7)
                    }
                }
                stem(SIMD3(0.12, 0.067, side * 0.028), SIMD3(0.125, 0.14, side * 0.033), SIMD3(-0.015, 0, 0), 0.012, 3)
            }
        }
        return mesh
    }
}

// The second collection uses sculpted volumes, sealed fins and fine glass details.
// All coordinates remain local so the same models work in the bowl and widgets.
extension AquariumCatalog {
    private static func rayPoint(_ p: SIMD3<Float>) -> SIMD3<Float> {
        let angle: Float = -0.62
        return SIMD3(p.x, p.y * cos(angle) - p.z * sin(angle), p.y * sin(angle) + p.z * cos(angle))
    }

    private static func eelCenter(_ t: Float) -> SIMD3<Float> {
        SIMD3(0.47 - 1.64 * t, sin(t * .pi * 2.2) * 0.10, sin(t * .pi) * 0.025)
    }

    static func collectionBody(_ species: FishSpecies) -> AquariumMeshData? {
        switch species {
        case .leafySeaDragon: return leafyDragonBody()
        case .moonStingray:
            var mesh = AquariumGeometry.grid(columns: 80, rows: 48) { u, v in
                let theta = (0.0001 + v * 0.9998) * Float.pi
                let phi = u * 2 * Float.pi
                let breadth = pow(sin(theta), 1.7)
                let z = sin(phi) * breadth * 0.59
                let x = 0.07 + cos(theta) * 0.43 - abs(z) * 0.23
                return rayPoint(SIMD3(x, cos(phi) * sin(theta) * 0.057, z))
            }
            for i in mesh.vertices.indices { mesh.vertices[i].uv.w = 0.075 }
            mesh.append(AquariumGeometry.glassTube(seed: 0, radius: 0.033, rows: 72, roundness: 0.16, taper: 0.91) { t in
                rayPoint(SIMD3(-0.28 - t * 0.90, -0.012 + sin(t * .pi) * 0.045, sin(t * 4) * 0.065))
            })
            return mesh
        case .ribbonEel:
            var mesh = AquariumGeometry.glassTube(seed: 0, radius: 0.092, rows: 100, depthRatio: 0.83, roundness: 0.13, taper: 0.93, curve: eelCenter)
            mesh.append(AquariumGeometry.ellipsoid(center: SIMD3(0.43, 0, 0), radii: SIMD3(0.125, 0.067, 0.063)))
            return mesh
        case .pearlSeahorse:
            // The crown sits over the chest. A recessed throat and rounded belly
            // give the upright S silhouette, while retaining the compact tail curl.
            let segments: [[SIMD3<Float>]] = [
                [SIMD3(-0.024, 0.430, 0), SIMD3(-0.140, 0.434, 0), SIMD3(-0.166, 0.310, 0), SIMD3(-0.070, 0.205, 0)],
                [SIMD3(-0.070, 0.205, 0), SIMD3(0.026, 0.100, 0), SIMD3(0.00, -0.13, 0), SIMD3(-0.05, -0.21, 0)],
                [SIMD3(-0.05, -0.21, 0), SIMD3(-0.10, -0.29, 0), SIMD3(-0.15, -0.385, 0), SIMD3(-0.09, -0.46, 0)],
                [SIMD3(-0.09, -0.46, 0), SIMD3(-0.03, -0.535, 0), SIMD3(0.13, -0.52, 0), SIMD3(0.165, -0.43, 0)],
                [SIMD3(0.165, -0.43, 0), SIMD3(0.20, -0.34, 0), SIMD3(0.13, -0.285, 0), SIMD3(0.075, -0.315, 0)],
                [SIMD3(0.075, -0.315, 0), SIMD3(0.02, -0.345, 0), SIMD3(0.045, -0.40, 0), SIMD3(0.085, -0.385, 0)]
            ]
            let radii: [Float] = [0.063, 0.078, 0.048, 0.033, 0.024, 0.014, 0.0015]
            func center(_ t: Float) -> SIMD3<Float> {
                let value = min(t * 6, 5.9999), i = Int(value), v = value - Float(i), u = 1 - v
                let c = segments[i]
                return c[0] * (u * u * u) + c[1] * (3 * u * u * v)
                    + c[2] * (3 * u * v * v) + c[3] * (v * v * v)
            }
            func radius(_ t: Float) -> Float {
                let value = min(t * 6, 5.9999), i = Int(value), f = value - Float(i)
                let base = radii[i] + (radii[i + 1] - radii[i]) * (f * f * (3 - 2 * f))
                // Zero slope at both ends keeps the fuller belly smooth at the waist.
                return base + (i == 1 ? pow(sin(f * .pi), 2) * 0.062 : 0)
            }
            var mesh = AquariumGeometry.grid(columns: 48, rows: 240) { u, v in
                let t = 0.0001 + v * 0.9998
                let tangent = simd_normalize(center(min(t + 0.0005, 1)) - center(max(t - 0.0005, 0)))
                let side = simd_normalize(simd_cross(tangent, SIMD3<Float>(0, 0, 1)))
                let a = u * 2 * Float.pi, r = radius(t)
                return center(t) + side * (cos(a) * r) + SIMD3(0, 0, sin(a) * r * 0.86)
            }
            for i in mesh.vertices.indices {
                let t = 0.0001 + mesh.vertices[i].uv.y * 0.9998
                if simd_dot(mesh.vertices[i].normal.xyz, mesh.vertices[i].position.xyz - center(t)) < 0 {
                    mesh.vertices[i].normal *= -1
                }
                mesh.vertices[i].uv.w = radius(t) * 1.72
            }
            let head = AquariumGeometry.ellipsoid(center: .zero, radii: SIMD3(0.104, 0.068, 0.064))
            mesh.append(head.transformed { p in
                let angle: Float = -0.55
                return SIMD3(0.016 + p.x * cos(angle) - p.y * sin(angle),
                             0.412 + p.x * sin(angle) + p.y * cos(angle), p.z)
            })
            mesh.append(AquariumGeometry.glassTube(seed: 0, radius: 0.025, rows: 36, roundness: 0.09, taper: 0.18) { t in
                SIMD3(0.076 + t * 0.174, 0.394 - t * 0.043, 0)
            })
            mesh.append(AquariumGeometry.ellipsoid(center: SIMD3(-0.042, 0.467, 0), radii: SIMD3(0.036, 0.036, 0.029)))
            return mesh
        case .crystalPuffer:
            var mesh = AquariumGeometry.ellipsoid(center: SIMD3(0.065, 0.015, 0), radii: SIMD3(0.321, 0.267, 0.219))
            mesh.append(AquariumGeometry.ellipsoid(center: SIMD3(0.377, 0.005, 0), radii: SIMD3(0.025, 0.020, 0.025)))
            return mesh
        case .glassSailfish:
            var mesh = AquariumGeometry.fishBody().transformed { fishPoint($0, species: species) }
            for i in mesh.vertices.indices { mesh.vertices[i].uv.w *= species.glassProportions.z }
            mesh.append(AquariumGeometry.glassTube(seed: 0, radius: 0.021, rows: 48, roundness: 0.11, taper: 0.94) { t in
                SIMD3(0.49 + t * 0.36, 0.005, 0)
            })
            return mesh
        default: return nil
        }
    }

    static func collectionFeatures(_ species: FishSpecies) -> AquariumMeshData? {
        guard species.glassID >= 11 else { return nil }
        var mesh = AquariumMeshData()
        func eye(_ center: SIMD3<Float>, _ radius: Float, side: Float) {
            mesh.append(AquariumGeometry.ellipsoid(center: center, radii: SIMD3(repeating: radius), seed: 0, columns: 24, rows: 16))
            mesh.append(AquariumGeometry.ellipsoid(center: center + SIMD3(0.002, 0, side * radius * 0.57),
                radii: SIMD3(radius * 0.68, radius * 0.72, radius * 0.62), seed: 1, columns: 24, rows: 16))
        }
        for side: Float in [-1, 1] {
            switch species {
            case .moonStingray:
                let center = rayPoint(SIMD3(0.315, 0.050, side * 0.075))
                mesh.append(AquariumGeometry.ellipsoid(center: center, radii: SIMD3(repeating: 0.018), seed: 0, columns: 24, rows: 16))
                mesh.append(AquariumGeometry.ellipsoid(center: center + rayPoint(SIMD3(0, 0.012, 0)),
                    radii: SIMD3(repeating: 0.012), seed: 1, columns: 24, rows: 16))
            case .ribbonEel: eye(SIMD3(0.462, 0.027, side * 0.053), 0.014, side: side)
            case .pearlSeahorse: eye(SIMD3(0.060, 0.434, side * 0.050), 0.016, side: side)
            case .leafySeaDragon: eye(SIMD3(0.342, 0.285, side * 0.052), 0.016, side: side)
            case .crystalPuffer: eye(SIMD3(0.287, 0.107, side * 0.127), 0.027, side: side)
            default:
                eye(fishPoint(SIMD3(0.402, 0.051, side * 0.063), species: species), 0.017, side: side)
            }
        }
        // A small dark opening, flush with the snout instead of an orange bead.
        let mouth = species.glassMouth
        mesh.append(AquariumGeometry.ellipsoid(center: mouth - SIMD3(0.002, 0, 0),
            radii: SIMD3(0.003, species == .crystalPuffer ? 0.010 : 0.006, 0.009), seed: 1, columns: 24, rows: 16))
        return mesh
    }

    /// Rounded fan pulled from a single attachment; every edge has real thickness.
    private static func petal(root: SIMD3<Float>, end: SIMD3<Float>, spread: SIMD3<Float>, seed: Float = 1) -> AquariumMeshData {
        AquariumGeometry.fanFin(seed: seed, thickness: 0.012, goldRim: true) { u, v in
            let a = (u - 0.5) * Float.pi * 1.20
            return root + ((end - root) * (0.56 + cos(a) * 0.44) + spread * sin(a)) * v
        }
    }

    static func collectionFins(_ species: FishSpecies) -> AquariumMeshData? {
        guard species.glassID >= 11 else { return nil }
        var mesh = AquariumMeshData()
        switch species {
        case .leafySeaDragon: return leafyDragonFins()
        case .moonStingray:
            // Wing tips are thin extensions of the central lens, angled toward the viewer.
            for side: Float in [-1, 1] {
                mesh.append(AquariumGeometry.fanFin(seed: 1, thickness: 0.010, goldRim: true) { u, v in
                    let x = -0.35 + u * 0.79
                    let width = pow(sin(u * .pi), 1.35)
                    return rayPoint(SIMD3(x - v * width * 0.12, sin(u * .pi) * 0.007,
                                         side * width * (0.35 + v * 0.40)))
                })
            }
        case .ribbonEel:
            for side: Float in [-1, 1] {
                mesh.append(AquariumGeometry.fanFin(seed: 1, thickness: 0.009, goldRim: true) { u, v in
                    let center = eelCenter(u)
                    let radius = 0.070 * (1 - u * 0.87)
                    let fan = pow(sin(u * .pi), 0.8) * (side > 0 ? 0.085 : 0.043)
                    return center + SIMD3(-v * fan * 0.3, side * (radius + v * fan), 0)
                })
            }
        case .pearlSeahorse:
            func fin(root: SIMD3<Float>, end: SIMD3<Float>, spread: SIMD3<Float>) {
                var fin = petal(root: root, end: end, spread: spread)
                for i in fin.vertices.indices { fin.vertices[i].motion = SIMD4(root, 110) }
                mesh.append(fin)
            }
            fin(root: SIMD3(-0.130, 0.040, 0), end: SIMD3(-0.245, -0.005, 0), spread: SIMD3(0, 0.090, 0))
            for side: Float in [-1, 1] {
                fin(root: SIMD3(0.015, 0.372, side * 0.050), end: SIMD3(-0.025, 0.335, side * 0.085),
                    spread: SIMD3(0.021, 0.010, 0))
            }
        case .crystalPuffer:
            mesh.append(petal(root: SIMD3(-0.23, 0.02, 0), end: SIMD3(-0.49, 0.03, 0), spread: SIMD3(0, 0.14, 0)))
            for side: Float in [-1, 1] {
                mesh.append(petal(root: SIMD3(0.14, -0.05, side * 0.195), end: SIMD3(-0.045, -0.12, side * 0.32), spread: SIMD3(0, 0.075, 0)))
            }
            mesh.append(petal(root: SIMD3(-0.075, 0.235, 0), end: SIMD3(-0.19, 0.35, 0), spread: SIMD3(0.085, 0.025, 0)))
        case .sunburstButterfly, .blueTang:
            let butterfly = species == .sunburstButterfly
            mesh.append(petal(root: fishPoint(SIMD3(-0.24, 0.01, 0), species: species),
                end: SIMD3(butterfly ? -0.39 : -0.52, 0.012, 0), spread: SIMD3(0, butterfly ? 0.16 : 0.19, 0)))
            for side: Float in [-1, 1] {
                mesh.append(AquariumGeometry.fanFin(seed: 1, thickness: 0.013, goldRim: true) { u, v in
                    let belly = pow(sin(u * .pi), 0.7)
                    return SIMD3(-0.025 + u * 0.43 - v * belly * 0.13,
                        side * belly * ((butterfly ? 0.225 : 0.188) + v * (butterfly ? 0.135 : 0.075)), 0)
                })
                mesh.append(petal(root: SIMD3(0.295, -0.052, side * 0.065), end: SIMD3(0.07, -0.13, side * 0.15), spread: SIMD3(0.045, 0.07, 0)))
            }
        case .mandarinDragonet:
            mesh.append(petal(root: fishPoint(SIMD3(-0.24, 0.01, 0), species: species), end: SIMD3(-0.68, 0, 0), spread: SIMD3(0, 0.24, 0)))
            mesh.append(AquariumGeometry.fanFin(seed: 1, thickness: 0.014, goldRim: true) { u, v in
                let scallop = sin(u * .pi) * (0.88 + 0.12 * cos(u * .pi * 6))
                return SIMD3(-0.22 + u * 0.51 - v * scallop * 0.12, 0.064 + sin(u * .pi) * 0.070 + v * scallop * 0.20, 0)
            })
            for side: Float in [-1, 1] {
                mesh.append(petal(root: SIMD3(0.28, -0.035, side * 0.079), end: SIMD3(-0.09, -0.15, side * 0.24), spread: SIMD3(0.045, 0.13, 0)))
            }
        case .glassSailfish:
            mesh.append(AquariumGeometry.fanFin(seed: 1, thickness: 0.012, goldRim: true) { u, v in
                let sail = pow(sin(u * .pi), 0.58)
                return SIMD3(-0.46 + u * 0.80 - v * sail * 0.045, 0.032 + sail * (0.055 + v * 0.33), 0)
            })
            for side: Float in [-1, 1] {
                mesh.append(petal(root: SIMD3(-0.49, 0.008, 0), end: SIMD3(-0.82, side * 0.23, 0), spread: SIMD3(0.045, side * 0.032, 0)))
                mesh.append(petal(root: SIMD3(0.24, -0.045, side * 0.055), end: SIMD3(-0.15, -0.11, side * 0.22), spread: SIMD3(0.025, 0.033, 0)))
            }
        default: break
        }
        return mesh
    }

    static func miniatureSubmarine() -> AquariumMeshData {
        var mesh = AquariumMeshData()
        func oval(_ center: SIMD3<Float>, _ radii: SIMD3<Float>, _ tint: Float) {
            mesh.append(AquariumGeometry.ellipsoid(center: center, radii: radii, seed: tint, columns: 40, rows: 24))
        }
        // Small landing skids sit in the sand, leaving a little space under the hull.
        for side: Float in [-1, 1] {
            mesh.append(AquariumGeometry.glassTube(seed: 8, radius: 0.027, rows: 40, roundness: 0.2, taper: 0) { t in
                SIMD3(0.19 + t * 0.46, -1.468 + pow((t - 0.5) * 2, 4) * 0.05, -0.26 + side * 0.14)
            })
            for x: Float in [0.30, 0.55] {
                oval(SIMD3(x, -1.413, -0.26 + side * 0.13), SIMD3(0.024, 0.065, 0.024), 3)
            }
        }
        oval(SIMD3(0.43, -1.285, -0.26), SIMD3(0.355, 0.165, 0.172), 3)
        // Champagne collar and a clear turquoise nose lens.
        oval(SIMD3(0.69, -1.28, -0.26), SIMD3(0.070, 0.127, 0.137), 8)
        oval(SIMD3(0.739, -1.28, -0.26), SIMD3(0.065, 0.106, 0.119), 2)
        for side: Float in [-1, 1] {
            for x: Float in [0.30, 0.49] {
                oval(SIMD3(x, -1.267, -0.26 + side * 0.160), SIMD3(0.067, 0.068, 0.022), 8)
                oval(SIMD3(x, -1.267, -0.26 + side * 0.177), SIMD3(0.049, 0.050, 0.013), 2)
            }
        }
        oval(SIMD3(0.39, -1.115, -0.26), SIMD3(0.087, 0.085, 0.075), 3)
        mesh.append(AquariumGeometry.glassTube(seed: 8, radius: 0.024, rows: 40, roundness: 0.12, taper: 0) { t in
            let a = min(t * 1.5, 1)
            return SIMD3(0.39 + max(0, t - 0.55) * 0.14, -1.07 + sin(a * .pi / 2) * 0.15, -0.26)
        })
        oval(SIMD3(0.453, -0.92, -0.26), SIMD3(0.027, 0.025, 0.028), 2)
        oval(SIMD3(0.078, -1.285, -0.26), SIMD3(0.063, 0.035, 0.035), 8)
        // Three rounded propeller petals, readable as a little clockwork detail.
        for i in 0..<3 {
            let a = Float(i) * .pi * 2 / 3
            var blade = AquariumGeometry.glassFin(from: SIMD3(0.053, -1.285, -0.26),
                to: SIMD3(0.025, -1.285 + cos(a) * 0.114, -0.26 + sin(a) * 0.114),
                width: 0.038, thickness: 0.012, seed: 8)
            for j in blade.vertices.indices { blade.vertices[j].motion.w = 70 }
            mesh.append(blade)
        }
        return mesh.transformed { p in
            SIMD3(0.30 + (p.x - 0.43) * 0.84, -1.50 + (p.y + 1.50) * 0.84, -0.26 + (p.z + 0.26) * 0.84)
        }
    }

    static func pearlShell() -> AquariumMeshData {
        var mesh = AquariumMeshData()
        let hinge = SIMD3<Float>(0.43, -1.44, -0.44)
        // Two thick scalloped valves meet at a rear hinge; the top opens toward us.
        for lid in [false, true] {
            mesh.append(AquariumGeometry.fanFin(seed: 14, thickness: 0.027, goldRim: true) { u, v in
                let a = (u - 0.5) * Float.pi * 1.18
                let r = v * (0.94 + 0.06 * cos(u * .pi * 18))
                let x = sin(a) * r * 0.36
                let depth = cos(a) * r * 0.45
                let cup = sin(v * .pi) * 0.065
                return hinge + SIMD3(x, lid ? depth * 1.17 + cup : 0.024 - cup * 0.4, lid ? depth * 0.15 : depth)
            })
        }
        mesh.append(AquariumGeometry.ellipsoid(center: SIMD3(0.43, -1.34, -0.205), radii: SIMD3(repeating: 0.096), seed: 15))
        return mesh.transformed { p in
            SIMD3(0.30 + (p.x - 0.43) * 0.84, -1.50 + (p.y + 1.50) * 0.84, -0.26 + (p.z + 0.26) * 0.84)
        }
    }
}

extension AquariumCatalog {
    /// A sealed, round-tipped rod with a stable frame in every radial direction.
    private static func roundedGlassRod(from start: SIMD3<Float>, to end: SIMD3<Float>,
                                        radius: Float, tint: Float) -> AquariumMeshData {
        let center = (start + end) * 0.5
        let axis = simd_normalize(end - start), halfLength = simd_distance(start, end) * 0.5
        let reference = abs(axis.z) < 0.9 ? SIMD3<Float>(0, 0, 1) : SIMD3<Float>(0, 1, 0)
        let side = simd_normalize(simd_cross(axis, reference)), across = simd_cross(side, axis)
        var mesh = AquariumGeometry.grid(columns: 16, rows: 12) { u, v in
            let a = u * 2 * Float.pi, b = (0.0001 + v * 0.9998) * Float.pi
            return center + side * (sin(b) * cos(a) * radius) + axis * (cos(b) * halfLength)
                + across * (sin(b) * sin(a) * radius)
        }
        for i in mesh.vertices.indices {
            let p = mesh.vertices[i].position.xyz - center
            let normal = side * (simd_dot(p, side) / (radius * radius))
                + axis * (simd_dot(p, axis) / (halfLength * halfLength))
                + across * (simd_dot(p, across) / (radius * radius))
            mesh.vertices[i].normal = SIMD4(simd_normalize(normal), 0)
            mesh.vertices[i].uv.z = tint
            mesh.vertices[i].uv.w = radius * 2
        }
        return mesh
    }

    static func seaUrchin() -> AquariumMeshData {
        let center = SIMD3<Float>(0, 0.093, 0)
        var mesh = AquariumGeometry.ellipsoid(center: center, radii: SIMD3(0.105, 0.083, 0.105), seed: 6)
        // Short club-shaped spines retain the urchin silhouette without needle points.
        for ring in 0..<5 {
            let polar = 0.20 + Float(ring) * 0.40
            let count = [6, 12, 17, 20, 19][ring]
            for i in 0..<count {
                let a = (Float(i) / Float(count) + Float(ring) * 0.061) * Float.pi * 2
                let direction = SIMD3(sin(polar) * cos(a), cos(polar), sin(polar) * sin(a))
                let root = center + direction * SIMD3(0.091, 0.071, 0.091)
                let length: Float = 0.046 + 0.008 * sin(Float(i) * 2.4 + Float(ring))
                let end = center + direction * SIMD3(0.105 + length, 0.083 + length, 0.105 + length)
                var spine = roundedGlassRod(from: root, to: end, radius: 0.0085, tint: 18)
                for j in spine.vertices.indices { spine.vertices[j].motion = SIMD4(root, 90 + Float(i % 5)) }
                mesh.append(spine)
            }
        }
        // The small tube feet provide a surface contact and a subtle walking gait.
        for i in 0..<10 {
            let a = Float(i) / 10 * Float.pi * 2
            let root = SIMD3<Float>(cos(a) * 0.057, 0.041, sin(a) * 0.057)
            let end = SIMD3<Float>(cos(a) * 0.098, 0.003, sin(a) * 0.098)
            var foot = roundedGlassRod(from: root, to: end, radius: 0.0055, tint: 5)
            for j in foot.vertices.indices { foot.vertices[j].motion = SIMD4(root, 80 + Float(i % 5)) }
            mesh.append(foot)
        }
        return mesh
    }

    static func seaFan() -> AquariumMeshData {
        var mesh = AquariumGeometry.ellipsoid(center: SIMD3(0.31, -1.463, -0.35),
            radii: SIMD3(0.14, 0.041, 0.11), seed: 2)
        let root = SIMD3<Float>(0.31, -1.46, -0.35)
        mesh.append(AquariumGeometry.glassTube(seed: 2, radius: 0.034, rows: 36, roundness: 0.17, taper: 0.2) { t in
            root + SIMD3(sin(t * .pi) * 0.025, t * 0.27, -t * 0.025)
        })
        // A single broad fan with three round lobes and a gently curled outer lip.
        mesh.append(AquariumGeometry.fanFin(seed: 16, thickness: 0.029) { u, v in
            let a = (u - 0.5) * Float.pi * 1.17
            let lobe = 0.94 + 0.06 * cos(a * 5.0)
            let r = v * lobe
            let x = sin(a) * r * 0.34
            let y = cos(a) * r * 0.59
            let curl = pow(v, 5) * (0.072 + 0.025 * cos(a * 3))
            return root + SIMD3(x, 0.21 + y, -0.03 + sin(a * 2) * r * 0.045 + curl)
        })
        return mesh
    }

    private static func dragonSpine(_ t: Float) -> SIMD3<Float> {
        SIMD3(0.30 - t * 1.13, 0.265 * exp(-t * 6) + sin(t * .pi * 2) * 0.076 - t * 0.17, sin(t * .pi) * 0.022)
    }

    static func leafyDragonBody() -> AquariumMeshData {
        var mesh = AquariumGeometry.glassTube(seed: 0, radius: 0.076, rows: 112,
            depthRatio: 0.72, roundness: 0.11, taper: 0.93, curve: dragonSpine)
        mesh.append(AquariumGeometry.ellipsoid(center: SIMD3(0.325, 0.265, 0), radii: SIMD3(0.090, 0.064, 0.058)))
        mesh.append(AquariumGeometry.glassTube(seed: 0, radius: 0.026, rows: 32, roundness: 0.12, taper: 0.38) { t in
            SIMD3(0.373 + t * 0.207, 0.25, 0)
        })
        return mesh
    }

    static func leafyDragonFins() -> AquariumMeshData {
        var mesh = AquariumMeshData()
        // Paired leaves grow from curved glass petioles, with rounded lobed edges.
        func leaf(root: SIMD3<Float>, end: SIMD3<Float>, spread: SIMD3<Float>, bend: SIMD3<Float>) {
            let stemEnd = root + (end - root) * 0.25
            var leafMesh = AquariumGeometry.glassTube(seed: 1, radius: 0.009, rows: 20, taper: 0.18) { t in
                root + (stemEnd - root) * t + bend * sin(t * .pi) * 0.20
            }
            leafMesh.append(AquariumGeometry.fanFin(seed: 1, thickness: 0.011, goldRim: true) { u, v in
                let a = (u - 0.5) * Float.pi * 1.32
                let lobes = 0.91 + 0.09 * cos(a * 4)
                let edge = (end - stemEnd) * (0.57 + 0.43 * cos(a)) + spread * sin(a)
                return stemEnd + edge * (v * lobes) + bend * sin(v * .pi)
            })
            for i in leafMesh.vertices.indices { leafMesh.vertices[i].motion = SIMD4(root, 100) }
            mesh.append(leafMesh)
        }
        leaf(root: SIMD3(0.29, 0.30, 0), end: SIMD3(0.19, 0.57, 0), spread: SIMD3(0.11, 0.025, 0), bend: SIMD3(0.02, 0, 0.018))
        for i in 0..<4 {
            let t = 0.18 + Float(i) * 0.20
            let p = dragonSpine(t)
            let height: Float = i == 3 ? 0.18 : 0.25
            leaf(root: p, end: p + SIMD3(-0.13, height, -0.015),
                 spread: SIMD3(0.10, 0.028, 0), bend: SIMD3(-0.012, 0.025, 0.028))
            leaf(root: p, end: p + SIMD3(-0.055, -height * 0.78, 0.055),
                 spread: SIMD3(0.084, -0.025, 0), bend: SIMD3(-0.03, 0, 0.025))
        }
        for side: Float in [-1, 1] {
            leaf(root: SIMD3(0.18, 0.18, side * 0.041), end: SIMD3(0.02, 0.075, side * 0.13),
                 spread: SIMD3(0.03, 0.075, 0), bend: SIMD3(0, 0, side * 0.020))
        }
        return mesh
    }
}
