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
    static let title: LocalizedStringResource = "Choose a bowl"
    static let description = IntentDescription("Choose an aquarium from your collection.")

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
        .configurationDisplayName("Glass Aquarium")
        .description("A little glass aquarium for your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private struct FishbowlWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: FishbowlEntry

    var body: some View {
        Group {
        if let image = AquariumGlassSnapshots.image(configuration: entry.profile.configuration, format: displayFormat,
                                                    snapshot: entry.profile.petSnapshot(at: entry.date), daylight: colorScheme != .dark) {
            GeometryReader { geometry in
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .accessibilityLabel("\(entry.profile.name), \(entry.profile.widgetSubtitle)")
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "fish")
                    .font(.system(size: 30, weight: .ultraLight))
                    .foregroundStyle(GlassPalette.sea)
                Text("Open your aquarium")
                    .font(.system(.subheadline, design: .serif))
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .accessibilityLabel("Open Glass Aquarium to refresh this bowl")
        }
        }
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

}
