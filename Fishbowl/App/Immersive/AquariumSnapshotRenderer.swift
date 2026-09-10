import MetalKit
import SwiftUI
import WidgetKit

@MainActor
enum AquariumSnapshotRenderer {
    private struct Session {
        let view: MTKView
        let experience: AquariumExperience
        let renderer: AquariumDepthRenderer
    }
    private static var session: Session?
    private static var tail: Task<UIImage?, Never>?
    private static var generation = UUID()
    private static var releaseTask: Task<Void, Never>?
    #if DEBUG
    private(set) static var sessionBuildCount = 0
    #endif

    /// Jobs serialize access to one offscreen view. Only UIKit setup and command
    /// encoding use the main actor; construction, readback copying and PNG work do not.
    @discardableResult
    static func prepare(configuration: AquariumConfiguration, format: AquariumDisplayFormat,
                        snapshot: AquariumPetSnapshot, daylight: Bool = true) async -> UIImage? {
        guard !Task.isCancelled,
              let url = AquariumGlassSnapshots.url(configuration: configuration, format: format, snapshot: snapshot, daylight: daylight) else { return nil }
        releaseTask?.cancel()
        let previous = tail, id = UUID()
        generation = id
        let job = Task { @MainActor () -> UIImage? in
            _ = await previous?.value
            guard !Task.isCancelled else { return nil }
            let cached = await Task.detached(priority: .utility) {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-AquariumRefreshSnapshots") { return nil as UIImage? }
                #endif
                return UIImage(contentsOfFile: url.path)
            }.value
            guard !Task.isCancelled else { return nil }
            if let cached { return cached }
            do {
                let resources = try await AquariumRenderResourceStore.shared.resources(multisampling: true)
                let prepared = try await AquariumRenderResourceStore.shared.catalog(configuration: configuration,
                    baby: snapshot.babySpecies, needsRoutes: false)
                try Task.checkCancellation()
                if session == nil {
                    let view = MTKView(frame: .zero, device: resources.device)
                    view.colorPixelFormat = .bgra8Unorm_srgb
                    view.depthStencilPixelFormat = .invalid
                    view.sampleCount = 1
                    view.framebufferOnly = false
                    view.isOpaque = false; view.backgroundColor = .clear
                    view.isPaused = true; view.autoResizeDrawable = false
                    let experience = AquariumExperience()
                    experience.tiltEnabled = false
                    let renderer = try AquariumDepthRenderer(view: view, experience: experience, resources: resources,
                        diagnostics: false, preview: true, widgetFormat: format)
                    session = Session(view: view, experience: experience, renderer: renderer)
                    #if DEBUG
                    sessionBuildCount += 1
                    #endif
                }
                guard let session else { return nil }
                let size = format == .widgetMedium ? CGSize(width: 960, height: 450) : CGSize(width: 600, height: 600)
                session.view.frame = CGRect(origin: .zero, size: size)
                session.view.drawableSize = size
                session.experience.configuration = configuration
                session.experience.daylight = daylight
                session.experience.snapshotOverride = snapshot
                session.renderer.prepareSnapshot(prepared, format: format)
                guard let cgImage = await session.renderer.snapshot(in: session.view), !Task.isCancelled else { return nil }
                return await Task.detached(priority: .utility) {
                    autoreleasepool {
                        let image = UIImage(cgImage: cgImage)
                        do {
                            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                            try image.pngData()?.write(to: url, options: .atomic)
                        } catch { return image }
                        return image
                    }
                }.value
            } catch { return nil }
        }
        tail = job
        let image = await withTaskCancellationHandler {
            await job.value
        } onCancel: {
            job.cancel()
        }
        if generation == id {
            releaseTask = Task {
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
                guard generation == id else { return }
                session?.renderer.stop()
                session = nil; tail = nil
            }
        }
        return Task.isCancelled ? nil : image
    }

    static func prepareProfiles(_ profiles: [BowlProfile]) async {
        var requested = Set<URL>()
        for profile in profiles {
            let now = Date.now
            let normal = AquariumPetSnapshot.decorative(at: now)
            let empty = AquariumPetSnapshot(date: now, mood: .dead, hungerProgress: 1, fullnessProgress: 0,
                                            vitality: 0, isAlive: false, babySpecies: nil)
            let current = profile.petSnapshot(at: now)
            for format in [AquariumDisplayFormat.widgetSmall, .widgetMedium, .widgetLarge] {
                for daylight in [true, false] {
                    for snapshot in profile.mode == .pet ? [normal, empty, current] : [normal] {
                        guard !Task.isCancelled else { return }
                        guard let key = AquariumGlassSnapshots.url(configuration: profile.configuration, format: format, snapshot: snapshot, daylight: daylight),
                              requested.insert(key).inserted else { continue }
                        await prepare(configuration: profile.configuration, format: format, snapshot: snapshot, daylight: daylight)
                    }
                }
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    #if DEBUG
    static func exportDiagnosticCollection() async {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CollectionDiagnostics", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for species in FishSpecies.allCases where species.glassID >= 11 {
            var configuration = AquariumConfiguration.murano
            configuration.fishSpecies = species
            configuration.featurePiece = .pearlShell
            configuration.companions = [.miniSubmarine]
            for format in [AquariumDisplayFormat.widgetSmall, .widgetMedium, .widgetLarge] {
                guard !Task.isCancelled else { return }
                let image = await prepare(configuration: configuration, format: format, snapshot: .decorative(at: .now))
                try? image?.pngData()?.write(to: directory.appendingPathComponent("\(species.rawValue)-\(format.rawValue).png"), options: .atomic)
                await Task.yield()
            }
        }
    }

    static func exportDiagnosticWidgets() async {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WidgetDiagnostics", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var coral = AquariumConfiguration.murano
        coral.decoration = .coralGarden; coral.theme = .sunset; coral.companions = [.shrimp, .snail]
        var mixed = AquariumConfiguration.murano
        mixed.theme = .neonJungle; mixed.fishCount = .trio
        mixed.additionalFishSpecies = [.moonKoi, .opalAngelfish]
        mixed.featurePiece = .driftwoodArch; mixed.companions = [.crab, .nudibranchRibbon, .seaCucumber]
        var ivory = AquariumConfiguration.murano
        ivory.theme = .ivory
        var seaGarden = AquariumConfiguration.murano
        seaGarden.fishSpecies = .leafySeaDragon; seaGarden.featurePiece = .seaFan
        seaGarden.companions = [.seaUrchin, .miniSubmarine]
        var paired = seaGarden
        paired.featurePieces = [.seaFan, .pearlShell]
        var tallPair = paired
        tallPair.featurePieces = [.kelp, .seaFan]
        var archPair = paired
        archPair.featurePieces = [.driftwoodArch, .moonLantern]
        var seahorse = paired
        seahorse.fishSpecies = .pearlSeahorse
        let fixtures = [("seahorse", seahorse), ("paired", paired), ("tall-pair", tallPair), ("arch-pair", archPair), ("ivory", ivory), ("lagoon", AquariumConfiguration.murano), ("coral", coral), ("mixed", mixed), ("sea-garden", seaGarden)]
        for (name, configuration) in fixtures {
            for format in [AquariumDisplayFormat.widgetSmall, .widgetMedium, .widgetLarge] {
                guard !Task.isCancelled else { return }
                let image = await prepare(configuration: configuration, format: format, snapshot: .decorative(at: .now))
                try? image?.pngData()?.write(to: directory.appendingPathComponent("\(name)-\(format.rawValue).png"), options: .atomic)
                await Task.yield()
            }
        }
        let night = await prepare(configuration: coral, format: .widgetMedium, snapshot: .decorative(at: .now), daylight: false)
        try? night?.pngData()?.write(to: directory.appendingPathComponent("coral-evening.png"), options: .atomic)
    }
    #endif
}

struct AquariumGlassStillView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var daylight: Bool { colorScheme != .dark }
    let configuration: AquariumConfiguration
    let format: AquariumDisplayFormat
    let phase: Double
    var petSnapshot: AquariumPetSnapshot = .decorative(at: .now)
    @State private var image: UIImage?
    @State private var isPreparing = true

    var body: some View {
        Group {
            if let image = image ?? AquariumGlassSnapshots.image(configuration: configuration, format: format, snapshot: petSnapshot, daylight: daylight) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                AquariumPreviewPlaceholder(unavailable: !isPreparing)
            }
        }
        .aspectRatio(format.aspectRatio, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 26))
        .task(id: AquariumGlassSnapshots.url(configuration: configuration, format: format, snapshot: petSnapshot, daylight: daylight)) {
            isPreparing = true
            let prepared = await AquariumSnapshotRenderer.prepare(configuration: configuration, format: format, snapshot: petSnapshot, daylight: daylight)
            guard !Task.isCancelled else { return }
            image = prepared
            isPreparing = false
        }
    }
}
