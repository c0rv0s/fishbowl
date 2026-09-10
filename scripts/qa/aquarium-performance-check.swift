import Foundation
import Metal

@main
struct AquariumPerformanceCheck {
    @MainActor
    static func main() async throws {
        let store = AquariumRenderResourceStore()
        var configuration = AquariumConfiguration.murano
        configuration.fishSpecies = .leafySeaDragon
        configuration.featurePieces = [.seaFan, .pearlShell]
        configuration.companions = [.crab, .miniSubmarine, .seaUrchin]
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
        let start = Date()
        let resources = try await store.resources(multisampling: true)
        let first = try await store.catalog(configuration: configuration, needsRoutes: true)
        let elapsed = Date().timeIntervalSince(start)
        heartbeat.cancel()
        precondition(ticks > 5, "UI executor did not run during cold preparation")
        let coldBuilds = await store.routeBuildCount
        precondition(coldBuilds == 1)
        let warmStart = Date()
        configuration.theme = .sunset
        let second = try await store.catalog(configuration: configuration, needsRoutes: true)
        let warm = Date().timeIntervalSince(warmStart)
        let warmBuilds = await store.routeBuildCount
        precondition(warmBuilds == coldBuilds, "Theme change rebuilt paths")
        precondition((first.fish[.leafySeaDragon]!.body.vertices as AnyObject) === (second.fish[.leafySeaDragon]!.body.vertices as AnyObject))
        precondition((first.features[0].vertices as AnyObject) === (second.features[0].vertices as AnyObject))
        let reused = try await store.resources(multisampling: true)
        precondition((resources.opaque as AnyObject) === (reused.opaque as AnyObject))
        for time in stride(from: Float(0), through: 180, by: 0.5) {
            for (index, style) in configuration.resolvedCompanions.enumerated() {
                let a = first.routes!.pose(style: style, index: index, time: time)
                let b = second.routes!.pose(style: style, index: index, time: time)
                precondition(a.position == b.position && a.activity == b.activity)
            }
        }
        // A canceled queued request must not construct an unused habitat.
        var canceledConfiguration = configuration
        canceledConfiguration.featurePieces = [.driftwoodArch, .moonLantern]
        let canceled = Task {
            return try await store.catalog(configuration: canceledConfiguration, needsRoutes: true)
        }
        canceled.cancel()
        do { _ = try await canceled.value; preconditionFailure("Canceled request completed") }
        catch is CancellationError { }
        let finalBuilds = await store.routeBuildCount
        precondition(finalBuilds == coldBuilds)
        // Snapshot construction shares the habitat but never builds motion routes.
        let widget = try await store.catalog(configuration: canceledConfiguration, needsRoutes: false)
        precondition(widget.routes == nil)
        let afterWidget = await store.routeBuildCount
        precondition(afterWidget == coldBuilds)
        print(String(format: "PASS: cold preparation %.1f ms, %d main-actor heartbeats, largest heartbeat gap %.1f ms", elapsed * 1000, ticks, largestGap * 1000))
        print(String(format: "PASS: cached catalog %.3f ms; shared mesh/pipeline buffers, route reuse, canceled request, route-free widgets", warm * 1000))
    }
}
