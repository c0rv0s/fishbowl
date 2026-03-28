import SwiftUI

struct ContentView: View {
    @StateObject private var studio = BowlStudio()
    @State private var composerDraft: BowlProfile?
    @State private var deletingProfile: BowlProfile?
    @State private var feedBurstsByProfileID: [UUID: [FeedBurst]] = [:]

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(studio.profiles) { profile in
                            TankHomePage(
                                profile: profile,
                                safeAreaInsets: geometry.safeAreaInsets,
                                feedBursts: feedBurstsByProfileID[profile.id] ?? [],
                                onFeed: { xFraction in
                                    dropFood(in: profile, at: xFraction)
                                },
                                onDelete: {
                                    deletingProfile = profile
                                }
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .id(profile.id)
                        }

                        if studio.canCreateProfile {
                            AddTankPage(
                                slotNumber: studio.profiles.count + 1,
                                safeAreaInsets: geometry.safeAreaInsets
                            ) {
                                composerDraft = studio.makeDraftProfile()
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .id("add-slot-\(studio.profiles.count)")
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollClipDisabled()
            }
            .navigationBarHidden(true)
        }
        .fullScreenCover(item: $composerDraft) { draft in
            TankComposerScreen(initialProfile: draft) { profile in
                studio.addProfile(profile)
                composerDraft = nil
            } onCancel: {
                composerDraft = nil
            }
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
    }

    private func dropFood(in profile: BowlProfile, at xFraction: CGFloat) {
        let snapshot = profile.petSnapshot(at: .now)
        guard profile.mode == .pet, snapshot.isAlive else { return }

        let now = Date.now
        let clampedX = min(max(xFraction, 0.18), 0.82)
        let activeBursts = feedBurstsByProfileID[profile.id, default: []]
            .filter { now.timeIntervalSince($0.startedAt) < 1.6 }

        feedBurstsByProfileID[profile.id] = activeBursts + [
            FeedBurst(startedAt: now, xFraction: clampedX)
        ]

        studio.feedProfile(id: profile.id, at: now)
    }
}

private struct TankHomePage: View {
    let profile: BowlProfile
    let safeAreaInsets: EdgeInsets
    let feedBursts: [FeedBurst]
    let onFeed: (CGFloat) -> Void
    let onDelete: () -> Void

    private var snapshot: AquariumPetSnapshot {
        profile.petSnapshot(at: .now)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AmbientScreenBackdrop(configuration: profile.configuration)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(profile.name)
                            .font(.system(size: 44, weight: .medium, design: .serif))
                            .foregroundStyle(Color.black.opacity(0.90))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Text(subtitleText)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.60))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 14)

                    IconGlassButton(systemImage: "trash") {
                        onDelete()
                    }
                }

                AnimatedAquariumStage(
                    profile: profile,
                    configuration: profile.configuration,
                    format: .widgetLarge,
                    feedBursts: feedBursts,
                    onFeed: onFeed
                )
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)

                Spacer(minLength: 0)
            }
            .padding(.top, max(22, safeAreaInsets.top + 10))
            .padding(.horizontal, 24)
            .padding(.bottom, max(28, safeAreaInsets.bottom + 14))

            TankDetailCard(profile: profile)
                .padding(.horizontal, 24)
                .padding(.bottom, max(24, safeAreaInsets.bottom + 8))
        }
    }

    private var subtitleText: String {
        switch profile.mode {
        case .decorative:
            return "Decorative • Made for your Home Screen"
        case .pet:
            return snapshot.isAlive
            ? "\(snapshot.mood.title) • \(subtitlePrompt)"
            : "Gone • Delete this tank to make a new one"
        }
    }

    private var subtitlePrompt: String {
        switch snapshot.mood {
        case .decorative:
            return "Made for your Home Screen"
        case .content:
            return "Tap the tank to drop food in"
        case .hungry:
            return "Tap the tank to feed your fish"
        case .critical:
            return "Feed this tank now"
        case .dead:
            return "Delete this tank to make a new one"
        }
    }

}

private struct AddTankPage: View {
    let slotNumber: Int
    let safeAreaInsets: EdgeInsets
    let onCreate: () -> Void

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer(minLength: max(42, safeAreaInsets.top + 28))

                VStack(alignment: .leading, spacing: 10) {
                    Text("New Tank")
                        .font(.system(size: 46, weight: .medium, design: .serif))
                        .foregroundStyle(Color.black.opacity(0.90))

                    Text("Slot \(slotNumber) of 3 is open. Tap below to make a fresh bowl or pet tank.")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.56))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onCreate) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 38, style: .continuous)
                            .fill(Color.white)
                            .overlay {
                                RoundedRectangle(cornerRadius: 38, style: .continuous)
                                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                            }
                            .shadow(color: Color.black.opacity(0.05), radius: 18, y: 10)

                        VStack(spacing: 14) {
                            Image(systemName: "plus")
                                .font(.system(size: 46, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.76))

                            Text("Make a New Tank")
                                .font(.system(size: 21, weight: .semibold, design: .serif))
                                .foregroundStyle(Color.black.opacity(0.84))

                            Text("Pick the fish, choose the bowl, and give it a name.")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.black.opacity(0.54))
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

private struct TankComposerScreen: View {
    @State private var draft: BowlProfile
    @State private var previewFormat: AquariumDisplayFormat = .studioHero
    @FocusState private var isNameFieldFocused: Bool

    let onSave: (BowlProfile) -> Void
    let onCancel: () -> Void

    init(initialProfile: BowlProfile, onSave: @escaping (BowlProfile) -> Void, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: initialProfile)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientScreenBackdrop(configuration: draft.configuration)

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
    }

    private var composerHeader: some View {
        GlassPanel(cornerRadius: 34) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    IconGlassButton(systemImage: "xmark") {
                        onCancel()
                    }

                    Spacer()

                    ActionGlassButton(title: "Add Tank", systemImage: "checkmark") {
                        onSave(sanitizedDraft)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("New Tank")
                        .font(.system(size: 38, weight: .medium, design: .serif))
                        .foregroundStyle(Color.black.opacity(0.88))

                    Text("Set the name, choose the fish, and decide if this one is just for looks or if it needs feeding.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.60))
                        .fixedSize(horizontal: false, vertical: true)
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
                        .frame(height: 360)
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
                    detail: "Give this tank a name and decide if it is decorative or a pet."
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("TANK NAME")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)

                    TextField("Blue Bowl", text: $draft.name)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.86))
                        .textInputAutocapitalization(.words)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.22))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.white.opacity(0.72), lineWidth: 1)
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
                            ForEach(AquariumVesselStyle.allCases) { option in
                                SelectablePill(
                                    title: option.title,
                                    subtitle: option.summary,
                                    isSelected: draft.configuration.vesselStyle == option
                                ) {
                                    draft.configuration.vesselStyle = option
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
                        detail: "Pick the fish and how many you want swimming around."
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(FishSpecies.allCases) { option in
                                SelectablePill(
                                    title: option.title,
                                    subtitle: option.summary,
                                    isSelected: draft.configuration.fishSpecies == option
                                ) {
                                    draft.configuration.fishSpecies = option
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
                            ForEach(SubstrateStyle.allCases) { option in
                                SelectablePill(
                                    title: option.title,
                                    subtitle: option.summary,
                                    isSelected: draft.configuration.substrate == option
                                ) {
                                    draft.configuration.substrate = option
                                }
                            }
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(DecorationStyle.allCases) { option in
                                SelectablePill(
                                    title: option.title,
                                    subtitle: option.summary,
                                    isSelected: draft.configuration.decoration == option
                                ) {
                                    draft.configuration.decoration = option
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
                        detail: "Add a snail, shrimp, or crab, or leave it simple."
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(CompanionStyle.allCases) { option in
                                SelectablePill(
                                    title: option.title,
                                    subtitle: option.summary,
                                    isSelected: draft.configuration.companion == option
                                ) {
                                    draft.configuration.companion = option
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
        return draft
    }
}

private struct WidgetSizePreview: View {
    let configuration: AquariumConfiguration
    let format: AquariumDisplayFormat
    let petSnapshot: AquariumPetSnapshot

    var body: some View {
        GeometryReader { geometry in
            let tileSize = previewTileSize(for: geometry.size.width)
            let tileShape = RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous)

            ZStack {
                tileShape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.93, green: 0.95, blue: 0.98),
                                Color(red: 0.84, green: 0.87, blue: 0.92),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

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
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.10), radius: 16, y: 10)
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
            width = min(176, availableWidth * 0.56)
        case .widgetMedium:
            width = min(availableWidth, 350)
        case .widgetLarge:
            width = min(availableWidth, 350)
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
    let feedBursts: [FeedBurst]
    let onFeed: (CGFloat) -> Void

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
                let snapshot = profile.petSnapshot(at: context.date)
                let pellets = visiblePellets(at: context.date)

                AquariumSceneView(
                    configuration: configuration,
                    format: format,
                    phase: context.date.timeIntervalSinceReferenceDate / 3.8,
                    petSnapshot: snapshot,
                    foodPellets: pellets
                )
                .drawingGroup(opaque: false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        let width = max(geometry.size.width, 1)
                        onFeed(value.location.x / width)
                    }
            )
        }
    }

    private func visiblePellets(at date: Date) -> [AquariumFoodPellet] {
        feedBursts.flatMap { burst in
            let elapsed = date.timeIntervalSince(burst.startedAt)
            let dropDuration: TimeInterval = 1.15
            let grazeDuration: TimeInterval = 1.8
            let releaseDuration: TimeInterval = 2.2
            let totalDuration = dropDuration + grazeDuration + releaseDuration
            guard elapsed >= 0, elapsed <= totalDuration else { return [AquariumFoodPellet]() }

            let dropProgress = min(max(elapsed / dropDuration, 0), 1)
            let easedDrop = CGFloat(1 - pow(1 - dropProgress, 2))
            let grazeProgress = CGFloat(min(max((elapsed - dropDuration) / grazeDuration, 0), 1))
            let releaseProgress = CGFloat(min(max((elapsed - dropDuration - grazeDuration) / releaseDuration, 0), 1))

            return (0..<3).map { index in
                let spread = CGFloat(index - 1) * 0.026
                let x = min(max(burst.xFraction + spread, 0.18), 0.82)
                let restingDepth = 0.50 + CGFloat(index) * 0.07
                let restingY = min(0.76, 0.08 + restingDepth)
                let y: CGFloat
                let visibility: CGFloat

                if elapsed < dropDuration {
                    y = min(0.76, 0.08 + easedDrop * restingDepth)
                    visibility = 1.0
                } else if elapsed < dropDuration + grazeDuration {
                    let bobAmount = 0.010 - grazeProgress * 0.004
                    y = restingY + CGFloat(sin(Double(grazeProgress) * .pi * 2 + Double(index) * 0.8)) * bobAmount
                    visibility = 0.96 - grazeProgress * 0.30
                } else {
                    y = restingY + CGFloat(sin(Double(releaseProgress) * .pi * 2 + Double(index) * 0.7)) * 0.004
                    visibility = max(0.02, (1.0 - releaseProgress) * (1.0 - releaseProgress) * 0.66)
                }

                let baseScale: CGFloat = index == 1 ? 1.0 : 0.84

                return AquariumFoodPellet(
                    xFraction: x,
                    yFraction: y,
                    scale: baseScale * visibility
                )
            }
        }
    }
}

private struct TankDetailCard: View {
    let profile: BowlProfile

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
                    .foregroundStyle(Color.black.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)

                Text(profile.configuration.detailLine)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.56))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: 320, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.80), lineWidth: 1)
                }
        }
        .shadow(color: Color.black.opacity(0.06), radius: 18, y: 8)
    }
}

private struct AmbientScreenBackdrop: View {
    let configuration: AquariumConfiguration

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let palette = configuration.ambientBackdropColors

            ZStack {
                Color.white

                ZStack {
                    Ellipse()
                        .fill(palette[0].opacity(0.18))
                        .frame(width: size.width * 1.18, height: size.height * 0.58)
                        .blur(radius: 118)
                        .offset(x: -size.width * 0.22, y: size.height * 0.14)

                    Ellipse()
                        .fill(palette[1].opacity(0.15))
                        .frame(width: size.width * 1.12, height: size.height * 0.54)
                        .blur(radius: 112)
                        .offset(x: size.width * 0.22, y: size.height * 0.18)

                    Ellipse()
                        .fill(palette[2].opacity(0.13))
                        .frame(width: size.width * 1.00, height: size.height * 0.50)
                        .blur(radius: 102)
                        .offset(x: 0, y: size.height * 0.30)

                    RoundedRectangle(cornerRadius: size.width * 0.22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    palette[0].opacity(0.08),
                                    palette[2].opacity(0.12),
                                    palette[1].opacity(0.10),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: size.width * 1.18, height: size.height * 0.42)
                        .blur(radius: 96)
                        .offset(y: size.height * 0.26)
                }
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.00),
                            .init(color: .white.opacity(0.08), location: 0.06),
                            .init(color: .white, location: 0.18),
                            .init(color: .white, location: 0.82),
                            .init(color: .white.opacity(0.10), location: 0.94),
                            .init(color: .clear, location: 1.00),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color.white.opacity(0.96),
                            Color.white.opacity(0.24),
                            Color.clear,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: size.height * 0.24)

                    Spacer(minLength: 0)

                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.96),
                            Color.white,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: size.height * 0.26)
                }
            }
            .ignoresSafeArea()
        }
    }
}

private struct ActionGlassButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.82))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.22))
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.76), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
    }
}

private struct IconGlassButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.78))
                .frame(width: 42, height: 42)
                .background {
                    Circle()
                        .fill(Color.white.opacity(0.20))
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.72), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
    }
}

private struct FeedBurst: Identifiable {
    let id = UUID()
    let startedAt: Date
    let xFraction: CGFloat
}

private extension AquariumConfiguration {
    func withFallbackStyle(_ style: AquariumVesselStyle) -> AquariumConfiguration {
        AquariumConfiguration(
            vesselStyle: vesselStyle == .orb && style != .orb ? style : vesselStyle,
            fishSpecies: fishSpecies,
            fishCount: fishCount,
            companion: companion,
            substrate: substrate,
            decoration: decoration
        )
    }

    var ambientBackdropColors: [Color] {
        [
            fishSpecies.palette[1],
            decoration.accentColors[1],
            substrate.accentColors[2],
        ]
    }
}
