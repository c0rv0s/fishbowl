import AppIntents
import SwiftUI
import WidgetKit

struct BowlProfileEntity: AppEntity, Identifiable, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Bowl")
    static let defaultQuery = BowlProfileQuery()

    let id: String
    let name: String
    let subtitle: String

    init(profile: BowlProfile) {
        id = profile.id.uuidString
        name = profile.name
        subtitle = profile.widgetSubtitle
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name),
            subtitle: LocalizedStringResource(stringLiteral: subtitle)
        )
    }
}

struct BowlProfileQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [BowlProfileEntity] {
        let identifierSet = Set(identifiers)
        return BowlRepository
            .loadProfiles()
            .filter { identifierSet.contains($0.id.uuidString) }
            .map(BowlProfileEntity.init(profile:))
    }

    func suggestedEntities() async throws -> [BowlProfileEntity] {
        BowlRepository.loadProfiles().map(BowlProfileEntity.init(profile:))
    }
}

struct AquariumWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Bowl"
    static let description = IntentDescription("Pick one of your saved bowls or tanks for the widget.")

    @Parameter(title: "Bowl")
    var profile: BowlProfileEntity?

    init() {
        profile = BowlRepository
            .loadProfiles()
            .first
            .map(BowlProfileEntity.init(profile:))
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$profile)")
    }
}

struct FishbowlEntry: TimelineEntry {
    let date: Date
    let profile: BowlProfile
}

struct FishbowlTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> FishbowlEntry {
        FishbowlEntry(date: .now, profile: BowlRepository.defaultProfiles().first ?? BowlProfile(name: "Blue Bowl", configuration: .hero, mode: .decorative))
    }

    func snapshot(for configuration: AquariumWidgetIntent, in context: Context) async -> FishbowlEntry {
        FishbowlEntry(date: .now, profile: profile(for: configuration))
    }

    func timeline(for configuration: AquariumWidgetIntent, in context: Context) async -> Timeline<FishbowlEntry> {
        let profile = profile(for: configuration)
        let entries = (0..<12).map { index in
            FishbowlEntry(
                date: Calendar.current.date(byAdding: .hour, value: index, to: .now) ?? .now,
                profile: profile
            )
        }

        return Timeline(entries: entries, policy: .atEnd)
    }

    private func profile(for configuration: AquariumWidgetIntent) -> BowlProfile {
        let identifier = configuration.profile.flatMap { UUID(uuidString: $0.id) }
        return BowlRepository.profile(for: identifier)
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
            phase: entry.date.timeIntervalSinceReferenceDate / 8.0,
            petSnapshot: entry.profile.petSnapshot(at: entry.date)
        )
        .padding(sceneInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            AquariumTileBackground()
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
        case .systemMedium where entry.profile.configuration.vesselStyle == .orb:
            return AquariumConfiguration(
                vesselStyle: .gallery,
                fishSpecies: entry.profile.configuration.fishSpecies,
                fishCount: entry.profile.configuration.fishCount,
                additionalFishSpecies: entry.profile.configuration.additionalFishSpecies,
                personality: entry.profile.configuration.personality,
                companions: entry.profile.configuration.resolvedCompanions,
                substrate: entry.profile.configuration.substrate,
                decoration: entry.profile.configuration.decoration,
                featurePiece: entry.profile.configuration.featurePiece
            )
        case .systemLarge where entry.profile.configuration.vesselStyle == .orb:
            return AquariumConfiguration(
                vesselStyle: .panorama,
                fishSpecies: entry.profile.configuration.fishSpecies,
                fishCount: entry.profile.configuration.fishCount,
                additionalFishSpecies: entry.profile.configuration.additionalFishSpecies,
                personality: entry.profile.configuration.personality,
                companions: entry.profile.configuration.resolvedCompanions,
                substrate: entry.profile.configuration.substrate,
                decoration: entry.profile.configuration.decoration,
                featurePiece: entry.profile.configuration.featurePiece
            )
        default:
            return entry.profile.configuration
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
