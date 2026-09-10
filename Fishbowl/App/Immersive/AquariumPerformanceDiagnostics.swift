#if DEBUG
import MetalKit
import SwiftUI

@MainActor
enum AquariumPerformanceDiagnostics {
    // Ephemeral fixtures exercise library scaling without changing saved bowls.
    static let libraryFixtures: [BowlProfile] = (0..<12).map { index in
        var configuration = AquariumConfiguration.murano
        configuration.theme = AquariumTheme.allCases[index % AquariumTheme.allCases.count]
        return BowlProfile(name: "Preview \(index + 1)", configuration: configuration, mode: .decorative)
    }
    private static var previewViews = Set<ObjectIdentifier>()
    private static var visitedProfiles = Set<UUID>()
    private static var peakPreviewViews = 0
    private static var settledPreviewViews = 0

    static func previewCreated(_ view: MTKView, profile: BowlProfile?) {
        guard ProcessInfo.processInfo.arguments.contains("-AquariumLibraryStress") else { return }
        previewViews.insert(ObjectIdentifier(view))
        if let profile { visitedProfiles.insert(profile.id) }
        peakPreviewViews = max(peakPreviewViews, previewViews.count)
        writePreviewCounts()
    }

    static func previewRemoved(_ view: MTKView) {
        guard previewViews.remove(ObjectIdentifier(view)) != nil else { return }
        writePreviewCounts()
    }

    private static func writePreviewCounts() {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("library-preview-counts.txt")
        try? "Current preview views: \(previewViews.count)\nPeak preview views during transitions: \(peakPreviewViews)\nPeak preview views after layout settled: \(settledPreviewViews)\nVisited bowls: \(visitedProfiles.count) of 12\n"
            .write(to: url, atomically: true, encoding: .utf8)
    }

    static func scrollLibrary() async {
        func scrollViews(in view: UIView) -> [UIScrollView] {
            (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
        }
        do {
            // Let the full-screen library finish presenting and laying out.
            try await Task.sleep(for: .seconds(2))
            let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
            guard let scroll = windows.flatMap({ scrollViews(in: $0) })
                .max(by: { $0.contentSize.height < $1.contentSize.height }),
                  scroll.contentSize.height > scroll.bounds.height else {
                preconditionFailure("The twelve-bowl library did not lay out")
            }
            // LazyVStack refines its estimated height as rows are realized.
            for direction: CGFloat in [1, -1] {
                for _ in 0..<24 {
                    let bottom = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
                    let y = min(bottom, max(0, scroll.contentOffset.y + direction * scroll.bounds.height * 0.75))
                    scroll.setContentOffset(CGPoint(x: 0, y: y), animated: false)
                    try await Task.sleep(for: .milliseconds(200))
                    settledPreviewViews = max(settledPreviewViews, previewViews.count)
                }
            }
            writePreviewCounts()
            // SwiftUI can create the next two visible views before dismantling
            // the previous pair in the same layout transaction.
            precondition(peakPreviewViews <= 4 && settledPreviewViews <= 2 && !previewViews.isEmpty && visitedProfiles.count == 12,
                         "The library retained offscreen preview views")
        } catch { }
    }

    static func run() async {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PerformanceDiagnostics", isDirectory: true)
        do {
            let resources = try await AquariumRenderResourceStore.shared.resources(multisampling: true)
            let view = MTKView(frame: CGRect(x: 0, y: 0, width: 600, height: 600), device: resources.device)
            view.colorPixelFormat = .bgra8Unorm_srgb; view.depthStencilPixelFormat = .invalid
            view.sampleCount = 1; view.isPaused = true; view.framebufferOnly = false
            view.autoResizeDrawable = false; view.drawableSize = CGSize(width: 600, height: 600)
            let experience = AquariumExperience()
            experience.tiltEnabled = false
            var a = AquariumConfiguration.murano
            a.companions = [.crab]; a.featurePieces = [.seaFan, .pearlShell]
            experience.configuration = a
            let renderer = try AquariumDepthRenderer(view: view, experience: experience, resources: resources, diagnostics: false)
            defer { renderer.stop() }
            renderer.configure(active: false, reduceMotion: false)
            await renderer.diagnosticWaitForCatalog()
            precondition(renderer.diagnosticConfiguration == a)
            var b = a
            b.decoration = .coralGarden; b.featurePieces = [.kelp, .seaFan]
            experience.configuration = b
            renderer.configure(active: false, reduceMotion: false)
            let obsolete = Task { await renderer.diagnosticWaitForCatalog() }
            try await Task.sleep(for: .milliseconds(20))
            experience.configuration = a
            renderer.configure(active: false, reduceMotion: false)
            await obsolete.value
            await renderer.diagnosticWaitForCatalog()
            precondition(renderer.diagnosticConfiguration == a, "An obsolete layout replaced the selected bowl")
            // Switching between profiles with identical art must also cancel pending results.
            let first = BowlProfile(name: "QA First", configuration: a, mode: .decorative)
            let second = BowlProfile(name: "QA Second", configuration: a, mode: .decorative)
            experience.profile = first
            renderer.configure(active: false, reduceMotion: false)
            await renderer.diagnosticWaitForCatalog()
            experience.profile = second
            renderer.configure(active: false, reduceMotion: false)
            let obsoleteProfile = Task { await renderer.diagnosticWaitForCatalog() }
            await Task.yield()
            experience.profile = first
            renderer.configure(active: false, reduceMotion: false)
            await obsoleteProfile.value
            await renderer.diagnosticWaitForCatalog()
            precondition(renderer.diagnosticProfileID == first.id)
            guard await renderer.snapshot(in: view) != nil else { preconditionFailure("Live Metal pipeline did not render") }
            precondition(view.multisampleColorTexture == nil && view.depthStencilTexture == nil,
                         "Presentation allocated redundant attachments")
            precondition(renderer.diagnosticSceneSamples == resources.samples)

            var ticks = 0, largestGap = 0.0
            let heartbeat = Task { @MainActor in
                var previous = Date()
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(5)) } catch { return }
                    let now = Date()
                    largestGap = max(largestGap, now.timeIntervalSince(previous))
                    previous = now; ticks += 1
                }
            }
            let builds = AquariumSnapshotRenderer.sessionBuildCount
            let snapshot = AquariumPetSnapshot.decorative(at: .now)
            let baby = AquariumPetSnapshot(date: .now, mood: .content, hungerProgress: 0, fullnessProgress: 0,
                vitality: 1, isAlive: true, babySpecies: .blueTang)
            let empty = AquariumPetSnapshot(date: .now, mood: .dead, hungerProgress: 1, fullnessProgress: 0,
                vitality: 0, isAlive: false, babySpecies: nil)
            let configurationA = a, configurationB = b
            async let day = AquariumSnapshotRenderer.prepare(configuration: configurationA, format: .widgetSmall, snapshot: snapshot)
            async let night = AquariumSnapshotRenderer.prepare(configuration: configurationB, format: .widgetMedium, snapshot: snapshot, daylight: false)
            async let family = AquariumSnapshotRenderer.prepare(configuration: configurationA, format: .widgetLarge, snapshot: baby)
            async let vacant = AquariumSnapshotRenderer.prepare(configuration: configurationB, format: .widgetSmall, snapshot: empty)
            let images = await [day, night, family, vacant]
            heartbeat.cancel()
            precondition(images.allSatisfy { $0 != nil }, "Snapshot queue lost an image")
            precondition(images[0]!.size == CGSize(width: 600, height: 600))
            precondition(images[1]!.size == CGSize(width: 960, height: 450), "Concurrent jobs mixed widget dimensions")
            precondition(AquariumSnapshotRenderer.sessionBuildCount - builds <= 1, "Snapshot renderer was not reused")
            precondition(ticks > 0, "Snapshot generation blocked the UI executor")
            let report = String(format: "PASS: rapid A/B/A layout changes, profile identity cancellation, live Metal rendering\nPASS: single-sample presentation without depth; scene retains %dx MSAA\nPASS: concurrent day/night/baby/empty widget jobs, correct sizes, one reused renderer\nSnapshot batch: %d UI heartbeats; largest gap %.1f ms on Simulator\n", resources.samples, ticks, largestGap * 1000)
            await Task.detached(priority: .utility) {
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                for (index, image) in images.enumerated() {
                    try? image?.pngData()?.write(to: directory.appendingPathComponent("snapshot-\(index).png"))
                }
                try? report.write(to: directory.appendingPathComponent("checks.txt"), atomically: true, encoding: .utf8)
            }.value
        } catch {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? "FAIL: \(error)".write(to: directory.appendingPathComponent("checks.txt"), atomically: true, encoding: .utf8)
        }
    }
}
#endif
