import Foundation
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

enum AquariumMode: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case decorative
    case pet

    var id: Self { self }

    var title: String {
        switch self {
        case .decorative:
            return "Decorative"
        case .pet:
            return "Pet"
        }
    }

    var summary: String {
        switch self {
        case .decorative:
            return "Just let it sit there and look good."
        case .pet:
            return "Your fish gets hungry and needs feeding."
        }
    }
}

enum AquariumPetMood: String, Codable, Hashable, Sendable {
    case decorative
    case content
    case stuffed
    case hungry
    case critical
    case dead
    case burst

    var title: String {
        switch self {
        case .decorative:
            return "Decorative"
        case .content:
            return "Happy"
        case .stuffed:
            return "Stuffed"
        case .hungry:
            return "Hungry"
        case .critical:
            return "Very Hungry"
        case .dead:
            return "Gone"
        case .burst:
            return "Popped"
        }
    }
}

struct AquariumPetSnapshot: Hashable, Sendable {
    let date: Date
    let mood: AquariumPetMood
    let hungerProgress: Double
    let fullnessProgress: Double
    let vitality: Double
    let isAlive: Bool
    let babySpecies: FishSpecies?

    static func decorative(at date: Date) -> AquariumPetSnapshot {
        AquariumPetSnapshot(
            date: date,
            mood: .decorative,
            hungerProgress: 0,
            fullnessProgress: 0,
            vitality: 1,
            isAlive: true,
            babySpecies: nil
        )
    }

    private var visibleFullness: CGFloat {
        let fullness = CGFloat(fullnessProgress)
        if !isAlive {
            return fullness
        }

        return mood == .stuffed ? max(fullness, 0.56) : fullness
    }

    var bodyScaleX: CGFloat {
        1
    }

    var bodyScaleY: CGFloat {
        1
    }

    var bodyOvalScaleY: CGFloat {
        if !isAlive { return 0.5 }

        if mood == .stuffed {
            return min(1.8, 1.2 + visibleFullness * 0.6)
        }

        let hunger = min(max(CGFloat(hungerProgress), 0), 1)
        return max(0.5, 1 - hunger * 0.5)
    }

    var colorStrength: Double {
        if mood == .decorative {
            return 1
        }

        return isAlive ? 0.58 + vitality * 0.42 : 0.26
    }

    var bubbleIntensity: Double {
        if mood == .decorative {
            return 1
        }

        return isAlive ? 0.42 + vitality * 0.58 : 0.16
    }

    var driftIntensity: CGFloat {
        if !isAlive {
            return 0.18
        }

        if mood == .decorative {
            return 1
        }

        return 0.42 + CGFloat(vitality) * 0.58
    }

    var statusLine: String {
        switch mood {
        case .decorative:
            return "A saved bowl for the widget."
        case .content:
            return "Fed and looking good."
        case .stuffed:
            return "They are round and happily digesting."
        case .hungry:
            return "Ready for a little food."
        case .critical:
            return "Needs food soon."
        case .dead:
            return "This bowl needs a fresh start."
        case .burst:
            return "You fed them too much. This tank needs a fresh start."
        }
    }

    var feedPrompt: String {
        switch mood {
        case .decorative:
            return "Switch this bowl to Pet mode if you want to care for it."
        case .content:
            return "Tap the tank to drop food in."
        case .stuffed:
            return "Let them finish what is already in the tank."
        case .hungry:
            return "Tap the tank to feed your fish."
        case .critical:
            return "Open the tank and feed it now."
        case .dead:
            return "Start a new bowl to bring it back."
        case .burst:
            return "Delete this tank and make a fresh one."
        }
    }
}

struct AquariumPetState: Hashable, Codable, Sendable {
    static let hungryAfter: TimeInterval = 12 * 60 * 60
    static let criticalAfter: TimeInterval = 24 * 60 * 60
    static let starvationAfter: TimeInterval = 36 * 60 * 60
    static let overfeedWindow: TimeInterval = 8 * 60
    static let stuffedAfter = 3
    static let burstAfter = 7
    static let babyAfterFeedCount = 4
    static let babyAfterAge: TimeInterval = 18 * 60 * 60

    var startedAt: Date
    var lastFedAt: Date
    var deathDate: Date?
    var burstDate: Date?
    var feedCount: Int
    var recentFeedDates: [Date]

    enum CodingKeys: String, CodingKey {
        case startedAt
        case lastFedAt
        case deathDate
        case burstDate
        case feedCount
        case recentFeedDates
    }

    static func fresh(at date: Date = .now) -> AquariumPetState {
        AquariumPetState(
            startedAt: date,
            lastFedAt: date,
            deathDate: nil,
            burstDate: nil,
            feedCount: 0,
            recentFeedDates: []
        )
    }

    init(
        startedAt: Date,
        lastFedAt: Date,
        deathDate: Date?,
        burstDate: Date?,
        feedCount: Int,
        recentFeedDates: [Date]
    ) {
        self.startedAt = startedAt
        self.lastFedAt = lastFedAt
        self.deathDate = deathDate
        self.burstDate = burstDate
        self.feedCount = feedCount
        self.recentFeedDates = recentFeedDates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        lastFedAt = try container.decode(Date.self, forKey: .lastFedAt)
        deathDate = try container.decodeIfPresent(Date.self, forKey: .deathDate)
        burstDate = try container.decodeIfPresent(Date.self, forKey: .burstDate)
        feedCount = try container.decodeIfPresent(Int.self, forKey: .feedCount) ?? 0
        recentFeedDates = try container.decodeIfPresent([Date].self, forKey: .recentFeedDates) ?? []
    }

    func snapshot(at date: Date, configuration: AquariumConfiguration) -> AquariumPetSnapshot {
        if let burstDate, date >= burstDate {
            return AquariumPetSnapshot(
                date: date,
                mood: .burst,
                hungerProgress: 1,
                fullnessProgress: 1,
                vitality: 0,
                isAlive: false,
                babySpecies: nil
            )
        }

        if let deathDate, date >= deathDate {
            return AquariumPetSnapshot(
                date: date,
                mood: .dead,
                hungerProgress: 1,
                fullnessProgress: 0,
                vitality: 0,
                isAlive: false,
                babySpecies: nil
            )
        }

        let elapsed = max(0, date.timeIntervalSince(lastFedAt))
        if elapsed >= Self.starvationAfter {
            return AquariumPetSnapshot(
                date: date,
                mood: .dead,
                hungerProgress: 1,
                fullnessProgress: 0,
                vitality: 0,
                isAlive: false,
                babySpecies: nil
            )
        }

        let recentFeeds = recentFeedDates.filter { date.timeIntervalSince($0) <= Self.overfeedWindow }
        let hungerProgress = min(elapsed / Self.starvationAfter, 1)
        let fullnessProgress = min(
            Double(max(recentFeeds.count - 1, 0)) / Double(max(Self.burstAfter - 1, 1)),
            1
        )
        let vitality = max(0.18, 1 - hungerProgress * 0.92)
        let mood: AquariumPetMood

        if recentFeeds.count >= Self.stuffedAfter {
            mood = .stuffed
        } else {
            switch elapsed {
            case ..<Self.hungryAfter:
                mood = .content
            case ..<Self.criticalAfter:
                mood = .hungry
            default:
                mood = .critical
            }
        }

        return AquariumPetSnapshot(
            date: date,
            mood: mood,
            hungerProgress: hungerProgress,
            fullnessProgress: fullnessProgress,
            vitality: vitality,
            isAlive: true,
            babySpecies: babySpecies(for: configuration, at: date)
        )
    }

    mutating func feed(at date: Date = .now) {
        lastFedAt = date
        deathDate = nil
        recentFeedDates = recentFeedDates.filter { date.timeIntervalSince($0) <= Self.overfeedWindow }
        recentFeedDates.append(date)
        feedCount += 1
        if recentFeedDates.count >= Self.burstAfter {
            burstDate = date
            deathDate = date
        }
    }

    func wouldBurstOnNextFeed(at date: Date = .now) -> Bool {
        guard burstDate == nil else { return true }
        if let deathDate, date >= deathDate {
            return false
        }

        let recentFeeds = recentFeedDates.filter { date.timeIntervalSince($0) <= Self.overfeedWindow }
        return recentFeeds.count + 1 >= Self.burstAfter
    }

    mutating func reset(at date: Date = .now) {
        self = .fresh(at: date)
    }

    private func babySpecies(for configuration: AquariumConfiguration, at date: Date) -> FishSpecies? {
        let lineup = configuration.resolvedFishSpecies
        guard lineup.count >= 2, Set(lineup).count == 1 else { return nil }
        guard date.timeIntervalSince(startedAt) >= Self.babyAfterAge else { return nil }
        guard feedCount >= Self.babyAfterFeedCount else { return nil }
        return lineup.first
    }
}

struct AquariumFoodPellet: Hashable, Identifiable, Sendable {
    let id: UUID
    let xFraction: CGFloat
    let yFraction: CGFloat
    let scale: CGFloat
    let attraction: CGFloat

    init(
        id: UUID = UUID(),
        xFraction: CGFloat,
        yFraction: CGFloat,
        scale: CGFloat,
        attraction: CGFloat? = nil
    ) {
        self.id = id
        self.xFraction = xFraction
        self.yFraction = yFraction
        self.scale = scale
        self.attraction = attraction ?? scale
    }
}

struct BowlProfile: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var name: String
    var configuration: AquariumConfiguration
    var mode: AquariumMode
    var petState: AquariumPetState
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        configuration: AquariumConfiguration,
        mode: AquariumMode,
        petState: AquariumPetState = .fresh(),
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.configuration = configuration
        self.mode = mode
        self.petState = petState
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func petSnapshot(at date: Date) -> AquariumPetSnapshot {
        switch mode {
        case .decorative:
            return .decorative(at: date)
        case .pet:
            return petState.snapshot(at: date, configuration: configuration)
        }
    }

    var widgetSubtitle: String {
        switch mode {
        case .decorative:
            return configuration.descriptor
        case .pet:
            return "\(mode.title) • \(configuration.descriptor)"
        }
    }

    mutating func touch(at date: Date = .now) {
        updatedAt = date
    }

    mutating func feed(at date: Date = .now) {
        guard mode == .pet else { return }
        guard petSnapshot(at: date).isAlive else { return }
        petState.feed(at: date)
        touch(at: date)
    }

    func willBurstOnNextFeed(at date: Date = .now) -> Bool {
        guard mode == .pet else { return false }
        guard petSnapshot(at: date).isAlive else { return false }
        return petState.wouldBurstOnNextFeed(at: date)
    }

    mutating func resetPet(at date: Date = .now) {
        petState.reset(at: date)
        touch(at: date)
    }
}

enum BowlRepository {
    static let appGroupID = "group.com.nate.fishbowl"
    static let storageMaxProfiles = 12
    private static let profilesKey = "fishbowl.savedProfiles"
    private static let selectedProfileKey = "fishbowl.selectedProfileID"
    private static let didMigrateEmptyStartKey = "fishbowl.didMigrateEmptyStart"

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func defaults() -> UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func loadProfiles() -> [BowlProfile] {
        let defaults = defaults()

        guard let data = defaults.data(forKey: profilesKey) else {
            return []
        }

        guard let profiles = try? decoder.decode([BowlProfile].self, from: data) else {
            return []
        }

        let normalizedProfiles = normalizeProfiles(profiles)
        let migratedProfiles = migrateSeedProfilesIfNeeded(normalizedProfiles)

        if migratedProfiles != profiles {
            saveProfiles(migratedProfiles)
        } else if normalizedProfiles != profiles {
            saveProfiles(normalizedProfiles)
        }

        return migratedProfiles
    }

    static func saveProfiles(_ profiles: [BowlProfile]) {
        guard let data = try? encoder.encode(profiles) else { return }
        defaults().set(data, forKey: profilesKey)
    }

    static func loadSelectedProfileID(from profiles: [BowlProfile]) -> UUID {
        let defaults = defaults()

        if
            let rawValue = defaults.string(forKey: selectedProfileKey),
            let identifier = UUID(uuidString: rawValue),
            profiles.contains(where: { $0.id == identifier })
        {
            return identifier
        }

        let fallback = profiles.first?.id ?? UUID()
        defaults.set(fallback.uuidString, forKey: selectedProfileKey)
        return fallback
    }

    static func saveSelectedProfileID(_ id: UUID) {
        defaults().set(id.uuidString, forKey: selectedProfileKey)
    }

    static func profile(for id: UUID?) -> BowlProfile {
        let profiles = loadProfiles()

        if let id, let match = profiles.first(where: { $0.id == id }) {
            return match
        }

        return profiles.first ?? defaultProfiles().first ?? BowlProfile(
            name: "Blue Bowl",
            configuration: .hero,
            mode: .pet
        )
    }

    static func defaultProfiles(referenceDate: Date = .now) -> [BowlProfile] {
        [
            BowlProfile(
                name: "Blue Bowl",
                configuration: .hero,
                mode: .decorative,
                petState: .fresh(at: referenceDate)
            ),
            BowlProfile(
                name: "Soft Glow",
                configuration: AquariumConfiguration(
                    vesselStyle: .gallery,
                    fishSpecies: .royalBetta,
                    fishCount: .solo,
                    companion: .none,
                    substrate: .pearlSand,
                    decoration: .riverRocks,
                    featurePiece: .none
                ),
                mode: .decorative,
                petState: .fresh(at: referenceDate)
            ),
            BowlProfile(
                name: "Moon Tank",
                configuration: AquariumConfiguration(
                    vesselStyle: .panorama,
                    fishSpecies: .moonKoi,
                    fishCount: .duet,
                    companion: .shrimp,
                    substrate: .moonGravel,
                    decoration: .riverRocks,
                    featurePiece: .moonLantern
                ),
                mode: .pet,
                petState: .fresh(at: referenceDate.addingTimeInterval(-6 * 60 * 60))
            ),
        ]
    }

    private static func normalizeProfiles(_ profiles: [BowlProfile]) -> [BowlProfile] {
        Array(
            profiles
                .map { profile in
                    var profile = profile
                    if profile.name == "Pet Tank" {
                        profile.name = "Moon Tank"
                    }
                    return profile
                }
                .prefix(storageMaxProfiles)
        )
    }

    private static func migrateSeedProfilesIfNeeded(_ profiles: [BowlProfile]) -> [BowlProfile] {
        let defaults = defaults()
        if defaults.bool(forKey: didMigrateEmptyStartKey) {
            return profiles
        }

        defer {
            defaults.set(true, forKey: didMigrateEmptyStartKey)
        }

        let seededSignatures = Set(
            defaultProfiles().map { profile in
                SeedSignature(
                    name: profile.name,
                    configuration: profile.configuration,
                    mode: profile.mode
                )
            }
        )

        let legacySignatures = Set(
            defaultProfiles().map { profile in
                SeedSignature(
                    name: profile.name == "Moon Tank" ? "Pet Tank" : profile.name,
                    configuration: profile.configuration,
                    mode: profile.mode
                )
            }
        )

        let loadedSignatures = Set(
            profiles.map { profile in
                SeedSignature(
                    name: profile.name,
                    configuration: profile.configuration,
                    mode: profile.mode
                )
            }
        )

        if loadedSignatures == seededSignatures || loadedSignatures == legacySignatures {
            return []
        }

        return profiles
    }
}

enum PremiumAccess {
    static let productID = "com.nate.fishbowl.premium"
    static let entitlementKey = "fishbowl.premiumUnlocked"
    static let freeTankLimit = 3
    static let premiumTankLimit = 12
    static let fallbackPrice = "$2.99"
    #if DEBUG
    private static let previewUnlockKey = "fishbowl.previewPremiumUnlocked"
    #endif

    static var isPremiumUnlocked: Bool {
        let defaults = BowlRepository.defaults()
        #if DEBUG
        return defaults.bool(forKey: entitlementKey) || defaults.bool(forKey: previewUnlockKey)
        #else
        return defaults.bool(forKey: entitlementKey)
        #endif
    }

    static var currentTankLimit: Int {
        isPremiumUnlocked ? premiumTankLimit : freeTankLimit
    }

    static func setPremiumUnlocked(_ unlocked: Bool) {
        BowlRepository.defaults().set(unlocked, forKey: entitlementKey)
    }

    #if DEBUG
    static var isPreviewUnlockEnabled: Bool {
        BowlRepository.defaults().bool(forKey: previewUnlockKey)
    }

    static func setPreviewUnlockEnabled(_ unlocked: Bool) {
        BowlRepository.defaults().set(unlocked, forKey: previewUnlockKey)
    }
    #endif
}

private struct SeedSignature: Hashable {
    let name: String
    let configuration: AquariumConfiguration
    let mode: AquariumMode
}

@MainActor
final class BowlStudio: ObservableObject {
    @Published private(set) var profiles: [BowlProfile]
    @Published var selectedProfileID: UUID {
        didSet {
            BowlRepository.saveSelectedProfileID(selectedProfileID)
        }
    }

    init() {
        let loadedProfiles = BowlRepository.loadProfiles()
        profiles = loadedProfiles
        selectedProfileID = BowlRepository.loadSelectedProfileID(from: loadedProfiles)
    }

    var selectedProfile: BowlProfile {
        profiles.first(where: { $0.id == selectedProfileID }) ?? profiles.first ?? makeDraftProfile()
    }

    var canCreateProfile: Bool {
        profiles.count < PremiumAccess.currentTankLimit
    }

    func selectProfile(_ id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        selectedProfileID = id
    }

    func updateSelectedProfile(_ mutation: (inout BowlProfile) -> Void) {
        var profile = selectedProfile
        mutation(&profile)
        profile.touch()
        profiles[selectedIndex] = profile
        persist()
    }

    func renameSelected(to rawName: String) {
        updateSelectedProfile { profile in
            let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.name = trimmed.isEmpty ? generatedName() : trimmed
        }
    }

    func updateSelectedConfiguration(_ mutation: (inout AquariumConfiguration) -> Void) {
        updateSelectedProfile { profile in
            mutation(&profile.configuration)
        }
    }

    func updateSelectedMode(_ mode: AquariumMode) {
        updateSelectedProfile { profile in
            profile.mode = mode
            if mode == .pet, profile.petState.feedCount == 0, profile.petState.startedAt == profile.petState.lastFedAt {
                profile.petState.lastFedAt = .now
            }
        }
    }

    func createProfile() {
        addProfile(makeDraftProfile())
    }

    func feedSelected(at date: Date = .now) {
        updateSelectedProfile { profile in
            profile.feed(at: date)
        }
    }

    func resetSelectedPet(at date: Date = .now) {
        updateSelectedProfile { profile in
            profile.resetPet(at: date)
        }
    }

    func petSnapshot(at date: Date = .now) -> AquariumPetSnapshot {
        selectedProfile.petSnapshot(at: date)
    }

    func makeDraftProfile() -> BowlProfile {
        var configuration = AquariumConfiguration.hero
        configuration.companion = .none
        configuration.substrate = .pearlSand
        configuration.featurePiece = .none

        return BowlProfile(
            name: generatedName(),
            configuration: configuration,
            mode: .pet,
            petState: .fresh()
        )
    }

    func addProfile(_ profile: BowlProfile) {
        guard canCreateProfile else { return }

        var profile = profile
        profile.id = UUID()
        profile.createdAt = .now
        profile.updatedAt = .now
        if profile.mode == .pet {
            profile.petState = .fresh()
        }

        profiles.append(profile)
        selectedProfileID = profile.id
        persist()
    }

    func deleteProfile(id: UUID) {
        profiles.removeAll { $0.id == id }

        if let firstProfile = profiles.first {
            if !profiles.contains(where: { $0.id == selectedProfileID }) {
                selectedProfileID = firstProfile.id
            }
        } else {
            selectedProfileID = UUID()
        }

        persist()
    }

    func feedProfile(id: UUID, at date: Date = .now) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        var profile = profiles[index]
        profile.feed(at: date)
        profiles[index] = profile
        selectedProfileID = id
        persist()
    }

    private var selectedIndex: Int {
        profiles.firstIndex(where: { $0.id == selectedProfileID }) ?? 0
    }

    private func generatedName() -> String {
        let baseNames = ["New Bowl", "New Tank", "Glass Bowl", "Dream Tank"]

        for baseName in baseNames {
            if !profiles.contains(where: { $0.name == baseName }) {
                return baseName
            }
        }

        var index = 2
        while profiles.contains(where: { $0.name == "Bowl \(index)" }) {
            index += 1
        }

        return "Bowl \(index)"
    }

    private func persist() {
        BowlRepository.saveProfiles(profiles)
        BowlRepository.saveSelectedProfileID(selectedProfileID)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
