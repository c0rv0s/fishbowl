import Foundation
import simd

/// A vertical ray index of the rendered triangles. Multiple solid intervals preserve
/// the empty space below an arch instead of treating it as a solid height map.
struct AquariumSurfaceIndex {
    struct Hit {
        var height: Float
        var normal: SIMD3<Float>
    }
    struct Solid {
        var bottom: Float
        var bottomNormal: SIMD3<Float>
        var top: Hit
    }
    private struct Triangle {
        var a: SIMD3<Float>, b: SIMD3<Float>, c: SIMD3<Float>
        var na: SIMD3<Float>, nb: SIMD3<Float>, nc: SIMD3<Float>
    }
    private let cell: Float = 0.10
    private var triangles: [Triangle] = []
    private var bins: [SIMD2<Int>: [Int]] = [:]

    init(_ mesh: AquariumMeshData) {
        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            let a = mesh.vertices[Int(mesh.indices[i])]
            let b = mesh.vertices[Int(mesh.indices[i + 1])]
            let c = mesh.vertices[Int(mesh.indices[i + 2])]
            let t = Triangle(a: a.position.xyz, b: b.position.xyz, c: c.position.xyz,
                             na: a.normal.xyz, nb: b.normal.xyz, nc: c.normal.xyz)
            let low = simd_min(t.a, simd_min(t.b, t.c)), high = simd_max(t.a, simd_max(t.b, t.c))
            let index = triangles.count
            triangles.append(t)
            for x in Int(floor(low.x / cell))...Int(floor(high.x / cell)) {
                for z in Int(floor(low.z / cell))...Int(floor(high.z / cell)) {
                    bins[SIMD2(x, z), default: []].append(index)
                }
            }
        }
    }

    func solids(at location: SIMD2<Float>) -> [Solid] {
        // Avoid the microscopic polar seam of a lathed glass mesh and ambiguous
        // rays exactly through a vertex. This is below a tenth of a screen pixel.
        let p = location + SIMD2<Float>(0.00013, 0.00017)
        var hits: [Hit] = []
        for index in bins[SIMD2(Int(floor(p.x / cell)), Int(floor(p.y / cell)))] ?? [] {
            let t = triangles[index]
            let ab = SIMD2(t.b.x - t.a.x, t.b.z - t.a.z)
            let ac = SIMD2(t.c.x - t.a.x, t.c.z - t.a.z)
            let ap = p - SIMD2(t.a.x, t.a.z)
            let det = ab.x * ac.y - ab.y * ac.x
            guard abs(det) > 1e-9 else { continue }
            let u = (ap.x * ac.y - ap.y * ac.x) / det
            let v = (ab.x * ap.y - ab.y * ap.x) / det
            guard u >= -0.00001, v >= -0.00001, u + v <= 1.00001 else { continue }
            hits.append(Hit(height: t.a.y + u * (t.b.y - t.a.y) + v * (t.c.y - t.a.y),
                            normal: simd_normalize(t.na * (1 - u - v) + t.nb * u + t.nc * v)))
        }
        hits.sort { $0.height > $1.height }
        var depth = 0, result: [Solid] = []
        var top: Hit?
        var previous: Hit?
        for hit in hits {
            // A ray on a shared triangle edge must only cross that surface once.
            if let previous, abs(previous.height - hit.height) < 0.0001,
               previous.normal.y * hit.normal.y > 0 { continue }
            previous = hit
            if hit.normal.y > 0 {
                if depth == 0 { top = hit }
                depth += 1
            } else {
                depth = max(0, depth - 1)
                if depth == 0, let start = top {
                    result.append(Solid(bottom: hit.height, bottomNormal: hit.normal, top: start)); top = nil
                }
            }
        }
        return result
    }

    func intersects(_ p: SIMD3<Float>, radius: Float) -> Bool {
        // Sample the silhouette as well as its center; thin arch legs and fronds
        // must block a route even when its center line clears them.
        for offset in [SIMD2<Float>.zero, SIMD2(radius, 0), SIMD2(-radius, 0),
                       SIMD2(0, radius), SIMD2(0, -radius)] {
            for solid in solids(at: SIMD2(p.x, p.z) + offset) {
                if solid.bottom < p.y + radius && solid.top.height > p.y - radius { return true }
            }
        }
        return false
    }

    /// Conservative clearance for the whole swimmer footprint, including thin glass edges.
    func clearanceHeight(near p: SIMD2<Float>, radius: Float) -> Float? {
        let center = SIMD2(Int(floor(p.x / cell)), Int(floor(p.y / cell)))
        let extent = Int(ceil(radius / cell))
        var visited = Set<Int>(), height: Float?
        for x in -extent...extent { for z in -extent...extent {
            for index in bins[center &+ SIMD2(x, z)] ?? [] where visited.insert(index).inserted {
                let t = triangles[index]
                let low = simd_min(t.a, simd_min(t.b, t.c)), high = simd_max(t.a, simd_max(t.b, t.c))
                let nearest = simd_clamp(p, SIMD2(low.x, low.z), SIMD2(high.x, high.z))
                if simd_distance_squared(p, nearest) <= radius * radius {
                    height = max(height ?? -.infinity, high.y)
                }
            }
        } }
        return height
    }

    func nearest(to p: SIMD3<Float>, radius: Float = 0.12) -> AquariumCompanionRoute.Contact? {
        var best: AquariumCompanionRoute.Contact?
        var distance = radius * radius
        var visited = Set<Int>()
        let center = SIMD2(Int(floor(p.x / cell)), Int(floor(p.z / cell)))
        let extent = Int(ceil(radius / cell))
        for x in -extent...extent {
            for z in -extent...extent {
                for index in bins[center &+ SIMD2(x, z)] ?? [] where visited.insert(index).inserted {
                    let t = triangles[index], ab = t.b - t.a, ac = t.c - t.a
                    let face = simd_cross(ab, ac)
                    let area = simd_length_squared(face)
                    guard area > 1e-14 else { continue }
                    let projected = p - face * (simd_dot(p - t.a, face) / area)
                    let ap = projected - t.a
                    let d00 = simd_dot(ab, ab), d01 = simd_dot(ab, ac), d11 = simd_dot(ac, ac)
                    let denom = d00 * d11 - d01 * d01
                    guard abs(denom) > 1e-14 else { continue }
                    var u = (d11 * simd_dot(ap, ab) - d01 * simd_dot(ap, ac)) / denom
                    var v = (d00 * simd_dot(ap, ac) - d01 * simd_dot(ap, ab)) / denom
                    var q = projected
                    if u < 0 || v < 0 || u + v > 1 {
                        func edge(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> {
                            let e = b - a
                            return a + e * min(1, max(0, simd_dot(p - a, e) / max(1e-14, simd_length_squared(e))))
                        }
                        q = [edge(t.a, t.b), edge(t.b, t.c), edge(t.c, t.a)].min {
                            simd_distance_squared($0, p) < simd_distance_squared($1, p)
                        }!
                        let aq = q - t.a
                        u = (d11 * simd_dot(aq, ab) - d01 * simd_dot(aq, ac)) / denom
                        v = (d00 * simd_dot(aq, ac) - d01 * simd_dot(aq, ab)) / denom
                    }
                    let d = simd_distance_squared(p, q)
                    if d < distance {
                        distance = d
                        best = .init(point: q, normal: simd_normalize(t.na * (1 - u - v) + t.nb * u + t.nc * v))
                    }
                }
            }
        }
        return best
    }
}

struct AquariumCompanionPose {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var forward: SIMD3<Float>
    var gait: Float
    var activity: Float
    var ambientTime: Float

    func model(scale: Float) -> simd_float4x4 {
        let y = simd_normalize(normal)
        let x = simd_normalize(forward - y * simd_dot(forward, y))
        let z = simd_normalize(simd_cross(x, y))
        return simd_float4x4(columns: (SIMD4(x * scale, 0), SIMD4(y * scale, 0),
                                       SIMD4(z * scale, 0), SIMD4(position, 1)))
    }
}

/// Routes are built on a habitat change, then sampled by distance. Render rate,
/// paused previews, and shadow passes cannot change a companion's trajectory.
struct AquariumCompanionRoute: Sendable {
    struct Contact: Sendable {
        var point: SIMD3<Float>
        var normal: SIMD3<Float>
    }
    let contacts: [Contact]
    private let distances: [Float]
    let length: Float

    init(_ contacts: [Contact]) {
        self.contacts = contacts
        var distances: [Float] = [0]
        for i in 1..<max(1, contacts.count) {
            distances.append(distances.last! + simd_distance(contacts[i - 1].point, contacts[i].point))
        }
        self.distances = distances
        length = distances.last ?? 0
    }

    func contact(at distance: Float) -> Contact {
        guard contacts.count > 1, length > 0.001 else {
            return contacts.first ?? Contact(point: SIMD3(0.3, -1.5, 0.4), normal: SIMD3(0, 1, 0))
        }
        let d = (distance.truncatingRemainder(dividingBy: length) + length).truncatingRemainder(dividingBy: length)
        var lo = 0, hi = distances.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if distances[mid] <= d { lo = mid } else { hi = mid }
        }
        let a = contacts[lo], b = contacts[hi]
        let t = (d - distances[lo]) / max(0.0001, distances[hi] - distances[lo])
        return Contact(point: simd_mix(a.point, b.point, SIMD3(repeating: t)),
                       normal: simd_normalize(simd_mix(a.normal, b.normal, SIMD3(repeating: t))))
    }
}

struct AquariumCompanionHabitat {
    private struct Node {
        var contact: AquariumCompanionRoute.Contact
        var onRock = false
        var links: [Int] = []
    }
    let decoration: DecorationStyle
    let features: [FeaturePieceStyle]
    let layout: AquariumHabitatLayout
    let solids: AquariumSurfaceIndex
    private let climbable: AquariumSurfaceIndex
    private let obstacles: AquariumSurfaceIndex
    private var nodes: [Node] = []
    private(set) var walkingRoute = AquariumCompanionRoute([])
    private(set) var swimmingRoute = AquariumCompanionRoute([])

    init(decoration: DecorationStyle, feature: FeaturePieceStyle) {
        self.init(decoration: decoration, features: [feature])
    }

    init(decoration: DecorationStyle, features: [FeaturePieceStyle]) {
        self.decoration = decoration
        self.features = AquariumConfiguration.normalizedFeatures(features)
        layout = AquariumHabitatLayout(decoration: decoration, features: self.features)
        let decor = layout.decoration.mesh
        var all = decor, walk = AquariumMeshData(), blocked = AquariumMeshData()
        if decoration == .riverRocks || decoration == .glassPearls { walk.append(decor) }
        else { blocked.append(decor) }
        for feature in layout.features {
            all.append(feature.piece.mesh)
            if feature.style == .bubbleStone { walk.append(feature.piece.mesh) }
            else { blocked.append(feature.piece.mesh) }
        }
        solids = AquariumSurfaceIndex(all)
        climbable = AquariumSurfaceIndex(walk); obstacles = AquariumSurfaceIndex(blocked)
        buildWalkingRoute(mesh: walk)
        buildSwimmingRoute()
    }

    static func sandContact(_ p: SIMD2<Float>) -> AquariumCompanionRoute.Contact {
        func height(_ p: SIMD2<Float>) -> Float {
            let section = sqrt(1 - pow((AquariumBowl.sandHeight - AquariumBowl.center.y) / AquariumBowl.radii.y, 2))
            let radial = SIMD2(p.x / (AquariumBowl.radii.x * section * 0.99),
                              (p.y - AquariumBowl.center.z) / (AquariumBowl.radii.z * section * 0.99))
            let r2 = min(1, simd_length_squared(radial))
            return AquariumBowl.sandHeight + (sin(p.x * 2.4 + p.y * 0.8) * 0.023 + sin(p.y * 3.2) * 0.015) * (1 - r2)
        }
        let dx = (height(p + SIMD2(0.002, 0)) - height(p - SIMD2(0.002, 0))) / 0.004
        let dz = (height(p + SIMD2(0, 0.002)) - height(p - SIMD2(0, 0.002))) / 0.004
        return .init(point: SIMD3(p.x, height(p), p.y), normal: simd_normalize(SIMD3(-dx, 1, -dz)))
    }

    private func contact(_ p: SIMD2<Float>) -> AquariumCompanionRoute.Contact {
        var floor = Self.sandContact(p)
        for solid in climbable.solids(at: p) where solid.top.height > floor.point.y {
            floor.point.y = solid.top.height; floor.normal = solid.top.normal
        }
        return floor
    }

    private func clearForWalker(_ c: AquariumCompanionRoute.Contact) -> Bool {
        let p = c.point
        guard abs(p.x) < 0.92, p.z < 0.59, p.z > -1.27,
              AquariumBowl.contains(p + SIMD3(p.x < 0 ? -0.17 : 0.17, 0.09, 0), tolerance: -0.025) else { return false }
        return !obstacles.intersects(p + c.normal * 0.095, radius: 0.16)
    }

    private func nearestContact(_ p: SIMD3<Float>) -> AquariumCompanionRoute.Contact {
        let sand = Self.sandContact(SIMD2(p.x, p.z))
        if let rock = climbable.nearest(to: p), simd_distance_squared(rock.point, p) < simd_distance_squared(sand.point, p) {
            return rock
        }
        return sand
    }

    private mutating func buildWalkingRoute(mesh: AquariumMeshData) {
        let step: Float = 0.045
        var grid: [SIMD2<Int>: Int] = [:]
        for x in -20...20 {
            for z in -28...13 {
                let c = Self.sandContact(SIMD2(Float(x) * step, Float(z) * step))
                let inside = climbable.solids(at: SIMD2(c.point.x, c.point.z)).contains {
                    c.point.y > $0.bottom + 0.002 && c.point.y < $0.top.height - 0.002
                }
                if !inside && clearForWalker(c) {
                    grid[SIMD2(x, z)] = nodes.count
                    nodes.append(Node(contact: c))
                }
            }
        }
        // Add the actual rock skin, including near-vertical and overhanging
        // flanks that cannot be represented by a height map. The buried portion
        // and internal overlaps between stones are excluded.
        var occupied = Set<SIMD3<Int>>()
        for vertex in mesh.vertices {
            let p = vertex.position.xyz
            let key = SIMD3(Int(floor(p.x / 0.023)), Int(floor(p.y / 0.023)), Int(floor(p.z / 0.023)))
            guard occupied.insert(key).inserted, p.y > Self.sandContact(SIMD2(p.x, p.z)).point.y - 0.006 else { continue }
            let intervals = climbable.solids(at: SIMD2(p.x, p.z))
            if intervals.contains(where: { p.y > $0.bottom + 0.015 && p.y < $0.top.height - 0.015 }) { continue }
            let c = AquariumCompanionRoute.Contact(point: p, normal: vertex.normal.xyz)
            if clearForWalker(c) {
                nodes.append(Node(contact: c, onRock: true))
                let sand = Self.sandContact(SIMD2(p.x, p.z))
                if abs(p.y - sand.point.y) < 0.025 {
                    nodes.append(Node(contact: sand))
                }
            }
        }
        for (key, index) in grid {
            for dx in -1...1 {
                for dz in -1...1 where dx != 0 || dz != 0 {
                    guard let neighbor = grid[key &+ SIMD2(dx, dz)] else { continue }
                    let a = nodes[index].contact, b = nodes[neighbor].contact
                    guard simd_distance(a.point, b.point) < 0.16,
                          simd_dot(a.normal, b.normal) > 0.15 else { continue }
                    let mid = contact(SIMD2((a.point.x + b.point.x) * 0.5, (a.point.z + b.point.z) * 0.5))
                    if clearForWalker(mid), abs(mid.point.y - (a.point.y + b.point.y) * 0.5) < 0.05 {
                        nodes[index].links.append(neighbor)
                    }
                }
            }
        }
        var spatial: [SIMD3<Int>: [Int]] = [:]
        let reach: Float = 0.08
        func key(_ p: SIMD3<Float>) -> SIMD3<Int> {
            SIMD3(Int(floor(p.x / reach)), Int(floor(p.y / reach)), Int(floor(p.z / reach)))
        }
        for i in nodes.indices { spatial[key(nodes[i].contact.point), default: []].append(i) }
        for i in nodes.indices {
            let a = nodes[i].contact
            let cell = key(a.point)
            for x in -1...1 { for y in -1...1 { for z in -1...1 {
                for j in spatial[cell &+ SIMD3(x, y, z)] ?? [] where j > i {
                    let b = nodes[j].contact
                    guard simd_distance(a.point, b.point) < reach else { continue }
                    // Transfer feet where the rock actually meets the sand,
                    // rather than jumping from the floor to an overhang.
                    if nodes[i].onRock != nodes[j].onRock, abs(a.point.y - b.point.y) > 0.025 { continue }
                    let midpoint = (a.point + b.point) * 0.5
                    if climbable.solids(at: SIMD2(midpoint.x, midpoint.z)).contains(where: {
                        midpoint.y > $0.bottom + 0.008 && midpoint.y < $0.top.height - 0.008
                    }) { continue }
                    // Never bridge through an arch leg, even on a diagonal.
                    if !obstacles.intersects(midpoint + SIMD3(0, 0.10, 0), radius: 0.15) {
                        nodes[i].links.append(j); nodes[j].links.append(i)
                    }
                }
            } } }
        }
        guard !nodes.isEmpty else { return }
        // Deliberate destinations invite climbing; a shortest path between two
        // sand points alone would usually skirt every rock.
        var stops: [SIMD2<Float>] = [SIMD2(0.32, 0.40)]
        if decoration == .riverRocks || decoration == .glassPearls {
            stops += [SIMD3<Float>(-0.29, -1.50, 0.27), SIMD3(-0.64, -1.50, -0.18), SIMD3(-0.73, -1.50, 0.35)].map {
                let p = layout.decoration.position($0)
                return SIMD2(p.x, p.z)
            }
        } else { stops += [SIMD2(-0.52, 0.36), SIMD2(-0.63, -0.15)] }
        stops += [SIMD2(-0.30, 0.51), SIMD2(0.33, 0.09)]
        let arches = layout.features.filter { $0.style == .driftwoodArch }
        if !arches.isEmpty {
            for arch in arches {
                stops += [SIMD3<Float>(0.35, -1.50, -0.90), SIMD3(0.35, -1.50, -0.52), SIMD3(0.35, -1.50, -0.12),
                          SIMD3(0.76, -1.50, -0.08)].map {
                    let p = arch.piece.position($0)
                    return SIMD2(p.x, p.z)
                }
            }
        } else { stops += [SIMD2(0.26, -0.85), SIMD2(0.66, -0.15)] }
        stops.append(stops[0])
        func nearest(_ p: SIMD2<Float>) -> Int {
            let target = contact(p).point
            return nodes.indices.min { simd_distance_squared(nodes[$0].contact.point, target)
                < simd_distance_squared(nodes[$1].contact.point, target) }!
        }
        var route: [AquariumCompanionRoute.Contact] = []
        var current = nearest(stops[0])
        for stop in stops.dropFirst() {
            let target = nearest(stop)
            let path = path(from: current, to: target)
            guard !path.isEmpty else { continue }
            route += path.dropLast().map { nodes[$0].contact }
            current = target
        }
        if let first = route.first { route.append(first) }
        // Round grid corners, projecting each new point back onto the actual
        // triangle surface. Reject a smoothing step if it cuts into a prop.
        for _ in 0..<3 where route.count > 3 {
            var smoothed = route
            let count = route.count - 1
            for i in 0..<count {
                let p = (route[(i + count - 1) % count].point + route[i].point * 2 + route[(i + 1) % count].point) / 4
                let c = nearestContact(p)
                if clearForWalker(c), simd_distance(c.point, p) < 0.035 { smoothed[i] = c }
            }
            smoothed[count] = smoothed[0]; route = smoothed
        }
        var fitted: [AquariumCompanionRoute.Contact] = []
        for i in 1..<route.count {
            let a = route[i - 1], b = route[i]
            let count = max(1, Int(ceil(simd_distance(a.point, b.point) / 0.012)))
            for j in 0..<count {
                let t = Float(j) / Float(count)
                let p = simd_mix(a.point, b.point, SIMD3(repeating: t))
                fitted.append(nearestContact(p))
            }
        }
        if let first = fitted.first { fitted.append(first) }
        walkingRoute = AquariumCompanionRoute(fitted)
        nodes = [] // The graph is only needed while planning the route.
    }

    private func path(from start: Int, to end: Int) -> [Int] {
        var cost = Array(repeating: Float.infinity, count: nodes.count)
        var previous = Array(repeating: -1, count: nodes.count)
        var queue = [(Float, Int)]()
        func push(_ value: (Float, Int)) {
            queue.append(value)
            var i = queue.count - 1
            while i > 0 {
                let parent = (i - 1) / 2
                if queue[parent].0 <= queue[i].0 { break }
                queue.swapAt(parent, i); i = parent
            }
        }
        func pop() -> (Float, Int) {
            let first = queue[0], last = queue.removeLast()
            if !queue.isEmpty {
                queue[0] = last
                var i = 0
                while i * 2 + 1 < queue.count {
                    var child = i * 2 + 1
                    if child + 1 < queue.count, queue[child + 1].0 < queue[child].0 { child += 1 }
                    if queue[i].0 <= queue[child].0 { break }
                    queue.swapAt(i, child); i = child
                }
            }
            return first
        }
        cost[start] = 0; push((0, start))
        while !queue.isEmpty {
            let (distance, current) = pop()
            if current == end { break }
            if distance > cost[current] { continue }
            for next in nodes[current].links {
                let delta = simd_distance(nodes[current].contact.point, nodes[next].contact.point)
                let nextCost = distance + delta
                if nextCost < cost[next] {
                    cost[next] = nextCost; previous[next] = current; push((nextCost, next))
                }
            }
        }
        guard cost[end].isFinite else { return [] }
        var result = [end], current = end
        while current != start { current = previous[current]; result.append(current) }
        return result.reversed()
    }

    private mutating func buildSwimmingRoute() {
        var route: [AquariumCompanionRoute.Contact] = []
        for i in 0...720 {
            let a = Float(i) / 720 * 2 * Float.pi
            var p = SIMD3<Float>(0.62 * cos(a), -0.60 + sin(a * 2) * 0.34,
                                 -0.10 + sin(a) * 0.55)
            // Cover the entire footprint: isolated radial rays can miss a thin
            // frond after a second feature changes the arrangement.
            if let height = solids.clearanceHeight(near: SIMD2(p.x, p.z), radius: 0.28) {
                p.y = max(p.y, height + 0.28)
            }
            route.append(.init(point: p, normal: SIMD3(0, 1, 0)))
        }
        // Smooth height changes outward so every sample retains its clearance.
        for _ in 0..<32 {
            let old = route
            for i in 0..<720 {
                route[i].point.y = max(old[i].point.y,
                    (old[(i + 719) % 720].point.y + old[(i + 1) % 720].point.y) * 0.5)
            }
        }
        route[720] = route[0]
        swimmingRoute = AquariumCompanionRoute(route)
    }

    var routes: AquariumCompanionRoutes {
        AquariumCompanionRoutes(walkingRoute: walkingRoute, swimmingRoute: swimmingRoute)
    }

    func pose(style: CompanionStyle, index: Int, time: Float, reduceMotion: Bool = false) -> AquariumCompanionPose {
        routes.pose(style: style, index: index, time: time, reduceMotion: reduceMotion)
    }

    static func rhythm(style: CompanionStyle, index: Int, time: Float) -> (travel: Float, activity: Float) {
        AquariumCompanionRoutes.rhythm(style: style, index: index, time: time)
    }
}

/// Rendering retains only the finished routes, not the collision triangles or search graph.
struct AquariumCompanionRoutes: Sendable {
    let walkingRoute: AquariumCompanionRoute
    let swimmingRoute: AquariumCompanionRoute

    func pose(style: CompanionStyle, index: Int, time: Float, reduceMotion: Bool = false) -> AquariumCompanionPose {
        let t = max(0, time) * (reduceMotion ? 0.35 : 1)
        let phase = Float(index) * 2.13
        let rhythm = Self.rhythm(style: style, index: index, time: t)
        if style == .snail {
            func position(_ seconds: Float) -> SIMD3<Float> {
                let y = -0.42 + sin(seconds * 0.031) * 0.25
                let z = -1.73 + sin(seconds * 0.019) * 0.11
                let qy = (y - AquariumBowl.center.y) / AquariumBowl.radii.y
                let qz = (z - AquariumBowl.center.z) / AquariumBowl.radii.z
                let x = -AquariumBowl.radii.x * sqrt(max(0, 1 - qy * qy - qz * qz))
                return SIMD3(x, y, z)
            }
            let p = position(rhythm.travel)
            let inward = -simd_normalize((p - AquariumBowl.center) / (AquariumBowl.radii * AquariumBowl.radii))
            // Retain a small upward component at a turnaround; the shell never
            // flips abruptly when the snail pauses on the side wall.
            let direction = position(rhythm.travel + 2) - position(rhythm.travel - 2) + SIMD3(0, 0.005, 0.004)
            return .init(position: p + inward * 0.003, normal: inward,
                         forward: simd_normalize(direction), gait: rhythm.travel * 1.3,
                         activity: rhythm.activity, ambientTime: t)
        }
        let swimming = style == .shrimp || style == .miniSubmarine
        let route = swimming ? swimmingRoute : walkingRoute
        let speed: Float
        switch style {
        case .shrimp: speed = 0.115
        case .miniSubmarine: speed = 0.085
        case .crab: speed = 0.073
        case .seaCucumber: speed = 0.013
        case .seaUrchin: speed = 0.016
        default: speed = 0.024
        }
        let distance = speed * rhythm.travel
            + (swimming ? Float(index) * 1.17 + (style == .miniSubmarine ? 0.85 : 0) : Float(index) * 0.68)
        let c = route.contact(at: distance)
        let ahead = route.contact(at: distance + (swimming ? 0.12 : 0.065))
        let behind = route.contact(at: distance - (swimming ? 0.12 : 0.065))
        var forward = ahead.point - behind.point
        if simd_length_squared(forward) < 0.000001 { forward = SIMD3(1, 0, 0) }
        forward = simd_normalize(forward)
        if style == .miniSubmarine {
            // A buoyant little vessel stays mostly level even as its route climbs.
            forward.y *= 0.28
            forward = simd_normalize(forward)
        }
        var normal = c.normal
        if swimming {
            // Swimmers follow the corridor through ascents and gradual turns.
            let side = simd_normalize(simd_cross(forward, SIMD3<Float>(0, 1, 0)))
            normal = simd_normalize(simd_cross(side, forward))
        }
        return .init(position: c.point + normal * 0.004, normal: normal, forward: forward,
                     gait: style == .miniSubmarine ? rhythm.travel * 18 + t * 2 : (swimming ? t * 9 + phase : distance * (style == .crab ? 72 : 90) + phase),
                     activity: rhythm.activity, ambientTime: t)
    }

    /// Integrate a raised-cosine speed curve, including a true resting interval.
    /// Different cycle lengths and starting phases keep the friends independent.
    static func rhythm(style: CompanionStyle, index: Int, time: Float) -> (travel: Float, activity: Float) {
        let active: Float, rest: Float, ramp: Float
        switch style {
        case .shrimp: (active, rest, ramp) = (18, 5, 2)
        case .miniSubmarine: (active, rest, ramp) = (22, 9, 3)
        case .crab: (active, rest, ramp) = (12, 7, 1.5)
        case .seaCucumber: (active, rest, ramp) = (23, 18, 3.5)
        case .seaUrchin: (active, rest, ramp) = (25, 20, 4)
        case .snail: (active, rest, ramp) = (26, 17, 4)
        default: (active, rest, ramp) = (24, 13, 3)
        }
        let cycle = active + rest
        let offset = (Float(index) * 11.73 + style.motionID * 1.91).truncatingRemainder(dividingBy: cycle)
        func integral(_ t: Float) -> Float {
            let loops = floor(t / cycle), s = t - loops * cycle
            let partial: Float
            if s < ramp { partial = (s - ramp / .pi * sin(.pi * s / ramp)) * 0.5 }
            else if s < active - ramp { partial = s - ramp * 0.5 }
            else if s < active {
                let end = s - (active - ramp)
                partial = active - ramp * 1.5 + (end + ramp / .pi * sin(.pi * end / ramp)) * 0.5
            } else { partial = active - ramp }
            return loops * (active - ramp) + partial
        }
        let s = (time + offset).truncatingRemainder(dividingBy: cycle)
        let activity: Float
        if s < ramp { activity = (1 - cos(.pi * s / ramp)) * 0.5 }
        else if s < active - ramp { activity = 1 }
        else if s < active { activity = (1 + cos(.pi * (s - active + ramp) / ramp)) * 0.5 }
        else { activity = 0 }
        return (integral(time + offset) - integral(offset), activity)
    }
}

extension CompanionStyle {
    var motionID: Float {
        switch self {
        case .none: 0
        case .snail: 1
        case .shrimp: 2
        case .crab: 3
        case .seaCucumber: 4
        case .nudibranchFlame: 5
        case .nudibranchRibbon: 6
        case .miniSubmarine: 7
        case .seaUrchin: 8
        }
    }
}
