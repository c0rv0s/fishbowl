import StoreKit
import SwiftUI
import UIKit

private enum TankPageID: Hashable {
    case profile(UUID)
    case addSlot(Int)
    case premiumUpsell
}

struct ContentView: View {
    @StateObject private var studio = BowlStudio()
    @StateObject private var premiumStore = PremiumStore()
    @State private var composerDraft: BowlProfile?
    @State private var deletingProfile: BowlProfile?
    @State private var feedBurstsByProfileID: [UUID: [AquariumFeedBurst]] = [:]
    @State private var currentPageID: TankPageID?
    @State private var isPremiumSheetPresented = false
    @State private var isScrollTransitioning = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(studio.profiles) { profile in
                            TankHomePage(
                                profile: profile,
                                isFocused: currentPageID == .profile(profile.id),
                                isLivePrepared: shouldPrepareLiveScene(for: profile.id),
                                isScrollFrozen: isScrollTransitioning,
                                safeAreaInsets: geometry.safeAreaInsets,
                                feedBursts: feedBurstsByProfileID[profile.id] ?? [],
                                onFeed: { xFraction in
                                    dropFood(in: profile, at: xFraction)
                                },
                                onFeedConsumed: { burstID in
                                    finishFeeding(in: profile, burstID: burstID)
                                },
                                onDelete: {
                                    deletingProfile = profile
                                }
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .id(TankPageID.profile(profile.id))
                        }

                        if studio.canCreateProfile {
                            AddTankPage(
                                slotNumber: studio.profiles.count + 1,
                                tankLimit: premiumStore.tankLimit,
                                safeAreaInsets: geometry.safeAreaInsets
                            ) {
                                composerDraft = studio.makeDraftProfile()
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .id(TankPageID.addSlot(studio.profiles.count + 1))
                        } else if !premiumStore.isPremiumUnlocked {
                            PremiumUpsellPage(
                                currentTankCount: studio.profiles.count,
                                safeAreaInsets: geometry.safeAreaInsets,
                                onUnlock: {
                                    isPremiumSheetPresented = true
                                }
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .id(TankPageID.premiumUpsell)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollClipDisabled()
                .scrollPosition(id: $currentPageID)
                .onScrollPhaseChange { _, newPhase in
                    isScrollTransitioning = newPhase != .idle
                }
            }
            .navigationBarHidden(true)
        }
        .fullScreenCover(item: $composerDraft) { draft in
            TankComposerScreen(initialProfile: draft, premiumStore: premiumStore) { profile in
                studio.addProfile(profile)
                currentPageID = .profile(profile.id)
                composerDraft = nil
            } onCancel: {
                composerDraft = nil
            }
        }
        .sheet(isPresented: $isPremiumSheetPresented) {
            PremiumUnlockSheet(store: premiumStore)
        }
        .confirmationDialog(
            "Delete this tank?",
            isPresented: Binding(
                get: { deletingProfile != nil },
                set: { isPresented in
                    if !isPresented {
                        deletingProfile = nil
                    }
                }
            ),
            titleVisibility: .visible,
            presenting: deletingProfile
        ) { profile in
            Button("Delete \(profile.name)", role: .destructive) {
                feedBurstsByProfileID[profile.id] = nil
                studio.deleteProfile(id: profile.id)
                deletingProfile = nil
            }

            Button("Cancel", role: .cancel) {
                deletingProfile = nil
            }
        } message: { profile in
            Text("Remove \(profile.name) and free up this slot for a new tank.")
        }
        .onAppear(perform: syncCurrentPageID)
        .onChange(of: pageIDs) { _, _ in
            syncCurrentPageID()
        }
    }

    private func dropFood(in profile: BowlProfile, at xFraction: CGFloat) {
        let snapshot = profile.petSnapshot(at: .now)
        guard profile.mode == .pet, snapshot.isAlive else { return }

        let now = Date.now
        let clampedX = min(max(xFraction, 0.18), 0.82)
        let activeBursts = feedBurstsByProfileID[profile.id, default: []]
            .filter { $0.endsAt > now }

        feedBurstsByProfileID[profile.id] = activeBursts
        guard activeBursts.isEmpty else { return }

        feedBurstsByProfileID[profile.id] = [
            AquariumFeedBurst(startedAt: now, xFraction: clampedX)
        ]
    }

    private func finishFeeding(in profile: BowlProfile, burstID: UUID) {
        let currentBursts = feedBurstsByProfileID[profile.id, default: []]
        guard currentBursts.contains(where: { $0.id == burstID }) else { return }

        feedBurstsByProfileID[profile.id] = currentBursts.filter { $0.id != burstID }
        let willBurst = profile.willBurstOnNextFeed(at: .now)
        withAnimation(.easeInOut(duration: willBurst ? 0.72 : 0.34)) {
            studio.feedProfile(id: profile.id, at: .now)
        }
    }

    private var pageIDs: [TankPageID] {
        let profilePages = studio.profiles.map { TankPageID.profile($0.id) }
        if studio.canCreateProfile {
            return profilePages + [.addSlot(studio.profiles.count + 1)]
        }
        if !premiumStore.isPremiumUnlocked {
            return profilePages + [.premiumUpsell]
        }
        return profilePages
    }

    private func syncCurrentPageID() {
        guard !pageIDs.isEmpty else {
            currentPageID = nil
            return
        }

        if let currentPageID, pageIDs.contains(currentPageID) {
            return
        }

        currentPageID = pageIDs.first
    }

    private func shouldPrepareLiveScene(for profileID: UUID) -> Bool {
        studio.profiles.contains { $0.id == profileID }
    }
}

private struct TankHomePage: View {
    @Environment(\.colorScheme) private var colorScheme

    let profile: BowlProfile
    let isFocused: Bool
    let isLivePrepared: Bool
    let isScrollFrozen: Bool
    let safeAreaInsets: EdgeInsets
    let feedBursts: [AquariumFeedBurst]
    let onFeed: (CGFloat) -> Void
    let onFeedConsumed: AquariumFeedBurstConsumedHandler
    let onDelete: () -> Void
    @State private var shareImage: UIImage?

    private var layoutScale: CGFloat {
        min(max(UIScreen.main.bounds.width / 390, 1.0), 1.12)
    }

    private var snapshot: AquariumPetSnapshot {
        profile.petSnapshot(at: .now)
    }

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding = 24 * layoutScale
            let tankSize = max(0, geometry.size.width - horizontalPadding * 2)
            let headerTop = max(22, safeAreaInsets.top + 10)
            let cardBottom = max(24, safeAreaInsets.bottom + 8)

            ZStack(alignment: .bottomLeading) {
                AmbientScreenBackdrop(
                    configuration: profile.configuration,
                    renderStyle: .lightweight
                )

                AnimatedAquariumStage(
                    profile: profile,
                    configuration: profile.configuration,
                    format: .widgetLarge,
                    isFocused: isFocused,
                    isPrepared: isLivePrepared,
                    isScrollFrozen: isScrollFrozen,
                    feedBursts: feedBursts,
                    onFeed: onFeed,
                    onFeedConsumed: onFeedConsumed
                )
                .frame(width: tankSize, height: tankSize)
                .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.5)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(profile.name)
                                .font(.system(size: 44 * layoutScale, weight: .medium, design: .serif))
                                .foregroundStyle(colorScheme.fishbowlPrimaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            Text(subtitleText)
                                .font(.system(size: 16 * layoutScale, weight: .medium, design: .rounded))
                                .foregroundStyle(colorScheme.fishbowlSecondaryText)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer(minLength: 14)

                        HStack(spacing: 10) {
                            IconGlassButton(systemImage: "square.and.arrow.up") {
                                shareImage = renderShareImage()
                            }

                            IconGlassButton(systemImage: "trash") {
                                onDelete()
                            }
                        }
                    }
                    .frame(minHeight: 92 * layoutScale, alignment: .top)

                    Spacer(minLength: 0)
                }
                .padding(.top, headerTop)
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, max(28, safeAreaInsets.bottom + 14))

                TankDetailCard(profile: profile)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, cardBottom)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { shareImage != nil },
                set: { isPresented in
                    if !isPresented {
                        shareImage = nil
                    }
                }
            )
        ) {
            if let shareImage {
                ActivityView(activityItems: [shareImage])
            }
        }
    }

    private var subtitleText: String {
        switch profile.mode {
        case .decorative:
            return "Decorative • Made for your Home Screen"
        case .pet:
            return snapshot.isAlive
            ? "\(snapshot.mood.title) • \(subtitlePrompt)"
            : (snapshot.mood == .burst
               ? "Popped • Delete this tank to make a new one"
               : "Gone • Delete this tank to make a new one")
        }
    }

    private var subtitlePrompt: String {
        switch snapshot.mood {
        case .decorative:
            return "Made for your Home Screen"
        case .content:
            return "Tap the tank to drop food in"
        case .stuffed:
            return "They are digesting"
        case .hungry:
            return "Tap the tank to feed your fish"
        case .critical:
            return "Feed this tank now"
        case .dead:
            return "Delete this tank to make a new one"
        case .burst:
            return "You fed this one too much"
        }
    }

    private func renderShareImage() -> UIImage? {
        let shareSize: CGFloat = 430
        let content = PhotoShareCard(profile: profile)
            .environment(\.colorScheme, colorScheme)
            .frame(width: shareSize, height: shareSize)

        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: shareSize, height: shareSize)
        renderer.scale = 3
        return renderer.uiImage
    }

}

private struct AddTankPage: View {
    @Environment(\.colorScheme) private var colorScheme

    let slotNumber: Int
    let tankLimit: Int
    let safeAreaInsets: EdgeInsets
    let onCreate: () -> Void

    var body: some View {
        ZStack {
            AmbientScreenBackdrop(
                configuration: .appIcon,
                renderStyle: .lightweight
            )

            VStack(spacing: 26) {
                Spacer(minLength: max(42, safeAreaInsets.top + 28))

                VStack(alignment: .leading, spacing: 10) {
                    Text("New Tank")
                        .font(.system(size: 46, weight: .medium, design: .serif))
                        .foregroundStyle(colorScheme.fishbowlPrimaryText)

                    Text("Slot \(slotNumber) of \(tankLimit) is open. Tap below to make a fresh bowl or pet tank.")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(colorScheme.fishbowlSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onCreate) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 38, style: .continuous)
                            .fill(colorScheme.fishbowlElevatedFill)
                            .overlay {
                                RoundedRectangle(cornerRadius: 38, style: .continuous)
                                    .stroke(colorScheme.fishbowlElevatedStroke, lineWidth: 1)
                            }
                            .shadow(color: colorScheme.fishbowlShadow.opacity(0.8), radius: 18, y: 10)

                        VStack(spacing: 14) {
                            Image(systemName: "plus")
                                .font(.system(size: 46, weight: .medium))
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.74) : Color.black.opacity(0.76))

                            Text("Make a New Tank")
                                .font(.system(size: 21, weight: .semibold, design: .serif))
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.86) : Color.black.opacity(0.84))

                            Text("Pick the fish, choose the bowl, and give it a name.")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(colorScheme.fishbowlSecondaryText)
                        }
                        .padding(30)
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
                .buttonStyle(.plain)

                Spacer(minLength: max(26, safeAreaInsets.bottom + 12))
            }
            .padding(.horizontal, 28)
        }
    }
}

private struct PremiumUpsellPage: View {
    @Environment(\.colorScheme) private var colorScheme

    let currentTankCount: Int
    let safeAreaInsets: EdgeInsets
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            AmbientScreenBackdrop(configuration: premiumPreviewConfiguration)

            VStack(spacing: 24) {
                Spacer(minLength: max(36, safeAreaInsets.top + 22))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Fishbowl Premium")
                        .font(.system(size: 44, weight: .medium, design: .serif))
                        .foregroundStyle(colorScheme.fishbowlPrimaryText)

                    Text("You already filled your \(currentTankCount) free tanks. Unlock up to 12 tanks, mix different fish together, and open up the richer decor and feature pieces.")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(colorScheme.fishbowlSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)

                GlassPanel(cornerRadius: 38) {
                    VStack(alignment: .leading, spacing: 18) {
                        AquariumSceneView(
                            configuration: premiumPreviewConfiguration,
                            format: .studioHero,
                            phase: 0.32,
                            petSnapshot: .decorative(at: .now)
                        )
                        .frame(height: 280)

                        VStack(alignment: .leading, spacing: 8) {
                            PremiumBullet(text: "Up to 12 saved tanks instead of 3")
                            PremiumBullet(text: "Mixed-species schools with the premium fish set")
                            PremiumBullet(text: "Feature pieces like driftwood, lanterns, and kelp")
                        }

                        ActionGlassButton(title: "Unlock Premium", systemImage: "crown.fill") {
                            onUnlock()
                        }
                    }
                }
                .padding(.horizontal, 22)

                Spacer(minLength: max(24, safeAreaInsets.bottom + 12))
            }
        }
    }

    private var premiumPreviewConfiguration: AquariumConfiguration {
        AquariumConfiguration(
            vesselStyle: .panorama,
            fishSpecies: .glassGold,
            fishCount: .duet,
            additionalFishSpecies: [.opalAngelfish],
            companion: .crab,
            substrate: .moonGravel,
            decoration: .glassPearls,
            featurePiece: .moonLantern
        )
    }
}

private struct TankComposerScreen: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var draft: BowlProfile
    @State private var previewFormat: AquariumDisplayFormat = .studioHero
    @State private var isPremiumSheetPresented = false
    @FocusState private var isNameFieldFocused: Bool
    @ObservedObject var premiumStore: PremiumStore

    let onSave: (BowlProfile) -> Void
    let onCancel: () -> Void

    init(
        initialProfile: BowlProfile,
        premiumStore: PremiumStore,
        onSave: @escaping (BowlProfile) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: initialProfile)
        self.premiumStore = premiumStore
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var orderedVessels: [AquariumVesselStyle] {
        freeFirst(Array(AquariumVesselStyle.allCases)) { $0.isPremium }
    }

    private var orderedFishSpecies: [FishSpecies] {
        freeFirst(Array(FishSpecies.allCases)) { $0.isPremium }
    }

    private var orderedSubstrates: [SubstrateStyle] {
        freeFirst(Array(SubstrateStyle.allCases)) { $0.isPremium }
    }

    private var orderedDecorations: [DecorationStyle] {
        freeFirst(Array(DecorationStyle.allCases)) { $0.isPremium }
    }

    private var orderedFeaturePieces: [FeaturePieceStyle] {
        freeFirst(Array(FeaturePieceStyle.allCases)) { $0.isPremium }
    }

    private var orderedCompanions: [CompanionStyle] {
        freeFirst(Array(CompanionStyle.allCases)) { $0.isPremium }
    }

    private var companionSlotLimit: Int {
        premiumStore.isPremiumUnlocked ? 3 : 1
    }

    private var visibleCompanionSlotCount: Int {
        if !premiumStore.isPremiumUnlocked {
            return 1
        }

        return min(
            companionSlotLimit,
            max(1, min(companionSlotLimit, draft.configuration.resolvedCompanions.count + 1))
        )
    }

    private var extraFishSlotCount: Int {
        max(0, draft.configuration.fishCount.value - 1)
    }

    private var showsMixedSpeciesControls: Bool {
        premiumStore.isPremiumUnlocked && extraFishSlotCount > 0
    }

    private var visibleAdditionalFishSlotCount: Int {
        min(
            extraFishSlotCount,
            max(1, min(extraFishSlotCount, draft.configuration.additionalFishSpecies.count + 1))
        )
    }

    private var previewHeroHeight: CGFloat {
        min(max(UIScreen.main.bounds.width * 0.92, 360), 420)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientScreenBackdrop(
                    configuration: draft.configuration,
                    renderStyle: .lightweight
                )

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        composerHeader
                        previewSection
                        detailsSection
                        controlsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 34)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $isPremiumSheetPresented) {
            PremiumUnlockSheet(store: premiumStore)
        }
    }

    private func freeFirst<Option>(_ options: [Option], isPremium: (Option) -> Bool) -> [Option] {
        options.filter { !isPremium($0) } + options.filter(isPremium)
    }

    private func premiumBadge(isPremium: Bool) -> String? {
        guard isPremium, !premiumStore.isPremiumUnlocked else { return nil }
        return "Premium"
    }

    private func trimAdditionalFishSpecies(for count: FishCount) {
        draft.configuration.additionalFishSpecies = Array(
            draft.configuration.additionalFishSpecies.prefix(max(0, count.value - 1))
        )
    }

    private func selectedAdditionalSpecies(at slot: Int) -> FishSpecies? {
        guard slot < draft.configuration.additionalFishSpecies.count else { return nil }
        return draft.configuration.additionalFishSpecies[slot]
    }

    private func setAdditionalSpecies(_ species: FishSpecies?, at slot: Int) {
        let requiredCount = max(0, draft.configuration.fishCount.value - 1)
        var extras = Array(draft.configuration.additionalFishSpecies.prefix(requiredCount))

        guard slot < requiredCount else { return }

        if let species {
            while extras.count <= slot {
                extras.append(draft.configuration.fishSpecies)
            }
            extras[slot] = species
        } else {
            extras = Array(extras.prefix(slot))
        }

        draft.configuration.additionalFishSpecies = Array(extras.prefix(requiredCount))
    }

    private func selectedCompanion(at slot: Int) -> CompanionStyle? {
        guard slot < draft.configuration.resolvedCompanions.count else { return nil }
        return draft.configuration.resolvedCompanions[slot]
    }

    private func setCompanion(_ companion: CompanionStyle?, at slot: Int) {
        var companions = Array(draft.configuration.resolvedCompanions.prefix(companionSlotLimit))
        guard slot < companionSlotLimit else { return }

        if let companion, companion != .none {
            while companions.count <= slot {
                companions.append(.snail)
            }
            companions[slot] = companion
        } else {
            companions = Array(companions.prefix(slot))
        }

        draft.configuration.companions = Array(companions.prefix(companionSlotLimit))
    }

    private var composerHeader: some View {
        GlassPanel(cornerRadius: 34) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    IconGlassButton(systemImage: "xmark") {
                        onCancel()
                    }

                    Spacer()

                    if !premiumStore.isPremiumUnlocked {
                        ActionGlassButton(title: "Go Premium", systemImage: "crown.fill") {
                            isPremiumSheetPresented = true
                        }
                    }

                    ActionGlassButton(title: "Add Tank", systemImage: "checkmark") {
                        onSave(sanitizedDraft)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("New Tank")
                        .font(.system(size: 38, weight: .medium, design: .serif))
                        .foregroundStyle(colorScheme.fishbowlPrimaryText)

                    Text("Set the name, choose the fish, and decide if this one stays a pet or just sits there and looks good.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(colorScheme.fishbowlSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !premiumStore.isPremiumUnlocked {
                    PremiumComposerBanner {
                        isPremiumSheetPresented = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        GlassPanel(cornerRadius: 34) {
            VStack(alignment: .leading, spacing: 18) {
                Group {
                    switch previewFormat {
                    case .studioHero:
                        AquariumSceneView(
                            configuration: previewConfiguration,
                            format: .studioHero,
                            phase: 0.24,
                            petSnapshot: draft.petSnapshot(at: .now)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: previewHeroHeight)
                        .drawingGroup(opaque: false)
                    default:
                        WidgetSizePreview(
                            configuration: previewConfiguration,
                            format: previewFormat,
                            petSnapshot: draft.petSnapshot(at: .now)
                        )
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach([AquariumDisplayFormat.studioHero, .widgetSmall, .widgetMedium, .widgetLarge]) { option in
                            SelectablePill(
                                title: option.title,
                                subtitle: option == .studioHero ? "Big preview" : "Widget size",
                                isSelected: previewFormat == option
                            ) {
                                previewFormat = option
                            }
                        }
                    }
                }
            }
        }
    }

    private var detailsSection: some View {
        GlassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    SectionEyebrow(
                        title: "Details",
                        detail: "Give this tank a name. Pet mode is the default, but you can switch it to decorative."
                    )

                VStack(alignment: .leading, spacing: 8) {
                    Text("TANK NAME")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)

                    TextField("Blue Bowl", text: $draft.name)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.86) : Color.black.opacity(0.86))
                        .textInputAutocapitalization(.words)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(colorScheme.fishbowlGlassButtonFill)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(colorScheme.fishbowlGlassButtonStroke, lineWidth: 1)
                                }
                        }
                        .focused($isNameFieldFocused)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(AquariumMode.allCases) { option in
                            SelectablePill(
                                title: option.title,
                                subtitle: option.summary,
                                isSelected: draft.mode == option
                            ) {
                                draft.mode = option
                            }
                        }
                    }
                }
            }
        }
    }

    private var controlsSection: some View {
        VStack(spacing: 16) {
            GlassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    SectionEyebrow(
                        title: "Vessel",
                        detail: "Choose the kind of bowl or tank you want."
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(orderedVessels) { option in
                            SelectablePill(
                                title: option.title,
                                subtitle: option.summary,
                                isSelected: draft.configuration.vesselStyle == option,
                                badge: premiumBadge(isPremium: option.isPremium),
                                isLocked: option.isPremium && !premiumStore.isPremiumUnlocked
                            ) {
                                if option.isPremium && !premiumStore.isPremiumUnlocked {
                                    isPremiumSheetPresented = true
                                } else {
                                    draft.configuration.vesselStyle = option
                                }
                            }
                        }
                    }
                }
                }
            }

            GlassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    SectionEyebrow(
                        title: "Fish",
                        detail: "Pick the fish and how many you want swimming around. Premium can also mix different species together."
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(orderedFishSpecies) { option in
                            SelectablePill(
                                title: option.title,
                                subtitle: option.summary,
                                isSelected: draft.configuration.fishSpecies == option,
                                badge: premiumBadge(isPremium: option.isPremium),
                                isLocked: option.isPremium && !premiumStore.isPremiumUnlocked
                            ) {
                                if option.isPremium && !premiumStore.isPremiumUnlocked {
                                    isPremiumSheetPresented = true
                                } else {
                                    draft.configuration.fishSpecies = option
                                }
                            }
                        }
                    }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(FishCount.allCases) { option in
                                SelectablePill(
                                    title: option.title,
                                    subtitle: "Fish count",
                                    isSelected: draft.configuration.fishCount == option
                                ) {
                                    draft.configuration.fishCount = option
                                    trimAdditionalFishSpecies(for: option)
                                }
                            }
                        }
                    }

                    if showsMixedSpeciesControls {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(0..<visibleAdditionalFishSlotCount, id: \.self) { slot in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("FISH \(slot + 2)")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .tracking(1.2)
                                        .foregroundStyle(.secondary)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 10) {
                                            SelectablePill(
                                                title: "None",
                                                subtitle: "Leave this slot empty",
                                                isSelected: selectedAdditionalSpecies(at: slot) == nil
                                            ) {
                                                setAdditionalSpecies(nil, at: slot)
                                            }

                                            ForEach(orderedFishSpecies) { option in
                                                SelectablePill(
                                                    title: option.title,
                                                    subtitle: option.summary,
                                                    isSelected: selectedAdditionalSpecies(at: slot) == option,
                                                    badge: premiumBadge(isPremium: option.isPremium),
                                                    isLocked: option.isPremium && !premiumStore.isPremiumUnlocked
                                                ) {
                                                    if option.isPremium && !premiumStore.isPremiumUnlocked {
                                                        isPremiumSheetPresented = true
                                                    } else {
                                                        setAdditionalSpecies(option, at: slot)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            GlassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    SectionEyebrow(
                        title: "Personality",
                        detail: "Choose the overall mood and motion for this tank."
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(FishPersonality.allCases) { option in
                                SelectablePill(
                                    title: option.title,
                                    subtitle: option.summary,
                                    isSelected: draft.configuration.personality == option
                                ) {
                                    draft.configuration.personality = option
                                }
                            }
                        }
                    }
                }
            }

            GlassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    SectionEyebrow(
                        title: "Habitat",
                        detail: "Choose the bottom and the little details that sit inside the bowl."
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(orderedSubstrates) { option in
                                SelectablePill(
                                    title: option.title,
                                    subtitle: option.summary,
                                    isSelected: draft.configuration.substrate == option,
                                    badge: premiumBadge(isPremium: option.isPremium),
                                    isLocked: option.isPremium && !premiumStore.isPremiumUnlocked
                                ) {
                                    if option.isPremium && !premiumStore.isPremiumUnlocked {
                                        isPremiumSheetPresented = true
                                    } else {
                                        draft.configuration.substrate = option
                                    }
                                }
                            }
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(orderedDecorations) { option in
                                SelectablePill(
                                    title: option.title,
                                    subtitle: option.summary,
                                    isSelected: draft.configuration.decoration == option,
                                    badge: premiumBadge(isPremium: option.isPremium),
                                    isLocked: option.isPremium && !premiumStore.isPremiumUnlocked
                                ) {
                                    if option.isPremium && !premiumStore.isPremiumUnlocked {
                                        isPremiumSheetPresented = true
                                    } else {
                                        draft.configuration.decoration = option
                                    }
                                }
                            }
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(orderedFeaturePieces) { option in
                                SelectablePill(
                                    title: option.title,
                                    subtitle: option.summary,
                                    isSelected: draft.configuration.featurePiece == option,
                                    badge: premiumBadge(isPremium: option.isPremium),
                                    isLocked: option.isPremium && !premiumStore.isPremiumUnlocked
                                ) {
                                    if option.isPremium && !premiumStore.isPremiumUnlocked {
                                        isPremiumSheetPresented = true
                                    } else {
                                        draft.configuration.featurePiece = option
                                    }
                                }
                            }
                        }
                    }
                }
            }

            GlassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    SectionEyebrow(
                        title: "Companion",
                        detail: premiumStore.isPremiumUnlocked
                        ? "Pick up to three companions, or leave the tank simple."
                        : "Pick one companion, or leave the tank simple."
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(0..<visibleCompanionSlotCount, id: \.self) { slot in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("COMPANION \(slot + 1)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .tracking(1.2)
                                    .foregroundStyle(.secondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        SelectablePill(
                                            title: "None",
                                            subtitle: "Leave this slot empty",
                                            isSelected: selectedCompanion(at: slot) == nil
                                        ) {
                                            setCompanion(nil, at: slot)
                                        }

                                        ForEach(orderedCompanions.filter { $0 != .none }) { option in
                                            SelectablePill(
                                                title: option.title,
                                                subtitle: option.summary,
                                                isSelected: selectedCompanion(at: slot) == option,
                                                badge: premiumBadge(isPremium: option.isPremium || slot > 0),
                                                isLocked: (option.isPremium || slot > 0) && !premiumStore.isPremiumUnlocked
                                            ) {
                                                if (option.isPremium || slot > 0) && !premiumStore.isPremiumUnlocked {
                                                    isPremiumSheetPresented = true
                                                } else {
                                                    setCompanion(option, at: slot)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var previewConfiguration: AquariumConfiguration {
        switch previewFormat {
        case .widgetMedium where draft.configuration.vesselStyle == .orb:
            return draft.configuration.withFallbackStyle(.gallery)
        case .widgetLarge where draft.configuration.vesselStyle == .orb:
            return draft.configuration.withFallbackStyle(.panorama)
        default:
            return draft.configuration
        }
    }

    private var sanitizedDraft: BowlProfile {
        var draft = draft
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.name = trimmedName.isEmpty ? "New Bowl" : trimmedName
        draft.configuration.additionalFishSpecies = Array(
            draft.configuration.additionalFishSpecies.prefix(max(0, draft.configuration.fishCount.value - 1))
        )
        if !premiumStore.isPremiumUnlocked {
            draft.configuration = draft.configuration.sanitizedForFreeTier()
        }
        return draft
    }
}

private struct WidgetSizePreview: View {
    @Environment(\.colorScheme) private var colorScheme

    let configuration: AquariumConfiguration
    let format: AquariumDisplayFormat
    let petSnapshot: AquariumPetSnapshot

    var body: some View {
        GeometryReader { geometry in
            let tileSize = previewTileSize(for: geometry.size.width)
            let tileShape = RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous)

            ZStack {
                AquariumTileBackground()
                    .clipShape(tileShape)

                AquariumSceneView(
                    configuration: configuration,
                    format: format,
                    phase: petSnapshot.date.timeIntervalSinceReferenceDate / 8.0,
                    petSnapshot: petSnapshot
                )
                .padding(tileSceneInset)
                .drawingGroup(opaque: false)
            }
            .frame(width: tileSize.width, height: tileSize.height)
            .clipShape(tileShape)
            .overlay {
                tileShape
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.24) : Color.white.opacity(0.72), lineWidth: 1)
            }
            .shadow(color: colorScheme == .dark ? Color.black.opacity(0.24) : Color.black.opacity(0.10), radius: 16, y: 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: stageHeight)
    }

    private var tileCornerRadius: CGFloat {
        format == .widgetMedium ? 30 : 32
    }

    private var tileSceneInset: CGFloat {
        switch format {
        case .widgetSmall:
            return 2
        case .widgetMedium:
            return 4
        case .widgetLarge:
            return 6
        default:
            return 0
        }
    }

    private var stageHeight: CGFloat {
        switch format {
        case .widgetSmall:
            return 205
        case .widgetMedium:
            return 190
        case .widgetLarge:
            return 340
        default:
            return 360
        }
    }

    private func previewTileSize(for availableWidth: CGFloat) -> CGSize {
        let width: CGFloat

        switch format {
        case .widgetSmall:
            width = min(190, availableWidth * 0.60)
        case .widgetMedium:
            width = min(availableWidth, 380)
        case .widgetLarge:
            width = min(availableWidth, 390)
        default:
            width = availableWidth
        }

        return CGSize(width: width, height: width / format.aspectRatio)
    }
}

private struct AnimatedAquariumStage: View {
    let profile: BowlProfile
    let configuration: AquariumConfiguration
    let format: AquariumDisplayFormat
    let isFocused: Bool
    let isPrepared: Bool
    let isScrollFrozen: Bool
    let feedBursts: [AquariumFeedBurst]
    let onFeed: (CGFloat) -> Void
    let onFeedConsumed: AquariumFeedBurstConsumedHandler
    @State private var tapRipples: [AquariumTapRipple] = []

    private var restingPhase: Double {
        Double(abs(profile.id.hashValue % 997)) / 47.0
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                if isPrepared {
                    ZStack {
                        AquariumStaticBackdropView(
                            configuration: configuration,
                            format: format,
                            phase: restingPhase,
                            petSnapshot: profile.petSnapshot(at: .now),
                            showsDecoration: configuration.decoration != .coralGarden
                        )
                        .allowsHitTesting(false)

                        SpriteKitAquariumSceneView(
                            profile: profile,
                            configuration: configuration,
                            format: format,
                            feedBursts: feedBursts,
                            tapRipples: tapRipples,
                            phaseOffset: restingPhase,
                            isPaused: !isFocused || isScrollFrozen,
                            onFeedBurstConsumed: onFeedConsumed
                        )
                        .allowsHitTesting(false)

                        if configuration.decoration == .coralGarden {
                            AquariumDecorationForegroundOverlayView(
                                configuration: configuration,
                                format: format,
                                phase: restingPhase
                            )
                            .allowsHitTesting(false)
                        }
                    }
                } else {
                    restingScene
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .highPriorityGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        registerInteraction(at: value.location, in: geometry.size)
                    }
            )
        }
    }

    private var restingScene: some View {
        AquariumSceneView(
            configuration: configuration,
            format: format,
            phase: restingPhase,
            petSnapshot: profile.petSnapshot(at: .now),
            foodPellets: []
        )
    }

    private func registerInteraction(at location: CGPoint, in size: CGSize) {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let normalizedLocation = CGPoint(
            x: min(max(location.x / width, 0.08), 0.92),
            y: min(max(location.y / height, 0.10), 0.90)
        )
        let now = Date.now

        tapRipples = Array(
            (tapRipples.filter { now.timeIntervalSince($0.startedAt) < 1.2 } + [
                AquariumTapRipple(startedAt: now, normalizedLocation: normalizedLocation)
            ])
            .suffix(6)
        )

        onFeed(normalizedLocation.x)
    }
}

private struct TankDetailCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let profile: BowlProfile

    private var maxCardWidth: CGFloat {
        min(max(320, UIScreen.main.bounds.width - 56), 360)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.configuration.vesselStyle.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.2)

                Text(profile.configuration.descriptor)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.88) : Color.black.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)

                Text(profile.configuration.detailLine)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(colorScheme.fishbowlTertiaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: maxCardWidth, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(colorScheme.fishbowlCardFill)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(colorScheme.fishbowlCardStroke, lineWidth: 1)
                }
        }
        .shadow(color: colorScheme.fishbowlShadow, radius: 18, y: 8)
    }
}

private struct PhotoShareCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let profile: BowlProfile

    var body: some View {
        GeometryReader { geometry in
            let cardSize = min(geometry.size.width, geometry.size.height)
            let bowlSize = cardSize * 0.82
            let bowlLift = cardSize * 0.08
            let bottomMargin = cardSize * 0.06
            let renderDate = Date.now

            ZStack {
                AmbientScreenBackdrop(
                    configuration: profile.configuration,
                    renderStyle: .lightweight
                )

                AquariumSceneView(
                    configuration: profile.configuration,
                    format: .widgetLarge,
                    phase: renderDate.timeIntervalSinceReferenceDate / 4.1,
                    petSnapshot: profile.petSnapshot(at: renderDate)
                )
                .frame(width: bowlSize, height: bowlSize)
                .offset(y: -bowlLift)

                VStack {
                    Spacer(minLength: 0)

                    HStack {
                        ShareInfoPlaque(
                            title: profile.name,
                            subtitle: "Glass Aquarium"
                        )

                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 18)
                    .padding(.trailing, 18)
                    .padding(.bottom, bottomMargin)
                }
            }
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
    }
}

private struct ShareInfoPlaque: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(colorScheme.fishbowlPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            Text(subtitle)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(colorScheme.fishbowlSecondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: 235, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(colorScheme.fishbowlCardFill)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .stroke(colorScheme.fishbowlCardStroke, lineWidth: 1.2)
                }
        }
        .shadow(color: colorScheme.fishbowlShadow.opacity(1.05), radius: 20, y: 10)
    }
}

private struct AmbientScreenBackdrop: View {
    enum RenderStyle {
        case full
        case lightweight
    }

    @Environment(\.colorScheme) private var colorScheme

    let configuration: AquariumConfiguration
    var renderStyle: RenderStyle = .full

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let palette = configuration.ambientBackdropColors
            let fieldYOffset = colorScheme == .dark
            ? -size.height * (renderStyle == .lightweight ? 0.20 : 0.24)
            : -size.height * (renderStyle == .lightweight ? 0.14 : 0.18)

            ZStack {
                backgroundBase

                ZStack {
                    Ellipse()
                        .fill(palette[0].opacity(colorScheme == .dark ? primaryOpacity : primaryOpacity * 0.74))
                        .frame(width: size.width * (renderStyle == .lightweight ? 0.94 : 1.06), height: size.height * (renderStyle == .lightweight ? 0.36 : 0.46))
                        .blur(radius: renderStyle == .lightweight ? 62 : 96)
                        .offset(x: -size.width * 0.18, y: size.height * (renderStyle == .lightweight ? 0.00 : 0.05))
                        .blendMode(colorScheme == .dark ? .screen : .multiply)

                    Ellipse()
                        .fill(palette[1].opacity(colorScheme == .dark ? secondaryOpacity : secondaryOpacity * 0.74))
                        .frame(width: size.width * (renderStyle == .lightweight ? 0.88 : 1.02), height: size.height * (renderStyle == .lightweight ? 0.34 : 0.44))
                        .blur(radius: renderStyle == .lightweight ? 54 : 90)
                        .offset(x: size.width * 0.18, y: size.height * (renderStyle == .lightweight ? 0.03 : 0.08))
                        .blendMode(colorScheme == .dark ? .screen : .multiply)

                    if renderStyle == .full {
                        Ellipse()
                            .fill(palette[2].opacity(colorScheme == .dark ? 0.09 : 0.06))
                            .frame(width: size.width * 0.90, height: size.height * 0.38)
                            .blur(radius: 82)
                            .offset(x: 0, y: size.height * 0.20)
                            .blendMode(colorScheme == .dark ? .screen : .multiply)
                    }

                    if colorScheme == .dark {
                        ZStack {
                            Ellipse()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            palette[0].opacity(renderStyle == .lightweight ? 0.024 : 0.05),
                                            palette[2].opacity(renderStyle == .lightweight ? 0.032 : 0.07),
                                            Color.clear,
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: size.width * (renderStyle == .lightweight ? 0.76 : 0.92),
                                    height: size.height * (renderStyle == .lightweight ? 0.16 : 0.22)
                                )
                                .rotationEffect(.degrees(-6))
                                .offset(x: -size.width * 0.08, y: size.height * (renderStyle == .lightweight ? 0.08 : 0.13))

                            Ellipse()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.clear,
                                            palette[1].opacity(renderStyle == .lightweight ? 0.028 : 0.06),
                                            palette[2].opacity(renderStyle == .lightweight ? 0.026 : 0.05),
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: size.width * (renderStyle == .lightweight ? 0.84 : 0.98),
                                    height: size.height * (renderStyle == .lightweight ? 0.18 : 0.24)
                                )
                                .rotationEffect(.degrees(9))
                                .offset(x: size.width * 0.10, y: size.height * (renderStyle == .lightweight ? 0.10 : 0.16))
                        }
                        .blur(radius: renderStyle == .lightweight ? 44 : 76)
                        .blendMode(.screen)
                    } else {
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        palette[0].opacity(renderStyle == .lightweight ? 0.018 : 0.026),
                                        palette[2].opacity(renderStyle == .lightweight ? 0.022 : 0.032),
                                        Color.clear,
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: size.width * (renderStyle == .lightweight ? 0.96 : 1.08),
                                height: size.height * (renderStyle == .lightweight ? 0.18 : 0.24)
                            )
                            .rotationEffect(.degrees(-4))
                            .blur(radius: renderStyle == .lightweight ? 58 : 88)
                            .offset(y: size.height * (renderStyle == .lightweight ? 0.10 : 0.15))
                            .blendMode(.multiply)

                        Ellipse()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        palette[1].opacity(renderStyle == .lightweight ? 0.016 : 0.024),
                                        palette[2].opacity(renderStyle == .lightweight ? 0.018 : 0.026),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: size.width * (renderStyle == .lightweight ? 0.82 : 0.94),
                                height: size.height * (renderStyle == .lightweight ? 0.16 : 0.20)
                            )
                            .rotationEffect(.degrees(11))
                            .blur(radius: renderStyle == .lightweight ? 52 : 80)
                            .offset(x: size.width * 0.08, y: size.height * (renderStyle == .lightweight ? 0.12 : 0.17))
                            .blendMode(.multiply)
                    }
                }
                .opacity(renderStyle == .lightweight ? (colorScheme == .dark ? 0.24 : 0.24) : (colorScheme == .dark ? 0.44 : 0.42))
                .offset(y: fieldYOffset)
                .mask {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.00),
                                    .init(color: .white.opacity(0.06), location: 0.08),
                                    .init(color: .white, location: 0.22),
                                    .init(color: .white, location: 0.72),
                                    .init(color: .white.opacity(0.08), location: 0.88),
                                    .init(color: .clear, location: 1.00),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay {
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.00),
                                    .init(color: .white.opacity(0.12), location: 0.10),
                                    .init(color: .white, location: 0.24),
                                    .init(color: .white, location: 0.76),
                                    .init(color: .white.opacity(0.12), location: 0.90),
                                    .init(color: .clear, location: 1.00),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .blendMode(.multiply)
                        }
                }

                VStack(spacing: 0) {
                    LinearGradient(
                        colors: topFadeColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: size.height * 0.30)

                    Spacer(minLength: 0)

                    LinearGradient(
                        colors: bottomFadeColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: size.height * 0.30)
                }
            }
            .ignoresSafeArea()
        }
    }

    private var backgroundBase: Color {
        colorScheme == .dark
        ? Color.black
        : Color.white
    }

    private var primaryOpacity: Double {
        renderStyle == .lightweight ? 0.08 : 0.12
    }

    private var secondaryOpacity: Double {
        renderStyle == .lightweight ? 0.07 : 0.10
    }

    private var topFadeColors: [Color] {
        if colorScheme == .dark {
            return [
                backgroundBase,
                backgroundBase.opacity(0.98),
                backgroundBase.opacity(0.62),
                Color.clear,
            ]
        }

        return [
            Color.white,
            Color.white.opacity(0.98),
            Color.white.opacity(0.40),
            Color.clear,
        ]
    }

    private var bottomFadeColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.clear,
                backgroundBase.opacity(0.52),
                backgroundBase.opacity(0.98),
                backgroundBase,
            ]
        }

        return [
            Color.clear,
            Color.white.opacity(0.36),
            Color.white.opacity(0.98),
            Color.white,
        ]
    }
}

private struct ActionGlassButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.82) : Color.black.opacity(0.82))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background {
                    Capsule(style: .continuous)
                        .fill(colorScheme.fishbowlGlassButtonFill)
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(colorScheme.fishbowlGlassButtonStroke, lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
    }
}

private struct IconGlassButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.76) : Color.black.opacity(0.78))
                .frame(width: 42, height: 42)
                .background {
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.20))
                        .overlay {
                            Circle()
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.18) : Color.white.opacity(0.72), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
    }
}

private struct PremiumComposerBanner: View {
    @Environment(\.colorScheme) private var colorScheme

    let onUnlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.72, green: 0.55, blue: 0.09))

                Text("Free includes 3 tanks")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.86) : Color.black.opacity(0.84))

                Spacer(minLength: 0)
            }

            Text("Unlock up to 12 tanks, mix different fish together, and open up the richer habitats and feature pieces.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(colorScheme.fishbowlSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            ActionGlassButton(title: "Unlock Premium", systemImage: "crown.fill") {
                onUnlock()
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.16))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.16) : Color.white.opacity(0.80), lineWidth: 1)
                }
        }
    }
}

private struct PremiumBullet: View {
    @Environment(\.colorScheme) private var colorScheme

    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color(red: 0.73, green: 0.57, blue: 0.12))
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.74) : Color.black.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PremiumUnlockSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var store: PremiumStore

    private var showcaseConfiguration: AquariumConfiguration {
        AquariumConfiguration(
            vesselStyle: .panorama,
            fishSpecies: .glassGold,
            fishCount: .duet,
            additionalFishSpecies: [.opalAngelfish],
            companion: .crab,
            substrate: .moonGravel,
            decoration: .glassPearls,
            featurePiece: .moonLantern
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientScreenBackdrop(
                    configuration: showcaseConfiguration,
                    renderStyle: .lightweight
                )

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        GlassPanel(cornerRadius: 34, showsGlassEffect: false) {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("Fishbowl Premium")
                                        .font(.system(size: 36, weight: .medium, design: .serif))
                                        .foregroundStyle(colorScheme.fishbowlPrimaryText)

                                    Spacer()

                                    IconGlassButton(systemImage: "xmark") {
                                        dismiss()
                                    }
                                }

                                Text("Unlock the full aquarium with 12 tanks, mixed-species schools, richer habitats, and feature pieces.")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundStyle(colorScheme.fishbowlSecondaryText)
                                    .fixedSize(horizontal: false, vertical: true)

                                AquariumSceneView(
                                    configuration: showcaseConfiguration,
                                    format: .studioHero,
                                    phase: 0.28,
                                    petSnapshot: .decorative(at: .now)
                                )
                                .frame(height: 260)
                                .drawingGroup(opaque: false)
                            }
                        }

                        GlassPanel(showsGlassEffect: false) {
                            VStack(alignment: .leading, spacing: 14) {
                                PremiumBullet(text: "Save up to 12 tanks instead of 3")
                                PremiumBullet(text: "Mix different fish species together in the same tank")
                                PremiumBullet(text: "Unlock Panorama Tank, Leopard Shark, Glass Goldfish, and Opal Angelfish")
                                PremiumBullet(text: "Unlock Coral Garden, Glass Pearls, Moon Gravel, Coral Bloom, Shrimp, and Crab")
                                PremiumBullet(text: "Add feature pieces like driftwood arches, moon lanterns, and kelp")
                            }
                        }

                        if let statusMessage = store.statusMessage {
                            Text(statusMessage)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.62) : Color.black.opacity(0.62))
                                .padding(.horizontal, 8)
                        }

                        VStack(spacing: 12) {
                            Button {
                                Task {
                                    await store.purchasePremium()
                                }
                            } label: {
                                Text(store.purchaseButtonTitle)
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 15)
                                    .background(
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(red: 0.16, green: 0.24, blue: 0.48),
                                                        Color(red: 0.24, green: 0.48, blue: 0.88),
                                                    ],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(store.isBusy)

                            Button("Restore Purchases") {
                                Task {
                                    await store.restorePurchases()
                                }
                            }
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.74) : Color.black.opacity(0.72))
                            .disabled(store.isBusy)

                            #if DEBUG
                            Button(store.isPreviewUnlocked ? "Disable Preview Unlock" : "Use Preview Unlock") {
                                store.togglePreviewUnlock()
                            }
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.56) : Color.black.opacity(0.54))
                            #endif
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            await store.prepare()
        }
        .onChange(of: store.isPremiumUnlocked) { _, unlocked in
            if unlocked {
                dismiss()
            }
        }
    }
}

private extension ColorScheme {
    var fishbowlPrimaryText: Color {
        self == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.90)
    }

    var fishbowlSecondaryText: Color {
        self == .dark ? Color.white.opacity(0.68) : Color.black.opacity(0.60)
    }

    var fishbowlTertiaryText: Color {
        self == .dark ? Color.white.opacity(0.56) : Color.black.opacity(0.56)
    }

    var fishbowlElevatedFill: Color {
        self == .dark
        ? Color(red: 0.12, green: 0.13, blue: 0.17).opacity(0.86)
        : Color.white
    }

    var fishbowlElevatedStroke: Color {
        self == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)
    }

    var fishbowlShadow: Color {
        self == .dark ? Color.black.opacity(0.26) : Color.black.opacity(0.08)
    }

    var fishbowlCardFill: Color {
        self == .dark ? Color.black.opacity(0.24) : Color.white.opacity(0.12)
    }

    var fishbowlCardStroke: Color {
        self == .dark ? Color.white.opacity(0.22) : Color.white.opacity(0.80)
    }

    var fishbowlGlassButtonFill: Color {
        self == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.22)
    }

    var fishbowlGlassButtonStroke: Color {
        self == .dark ? Color.white.opacity(0.20) : Color.white.opacity(0.76)
    }
}

@MainActor
private final class PremiumStore: ObservableObject {
    @Published private(set) var isPremiumUnlocked = PremiumAccess.isPremiumUnlocked
    @Published private(set) var premiumProduct: Product?
    @Published private(set) var isBusy = false
    @Published var statusMessage: String?

    private var updatesTask: Task<Void, Never>?

    var tankLimit: Int {
        isPremiumUnlocked ? PremiumAccess.premiumTankLimit : PremiumAccess.freeTankLimit
    }

    var purchaseButtonTitle: String {
        if let premiumProduct {
            return "Unlock for \(premiumProduct.displayPrice)"
        }
        return "Unlock for \(PremiumAccess.fallbackPrice)"
    }

    #if DEBUG
    var isPreviewUnlocked: Bool {
        PremiumAccess.isPreviewUnlockEnabled
    }
    #endif

    init() {
        updatesTask = Task { [weak self] in
            await self?.observeTransactions()
        }

        Task { [weak self] in
            await self?.prepare()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func prepare() async {
        await refreshEntitlements()
        await loadProductIfNeeded()
    }

    func purchasePremium() async {
        statusMessage = nil
        await loadProductIfNeeded()

        guard let premiumProduct else {
            statusMessage = "Create the non-consumable product \(PremiumAccess.productID) in App Store Connect or attach a StoreKit config to test purchases."
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let result = try await premiumProduct.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                applyUnlocked(transaction.revocationDate == nil)
                await transaction.finish()
            case .pending:
                statusMessage = "Purchase is pending approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        statusMessage = nil
        isBusy = true
        defer { isBusy = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPremiumUnlocked {
                statusMessage = "No premium purchase was found to restore."
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    #if DEBUG
    func togglePreviewUnlock() {
        PremiumAccess.setPreviewUnlockEnabled(!PremiumAccess.isPreviewUnlockEnabled)
        applyUnlocked(PremiumAccess.isPremiumUnlocked)
    }
    #endif

    private func loadProductIfNeeded() async {
        guard premiumProduct == nil else { return }

        do {
            premiumProduct = try await Product.products(for: [PremiumAccess.productID]).first
        } catch {
            statusMessage = "Could not load purchase details right now."
        }
    }

    private func refreshEntitlements() async {
        var unlocked = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == PremiumAccess.productID else { continue }
            guard transaction.revocationDate == nil else { continue }
            unlocked = true
            break
        }

        applyUnlocked(unlocked || PremiumAccess.isPremiumUnlocked)
    }

    private func observeTransactions() async {
        for await result in Transaction.updates {
            guard !Task.isCancelled else { return }
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == PremiumAccess.productID else { continue }

            applyUnlocked(transaction.revocationDate == nil)
            await transaction.finish()
        }
    }

    private func applyUnlocked(_ unlocked: Bool) {
        PremiumAccess.setPremiumUnlocked(unlocked)
        isPremiumUnlocked = PremiumAccess.isPremiumUnlocked
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw PremiumStoreError.failedVerification
        }
    }
}

private enum PremiumStoreError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "The App Store could not verify that purchase."
        }
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private extension AquariumConfiguration {
    func withFallbackStyle(_ style: AquariumVesselStyle) -> AquariumConfiguration {
        AquariumConfiguration(
            vesselStyle: vesselStyle == .orb && style != .orb ? style : vesselStyle,
            fishSpecies: fishSpecies,
            fishCount: fishCount,
            additionalFishSpecies: additionalFishSpecies,
            personality: personality,
            companion: companion,
            substrate: substrate,
            decoration: decoration,
            featurePiece: featurePiece
        )
    }

    var ambientBackdropColors: [Color] {
        [
            fishPalette.dropFirst().first ?? fishPalette.first ?? Color.white,
            decoration.accentColors[1],
            substrate.accentColors[2],
        ]
    }
}
