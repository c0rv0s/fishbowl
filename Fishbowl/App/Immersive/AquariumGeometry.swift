import Foundation
import simd

struct AquariumVertex: Sendable {
    var position: SIMD4<Float>
    var normal: SIMD4<Float>
    var uv: SIMD4<Float>
    var motion = SIMD4<Float>.zero // local joint pivot and articulation group

    init(_ p: SIMD3<Float>, _ n: SIMD3<Float>, _ uv: SIMD2<Float>) {
        position = SIMD4(p, 1)
        normal = SIMD4(n, 0)
        self.uv = SIMD4(uv.x, uv.y, 0, 0)
    }
}

struct AquariumMeshData: Sendable {
    var vertices: [AquariumVertex] = []
    var indices: [UInt32] = []

    mutating func append(_ other: AquariumMeshData) {
        let offset = UInt32(vertices.count)
        vertices += other.vertices
        indices += other.indices.map { $0 + offset }
    }

    mutating func recalculateNormals() {
        var normals = Array(repeating: SIMD3<Float>.zero, count: vertices.count)
        for i in stride(from: 0, to: indices.count, by: 3) {
            let a = Int(indices[i]), b = Int(indices[i + 1]), c = Int(indices[i + 2])
            let p = vertices[a].position.xyz, q = vertices[b].position.xyz, r = vertices[c].position.xyz
            let n = simd_cross(q - p, r - p)
            normals[a] += n; normals[b] += n; normals[c] += n
        }
        for i in vertices.indices {
            let n = simd_length_squared(normals[i]) > 1e-20 ? simd_normalize(normals[i]) : SIMD3(0, 1, 0)
            vertices[i].normal = SIMD4(n, 0)
        }
    }
}

extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> { SIMD3(x, y, z) }
}

enum AquariumBowl {
    static let center = SIMD3<Float>(0, 0.16, -0.30)
    static let radii = SIMD3<Float>(1.50, 2.35, 1.95)
    static let frontCut: Float = 0.85
    static let waterHeight: Float = 1.88
    static let sandHeight: Float = -1.50

    static func contains(_ point: SIMD3<Float>, tolerance: Float = 0.01) -> Bool {
        simd_length_squared((point - center) / radii) <= 1 + tolerance && point.z <= frontCut + tolerance
    }
}

enum AquariumGeometry {
    static func grid(columns: Int, rows: Int, position: (Float, Float) -> SIMD3<Float>) -> AquariumMeshData {
        var mesh = AquariumMeshData()
        for y in 0...rows {
            for x in 0...columns {
                let u = Float(x) / Float(columns), v = Float(y) / Float(rows)
                mesh.vertices.append(AquariumVertex(position(u, v), SIMD3(0, 0, 1), SIMD2(u, v)))
            }
        }
        for y in 0..<rows {
            for x in 0..<columns {
                let a = UInt32(y * (columns + 1) + x), b = a + 1, c = a + UInt32(columns + 1), d = c + 1
                mesh.indices += [a, c, b, b, c, d]
            }
        }
        mesh.recalculateNormals()
        return mesh
    }

    static func sand() -> AquariumMeshData {
        grid(columns: 128, rows: 60) { u, v in
            let angle = -u * 2 * .pi
            let section = sqrt(1 - pow((AquariumBowl.sandHeight - AquariumBowl.center.y) / AquariumBowl.radii.y, 2))
            let radialZ = sin(angle) * AquariumBowl.radii.z * section * 0.99
            let limit = radialZ > 0 ? min(1, (AquariumBowl.frontCut - AquariumBowl.center.z) / radialZ) : 1
            let x = cos(angle) * v * limit * AquariumBowl.radii.x * section * 0.99
            let z = AquariumBowl.center.z + radialZ * v * limit
            let h = AquariumBowl.sandHeight + (sin(x * 2.4 + z * 0.8) * 0.023 + sin(z * 3.2) * 0.015) * (1 - v * v)
            return SIMD3(x, h, z)
        }
    }

    static func bowlGlass() -> AquariumMeshData {
        // A continuous curved shell ends at the flat viewing cut; there is no front dome over the screen.
        var mesh = grid(columns: 160, rows: 100) { u, v in
            let angle = u * 2 * .pi
            let z = AquariumBowl.center.z - AquariumBowl.radii.z + 0.0001
                + v * (AquariumBowl.frontCut - AquariumBowl.center.z + AquariumBowl.radii.z - 0.0001)
            let radius = sqrt(max(0, 1 - pow((z - AquariumBowl.center.z) / AquariumBowl.radii.z, 2)))
            return SIMD3(cos(angle) * radius * AquariumBowl.radii.x,
                         AquariumBowl.center.y + sin(angle) * radius * AquariumBowl.radii.y, z)
        }
        for i in mesh.vertices.indices {
            let outward = (mesh.vertices[i].position.xyz - AquariumBowl.center) / (AquariumBowl.radii * AquariumBowl.radii)
            mesh.vertices[i].normal = SIMD4(-simd_normalize(outward), 0)
        }
        return mesh
    }

    static func ellipsoid(center: SIMD3<Float>, radii: SIMD3<Float>, seed: Float = 0,
                          columns: Int = 48, rows: Int = 28, molten: Bool = false) -> AquariumMeshData {
        var mesh = grid(columns: columns, rows: rows) { u, v in
            let phi = u * 2 * Float.pi, theta = (0.0001 + v * 0.9998) * Float.pi
            let n = SIMD3<Float>(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
            let ripple: Float = molten ? 1 + 0.095 * sin(n.y * 5 + seed) * cos(n.x * 4 - n.z * 3)
                + 0.055 * cos(n.z * 5.4 + n.x * 3.1 + seed) : 1
            return center + n * radii * ripple
        }
        for i in mesh.vertices.indices {
            let outward = (mesh.vertices[i].position.xyz - center) / (radii * radii)
            if !molten { mesh.vertices[i].normal = SIMD4(simd_normalize(outward), 0) }
            else if simd_dot(mesh.vertices[i].normal.xyz, outward) < 0 { mesh.vertices[i].normal *= -1 }
            mesh.vertices[i].uv.z = seed
            mesh.vertices[i].uv.w = min(radii.x, min(radii.y, radii.z)) * 2
        }
        return mesh
    }

    /// Rounded pulled-glass tubes, including their sealed tips.
    static func glassTube(seed: Float, radius: Float, rows: Int = 40,
                          depthRatio: Float = 1, roundness: Float = 0.28, taper: Float = 0.32,
                          curve: (Float) -> SIMD3<Float>) -> AquariumMeshData {
        var mesh = grid(columns: 24, rows: rows) { u, v in
            let t = 0.0001 + v * 0.9998
            let center = curve(t)
            let tangent = simd_normalize(curve(min(t + 0.001, 1)) - curve(max(t - 0.001, 0)))
            let side = simd_normalize(simd_cross(tangent, SIMD3<Float>(0, 0, 1)))
            let normal = simd_cross(side, tangent)
            let r = radius * pow(sin(t * .pi), roundness) * (1 - t * taper)
            let angle = u * 2 * Float.pi
            return center + (side * cos(angle) + normal * (sin(angle) * depthRatio)) * r
        }
        for i in mesh.vertices.indices {
            let t = 0.0001 + mesh.vertices[i].uv.y * 0.9998
            let outward = mesh.vertices[i].position.xyz - curve(t)
            if simd_dot(mesh.vertices[i].normal.xyz, outward) < 0 { mesh.vertices[i].normal *= -1 }
            mesh.vertices[i].uv.z = seed
            mesh.vertices[i].uv.w = radius * depthRatio * 2
        }
        return mesh
    }

    static func rocks() -> AquariumMeshData {
        var mesh = AquariumMeshData()
        mesh.append(ellipsoid(center: SIMD3(-0.64, -1.20, -0.18), radii: SIMD3(0.31, 0.39, 0.30), seed: 1.7, molten: true))
        mesh.append(ellipsoid(center: SIMD3(-0.29, -1.36, 0.27), radii: SIMD3(0.35, 0.23, 0.29), seed: 4.3, molten: true))
        mesh.append(ellipsoid(center: SIMD3(-0.76, -1.40, 0.35), radii: SIMD3(0.26, 0.20, 0.25), seed: 2.2, molten: true))
        return mesh
    }

    static func plants() -> AquariumMeshData {
        var mesh = AquariumMeshData()
        let tips: [SIMD3<Float>] = [SIMD3(-0.30, 0.73, 0.10), SIMD3(-0.15, 1.03, -0.10),
                                    SIMD3(0.10, 0.91, -0.18), SIMD3(0.38, 0.74, 0.05), SIMD3(0.29, 1.05, -0.02)]
        // A small cluster of broad, rounded glass fronds; no fine pointed canes.
        for i in tips.indices {
            let k = Float(i)
            let root = SIMD3<Float>(-0.46 + k * 0.022, -1.50, -0.48 + Float(i % 2) * 0.07)
            let tip = tips[i]
            let bend: Float = i % 2 == 0 ? -0.17 : 0.16
            let a = root + SIMD3(tip.x * 0.10, tip.y * 0.37, tip.z * 0.3)
            let b = root + SIMD3(tip.x + bend * 0.5, tip.y * 0.80, tip.z - 0.04)
            let end = root + tip
            mesh.append(glassTube(seed: Float(i % 2), radius: 0.10 + Float(i % 3) * 0.020,
                                  rows: 56, depthRatio: 0.27, roundness: 0.5, taper: 0) { t in
                let s = 1 - t
                return root * (s * s * s) + a * (3 * s * s * t) + b * (3 * s * t * t) + end * (t * t * t)
            })
        }
        return mesh
    }

    /// A closed, thick glass cup. The underside folds continuously into the
    /// scalloped rim, so side views show rounded glass rather than a flat card.
    private static func coralCup(center: SIMD3<Float>, radius: SIMD2<Float>, lift: Float,
                                 tilt: Float, yaw: Float, phase: Float, tint: Float) -> AquariumMeshData {
        let columns = 96, rows = 48
        func orient(_ p: SIMD3<Float>) -> SIMD3<Float> {
            let q = SIMD3(p.x, p.y * cos(tilt) - p.z * sin(tilt), p.y * sin(tilt) + p.z * cos(tilt))
            return SIMD3(q.x * cos(yaw) + q.z * sin(yaw), q.y, -q.x * sin(yaw) + q.z * cos(yaw))
        }
        var mesh = grid(columns: columns, rows: rows) { u, v in
            let angle = u * 2 * Float.pi
            let section = v * Float.pi
            let radial = max(0, sin(section))
            let lobes = sin(angle * 5 + phase) * 0.075 + sin(angle * 8 - phase) * 0.025
            let spread = radial * (1 + lobes * radial * radial)
            let curl = (sin(angle * 5 + phase + 0.6) * 0.042 + sin(angle * 3 - phase) * 0.025)
                * pow(radial, 3)
            let height = lift * pow(radial, 1.8) + curl
            let thickness = (0.022 - radial * 0.009) * cos(section)
            let p = SIMD3(cos(angle) * radius.x * spread,
                          height + thickness,
                          sin(angle) * radius.y * spread)
            return center + orient(p)
        }
        // The meridian runs from the upper center around the lip to the underside.
        for i in stride(from: 0, to: mesh.indices.count, by: 3) { mesh.indices.swapAt(i + 1, i + 2) }
        mesh.recalculateNormals()
        for row in 0...rows {
            let a = row * (columns + 1), b = a + columns
            let normal: SIMD3<Float>
            if row == 0 || row == rows { normal = orient(SIMD3(0, row == 0 ? 1 : -1, 0)) }
            else { normal = simd_normalize(mesh.vertices[a].normal.xyz + mesh.vertices[b].normal.xyz) }
            mesh.vertices[a].normal = SIMD4(normal, 0)
            mesh.vertices[b].normal = SIMD4(normal, 0)
            for column in 0...columns {
                let i = a + column
                let radial = max(0, sin(Float(row) / Float(rows) * .pi))
                if row == 0 || row == rows { mesh.vertices[i].normal = SIMD4(normal, 0) }
                mesh.vertices[i].uv = SIMD4(Float(column) / Float(columns), radial, tint, 0.15 - radial * 0.095)
            }
        }
        return mesh
    }

    static func coralGarden() -> AquariumMeshData {
        var mesh = ellipsoid(center: SIMD3(-0.37, -1.49, -0.27), radii: SIMD3(0.23, 0.075, 0.19), seed: 7, molten: true)
        // Overlapping rose cups join along their folds. Broad folds and an
        // asymmetric arrangement give the colony a soft, open silhouette.
        mesh.append(coralCup(center: SIMD3(-0.39, -1.40, -0.20), radius: SIMD2(0.31, 0.27),
                             lift: 0.15, tilt: 0.44, yaw: -0.24, phase: 0.4, tint: 12))
        mesh.append(coralCup(center: SIMD3(-0.35, -1.24, -0.34), radius: SIMD2(0.34, 0.28),
                             lift: 0.18, tilt: 0.65, yaw: 0.17, phase: 2.1, tint: 12))
        mesh.append(coralCup(center: SIMD3(-0.41, -1.075, -0.44), radius: SIMD2(0.29, 0.24),
                             lift: 0.18, tilt: 0.88, yaw: -0.34, phase: 4.2, tint: 12))
        // A lower seafoam colony stays close to the main piece, leaving open sand.
        mesh.append(ellipsoid(center: SIMD3(0.01, -1.48, 0.08), radii: SIMD3(0.16, 0.064, 0.14), seed: 2))
        mesh.append(coralCup(center: SIMD3(0.02, -1.42, 0.10), radius: SIMD2(0.25, 0.20),
                             lift: 0.12, tilt: 0.40, yaw: 0.30, phase: 1.3, tint: 13))
        mesh.append(coralCup(center: SIMD3(-0.07, -1.285, -0.015), radius: SIMD2(0.23, 0.18),
                             lift: 0.13, tilt: 0.77, yaw: 0.44, phase: 3.5, tint: 13))
        return mesh
    }

    private static func fishSection(at x: Float) -> (center: Float, height: Float, depth: Float) {
        let t = min(max((x + 0.29) / 0.815, 0), 1)
        let profile = pow(max(0, sin(t * .pi)), 0.58) * (0.50 + t * 0.58)
        return (0.010 + sin(t * .pi) * 0.014, profile * 0.185, profile * 0.111)
    }

    static func fishBody() -> AquariumMeshData {
        // A continuous spindle narrows into the tail and keeps a softly rounded snout.
        var mesh = grid(columns: 64, rows: 80) { u, v in
            let x = -0.29 + (0.0001 + v * 0.9998) * 0.815
            let section = fishSection(at: x)
            let angle = u * 2 * Float.pi
            let workedGlass = 1 + 0.010 * sin(x * 34 + cos(angle * 2) * 1.6) + 0.004 * sin(angle * 4 + x * 19)
            return SIMD3(x, section.center + cos(angle) * section.height * workedGlass,
                         sin(angle) * section.depth * workedGlass)
        }
        for i in mesh.vertices.indices {
            let p = mesh.vertices[i].position.xyz
            let section = fishSection(at: p.x)
            let outward = SIMD3<Float>(0, p.y - section.center, p.z)
            if simd_dot(mesh.vertices[i].normal.xyz, outward) < 0 { mesh.vertices[i].normal *= -1 }
            mesh.vertices[i].uv.w = section.depth * 2
        }
        return mesh
    }

    static func glassFin(from start: SIMD3<Float>, to end: SIMD3<Float>, width: Float,
                         thickness: Float, seed: Float) -> AquariumMeshData {
        let direction = simd_normalize(end - start)
        let side = simd_normalize(simd_cross(direction, SIMD3<Float>(0, 0, 1)))
        let normal = simd_cross(side, direction)
        var mesh = grid(columns: 32, rows: 40) { u, v in
            let t = 0.0001 + v * 0.9998
            let axis = start + (end - start) * t
            let profile = pow(sin(t * .pi), 0.68)
            let angle = u * 2 * Float.pi
            return axis + side * (cos(angle) * width * profile)
                + normal * (sin(angle) * thickness * profile)
        }
        for i in mesh.vertices.indices {
            let t = 0.0001 + mesh.vertices[i].uv.y * 0.9998
            let outward = mesh.vertices[i].position.xyz - (start + (end - start) * t)
            if simd_dot(mesh.vertices[i].normal.xyz, outward) < 0 { mesh.vertices[i].normal *= -1 }
            mesh.vertices[i].uv.z = seed
            mesh.vertices[i].uv.w = thickness * 2
        }
        return mesh
    }

    static func fanFin(seed: Float, thickness: Float = 0.018, goldRim: Bool = false,
                       outline: (Float, Float) -> SIMD3<Float>) -> AquariumMeshData {
        var result = AquariumMeshData()
        func foldedPoint(_ u: Float, _ v: Float) -> SIMD3<Float> {
            var p = outline(u, v)
            let fold = sin(u * .pi * 12 + sin(v * .pi) * 1.4) * sin(u * .pi)
            p.z += fold * thickness * 1.10 * sin(v * .pi * 0.85)
            return p
        }
        for side: Float in [-1, 1] {
            var face = grid(columns: 96, rows: 40) { u, v in
                var p = foldedPoint(u, v)
                let crossSection = pow(max(0, sin(u * .pi) * sin(v * .pi)), 0.50)
                // Soft folds are part of the glass volume, so their reflections turn
                // with the fish instead of being painted stripes on a smooth fin.
                p.z += side * thickness * crossSection
                return p
            }
            for i in face.vertices.indices {
                if face.vertices[i].normal.z * side < 0 { face.vertices[i].normal *= -1 }
                face.vertices[i].uv.z = seed
                face.vertices[i].uv.w = thickness * 2
            }
            result.append(face)
        }
        if goldRim {
            result.append(glassTube(seed: 3, radius: 0.0055, rows: 144, roundness: 0.10, taper: 0) {
                foldedPoint($0, 1)
            })
        }
        return result
    }

    static func fishFins(flowing: Bool = false) -> AquariumMeshData {
        var mesh = AquariumMeshData()
        let root = SIMD2<Float>(-0.245, 0.010)
        // A closed, curved perimeter gives the tail rounded lobes and a soft notch.
        let curves: [(SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>)] = flowing ? [
            (root, SIMD2(-0.42, 0.18), SIMD2(-0.61, 0.35), SIMD2(-0.72, 0.32)),
            (SIMD2(-0.72, 0.32), SIMD2(-0.87, 0.28), SIMD2(-0.78, 0.16), SIMD2(-0.68, 0.12)),
            (SIMD2(-0.68, 0.12), SIMD2(-0.61, 0.095), SIMD2(-0.54, 0.045), SIMD2(-0.54, 0.010)),
            (SIMD2(-0.54, 0.010), SIMD2(-0.54, -0.025), SIMD2(-0.61, -0.075), SIMD2(-0.68, -0.10)),
            (SIMD2(-0.68, -0.10), SIMD2(-0.80, -0.15), SIMD2(-0.85, -0.28), SIMD2(-0.72, -0.29)),
            (SIMD2(-0.72, -0.29), SIMD2(-0.60, -0.33), SIMD2(-0.40, -0.15), root)
        ] : [
            (root, SIMD2(-0.39, 0.045), SIMD2(-0.57, 0.185), SIMD2(-0.635, 0.202)),
            (SIMD2(-0.635, 0.202), SIMD2(-0.706, 0.221), SIMD2(-0.695, 0.183), SIMD2(-0.643, 0.140)),
            (SIMD2(-0.643, 0.140), SIMD2(-0.587, 0.094), SIMD2(-0.548, 0.040), SIMD2(-0.541, 0.010)),
            (SIMD2(-0.541, 0.010), SIMD2(-0.548, -0.021), SIMD2(-0.593, -0.082), SIMD2(-0.641, -0.122)),
            (SIMD2(-0.641, -0.122), SIMD2(-0.691, -0.164), SIMD2(-0.697, -0.200), SIMD2(-0.627, -0.181)),
            (SIMD2(-0.627, -0.181), SIMD2(-0.535, -0.156), SIMD2(-0.378, -0.034), root)
        ]
        mesh.append(fanFin(seed: 0, thickness: 0.014, goldRim: flowing) { u, v in
            let segment = min(Int(u * Float(curves.count)), curves.count - 1)
            let t = u * Float(curves.count) - Float(segment), s = 1 - t
            let c = curves[segment]
            let edge = c.0 * (s*s*s) + c.1 * (3*s*s*t) + c.2 * (3*s*t*t) + c.3 * (t*t*t)
            let p = root + (edge - root) * v
            return SIMD3(p.x, p.y, sin(u * 2 * .pi) * v * 0.009)
        })
        mesh.append(fanFin(seed: 1, goldRim: flowing) { u, v in
            let x = -0.22 + u * 0.57
            let section = fishSection(at: x)
            let fin = pow(sin(u * .pi), 0.85) * (1.15 - u * 0.35)
            return SIMD3(x - v * fin * (flowing ? 0.17 : 0.080),
                         section.center + section.height * 0.97 + v * fin * (flowing ? 0.255 : 0.090), 0)
        })
        mesh.append(fanFin(seed: 1, goldRim: flowing) { u, v in
            let x = -0.18 + u * 0.47
            let section = fishSection(at: x)
            let fin = pow(sin(u * .pi), 0.85)
            return SIMD3(x - v * fin * (flowing ? 0.135 : 0.065),
                         section.center - section.height * 0.97 - v * fin * (flowing ? 0.16 : 0.055), 0)
        })
        for z: Float in [-1, 1] {
            mesh.append(glassFin(from: SIMD3(0.27, -0.014, z * 0.081),
                to: SIMD3(flowing ? 0.055 : 0.12, flowing ? -0.18 : -0.085, z * (flowing ? 0.16 : 0.126)),
                width: flowing ? 0.063 : 0.026, thickness: flowing ? 0.014 : 0.007, seed: 2))
        }
        return mesh
    }

    static func fishFeatures() -> AquariumMeshData {
        var mesh = AquariumMeshData()
        for z: Float in [-1, 1] {
            mesh.append(ellipsoid(center: SIMD3(0.402, 0.051, z * 0.063), radii: SIMD3(0.029, 0.029, 0.015), seed: 0, columns: 28, rows: 18))
            mesh.append(ellipsoid(center: SIMD3(0.409, 0.052, z * 0.077), radii: SIMD3(0.013, 0.016, 0.007), seed: 1, columns: 28, rows: 18))
        }
        mesh.append(ellipsoid(center: SIMD3(0.521, 0.010, 0), radii: SIMD3(0.012, 0.007, 0.014), seed: 2, columns: 24, rows: 16))
        return mesh
    }

    static func bubbles() -> AquariumMeshData {
        var mesh = AquariumMeshData()
        // Local spheres share one seed per bubble. The vertex shader moves each
        // whole sphere from its sand emitter to the surface without a wrap seam.
        for i in 0..<22 {
            let k = Float(i)
            let r: Float = 0.010 + (sin(k * 3.9) + 1) * 0.010
            var bubble = ellipsoid(center: .zero, radii: SIMD3(repeating: r), seed: k, columns: 24, rows: 16)
            for j in bubble.vertices.indices { bubble.vertices[j].uv.w = r }
            mesh.append(bubble)
        }
        return mesh
    }

    static func sphere(radius: Float) -> AquariumMeshData {
        ellipsoid(center: .zero, radii: SIMD3(repeating: radius), columns: 16, rows: 12)
    }
}
