import Metal
import Foundation
import simd

// Metal does not annotate buffers as Sendable. These buffers are filled before
// publication and are only read by subsequent command encoders and the GPU.
struct AquariumGPUMesh: @unchecked Sendable {
    let vertices: MTLBuffer
    let indices: MTLBuffer
    let count: Int
    let bounds: (min: SIMD3<Float>, max: SIMD3<Float>)

    init(device: MTLDevice, data: AquariumMeshData) throws {
        guard let v = device.makeBuffer(bytes: data.vertices, length: data.vertices.count * MemoryLayout<AquariumVertex>.stride),
              let i = device.makeBuffer(bytes: data.indices, length: data.indices.count * MemoryLayout<UInt32>.stride) else {
            throw AquariumRenderError.unavailable("Unable to allocate the aquarium geometry.")
        }
        var low = SIMD3<Float>(repeating: .infinity), high = -low
        for vertex in data.vertices {
            low = simd_min(low, vertex.position.xyz); high = simd_max(high, vertex.position.xyz)
        }
        vertices = v; indices = i; count = data.indices.count; bounds = (low, high)
    }
}

struct AquariumFishGPUMesh: Sendable {
    let body: AquariumGPUMesh
    let fins: AquariumGPUMesh
    let features: AquariumGPUMesh
    let bounds: (min: SIMD3<Float>, max: SIMD3<Float>)
}

enum AquariumRenderError: LocalizedError {
    case unavailable(String)
    var errorDescription: String? { if case .unavailable(let reason) = self { return reason }; return nil }
}

// The neutral texture is written only during init; all published resources are immutable.
struct AquariumRenderResources: @unchecked Sendable {
    let device: MTLDevice
    let samples: Int
    let opaque: MTLRenderPipelineState
    let background: MTLRenderPipelineState
    let optics: MTLRenderPipelineState
    let shadow: MTLRenderPipelineState
    let depth: MTLDepthStencilState
    let backgroundDepth: MTLDepthStencilState
    let sand: AquariumGPUMesh
    let bowlGlass: AquariumGPUMesh
    let pellet: AquariumGPUMesh
    let bubbles: AquariumGPUMesh
    let neutralRefraction: MTLTexture

    init(device: MTLDevice, samples: Int) throws {
        self.device = device; self.samples = samples
        let library = try device.makeLibrary(source: AquariumDepthShaders.source, options: nil)
        func pipeline(_ vertex: String, _ fragment: String, presentation: Bool = false, shadow: Bool = false) throws -> MTLRenderPipelineState {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: vertex)
            descriptor.fragmentFunction = library.makeFunction(name: fragment)
            descriptor.colorAttachments[0].pixelFormat = shadow ? .invalid : (presentation ? .bgra8Unorm_srgb : .rgba16Float)
            descriptor.depthAttachmentPixelFormat = presentation ? .invalid : .depth32Float
            descriptor.rasterSampleCount = presentation || shadow ? 1 : samples
            return try device.makeRenderPipelineState(descriptor: descriptor)
        }
        opaque = try pipeline("aquariumDepthVertex", "aquariumDepthFragment")
        background = try pipeline("aquariumBackgroundVertex", "aquariumBackgroundFragment")
        optics = try pipeline("aquariumBackgroundVertex", "aquariumOpticsFragment", presentation: true)
        shadow = try pipeline("aquariumDepthVertex", "aquariumShadowFragment", shadow: true)
        func depthState(write: Bool, compare: MTLCompareFunction) throws -> MTLDepthStencilState {
            let descriptor = MTLDepthStencilDescriptor()
            descriptor.isDepthWriteEnabled = write; descriptor.depthCompareFunction = compare
            guard let result = device.makeDepthStencilState(descriptor: descriptor) else {
                throw AquariumRenderError.unavailable("Unable to prepare aquarium depth testing.")
            }
            return result
        }
        depth = try depthState(write: true, compare: .lessEqual)
        backgroundDepth = try depthState(write: false, compare: .always)
        sand = try AquariumGPUMesh(device: device, data: AquariumGeometry.sand())
        bowlGlass = try AquariumGPUMesh(device: device, data: AquariumGeometry.bowlGlass())
        pellet = try AquariumGPUMesh(device: device, data: AquariumGeometry.sphere(radius: 0.009))
        bubbles = try AquariumGPUMesh(device: device, data: AquariumGeometry.bubbles())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: 1, height: 1, mipmapped: false)
        descriptor.usage = .shaderRead
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw AquariumRenderError.unavailable("Unable to prepare glass materials.")
        }
        let pixels: [UInt8] = [203, 210, 208, 255]
        pixels.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 4) }
        neutralRefraction = texture
    }
}

// A snapshot owns its staging buffer exclusively and hands it to the CPU only
// after that buffer's GPU completion callback has fired.
struct AquariumReadbackBuffer: @unchecked Sendable {
    let buffer: MTLBuffer
}

struct AquariumPreparedCatalog: Sendable {
    let layout: AquariumHabitatLayout
    let decoration: AquariumGPUMesh?
    let features: [AquariumGPUMesh]
    let companions: [AquariumGPUMesh]
    let fish: [FishSpecies: AquariumFishGPUMesh]
    let routes: AquariumCompanionRoutes?
}

/// This actor owns construction and caches. Published buffers and routes are immutable.
/// UIKit and the render loop only receive completed resources, never collision-building work.
actor AquariumRenderResourceStore {
    static let shared = AquariumRenderResourceStore()
    private let device = MTLCreateSystemDefaultDevice()
    private var pipelines: [Int: AquariumRenderResources] = [:]
    private var fish: [FishSpecies: AquariumFishGPUMesh] = [:]
    private var companions: [CompanionStyle: AquariumGPUMesh] = [:]
    private struct Habitat {
        let layout: AquariumHabitatLayout
        let decoration: AquariumGPUMesh?
        let features: [AquariumGPUMesh]
    }
    private var habitats: [(String, Habitat)] = []
    private var routes: [(String, AquariumCompanionRoutes)] = []
    #if DEBUG
    private(set) var routeBuildCount = 0
    #endif

    func resources(multisampling: Bool) throws -> AquariumRenderResources {
        try Task.checkCancellation()
        guard let device else { throw AquariumRenderError.unavailable("Metal rendering is not available.") }
        let samples = multisampling && device.supportsTextureSampleCount(4) ? 4 : 1
        if let cached = pipelines[samples] { return cached }
        let result = try AquariumRenderResources(device: device, samples: samples)
        pipelines[samples] = result
        return result
    }

    func catalog(configuration: AquariumConfiguration, baby: FishSpecies? = nil, needsRoutes: Bool) throws -> AquariumPreparedCatalog {
        try Task.checkCancellation()
        guard let device else { throw AquariumRenderError.unavailable("Metal rendering is not available.") }
        let features = configuration.resolvedFeaturePieces
        let key = "\(configuration.decoration.rawValue)/\(features.map(\.rawValue).joined(separator: ","))"
        let habitat: Habitat
        if let index = habitats.firstIndex(where: { $0.0 == key }) {
            let cached = habitats.remove(at: index)
            habitats.append(cached); habitat = cached.1
        } else {
            let layout = AquariumHabitatLayout(decoration: configuration.decoration, features: features)
            habitat = try Habitat(layout: layout,
                decoration: layout.decoration.mesh.indices.isEmpty ? nil : AquariumGPUMesh(device: device, data: layout.decoration.mesh),
                features: layout.features.map { try AquariumGPUMesh(device: device, data: $0.piece.mesh) })
            habitats.append((key, habitat))
            if habitats.count > 3 { habitats.removeFirst() }
        }
        var preparedFish: [FishSpecies: AquariumFishGPUMesh] = [:]
        for species in configuration.resolvedFishSpecies + (baby.map { [$0] } ?? []) {
            try Task.checkCancellation()
            if fish[species] == nil {
                let body = AquariumCatalog.body(species), fins = AquariumCatalog.fins(species)
                var low = SIMD3<Float>(repeating: .infinity), high = -low
                for mesh in [body, fins] { for v in mesh.vertices {
                    low = simd_min(low, v.position.xyz); high = simd_max(high, v.position.xyz)
                } }
                fish[species] = try AquariumFishGPUMesh(body: AquariumGPUMesh(device: device, data: body),
                    fins: AquariumGPUMesh(device: device, data: fins),
                    features: AquariumGPUMesh(device: device, data: AquariumCatalog.features(species)), bounds: (low, high))
            }
            preparedFish[species] = fish[species]
        }
        let preparedCompanions = try configuration.resolvedCompanions.map { style in
            if let cached = companions[style] { return cached }
            let mesh = try AquariumGPUMesh(device: device, data: AquariumCatalog.companion(style))
            companions[style] = mesh
            return mesh
        }
        var preparedRoutes: AquariumCompanionRoutes?
        if needsRoutes && !preparedCompanions.isEmpty {
            try Task.checkCancellation()
            if let index = routes.firstIndex(where: { $0.0 == key }) {
                let cached = routes.remove(at: index)
                routes.append(cached); preparedRoutes = cached.1
            } else {
                let result = AquariumCompanionHabitat(decoration: configuration.decoration, features: features).routes
                routes.append((key, result)); preparedRoutes = result
                if routes.count > 12 { routes.removeFirst() }
                #if DEBUG
                routeBuildCount += 1
                #endif
            }
        }
        try Task.checkCancellation()
        return AquariumPreparedCatalog(layout: habitat.layout, decoration: habitat.decoration,
            features: habitat.features, companions: preparedCompanions, fish: preparedFish, routes: preparedRoutes)
    }
}
