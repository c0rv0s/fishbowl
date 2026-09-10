import SwiftUI

@main
struct FishbowlApp: App {
    var body: some Scene {
        WindowGroup {
            ImmersiveAquariumView()
                #if DEBUG
                .task {
                    if ProcessInfo.processInfo.arguments.contains("-AquariumPerformanceCheck") {
                        await AquariumPerformanceDiagnostics.run()
                    }
                    if ProcessInfo.processInfo.arguments.contains("-AquariumCollectionExport") {
                        await AquariumSnapshotRenderer.exportDiagnosticCollection()
                    }
                    if ProcessInfo.processInfo.arguments.contains("-AquariumWidgetExport") {
                        await AquariumSnapshotRenderer.exportDiagnosticWidgets()
                    }
                }
                #endif
        }
    }
}
