import AppIntents
import SwiftUI
import WidgetKit

struct AquariumWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Customize Aquarium"
    static let description = IntentDescription("Pick the bowl, fish, companion, sand, and decor for your widget.")

    @Parameter(title: "Vessel")
    var vesselStyle: AquariumVesselStyle?

    @Parameter(title: "Fish")
    var fishSpecies: FishSpecies?

    @Parameter(title: "Count")
    var fishCount: FishCount?

    @Parameter(title: "Companion")
    var companion: CompanionStyle?

    @Parameter(title: "Substrate")
    var substrate: SubstrateStyle?

    @Parameter(title: "Decoration")
    var decoration: DecorationStyle?

    init() {
        vesselStyle = .orb
        fishSpecies = .royalBetta
        fishCount = .duet
        companion = .shrimp
        substrate = .coralBloom
        decoration = .coralGarden
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$fishCount) \(\.$fishSpecies) in \(\.$vesselStyle)") {
            \.$companion
            \.$substrate
            \.$decoration
        }
    }

    var aquariumConfiguration: AquariumConfiguration {
        AquariumConfiguration(
            vesselStyle: vesselStyle ?? .orb,
            fishSpecies: fishSpecies ?? .royalBetta,
            fishCount: fishCount ?? .duet,
            companion: companion ?? .shrimp,
            substrate: substrate ?? .coralBloom,
            decoration: decoration ?? .coralGarden
        )
    }
}

struct FishbowlEntry: TimelineEntry {
    let date: Date
    let configuration: AquariumConfiguration
}

struct FishbowlTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> FishbowlEntry {
        FishbowlEntry(date: .now, configuration: .hero)
    }

    func snapshot(for configuration: AquariumWidgetIntent, in context: Context) async -> FishbowlEntry {
        FishbowlEntry(date: .now, configuration: configuration.aquariumConfiguration)
    }

    func timeline(for configuration: AquariumWidgetIntent, in context: Context) async -> Timeline<FishbowlEntry> {
        let entries = (0..<6).map { index in
            FishbowlEntry(
                date: Calendar.current.date(byAdding: .minute, value: index * 20, to: .now) ?? .now,
                configuration: configuration.aquariumConfiguration
            )
        }

        return Timeline(entries: entries, policy: .atEnd)
    }
}

struct FishbowlWidget: Widget {
    private let kind = "FishbowlWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: AquariumWidgetIntent.self, provider: FishbowlTimelineProvider()) { entry in
            FishbowlWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Fishbowl")
        .description("A little glass aquarium for your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private struct FishbowlWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FishbowlEntry

    var body: some View {
        AquariumSceneView(
            configuration: resolvedConfiguration,
            format: displayFormat,
            phase: entry.date.timeIntervalSinceReferenceDate / 8.0
        )
        .padding(sceneInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            WidgetGlassBackground()
        }
    }

    private var displayFormat: AquariumDisplayFormat {
        switch family {
        case .systemSmall:
            return .widgetSmall
        case .systemMedium:
            return .widgetMedium
        default:
            return .widgetLarge
        }
    }

    private var resolvedConfiguration: AquariumConfiguration {
        switch family {
        case .systemMedium where entry.configuration.vesselStyle == .orb:
            return AquariumConfiguration(
                vesselStyle: .gallery,
                fishSpecies: entry.configuration.fishSpecies,
                fishCount: entry.configuration.fishCount,
                companion: entry.configuration.companion,
                substrate: entry.configuration.substrate,
                decoration: entry.configuration.decoration
            )
        case .systemLarge where entry.configuration.vesselStyle == .orb:
            return AquariumConfiguration(
                vesselStyle: .panorama,
                fishSpecies: entry.configuration.fishSpecies,
                fishCount: entry.configuration.fishCount,
                companion: entry.configuration.companion,
                substrate: entry.configuration.substrate,
                decoration: entry.configuration.decoration
            )
        default:
            return entry.configuration
        }
    }

    private var sceneInset: CGFloat {
        switch family {
        case .systemSmall:
            return 2
        case .systemMedium:
            return 4
        default:
            return 6
        }
    }
}

private struct WidgetGlassBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.90, green: 0.92, blue: 0.96),
                    Color(red: 0.82, green: 0.84, blue: 0.90),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.78),
                    Color.clear,
                ],
                center: .top,
                startRadius: 12,
                endRadius: 220
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.14),
                    Color.clear,
                    Color.black.opacity(0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 24)
        }
    }
}
