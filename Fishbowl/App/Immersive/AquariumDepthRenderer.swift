import CoreMotion
import MetalKit
import SwiftUI
import simd

@MainActor
@Observable
final class AquariumExperience {
    var configuration = AquariumConfiguration.murano
    var profile: BowlProfile?
    var snapshotOverride: AquariumPetSnapshot?
    var previewFocusY: Float?
    var daylight = true
    var tiltEnabled = true
    var recentInteraction = 0
    var mealsConsumed = 0
    var isFeeding = false
    var hasRenderedFrame = false
    var errorMessage: String?
    var onFeed: (() -> Void)?
    var onCenter: (() -> Void)?
    var onMealConsumed: (() -> Void)?
}

private struct AquariumUniforms {
    var viewProjection: simd_float4x4
    var model = matrix_identity_float4x4
    var lightViewProjection: simd_float4x4
    var inverseViewProjection: simd_float4x4
    var camera: SIMD4<Float>
    var control: SIMD4<Float>
    var interaction: SIMD4<Float>
    var fishLight: SIMD4<Float>
    var catalog: SIMD4<Float> // species, substrate, feature, vitality
    var companionMotion = SIMD4<Float>.zero // species, gait, activity, ambient time
    var wallLower = SIMD4<Float>.zero
    var wallUpper = SIMD4<Float>.zero
    var themeKey = SIMD4<Float>.zero
    var themeFill = SIMD4<Float>.zero
    var featureLight0 = SIMD4<Float>.zero
    var featureLight1 = SIMD4<Float>.zero
    var widget = SIMD4<Float>.zero // enabled, circular outline, half width, half height
}

struct AquariumMetalView: UIViewRepresentable {
    let experience: AquariumExperience
    let active: Bool
    let reduceMotion: Bool
    var preview = false
    var interactive = true

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.backgroundColor = UIColor(red: 0.01, green: 0.07, blue: 0.06, alpha: 1)
        view.colorPixelFormat = .bgra8Unorm_srgb
        view.contentScaleFactor = preview ? 1 : 2
        view.depthStencilPixelFormat = .invalid
        view.clearColor = MTLClearColor(red: 0.008, green: 0.035, blue: 0.026, alpha: 1)
        view.sampleCount = 1
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.preferredFramesPerSecond = preview || ProcessInfo.processInfo.isLowPowerModeEnabled ? 30 : 60
        view.isAccessibilityElement = true
        view.accessibilityLabel = "Aquarium with an amber glass fish"
        view.accessibilityHint = interactive
            ? (preview ? "Double tap to feed." : "Tap to feed. Double tap to center the view. Drag to look around the aquarium.")
            : "Aquarium preview."
        view.accessibilityTraits = interactive ? [.allowsDirectInteraction] : [.image]
        context.coordinator.start(view: view, experience: experience, preview: preview, interactive: interactive)
        #if DEBUG
        if preview { AquariumPerformanceDiagnostics.previewCreated(view, profile: experience.profile) }
        #endif
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        view.accessibilityLabel = "Aquarium with \(experience.configuration.resolvedFishSpecies.map(\.title).joined(separator: ", "))"
        view.isPaused = !active
        context.coordinator.active = active
        context.coordinator.reduceMotion = reduceMotion
        context.coordinator.renderer?.configure(active: active, reduceMotion: reduceMotion)
        if !active { view.setNeedsDisplay() }
    }

    static func dismantleUIView(_ view: MTKView, coordinator: Coordinator) {
        #if DEBUG
        AquariumPerformanceDiagnostics.previewRemoved(view)
        #endif
        view.isPaused = true
        view.delegate = nil
        coordinator.startup?.cancel()
        coordinator.renderer?.stop()
        coordinator.renderer = nil
    }

    @MainActor final class Coordinator {
        var renderer: AquariumDepthRenderer?
        var startup: Task<Void, Never>?
        var active = false
        var reduceMotion = false

        func start(view: MTKView, experience: AquariumExperience, preview: Bool, interactive: Bool) {
            startup = Task { [weak self, weak view] in
                do {
                    guard !Task.isCancelled else { return }
                    experience.hasRenderedFrame = false
                    experience.errorMessage = nil
                    var multisampling = !preview
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-AquariumNoMSAA") { multisampling = false }
                    if preview && ProcessInfo.processInfo.arguments.contains("-AquariumPreviewLoadingQA") {
                        try await Task.sleep(for: .seconds(20))
                    }
                    #endif
                    let resources = try await AquariumRenderResourceStore.shared.resources(multisampling: multisampling)
                    guard !Task.isCancelled, let self, let view else { return }
                    let renderer = try AquariumDepthRenderer(view: view, experience: experience,
                        resources: resources, diagnostics: !preview, preview: preview)
                    self.renderer = renderer
                    view.delegate = renderer
                    if interactive {
                        let tap = UITapGestureRecognizer(target: renderer, action: #selector(AquariumDepthRenderer.tap(_:)))
                        if !preview {
                            let pan = UIPanGestureRecognizer(target: renderer, action: #selector(AquariumDepthRenderer.pan(_:)))
                            let doubleTap = UITapGestureRecognizer(target: renderer, action: #selector(AquariumDepthRenderer.doubleTap(_:)))
                            doubleTap.numberOfTapsRequired = 2
                            doubleTap.require(toFail: pan); tap.require(toFail: pan); tap.require(toFail: doubleTap)
                            view.addGestureRecognizer(pan); view.addGestureRecognizer(doubleTap)
                        }
                        view.addGestureRecognizer(tap)
                    }
                    renderer.configure(active: active, reduceMotion: reduceMotion)
                    view.isPaused = !active
                    view.setNeedsDisplay()
                } catch is CancellationError {
                } catch { experience.errorMessage = error.localizedDescription }
            }
        }
    }
}

@MainActor
final class AquariumDepthRenderer: NSObject, MTKViewDelegate {
    private let experience: AquariumExperience
    private let preview: Bool
    private var widgetFormat: AquariumDisplayFormat?
    private let sceneSamples: Int
    private weak var view: MTKView?
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let opaque: MTLRenderPipelineState
    private let background: MTLRenderPipelineState
    private let optics: MTLRenderPipelineState
    private let shadowPipeline: MTLRenderPipelineState
    private let shadowTexture: MTLTexture
    private let depth: MTLDepthStencilState
    private let backgroundDepth: MTLDepthStencilState
    private let sand: AquariumGPUMesh
    private let bowlGlass: AquariumGPUMesh
    private var decoration: AquariumGPUMesh?
    private var features: [AquariumGPUMesh] = []
    private var habitatLayout: AquariumHabitatLayout?
    private var companions: [AquariumGPUMesh] = []
    private var companionRoutes: AquariumCompanionRoutes?
    private var catalogTask: Task<Void, Never>?
    private var pendingConfiguration: AquariumConfiguration?
    private var pendingProfileID: UUID?
    private var pendingBaby: FishSpecies?
    private var preparedBaby: FishSpecies?
    private var themePalette = AquariumTheme.ivory.palette
    private var didRenderTheme = false
    private var diagnosticCompanionTime: Float = 0
    private var diagnosticCompanionRate: Float = 1
    private var companionOrientations: [simd_quatf] = []
    private var fishMeshes: [FishSpecies: AquariumFishGPUMesh] = [:]
    private var configuration = AquariumConfiguration.murano
    private var profileID: UUID?
    private let pellet: AquariumGPUMesh
    private let bubbles: AquariumGPUMesh
    private let neutralRefraction: MTLTexture
    private var refractionColor: MTLTexture?
    private var refractionMSAA: MTLTexture?
    private var refractionDepth: MTLTexture?
    private var sculptureColor: MTLTexture?
    private var sceneColor: MTLTexture?
    private var sceneMSAA: MTLTexture?
    private var sceneDepth: MTLTexture?
    private let motion = CMMotionManager()
    private var neutral: simd_quatf?
    private var dynamics = AquariumDynamics()
    private var lastFrame: CFTimeInterval?
    private var light: Float = 1
    private var ripple = SIMD2<Float>(0.5, 0.5)
    private var rippleTime: Float = -100
    private var isActive = false
    private var diagnosticOffset: SIMD2<Float>?
    private var diagnosticFreeze = false
    private var needsInitialFrame = true
    private var firstFrameScheduled = false

    init(view: MTKView, experience: AquariumExperience, resources: AquariumRenderResources, diagnostics: Bool = true, preview: Bool = false,
         widgetFormat: AquariumDisplayFormat? = nil) throws {
        let device = resources.device
        guard let queue = device.makeCommandQueue() else {
            throw AquariumRenderError.unavailable("Metal rendering is not available on this device.")
        }
        self.device = device; self.queue = queue; self.experience = experience
        self.view = view; self.preview = preview; self.widgetFormat = widgetFormat
        sceneSamples = resources.samples
        opaque = resources.opaque; background = resources.background; optics = resources.optics
        shadowPipeline = resources.shadow
        depth = resources.depth; backgroundDepth = resources.backgroundDepth
        sand = resources.sand; bowlGlass = resources.bowlGlass
        pellet = resources.pellet; bubbles = resources.bubbles
        neutralRefraction = resources.neutralRefraction
        let shadowImage = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: 1024, height: 1024, mipmapped: false)
        shadowImage.usage = [.renderTarget, .shaderRead]; shadowImage.storageMode = .private
        guard let shadowTexture = device.makeTexture(descriptor: shadowImage) else {
            throw AquariumRenderError.unavailable("Unable to allocate the aquarium lighting buffer.")
        }
        self.shadowTexture = shadowTexture
        super.init()
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        experience.onFeed = { [weak self] in self?.feed(at: SIMD2(0.5, 0.3)) }
        experience.onCenter = { [weak self] in self?.center() }
        #if DEBUG
        if diagnostics {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-AquariumTheme"), args.indices.contains(index + 1),
           let theme = AquariumTheme(rawValue: args[index + 1]) { experience.configuration.theme = theme }
        if let index = args.firstIndex(of: "-AquariumSpecies"), args.indices.contains(index + 1),
           let species = FishSpecies(rawValue: args[index + 1]) { experience.configuration.fishSpecies = species }
        if let index = args.firstIndex(of: "-AquariumCompanion"), args.indices.contains(index + 1),
           let companion = CompanionStyle(rawValue: args[index + 1]) { experience.configuration.companions = [companion] }
        if let index = args.firstIndex(of: "-AquariumFriends"), args.indices.contains(index + 1) {
            experience.configuration.companions = args[index + 1].split(separator: ",").compactMap { CompanionStyle(rawValue: String($0)) }
        }
        if let index = args.firstIndex(of: "-AquariumCompanionTime"), args.indices.contains(index + 1),
           let seconds = Float(args[index + 1]), seconds.isFinite { diagnosticCompanionTime = max(0, seconds) }
        if let index = args.firstIndex(of: "-AquariumCompanionRate"), args.indices.contains(index + 1),
           let rate = Float(args[index + 1]), rate.isFinite { diagnosticCompanionRate = min(20, max(0, rate)) }
        if let index = args.firstIndex(of: "-AquariumDecoration"), args.indices.contains(index + 1),
           let decoration = DecorationStyle(rawValue: args[index + 1]) { experience.configuration.decoration = decoration }
        if let index = args.firstIndex(of: "-AquariumFeature"), args.indices.contains(index + 1),
           let feature = FeaturePieceStyle(rawValue: args[index + 1]) { experience.configuration.featurePiece = feature }
        if let index = args.firstIndex(of: "-AquariumFeatures"), args.indices.contains(index + 1) {
            experience.configuration.featurePieces = args[index + 1].split(separator: ",").compactMap { FeaturePieceStyle(rawValue: String($0)) }
        }
        if let index = args.firstIndex(of: "-AquariumSubstrate"), args.indices.contains(index + 1),
           let substrate = SubstrateStyle(rawValue: args[index + 1]) { experience.configuration.substrate = substrate }
        if args.contains("-AquariumTrio") {
            experience.configuration.fishCount = .trio
            experience.configuration.additionalFishSpecies = [.moonKoi, .opalAngelfish]
        }
        if args.contains("-AquariumEvening") { experience.daylight = false; light = 0 }
        if args.contains("-AquariumLookLeft") { diagnosticOffset = SIMD2(-1, diagnosticOffset?.y ?? 0) }
        if args.contains("-AquariumLookRight") { diagnosticOffset = SIMD2(1, diagnosticOffset?.y ?? 0) }
        if args.contains("-AquariumLookUp") { diagnosticOffset = SIMD2(diagnosticOffset?.x ?? 0, 1) }
        if args.contains("-AquariumLookDown") { diagnosticOffset = SIMD2(diagnosticOffset?.x ?? 0, -1) }
        if args.contains("-AquariumFreeze") {
            dynamics.drag = diagnosticOffset ?? .zero
            for _ in 0..<120 { dynamics.step(delta: 1.0 / 60.0) }
            diagnosticFreeze = true
        }
        }
        #endif
        if widgetFormat == nil { requestCatalog() }
    }

    func configure(active: Bool, reduceMotion: Bool) {
        var withoutThemeChange = experience.configuration
        withoutThemeChange.theme = configuration.theme
        let baby = experience.profile?.petSnapshot(at: .now).babySpecies
        if withoutThemeChange == configuration && profileID == experience.profile?.id && baby == preparedBaby && habitatLayout != nil {
            if configuration.theme != experience.configuration.theme {
                configuration.theme = experience.configuration.theme
                needsInitialFrame = true
            }
            // A → B → A while B is preparing must not install B later.
            if pendingConfiguration != experience.configuration || pendingProfileID != experience.profile?.id || pendingBaby != baby {
                catalogTask?.cancel(); catalogTask = nil
                pendingConfiguration = experience.configuration
                pendingProfileID = experience.profile?.id; pendingBaby = baby
            }
        } else { requestCatalog() }
        dynamics.reduceMotion = reduceMotion
        dynamics.motionEnabled = experience.tiltEnabled
        if active != isActive { lastFrame = nil }
        isActive = active
        if active && experience.tiltEnabled && !reduceMotion && motion.isDeviceMotionAvailable {
            if !motion.isDeviceMotionActive { neutral = nil; motion.startDeviceMotionUpdates(using: .xArbitraryZVertical) }
        } else {
            motion.stopDeviceMotionUpdates(); neutral = nil; dynamics.tilt = .zero
        }
    }

    func stop() {
        catalogTask?.cancel(); catalogTask = nil
        motion.stopDeviceMotionUpdates()
        experience.onFeed = nil
        experience.onCenter = nil
    }

    private func center() { neutral = nil; dynamics.recenter() }

    @objc func pan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view else { return }
        let translation = gesture.translation(in: view)
        switch gesture.state {
        case .began, .changed:
            dynamics.drag = AquariumParallax.drag(translation: SIMD2(Float(translation.x), Float(translation.y)),
                                                   viewport: SIMD2(Float(view.bounds.width), Float(view.bounds.height)))
        default: dynamics.drag = .zero
        }
        if gesture.state == .began { experience.recentInteraction += 1 }
    }

    @objc func tap(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        let p = gesture.location(in: view)
        feed(at: SIMD2(Float(p.x / max(view.bounds.width, 1)), Float(p.y / max(view.bounds.height, 1))))
    }

    @objc func doubleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        center()
        experience.recentInteraction += 1
    }

    private func feed(at point: SIMD2<Float>) {
        ripple = point; rippleTime = dynamics.time
        guard experience.profile?.petSnapshot(at: .now).isAlive != false else {
            experience.recentInteraction += 1
            return
        }
        if dynamics.feed(at: point.x) { experience.isFeeding = true }
        experience.recentInteraction += 1
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        needsInitialFrame = true
        view.setNeedsDisplay()
    }

    private func requestCatalog() {
        let next = experience.configuration, id = experience.profile?.id
        let baby = experience.profile?.petSnapshot(at: .now).babySpecies
        guard pendingConfiguration != next || pendingProfileID != id || pendingBaby != baby else { return }
        pendingConfiguration = next; pendingProfileID = id; pendingBaby = baby
        catalogTask?.cancel()
        catalogTask = Task { [weak self] in
            do {
                let prepared = try await AquariumRenderResourceStore.shared.catalog(configuration: next, baby: baby, needsRoutes: true)
                guard !Task.isCancelled, let self else { return }
                guard experience.configuration == next, experience.profile?.id == id,
                      experience.profile?.petSnapshot(at: .now).babySpecies == baby else {
                    requestCatalog()
                    return
                }
                install(prepared, configuration: next, profileID: id, baby: baby)
                catalogTask = nil
                view?.setNeedsDisplay()
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled, let self else { return }
                pendingConfiguration = nil
                experience.errorMessage = error.localizedDescription
            }
        }
    }

    private func install(_ prepared: AquariumPreparedCatalog, configuration next: AquariumConfiguration, profileID id: UUID?, baby: FishSpecies?) {
        let reset = configuration != next || profileID != id
        decoration = prepared.decoration; features = prepared.features; companions = prepared.companions
        habitatLayout = prepared.layout; companionRoutes = prepared.routes
        fishMeshes = prepared.fish; preparedBaby = baby
        companionOrientations = []
        configuration = next; profileID = id
        if reset && !diagnosticFreeze {
            let reduced = dynamics.reduceMotion, motionEnabled = dynamics.motionEnabled
            dynamics = AquariumDynamics(); dynamics.reduceMotion = reduced; dynamics.motionEnabled = motionEnabled
            experience.mealsConsumed = 0; experience.isFeeding = false; rippleTime = -100
        }
        needsInitialFrame = true
    }

    func prepareSnapshot(_ prepared: AquariumPreparedCatalog, format: AquariumDisplayFormat) {
        widgetFormat = format
        install(prepared, configuration: experience.configuration, profileID: nil, baby: experience.snapshotOverride?.babySpecies)
        lastFrame = nil
    }

    #if DEBUG
    var diagnosticConfiguration: AquariumConfiguration { configuration }
    var diagnosticProfileID: UUID? { profileID }
    var diagnosticSceneSamples: Int { sceneSamples }
    func diagnosticWaitForCatalog() async { await catalogTask?.value }
    #endif

    private func prepareRefraction(for view: MTKView) -> Bool {
        let width = max(1, Int(view.drawableSize.width))
        let height = max(1, Int(view.drawableSize.height))
        if sceneColor?.width == width && sceneColor?.height == height,
           sculptureColor != nil && sceneDepth != nil && refractionColor != nil && refractionDepth != nil,
           sceneSamples == 1 || (sceneMSAA != nil && refractionMSAA != nil) { return true }
        func texture(_ format: MTLPixelFormat, samples: Int, readable: Bool, scale: Int = 1) -> MTLTexture? {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: max(1, width / scale), height: max(1, height / scale), mipmapped: false)
            descriptor.textureType = samples > 1 ? .type2DMultisample : .type2D
            descriptor.sampleCount = samples
            descriptor.storageMode = .private
            descriptor.usage = readable ? [.renderTarget, .shaderRead] : .renderTarget
            return device.makeTexture(descriptor: descriptor)
        }
        refractionColor = texture(.rgba16Float, samples: 1, readable: true, scale: 2)
        refractionMSAA = sceneSamples > 1 ? texture(.rgba16Float, samples: sceneSamples, readable: false, scale: 2) : nil
        refractionDepth = texture(.depth32Float, samples: sceneSamples, readable: false, scale: 2)
        sculptureColor = texture(.rgba16Float, samples: 1, readable: true)
        sceneColor = texture(.rgba16Float, samples: 1, readable: true)
        sceneMSAA = sceneSamples > 1 ? texture(.rgba16Float, samples: sceneSamples, readable: false) : nil
        sceneDepth = texture(.depth32Float, samples: sceneSamples, readable: false)
        return refractionColor != nil && refractionDepth != nil && sculptureColor != nil && sceneColor != nil && sceneDepth != nil
            && (sceneSamples == 1 || (refractionMSAA != nil && sceneMSAA != nil))
    }

    func draw(in view: MTKView) {
        guard isActive || needsInitialFrame, habitatLayout != nil else { return }
        guard let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable else { return }
        render(in: view, presentation: pass, drawable: drawable)
    }

    private func render(in view: MTKView, presentation pass: MTLRenderPassDescriptor, drawable: CAMetalDrawable?) {
        guard isActive || needsInitialFrame, habitatLayout != nil, view.drawableSize.width > 0, view.drawableSize.height > 0 else { return }
        let now = CACurrentMediaTime()
        let dt = Float(min(max(now - (lastFrame ?? now), 0), 1.0 / 15.0)); lastFrame = now
        if let q = motion.deviceMotion?.attitude.quaternion, dynamics.motionEnabled, !dynamics.reduceMotion {
            let current = simd_quatf(ix: Float(q.x), iy: Float(q.y), iz: Float(q.z), r: Float(q.w))
            if neutral == nil { neutral = current }
            if let neutral {
                dynamics.tilt = AquariumParallax.tilt(relativeOrientation: neutral.inverse * current)
            }
        }
        if let diagnosticOffset { dynamics.drag = diagnosticOffset }
        let populationScale: Float = configuration.fishCount == .solo ? 1 : (configuration.fishCount == .duet ? 0.75 : 0.65)
        switch configuration.personality {
        case .playful: dynamics.swimTempo = 1.15
        case .shy: dynamics.swimTempo = 0.72
        case .greedy: dynamics.swimTempo = 1.02
        case .dreamy: dynamics.swimTempo = 0.58
        }
        let mouth = configuration.fishSpecies.glassMouth * configuration.fishSpecies.glassScale * populationScale
        dynamics.mouthReach = mouth.x
        dynamics.mouthHeight = mouth.y
        if !diagnosticFreeze && isActive { dynamics.step(delta: dt) }
        light += ((experience.daylight ? 1 : 0) - light) * (1 - exp(-dt * 2.0))
        if experience.mealsConsumed != dynamics.mealsConsumed {
            experience.mealsConsumed = dynamics.mealsConsumed
            experience.onMealConsumed?()
        }
        if experience.isFeeding != dynamics.isFeeding { experience.isFeeding = dynamics.isFeeding }
        guard let command = queue.makeCommandBuffer() else { return }
        command.label = "Aquarium frame"
        let aspect = Float(view.drawableSize.width / view.drawableSize.height)
        let widget = widgetFormat.map { _ in AquariumWidgetLayout(aspect: aspect, round: false) }
        let vp = widget == nil
            ? AquariumCamera.viewProjection(aspect: aspect, offset: dynamics.camera, preview: preview, focusY: experience.previewFocusY)
            : AquariumCamera.widgetProjection(aspect: aspect)
        var u = AquariumUniforms(viewProjection: vp,
                                 lightViewProjection: AquariumCamera.lightViewProjection(),
                                 inverseViewProjection: simd_inverse(vp),
                                 camera: SIMD4(AquariumCamera.position(offset: dynamics.camera, aspect: aspect, preview: preview), Float(view.drawableSize.height)),
                                 control: SIMD4(dynamics.time, 0, light, aspect),
                                 interaction: SIMD4(ripple.x, ripple.y, dynamics.time - rippleTime, dynamics.reduceMotion ? 0.25 : 1),
                                 fishLight: SIMD4(dynamics.fish, 0),
                                 catalog: SIMD4(configuration.fishSpecies.glassID,
                                    Float(SubstrateStyle.allCases.firstIndex(of: configuration.substrate) ?? 0),
                                    Float(FeaturePieceStyle.allCases.firstIndex(of: configuration.featurePiece) ?? 0), 1))
        let snapshot = experience.snapshotOverride ?? experience.profile?.petSnapshot(at: .now)
        let targetPalette = configuration.theme.palette
        if !didRenderTheme || !isActive || dynamics.reduceMotion { themePalette = targetPalette }
        else { themePalette = themePalette.blended(toward: targetPalette, amount: 1 - exp(-dt * 7)) }
        didRenderTheme = true
        u.wallLower = themePalette.lower; u.wallUpper = themePalette.upper
        u.themeKey = themePalette.key; u.themeFill = themePalette.fill
        if let widget {
            u.widget = SIMD4(1, widget.round ? 1 : 0, widget.halfWidth, widget.halfHeight)
            u.camera = SIMD4(0, 0, 8, Float(view.drawableSize.height))
            u.control.z = experience.daylight ? 1 : 0
        }
        u.catalog.w = Float(snapshot?.vitality ?? 1)
        var species = snapshot?.isAlive == false ? [] : configuration.resolvedFishSpecies
        if let baby = snapshot?.babySpecies {
            if fishMeshes[baby] != nil { species.append(baby) }
            else if widgetFormat == nil { requestCatalog() }
        }
        var fish: [(mesh: AquariumFishGPUMesh, model: simd_float4x4, species: FishSpecies, phase: Float)] = []
        for (index, kind) in species.enumerated() {
            guard let mesh = fishMeshes[kind] else { continue }
            let k = Float(index), t = dynamics.swimTime
            let isBaby = index >= configuration.fishCount.value
            let position = index == 0 ? dynamics.fish : SIMD3<Float>(
                sin(t * 0.16 + k * 2.1) * 0.28,
                (isBaby ? 0.86 : 0.36 - k * 0.49) + sin(t * 0.21 + k) * 0.075,
                -0.20 - k * 0.10 + sin(t * 0.13 + k) * 0.09)
            let yaw = index == 0 ? dynamics.heading : atan2(-cos(t * 0.13 + k) * 0.012, cos(t * 0.16 + k * 2.1) * 0.045)
            let scale = kind.glassScale * populationScale * (isBaby ? 0.43 : 1)
            let model = widget?.fishModel(kind, index: index, count: species.count, baby: isBaby, knownBounds: mesh.bounds)
                ?? AquariumCamera.model(position: position, yaw: yaw, scale: scale)
            fish.append((mesh, model, kind, k * 2.4))
        }
        let decorationMaterial: Float = configuration.decoration == .riverRocks ? 0 : 10
        guard let habitatLayout else { return }
        let paired = features.count == 2
        let hasDecoration = decoration != nil
        let decorationModel = widget.map {
            paired ? $0.pairedPropModel(habitatLayout.decoration.mesh, index: 0, hasDecoration: true)
                : $0.propModel(habitatLayout.decoration.mesh, feature: false)
        } ?? matrix_identity_float4x4
        let featureModels = habitatLayout.features.enumerated().map { index, item in
            widget.map {
                paired ? $0.pairedPropModel(item.piece.mesh, index: index + (hasDecoration ? 1 : 0), hasDecoration: hasDecoration)
                    : $0.propModel(item.piece.mesh, feature: true)
            } ?? matrix_identity_float4x4
        }
        let featureMaterials: [Float] = habitatLayout.features.map { $0.style == .kelp ? 2 : 10 }
        for (index, item) in habitatLayout.features.enumerated() where item.style == .moonLantern {
            let source = item.piece.position(SIMD3(0.44, -1.50, -0.35))
            let position = featureModels[index] * SIMD4(source, 1)
            let scale = item.piece.scale * simd_length(featureModels[index].columns.0.xyz)
            let pool = SIMD4(position.xyz, scale)
            if index == 0 { u.featureLight0 = pool } else { u.featureLight1 = pool }
        }
        var companionModels: [simd_float4x4] = []
        var companionMotions: [SIMD4<Float>] = []
        for index in companions.indices {
            let style = configuration.resolvedCompanions[index]
            if let widget {
                companionModels.append(widget.companionModel(style, index: index, count: companions.count))
                companionMotions.append(SIMD4(style.motionID, 0, 0, 0))
                continue
            }
            let pose = companionRoutes!.pose(style: style, index: index,
                time: dynamics.time * diagnosticCompanionRate + diagnosticCompanionTime, reduceMotion: dynamics.reduceMotion)
            var model = pose.model(scale: 1)
            let desired = simd_quatf(model)
            if companionOrientations.count <= index { companionOrientations.append(desired) }
            else if !diagnosticFreeze && isActive {
                let rate: Float = style == .shrimp || style == .crab ? 5 : 2
                companionOrientations[index] = simd_slerp(companionOrientations[index], desired, 1 - exp(-dt * rate))
            }
            model = simd_float4x4(companionOrientations[index])
            let scale: Float = companions.count == 1 ? 1.12 : 0.86
            model.columns.0 *= scale; model.columns.1 *= scale; model.columns.2 *= scale
            model.columns.3 = SIMD4(pose.position, 1)
            companionModels.append(model)
            companionMotions.append(SIMD4(style.motionID, pose.gait, pose.activity, pose.ambientTime))
        }
        let shadowPass = MTLRenderPassDescriptor()
        shadowPass.depthAttachment.texture = shadowTexture
        shadowPass.depthAttachment.loadAction = .clear
        shadowPass.depthAttachment.storeAction = .store
        shadowPass.depthAttachment.clearDepth = 1
        if let shadowEncoder = command.makeRenderCommandEncoder(descriptor: shadowPass) {
            shadowEncoder.label = "Live aquarium shadows"
            shadowEncoder.setRenderPipelineState(shadowPipeline)
            shadowEncoder.setDepthStencilState(depth)
            shadowEncoder.setCullMode(.none)
            shadowEncoder.setDepthBias(0.001, slopeScale: 1, clamp: 0.015)
            var s = u; s.viewProjection = u.lightViewProjection
            func cast(_ mesh: AquariumGPUMesh, material: Float, model: simd_float4x4 = matrix_identity_float4x4) {
                s.model = model; s.control.y = material
                shadowEncoder.setVertexBuffer(mesh.vertices, offset: 0, index: 0)
                shadowEncoder.setVertexBytes(&s, length: MemoryLayout<AquariumUniforms>.stride, index: 1)
                shadowEncoder.setFragmentBytes(&s, length: MemoryLayout<AquariumUniforms>.stride, index: 1)
                shadowEncoder.drawIndexedPrimitives(type: .triangle, indexCount: mesh.count, indexType: .uint32,
                                                    indexBuffer: mesh.indices, indexBufferOffset: 0)
            }
            if let decoration { cast(decoration, material: decorationMaterial, model: decorationModel) }
            for index in features.indices {
                cast(features[index], material: featureMaterials[index], model: featureModels[index])
            }
            for (index, companion) in companions.enumerated() {
                s.companionMotion = companionMotions[index]
                cast(companion, material: 10, model: companionModels[index])
            }
            for item in fish {
                s.catalog.x = item.species.glassID
                s.control.x = dynamics.time + item.phase
                cast(item.mesh.body, material: 3, model: item.model)
                cast(item.mesh.fins, material: 4, model: item.model)
            }
            shadowEncoder.endEncoding()
        }
        guard prepareRefraction(for: view), let refractionColor, let refractionDepth,
              let sculptureColor, let sceneColor, let sceneDepth else {
            experience.errorMessage = "Unable to prepare the glass refraction buffer."
            return
        }
        func drawMesh(_ encoder: MTLRenderCommandEncoder, uniforms: inout AquariumUniforms,
                      mesh: AquariumGPUMesh, material: Float, backdrop: MTLTexture,
                      model: simd_float4x4 = matrix_identity_float4x4) {
            uniforms.control.y = material; uniforms.model = model
            encoder.setRenderPipelineState(opaque)
            encoder.setDepthStencilState(depth)
            encoder.setVertexBuffer(mesh.vertices, offset: 0, index: 0)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<AquariumUniforms>.stride, index: 1)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<AquariumUniforms>.stride, index: 1)
            encoder.setFragmentTexture(backdrop, index: 0)
            encoder.setFragmentTexture(shadowTexture, index: 1)
            encoder.drawIndexedPrimitives(type: .triangle, indexCount: mesh.count, indexType: .uint32,
                                          indexBuffer: mesh.indices, indexBufferOffset: 0)
        }
        func drawEnvironment(_ encoder: MTLRenderCommandEncoder, uniforms: inout AquariumUniforms) {
            encoder.setCullMode(.none)
            encoder.setRenderPipelineState(background)
            encoder.setDepthStencilState(backgroundDepth)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<AquariumUniforms>.stride, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            if widget == nil {
                drawMesh(encoder, uniforms: &uniforms, mesh: bowlGlass, material: 6, backdrop: neutralRefraction)
                drawMesh(encoder, uniforms: &uniforms, mesh: sand, material: 1, backdrop: neutralRefraction)
            }
        }
        // Capture the live bowl and floor, then sample that scene through the colored glass.
        let refractionPass = MTLRenderPassDescriptor()
        refractionPass.colorAttachments[0].texture = refractionMSAA ?? refractionColor
        refractionPass.colorAttachments[0].resolveTexture = refractionMSAA == nil ? nil : refractionColor
        refractionPass.colorAttachments[0].loadAction = .clear
        refractionPass.colorAttachments[0].storeAction = refractionMSAA == nil ? .store : .multisampleResolve
        refractionPass.depthAttachment.texture = refractionDepth
        refractionPass.depthAttachment.loadAction = .clear
        refractionPass.depthAttachment.storeAction = .dontCare
        refractionPass.depthAttachment.clearDepth = 1
        guard let refractionEncoder = command.makeRenderCommandEncoder(descriptor: refractionPass) else { return }
        refractionEncoder.label = "Live glass refraction background"
        var captured = u
        captured.camera.w = Float(refractionColor.height)
        drawEnvironment(refractionEncoder, uniforms: &captured)
        refractionEncoder.endEncoding()

        let scenePass = MTLRenderPassDescriptor()
        scenePass.colorAttachments[0].texture = sceneMSAA ?? sculptureColor
        scenePass.colorAttachments[0].resolveTexture = sceneMSAA == nil ? nil : sculptureColor
        scenePass.colorAttachments[0].loadAction = .clear
        scenePass.colorAttachments[0].storeAction = sceneMSAA == nil ? .store : .storeAndMultisampleResolve
        scenePass.depthAttachment.texture = sceneDepth
        scenePass.depthAttachment.loadAction = .clear
        scenePass.depthAttachment.storeAction = .store
        scenePass.depthAttachment.clearDepth = 1
        guard let encoder = command.makeRenderCommandEncoder(descriptor: scenePass) else { return }
        encoder.label = "Murano glass aquarium"
        drawEnvironment(encoder, uniforms: &u)
        if let decoration { drawMesh(encoder, uniforms: &u, mesh: decoration, material: decorationMaterial, backdrop: refractionColor, model: decorationModel) }
        for index in features.indices {
            drawMesh(encoder, uniforms: &u, mesh: features[index], material: featureMaterials[index], backdrop: refractionColor, model: featureModels[index])
        }
        for (index, companion) in companions.enumerated() {
            u.companionMotion = companionMotions[index]
            drawMesh(encoder, uniforms: &u, mesh: companion, material: 10, backdrop: refractionColor, model: companionModels[index])
        }
        encoder.endEncoding()

        // Resolve the habitat before drawing fish. Their glass can now bend the
        // actual plants, rocks, and friends behind them, including during parallax.
        if sceneMSAA == nil {
            guard let copy = command.makeBlitCommandEncoder() else { return }
            copy.copy(from: sculptureColor, to: sceneColor)
            copy.endEncoding()
        }
        let fishPass = MTLRenderPassDescriptor()
        fishPass.colorAttachments[0].texture = sceneMSAA ?? sceneColor
        fishPass.colorAttachments[0].resolveTexture = sceneMSAA == nil ? nil : sceneColor
        fishPass.colorAttachments[0].loadAction = .load
        fishPass.colorAttachments[0].storeAction = sceneMSAA == nil ? .store : .storeAndMultisampleResolve
        fishPass.depthAttachment.texture = sceneDepth
        fishPass.depthAttachment.loadAction = .load
        fishPass.depthAttachment.storeAction = .store
        guard let fishEncoder = command.makeRenderCommandEncoder(descriptor: fishPass) else { return }
        fishEncoder.label = "Glass fish refract the live habitat"
        fishEncoder.setCullMode(.none)
        for item in fish {
            u.catalog.x = item.species.glassID
            u.control.x = dynamics.time + item.phase
            drawMesh(fishEncoder, uniforms: &u, mesh: item.mesh.fins, material: 4, backdrop: sculptureColor, model: item.model)
            drawMesh(fishEncoder, uniforms: &u, mesh: item.mesh.body, material: 3, backdrop: sculptureColor, model: item.model)
            drawMesh(fishEncoder, uniforms: &u, mesh: item.mesh.features, material: 7, backdrop: sculptureColor, model: item.model)
        }
        u.control.x = dynamics.time
        if let position = dynamics.foodPosition, let age = dynamics.foodAge {
            for i in 0..<3 {
                let k = Float(i)
                let p = position + SIMD3((k - 1) * 0.035 + sin(age + k) * 0.008, k * 0.028, k * 0.014)
                drawMesh(fishEncoder, uniforms: &u, mesh: pellet, material: 5, backdrop: sculptureColor,
                         model: AquariumCamera.model(position: p))
            }
        }
        fishEncoder.endEncoding()

        // Keep the resolved sculpture image separate from the bubble output.
        // MSAA color/depth are retained so bubbles correctly disappear behind objects.
        if sceneMSAA == nil {
            guard let copy = command.makeBlitCommandEncoder() else { return }
            copy.copy(from: sceneColor, to: sculptureColor)
            copy.endEncoding()
        }
        let bubblePass = MTLRenderPassDescriptor()
        bubblePass.colorAttachments[0].texture = sceneMSAA ?? sculptureColor
        bubblePass.colorAttachments[0].resolveTexture = sceneMSAA == nil ? nil : sculptureColor
        bubblePass.colorAttachments[0].loadAction = .load
        bubblePass.colorAttachments[0].storeAction = sceneMSAA == nil ? .store : .multisampleResolve
        bubblePass.depthAttachment.texture = sceneDepth
        bubblePass.depthAttachment.loadAction = .load
        bubblePass.depthAttachment.storeAction = .dontCare
        guard let bubbleEncoder = command.makeRenderCommandEncoder(descriptor: bubblePass) else { return }
        bubbleEncoder.label = "Rising bubbles refract the live sculptures"
        drawMesh(bubbleEncoder, uniforms: &u, mesh: bubbles, material: 9, backdrop: sceneColor)
        bubbleEncoder.endEncoding()

        guard let presentation = command.makeRenderCommandEncoder(descriptor: pass) else { return }
        presentation.label = "Liquid edge refraction and highlight bloom"
        presentation.setRenderPipelineState(optics)
        presentation.setFragmentBytes(&u, length: MemoryLayout<AquariumUniforms>.stride, index: 1)
        presentation.setFragmentTexture(sculptureColor, index: 0)
        presentation.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        presentation.endEncoding()
        if let drawable {
            if !firstFrameScheduled {
                firstFrameScheduled = true
                command.addCompletedHandler { [weak self] finished in
                    let succeeded = finished.status == .completed
                    let error = finished.error?.localizedDescription
                    Task { @MainActor in
                        guard let self, self.view?.delegate === self else { return }
                        if succeeded { self.experience.hasRenderedFrame = true }
                        else { self.experience.errorMessage = error ?? "Unable to render the aquarium preview." }
                    }
                }
            }
            command.present(drawable)
        }
        command.commit()
        needsInitialFrame = false
    }

    func snapshot(in view: MTKView) async -> CGImage? {
        // An owned offscreen texture avoids CAMetalLayer's display lifecycle,
        // drawable sizing and presentation throttling entirely for stills.
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb,
            width: max(1, Int(view.drawableSize.width)), height: max(1, Int(view.drawableSize.height)), mipmapped: false)
        descriptor.storageMode = .private; descriptor.usage = .renderTarget
        guard habitatLayout != nil, let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        needsInitialFrame = true
        render(in: view, presentation: pass, drawable: nil)
        let rowBytes = ((texture.width * 4 + 255) / 256) * 256
        guard let buffer = device.makeBuffer(length: rowBytes * texture.height, options: .storageModeShared),
              let command = queue.makeCommandBuffer(), let blit = command.makeBlitCommandEncoder() else { return nil }
        blit.copy(from: texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                  sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1),
                  to: buffer, destinationOffset: 0, destinationBytesPerRow: rowBytes,
                  destinationBytesPerImage: rowBytes * texture.height)
        blit.endEncoding()
        let completed = await withCheckedContinuation { continuation in
            command.addCompletedHandler { finished in
                continuation.resume(returning: finished.status == .completed)
            }
            command.commit()
        }
        guard completed, !Task.isCancelled else { return nil }
        let width = texture.width, height = texture.height
        let readback = AquariumReadbackBuffer(buffer: buffer)
        return await Task.detached(priority: .utility) {
            let data = Data(bytes: readback.buffer.contents(), count: rowBytes * height)
            guard let provider = CGDataProvider(data: data as CFData) else { return nil as CGImage? }
            return CGImage(width: width, height: height, bitsPerComponent: 8,
                bitsPerPixel: 32, bytesPerRow: rowBytes, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        }.value
    }
}
