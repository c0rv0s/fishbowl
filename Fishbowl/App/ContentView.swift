import AVFoundation
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
                let pageHeight = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom

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
                                    dropFood(in: profile.id, at: xFraction)
                                },
                                onFeedConsumed: { burstID in
                                    finishFeeding(in: profile.id, burstID: burstID)
                                },
                                onDelete: {
                                    deletingProfile = profile
                                }
                            )
                            .frame(width: geometry.size.width, height: pageHeight)
                            .id(TankPageID.profile(profile.id))
                        }

                        if studio.canCreateProfile {
                            AddTankPage(
                                slotNumber: studio.profiles.count + 1,
                                tankLimit: premiumStore.tankLimit,
                                safeAreaInsets: geometry.safeAreaInsets,
                                premiumStore: premiumStore
                            ) {
                                composerDraft = studio.makeDraftProfile()
                            } onGenerated: { profile in
                                studio.addProfile(profile)
                                currentPageID = .profile(profile.id)
                            }
                            .frame(width: geometry.size.width, height: pageHeight)
                            .id(TankPageID.addSlot(studio.profiles.count + 1))
                        } else if !premiumStore.isPremiumUnlocked {
                            PremiumUpsellPage(
                                currentTankCount: studio.profiles.count,
                                safeAreaInsets: geometry.safeAreaInsets,
                                onUnlock: {
                                    isPremiumSheetPresented = true
                                }
                            )
                            .frame(width: geometry.size.width, height: pageHeight)
                            .id(TankPageID.premiumUpsell)
                        }
                    }
                    .scrollTargetLayout()
                }
                .ignoresSafeArea()
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

    private func dropFood(in profileID: UUID, at xFraction: CGFloat) {
        guard let profile = currentProfile(id: profileID) else { return }
        let snapshot = profile.petSnapshot(at: .now)
        guard profile.mode == .pet, snapshot.isAlive else { return }

        let now = Date.now
        let clampedX = min(
            max(xFraction, AquariumFeedBurst.horizontalDropBounds.lowerBound),
            AquariumFeedBurst.horizontalDropBounds.upperBound
        )
        let activeBursts = feedBurstsByProfileID[profileID, default: []]
        guard activeBursts.count < AquariumFeedBurst.maxQueuedBursts else { return }

        feedBurstsByProfileID[profileID] = activeBursts + [
            AquariumFeedBurst(startedAt: now, xFraction: clampedX)
        ]
    }

    private func finishFeeding(in profileID: UUID, burstID: UUID) {
        guard let profile = currentProfile(id: profileID) else {
            feedBurstsByProfileID[profileID] = nil
            return
        }

        let currentBursts = feedBurstsByProfileID[profileID, default: []]
        guard currentBursts.contains(where: { $0.id == burstID }) else { return }

        feedBurstsByProfileID[profileID] = currentBursts.filter { $0.id != burstID }
        let willBurst = profile.willBurstOnNextFeed(at: .now)
        withAnimation(.easeInOut(duration: willBurst ? 0.72 : 0.34)) {
            studio.feedProfile(id: profileID, at: .now)
        }

        guard let updatedProfile = currentProfile(id: profileID) else {
            feedBurstsByProfileID[profileID] = nil
            return
        }

        if !updatedProfile.petSnapshot(at: .now).isAlive {
            feedBurstsByProfileID[profileID] = nil
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

    private func currentProfile(id: UUID) -> BowlProfile? {
        studio.profiles.first { $0.id == id }
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

    private var snapshot: AquariumPetSnapshot {
        profile.petSnapshot(at: .now)
    }

    var body: some View {
        GeometryReader { geometry in
            let layoutScale = min(max(geometry.size.width / 390, 1.0), 1.12)
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
               ? "Exploded • Delete this tank to make a new one"
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
    @ObservedObject var premiumStore: PremiumStore
    let onCreate: () -> Void
    let onGenerated: (BowlProfile) -> Void

    @StateObject private var recorder = HumBowlRecorder()
    @State private var stage: HumCreationStage = .idle
    @State private var holdStartedAt: Date?
    @State private var recordingStartedAt: Date?
    @State private var isTouchActive = false
    @State private var entryProgress: CGFloat = 0
    @State private var recordingProgress: CGFloat = 0
    @State private var holdMilestone = 0
    @State private var generatedDraft: HumGeneratedBowl?
    @State private var isPremiumSheetPresented = false
    @State private var analyzeTask: Task<Void, Never>?
    @State private var statusMessage: String?

    private let entryDuration: TimeInterval = 0.9
    private let maxRecordingDuration: TimeInterval = 8
    private let analysisDurationNanoseconds: UInt64 = 5_000_000_000
    private let humCreationTicker = Timer.publish(every: 1 / 30, on: .main, in: .common).autoconnect()
    private let tankCornerRadius: CGFloat = 34
    private let tankHorizontalInset: CGFloat = 12
    /// Vertical inset on both top and bottom so the glass panel clears the Dynamic Island and stays balanced.
    private let tankVerticalInsetBeyondSafeTop: CGFloat = 5

    var body: some View {
        GeometryReader { geometry in
            let tankVerticalInset = max(
                tankHorizontalInset,
                safeAreaInsets.top + tankVerticalInsetBeyondSafeTop
            )
            let tankSize = CGSize(
                width: max(0, geometry.size.width - tankHorizontalInset * 2),
                height: max(0, geometry.size.height - tankVerticalInset * 2)
            )
            let micDiameter = min(max(tankSize.width * 0.50, 184), 224)
            let micCenterY = min(
                max(tankSize.height * 0.54, safeAreaInsets.top + 220),
                tankSize.height - safeAreaInsets.bottom - 188
            )
            let accentConfiguration = generatedDraft?.profile.configuration ?? .appIcon

            ZStack {
                Color(red: 0.01, green: 0.12, blue: 0.22)
                    .ignoresSafeArea()

                ZStack {
                    fullBleedBackdrop(
                        configuration: accentConfiguration,
                        size: tankSize
                    )

                    if stage == .preview, let generatedDraft {
                        previewLayer(for: generatedDraft, in: tankSize)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        idleAndCaptureLayer(
                            in: tankSize,
                            micDiameter: micDiameter,
                            micCenterY: micCenterY
                        )
                    }

                    if stage != .preview {
                        HumMicButton(
                            stage: stage,
                            fillProgress: micFillProgress,
                            recordingProgress: recordingProgress,
                            waveformLevels: recorder.waveformLevels
                        )
                        .frame(width: micDiameter, height: micDiameter)
                        .position(x: tankSize.width * 0.5, y: micCenterY)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                    }

                    if stage == .analyzing {
                        HumAnalysisView()
                            .frame(width: min(micDiameter * 0.88, 170), height: min(micDiameter * 0.72, 110))
                            .position(x: tankSize.width * 0.5, y: micCenterY)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }

                    Color.clear
                        .frame(width: micDiameter + 40, height: micDiameter + 40)
                        .contentShape(Circle())
                        .position(x: tankSize.width * 0.5, y: micCenterY)
                        .highPriorityGesture(micHoldGesture)
                        .allowsHitTesting(stage != .preview && stage != .analyzing)

                    if stage != .idle {
                        IconGlassButton(systemImage: "xmark") {
                            resetCreationFlow(clearStatus: false)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.top, stage == .preview ? 16 : max(18, safeAreaInsets.top + 6))
                        .padding(.trailing, stage == .preview ? 14 : 22)
                    }
                }
                .frame(width: tankSize.width, height: tankSize.height)
                .clipShape(RoundedRectangle(cornerRadius: tankCornerRadius, style: .continuous))
                .overlay {
                    HumTankChrome(cornerRadius: tankCornerRadius)
                }
                .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.5)
            }
            .ignoresSafeArea()
            .sheet(isPresented: $isPremiumSheetPresented) {
                PremiumUnlockSheet(store: premiumStore)
            }
            .onChange(of: premiumStore.isPremiumUnlocked) { _, unlocked in
                guard unlocked, stage == .preview else { return }
                HumHaptics.reveal()
            }
            .onReceive(humCreationTicker) { now in
                handleTick(now)
            }
            .onDisappear {
                analyzeTask?.cancel()
                recorder.cancelCapture()
            }
        }
    }

    private var micFillProgress: CGFloat {
        switch stage {
        case .idle:
            return max(0.08, entryProgress)
        case .opening, .recording, .analyzing:
            return 1
        case .preview:
            return 0
        }
    }

    @ViewBuilder
    private func fullBleedBackdrop(
        configuration: AquariumConfiguration,
        size: CGSize
    ) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.20, blue: 0.38),
                    Color(red: 0.04, green: 0.34, blue: 0.56),
                    Color(red: 0.04, green: 0.46, blue: 0.69),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            HumCreationBackdrop(
                colors: configuration.ambientBackdropColors,
                isImmersive: stage != .idle
            )
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func idleAndCaptureLayer(
        in size: CGSize,
        micDiameter: CGFloat,
        micCenterY: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            if stage != .idle {
                VStack(spacing: 10) {
                    Text(stageTitle)
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.white.opacity(0.92))

                    if stage == .recording {
                        Text(recordingCounterLine)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.72))
                    }

                    if let statusMessage {
                        statusChip(statusMessage)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, max(20, safeAreaInsets.top + 2))
                .padding(.horizontal, 24)
                .transition(.opacity)
            } else {
                Spacer(minLength: max(24, safeAreaInsets.top + 8))
            }

            Spacer(minLength: 0)

            if stage == .recording || stage == .opening {
                VStack(spacing: 14) {
                    HumWaveformView(
                        levels: recorder.waveformLevels,
                        maxHeight: 84,
                        barWidth: 6
                    )
                    .frame(height: 88)
                    .frame(maxWidth: min(size.width - 72, 340))
                }
                .padding(.bottom, max(76, size.height - micCenterY - micDiameter * 0.74))
                .transition(.opacity)
            } else {
                Spacer(minLength: micDiameter + 92)
            }

            if stage == .idle {
                VStack(spacing: 14) {
                    if let statusMessage {
                        statusChip(statusMessage)
                    }

                    ActionGlassButton(title: "New Tank", systemImage: "plus") {
                        statusMessage = nil
                        onCreate()
                    }
                    .allowsHitTesting(true)

                    if recorder.permissionDenied {
                        Button("Microphone Settings") {
                            openSettings()
                        }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.76))
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, max(42, safeAreaInsets.bottom + 18))
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.32), value: stage)
    }

    @ViewBuilder
    private func previewLayer(for generatedDraft: HumGeneratedBowl, in size: CGSize) -> some View {
        let isCompact = size.height < 760
        let verticalSpacing: CGFloat = isCompact ? 14 : 22
        let headerSpacing: CGFloat = isCompact ? 7 : 10
        let topSpacer = max(isCompact ? 28 : 34, safeAreaInsets.top + (isCompact ? 8 : 18))
        let heroHeight = min(size.height * (isCompact ? 0.38 : 0.46), isCompact ? 300 : 390)
        let bottomSpacer = max(isCompact ? 12 : 22, safeAreaInsets.bottom + (isCompact ? 6 : 12))

        VStack(spacing: verticalSpacing) {
            Spacer(minLength: topSpacer)

            VStack(alignment: .leading, spacing: headerSpacing) {
                Text(generatedDraft.profile.name)
                    .font(.system(size: isCompact ? 34 : 42, weight: .medium, design: .serif))
                    .foregroundStyle(colorScheme.fishbowlPrimaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)

                Text(generatedDraft.analysis.headline)
                    .font(.system(size: isCompact ? 15 : 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                Text(generatedDraft.analysis.detailLine)
                    .font(.system(size: isCompact ? 13 : 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, isCompact ? 22 : 28)

            AquariumSceneView(
                configuration: generatedDraft.profile.configuration,
                format: .studioHero,
                phase: Date.now.timeIntervalSinceReferenceDate / 5.4,
                petSnapshot: generatedDraft.profile.petSnapshot(at: .now)
            )
            .frame(height: heroHeight)
            .padding(.horizontal, isCompact ? 22 : 18)
            .drawingGroup(opaque: false)

            GlassPanel(cornerRadius: 34, showsGlassEffect: false) {
                VStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
                    Text(generatedDraft.profile.configuration.descriptor)
                        .font(.system(size: isCompact ? 21 : 24, weight: .semibold, design: .serif))
                        .foregroundStyle(colorScheme.fishbowlPrimaryText)

                    Text(generatedDraft.profile.configuration.detailLine)
                        .font(.system(size: isCompact ? 13 : 14, weight: .medium, design: .rounded))
                        .foregroundStyle(colorScheme.fishbowlSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if premiumStore.isPremiumUnlocked {
                        HStack(spacing: 10) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.96))

                            Text("Tap anywhere to keep it.")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.96))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, isCompact ? 10 : 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.black.opacity(0.22))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: isCompact ? 15 : 16, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.86, green: 0.72, blue: 0.24))

                                Text("Unlock Premium To Keep This Bowl")
                                    .font(.system(size: isCompact ? 14 : 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(colorScheme.fishbowlPrimaryText)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.88)
                            }

                            Text("Save this bowl as a pet and unlock more fish, bowls, and customization.")
                                .font(.system(size: isCompact ? 13 : 14, weight: .medium, design: .rounded))
                                .foregroundStyle(colorScheme.fishbowlSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            Button {
                                isPremiumSheetPresented = true
                            } label: {
                                Text("View All Benefits")
                                    .font(.system(size: isCompact ? 15 : 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, isCompact ? 13 : 15)
                                    .background(
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(red: 0.15, green: 0.28, blue: 0.57),
                                                        Color(red: 0.15, green: 0.54, blue: 0.89),
                                                    ],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, isCompact ? 18 : 22)

            Spacer(minLength: bottomSpacer)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard premiumStore.isPremiumUnlocked else { return }
            keepGeneratedBowl()
        }
    }

    private var micHoldGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard stage != .analyzing, stage != .preview else { return }
                guard !isTouchActive else { return }

                isTouchActive = true
                statusMessage = nil

                if stage == .idle {
                    holdStartedAt = .now
                    entryProgress = 0
                    holdMilestone = 0
                    HumHaptics.beginHold()
                }
            }
            .onEnded { _ in
                let wasTouchActive = isTouchActive
                isTouchActive = false
                guard wasTouchActive else { return }

                switch stage {
                case .idle:
                    collapseEntryFill()
                case .opening:
                    resetCreationFlow(clearStatus: false)
                case .recording:
                    finishRecording()
                case .analyzing, .preview:
                    break
                }
            }
    }

    private var stageTitle: String {
        switch stage {
        case .idle:
            return ""
        case .opening:
            return "Listening"
        case .recording:
            return "Hum"
        case .analyzing:
            return "Analyzing"
        case .preview:
            return ""
        }
    }

    private var recordingCounterLine: String {
        let elapsed = maxRecordingDuration * Double(recordingProgress)
        let remaining = max(0, maxRecordingDuration - elapsed)
        return String(format: "%.1fs recorded  •  %.1fs left", elapsed, remaining)
    }

    private func handleTick(_ now: Date) {
        switch stage {
        case .idle:
            guard isTouchActive, let holdStartedAt else { return }
            let progress = CGFloat(min(now.timeIntervalSince(holdStartedAt) / entryDuration, 1))
            if progress != entryProgress {
                entryProgress = progress
            }

            let milestone = min(Int(progress * 5), 5)
            if milestone > holdMilestone {
                holdMilestone = milestone
                HumHaptics.fillStep()
            }

            if progress >= 1 {
                beginRecordingSequence()
            }

        case .recording:
            guard let recordingStartedAt else { return }
            let progress = CGFloat(min(now.timeIntervalSince(recordingStartedAt) / maxRecordingDuration, 1))
            if progress != recordingProgress {
                recordingProgress = progress
            }

            if progress >= 1 {
                finishRecording()
            }

        case .opening, .analyzing, .preview:
            break
        }
    }

    private func beginRecordingSequence() {
        guard stage == .idle else { return }
        stage = .opening
        entryProgress = 1

        Task { @MainActor in
            switch await recorder.ensurePermission() {
            case .ready:
                break
            case .justGranted:
                resetCreationFlow(clearStatus: true)
                return
            case .denied:
                statusMessage = "Microphone off"
                HumHaptics.warning()
                resetCreationFlow(clearStatus: false)
                return
            }

            guard isTouchActive else {
                resetCreationFlow(clearStatus: false)
                return
            }

            do {
                try recorder.startCapture()
                recordingStartedAt = .now
                recordingProgress = 0
                stage = .recording
                HumHaptics.recordingStarted()
            } catch {
                statusMessage = "Couldn’t start mic"
                HumHaptics.warning()
                resetCreationFlow(clearStatus: false)
            }
        }
    }

    private func finishRecording() {
        guard stage == .recording else { return }

        isTouchActive = false
        let duration = min(
            maxRecordingDuration,
            max(0.5, Date.now.timeIntervalSince(recordingStartedAt ?? .now))
        )

        let analysis = recorder.finishCapture(recordedDuration: duration)
        recordingStartedAt = nil
        recordingProgress = 0
        stage = .analyzing
        HumHaptics.recordingEnded()
        startAnalyzing(analysis)
    }

    private func startAnalyzing(_ analysis: HumAudioAnalysis) {
        analyzeTask?.cancel()
        analyzeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: analysisDurationNanoseconds)
            guard !Task.isCancelled else { return }

            let profile = HumBowlGenerator.makeProfile(from: analysis)
            generatedDraft = HumGeneratedBowl(profile: profile, analysis: analysis)
            stage = .preview
            HumHaptics.reveal()
        }
    }

    private func keepGeneratedBowl() {
        guard let generatedDraft else { return }
        onGenerated(generatedDraft.profile)
        resetCreationFlow(clearStatus: true)
    }

    private func collapseEntryFill() {
        holdStartedAt = nil
        holdMilestone = 0
        withAnimation(.easeOut(duration: 0.22)) {
            entryProgress = 0
        }
    }

    private func resetCreationFlow(clearStatus: Bool) {
        analyzeTask?.cancel()
        analyzeTask = nil
        recorder.cancelCapture()
        stage = .idle
        holdStartedAt = nil
        recordingStartedAt = nil
        isTouchActive = false
        recordingProgress = 0
        holdMilestone = 0
        generatedDraft = nil
        if clearStatus {
            statusMessage = nil
        }

        withAnimation(.easeOut(duration: 0.22)) {
            entryProgress = 0
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    @ViewBuilder
    private func statusChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.88))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.18))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    }
            }
    }
}

private enum HumCreationStage {
    case idle
    case opening
    case recording
    case analyzing
    case preview
}

private struct HumGeneratedBowl {
    let profile: BowlProfile
    let analysis: HumAudioAnalysis
}

private enum HumMicPermissionState {
    case ready
    case justGranted
    case denied
}

private enum HumHumMood: String {
    case hush
    case tide
    case bloom
    case spark

    var headline: String {
        switch self {
        case .hush:
            return "Soft, steady, and close to the glass."
        case .tide:
            return "Low and tidal with a deeper pull."
        case .bloom:
            return "Warm, rounded, and a little luminous."
        case .spark:
            return "Bright, lively, and built to move."
        }
    }
}

private struct HumAudioAnalysis {
    let averageLevel: Double
    let peakLevel: Double
    let variance: Double
    let pitch: Double
    let duration: TimeInterval

    var mood: HumHumMood {
        var picker = SeededHumPicker(seed: seed ^ 0xA5A5_5A5A_D3C1_B97F)
        return rankedMoods
            .map { candidate in
                let variation = picker.nextUnitInterval() * 0.12
                return (mood: candidate.mood, score: candidate.score + variation)
            }
            .max { $0.score < $1.score }?
            .mood ?? .bloom
    }

    var headline: String {
        mood.headline
    }

    var detailLine: String {
        let tone: String
        switch pitch {
        case ..<145:
            tone = "low tone"
        case ..<215:
            tone = "mid tone"
        case ..<255:
            tone = "lifted tone"
        default:
            tone = "bright tone"
        }

        let energy: String
        switch averageLevel {
        case ..<0.22:
            energy = "gentle energy"
        case ..<0.44:
            energy = "balanced energy"
        default:
            energy = "strong energy"
        }

        let texture = variance < 0.014 ? "steady texture" : "shifting texture"
        return "\(tone) • \(energy) • \(texture)"
    }

    var seed: UInt64 {
        let a = UInt64((averageLevel * 10_000).rounded())
        let p = UInt64((pitch * 100).rounded())
        let v = UInt64((variance * 1_000_000).rounded())
        let d = UInt64((duration * 1_000).rounded())
        return a ^ (p << 1) ^ (v << 7) ^ (d << 13) ^ 0x9E3779B97F4A7C15
    }

    func accentMood(excluding primary: HumHumMood) -> HumHumMood {
        let alternates = rankedMoods.filter { $0.mood != primary }
        guard let strongestAlternate = alternates.first else { return primary }

        let contenders = alternates
            .filter { $0.score >= strongestAlternate.score - 0.10 }
            .map(\.mood)

        var picker = SeededHumPicker(seed: seed ^ 0x6A09_E667_F3BC_C909)
        return picker.pick(contenders.isEmpty ? [strongestAlternate.mood] : contenders)
    }

    private var rankedMoods: [(mood: HumHumMood, score: Double)] {
        let normalizedPitch = Self.clamp01((pitch - 115) / 165)
        let lowPitchBias = Self.clamp01((175 - pitch) / 65)
        let middlePitchBias = 1 - Self.clamp01(abs(pitch - 195) / 78)
        let energy = Self.clamp01((averageLevel * 0.78) + (peakLevel * 0.22))
        let motion = Self.clamp01(variance / 0.028)
        let softness = Self.clamp01(1 - motion * 0.92)
        let energyBalance = 1 - Self.clamp01(abs(energy - 0.36) / 0.30)
        let motionBalance = 1 - Self.clamp01(abs(motion - 0.32) / 0.32)
        let durationBias = Self.clamp01(duration / 8)

        let hushScore = 0.40
            + ((1 - energy) * 0.58)
            + (softness * 0.48)
            + (middlePitchBias * 0.10)
        let tideScore = 0.40
            + (lowPitchBias * 0.88)
            + (softness * 0.18)
            + (durationBias * 0.16)
            + ((1 - energy) * 0.10)
        let bloomScore = 0.54
            + (middlePitchBias * 0.54)
            + (energyBalance * 0.34)
            + (motionBalance * 0.22)
        let sparkScore = 0.18
            + (normalizedPitch * 0.56)
            + (energy * 0.26)
            + (motion * 0.32)
            + (peakLevel * 0.08)

        return [
            (.hush, hushScore),
            (.tide, tideScore),
            (.bloom, bloomScore),
            (.spark, sparkScore)
        ]
        .sorted { lhs, rhs in
            lhs.score > rhs.score
        }
    }

    private static func clamp01(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

@MainActor
private final class HumBowlRecorder: ObservableObject {
    @Published private(set) var waveformLevels: [CGFloat] = Array(repeating: 0.18, count: 24)
    @Published private(set) var permissionDenied = false

    private let core = HumBowlRecorderCore()

    func ensurePermission() async -> HumMicPermissionState {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            permissionDenied = false
            return .ready
        case .denied:
            permissionDenied = true
            return .denied
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
            permissionDenied = !granted
            return granted ? .justGranted : .denied
        @unknown default:
            permissionDenied = true
            return .denied
        }
    }

    func startCapture() throws {
        waveformLevels = Array(repeating: 0.18, count: 24)
        try core.startCapture { [weak self] normalizedLevel in
            Task { @MainActor [weak self] in
                self?.appendWaveformLevel(CGFloat(normalizedLevel))
            }
        }
    }

    func finishCapture(recordedDuration: TimeInterval) -> HumAudioAnalysis {
        let snapshot = core.finishCapture()

        let levels = snapshot.normalizedLevels.isEmpty ? [0.18, 0.22, 0.20] : snapshot.normalizedLevels
        let averageLevel = levels.reduce(0, +) / Double(levels.count)
        let variance = levels.reduce(0) { partialResult, level in
            partialResult + pow(level - averageLevel, 2)
        } / Double(levels.count)
        let pitchLevels = snapshot.pitchSamples.isEmpty ? [178] : snapshot.pitchSamples
        let pitch = pitchLevels.reduce(0, +) / Double(pitchLevels.count)

        return HumAudioAnalysis(
            averageLevel: averageLevel,
            peakLevel: snapshot.peakLevel,
            variance: variance,
            pitch: pitch,
            duration: recordedDuration
        )
    }

    func cancelCapture() {
        core.cancelCapture()
        waveformLevels = Array(repeating: 0.18, count: 24)
    }

    private func appendWaveformLevel(_ level: CGFloat) {
        waveformLevels.append(level)
        if waveformLevels.count > 24 {
            waveformLevels.removeFirst(waveformLevels.count - 24)
        }
    }
}

private final class HumBowlRecorderCore: @unchecked Sendable {
    private let audioEngine = AVAudioEngine()
    private let analysisQueue = DispatchQueue(label: "com.nate.fishbowl.hum-analysis")
    private var metrics = HumRecorderMetrics()
    private var onWaveformSample: (@Sendable (Double) -> Void)?

    func startCapture(onWaveformSample: @escaping @Sendable (Double) -> Void) throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
        try audioSession.setActive(true, options: [])

        analysisQueue.sync {
            metrics = HumRecorderMetrics()
            self.onWaveformSample = onWaveformSample
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.inputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak self] buffer, _ in
            self?.consume(buffer: buffer, sampleRate: format.sampleRate)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    func finishCapture() -> HumRecorderMetrics {
        stopAudio()
        return analysisQueue.sync {
            let snapshot = metrics
            metrics = HumRecorderMetrics()
            onWaveformSample = nil
            return snapshot
        }
    }

    func cancelCapture() {
        stopAudio()
        analysisQueue.sync {
            metrics = HumRecorderMetrics()
            onWaveformSample = nil
        }
    }

    private func stopAudio() {
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.reset()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func consume(buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        var squareSum: Float = 0
        var zeroCrossings = 0
        var previousValue = channelData[0]

        for index in 0..<frameCount {
            let sample = channelData[index]
            squareSum += sample * sample
            if index > 0, (sample >= 0 && previousValue < 0) || (sample < 0 && previousValue >= 0) {
                zeroCrossings += 1
            }
            previousValue = sample
        }

        let rms = sqrt(squareSum / Float(frameCount))
        let decibels = 20 * log10(max(Double(rms), 0.000_015))
        let normalizedLevel = pow(max(0, min(1, (decibels + 54) / 30)), 0.72)
        let pitchEstimate = Double(zeroCrossings) * sampleRate / Double(frameCount * 2)
        let waveformOutput = analysisQueue.sync { () -> (@Sendable (Double) -> Void)? in
            metrics.normalizedLevels.append(normalizedLevel)
            if metrics.normalizedLevels.count > 240 {
                metrics.normalizedLevels.removeFirst(metrics.normalizedLevels.count - 240)
            }

            metrics.peakLevel = max(metrics.peakLevel, normalizedLevel)

            if pitchEstimate.isFinite, pitchEstimate >= 70, pitchEstimate <= 420 {
                metrics.pitchSamples.append(pitchEstimate)
                if metrics.pitchSamples.count > 120 {
                    metrics.pitchSamples.removeFirst(metrics.pitchSamples.count - 120)
                }
            }

            return onWaveformSample
        }

        waveformOutput?(normalizedLevel)
    }
}

private struct HumRecorderMetrics {
    var normalizedLevels: [Double] = []
    var pitchSamples: [Double] = []
    var peakLevel: Double = 0
}

private struct HumBowlRecipe {
    var vesselPool: [AquariumVesselStyle]
    var fishPool: [FishSpecies]
    var substratePool: [SubstrateStyle]
    var decorationPool: [DecorationStyle]
    var featurePool: [FeaturePieceStyle]
    var companionPool: [CompanionStyle]
    var personality: FishPersonality
    var adjectives: [String]
    var nouns: [String]
}

private enum HumBowlGenerator {
    static func makeProfile(from analysis: HumAudioAnalysis) -> BowlProfile {
        var picker = SeededHumPicker(seed: analysis.seed)
        let mood = analysis.mood
        var recipe = Self.recipe(for: mood)
        let accentMood = analysis.accentMood(excluding: mood)
        if accentMood != mood {
            blendAccent(
                into: &recipe,
                accent: Self.recipe(for: accentMood),
                analysis: analysis,
                picker: &picker
            )
        }

        let fishCount: FishCount
        if analysis.variance > 0.024 {
            fishCount = .trio
        } else if analysis.duration > 5.1 {
            fishCount = .duet
        } else {
            fishCount = .solo
        }

        let primaryFish = picker.pick(recipe.fishPool)
        let allowsMixedSpecies = analysis.averageLevel > 0.32 || analysis.variance > 0.016 || mood == .spark
        let extraCount = max(0, fishCount.value - 1)
        var extras: [FishSpecies] = []

        for _ in 0..<extraCount {
            if allowsMixedSpecies, picker.coinFlip() {
                let alternatePool = recipe.fishPool.filter { $0 != primaryFish }
                extras.append(alternatePool.isEmpty ? primaryFish : picker.pick(alternatePool))
            } else {
                extras.append(primaryFish)
            }
        }

        let companionCount: Int
        if analysis.averageLevel > 0.52 {
            companionCount = 2
        } else if analysis.averageLevel > 0.30 || mood == .spark {
            companionCount = 1
        } else {
            companionCount = 0
        }

        var companions: [CompanionStyle] = []
        while companions.count < companionCount {
            let candidate = picker.pick(recipe.companionPool)
            if !companions.contains(candidate) {
                companions.append(candidate)
            }
        }

        let profile = BowlProfile(
            name: "\(picker.pick(recipe.adjectives)) \(picker.pick(recipe.nouns))",
            configuration: AquariumConfiguration(
                vesselStyle: picker.pick(recipe.vesselPool),
                fishSpecies: primaryFish,
                fishCount: fishCount,
                additionalFishSpecies: extras,
                personality: recipe.personality,
                companions: companions,
                substrate: picker.pick(recipe.substratePool),
                decoration: picker.pick(recipe.decorationPool),
                featurePiece: picker.pick(recipe.featurePool)
            ),
            mode: .pet,
            petState: .fresh()
        )

        return profile
    }

    private static func recipe(for mood: HumHumMood) -> HumBowlRecipe {
        switch mood {
        case .hush:
            return HumBowlRecipe(
                vesselPool: [.orb, .gallery],
                fishPool: [.royalBetta, .glassGold, .opalAngelfish],
                substratePool: [.pearlSand, .moonGravel],
                decorationPool: [.minimal, .glassPearls],
                featurePool: [.bubbleStone, .moonLantern],
                companionPool: [.snail, .shrimp],
                personality: .dreamy,
                adjectives: ["Soft", "Silent", "Pearl", "Velvet"],
                nouns: ["Lagoon", "Glass", "Drift", "Hush"]
            )

        case .tide:
            return HumBowlRecipe(
                vesselPool: [.orb, .panorama],
                fishPool: [.moonKoi, .leopardShark, .glassGold],
                substratePool: [.obsidianSand, .moonGravel],
                decorationPool: [.riverRocks, .glassPearls],
                featurePool: [.driftwoodArch, .moonLantern, .kelp],
                companionPool: [.crab, .snail, .seaCucumber],
                personality: .shy,
                adjectives: ["Blue", "Midnight", "Tidal", "Deep"],
                nouns: ["Current", "Basin", "Reef", "Pool"]
            )

        case .bloom:
            return HumBowlRecipe(
                vesselPool: [.gallery, .panorama],
                fishPool: [.moonKoi, .opalAngelfish, .glassGold, .royalBetta],
                substratePool: [.pearlSand, .coralBloom, .moonGravel],
                decorationPool: [.glassPearls, .riverRocks, .coralGarden],
                featurePool: [.moonLantern, .bubbleStone, .kelp],
                companionPool: [.shrimp, .nudibranchRibbon, .snail],
                personality: .playful,
                adjectives: ["Lush", "Bloom", "Golden", "Warm"],
                nouns: ["Bowl", "Lantern", "Garden", "Glow"]
            )

        case .spark:
            return HumBowlRecipe(
                vesselPool: [.panorama, .gallery],
                fishPool: [.neonGuppy, .emberTetra, .opalAngelfish, .moonKoi],
                substratePool: [.obsidianSand, .coralBloom, .moonGravel],
                decorationPool: [.coralGarden, .glassPearls, .riverRocks],
                featurePool: [.kelp, .moonLantern, .driftwoodArch],
                companionPool: [.crab, .shrimp, .nudibranchFlame],
                personality: .greedy,
                adjectives: ["Neon", "Electric", "Bright", "Wild"],
                nouns: ["Surge", "Pulse", "Flash", "Current"]
            )
        }
    }

    private static func blendAccent(
        into recipe: inout HumBowlRecipe,
        accent: HumBowlRecipe,
        analysis: HumAudioAnalysis,
        picker: inout SeededHumPicker
    ) {
        let blendStrength = min(0.58, 0.22 + (analysis.variance * 9) + (analysis.averageLevel * 0.12))

        if picker.nextUnitInterval() < blendStrength {
            recipe.vesselPool = appendingUnique(recipe.vesselPool, picker.pick(accent.vesselPool))
        }
        if picker.nextUnitInterval() < blendStrength + 0.10 {
            recipe.fishPool = appendingUnique(recipe.fishPool, picker.pick(accent.fishPool))
        }
        if picker.nextUnitInterval() < blendStrength + 0.06 {
            recipe.substratePool = appendingUnique(recipe.substratePool, picker.pick(accent.substratePool))
        }
        if picker.nextUnitInterval() < blendStrength + 0.14 {
            recipe.decorationPool = appendingUnique(recipe.decorationPool, picker.pick(accent.decorationPool))
        }
        if picker.nextUnitInterval() < blendStrength {
            recipe.featurePool = appendingUnique(recipe.featurePool, picker.pick(accent.featurePool))
        }
        if picker.nextUnitInterval() < blendStrength {
            recipe.companionPool = appendingUnique(recipe.companionPool, picker.pick(accent.companionPool))
        }
        if picker.nextUnitInterval() < blendStrength + 0.18 {
            recipe.adjectives = appendingUnique(recipe.adjectives, picker.pick(accent.adjectives))
        }
        if picker.nextUnitInterval() < blendStrength + 0.18 {
            recipe.nouns = appendingUnique(recipe.nouns, picker.pick(accent.nouns))
        }
        if picker.nextUnitInterval() < blendStrength * 0.36 {
            recipe.personality = accent.personality
        }
    }

    private static func appendingUnique<T: Hashable>(_ values: [T], _ candidate: T) -> [T] {
        values.contains(candidate) ? values : values + [candidate]
    }
}

private struct SeededHumPicker {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x1234_5678_ABCD_EF01 : seed
    }

    mutating func pick<T>(_ values: [T]) -> T {
        values[nextIndex(upperBound: values.count)]
    }

    mutating func coinFlip() -> Bool {
        nextIndex(upperBound: 2) == 0
    }

    mutating func nextUnitInterval() -> Double {
        Double(nextRandomValue()) / Double(UInt64.max)
    }

    private mutating func nextIndex(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(nextRandomValue() % UInt64(upperBound))
    }

    private mutating func nextRandomValue() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

private struct HumCreationBackdrop: View {
    let colors: [Color]
    let isImmersive: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geometry in
                let phase = timeline.date.timeIntervalSinceReferenceDate
                let palette = (colors + [Color(red: 0.13, green: 0.44, blue: 0.71)]).prefix(3)
                let resolved = Array(palette)

                ZStack {
                    Ellipse()
                        .fill(resolved[0].opacity(isImmersive ? 0.14 : 0.08))
                        .frame(width: geometry.size.width * 0.84, height: geometry.size.height * 0.22)
                        .blur(radius: 54)
                        .offset(
                            x: -geometry.size.width * 0.18,
                            y: -geometry.size.height * (isImmersive ? 0.26 : 0.22)
                        )

                    Ellipse()
                        .fill(resolved[1].opacity(isImmersive ? 0.08 : 0.05))
                        .frame(width: geometry.size.width * 0.50, height: geometry.size.height * 0.16)
                        .blur(radius: 36)
                        .offset(
                            x: geometry.size.width * 0.22,
                            y: -geometry.size.height * 0.01
                        )

                    ForEach(0..<14, id: \.self) { index in
                        let normalizedX = CGFloat((index * 17) % 100) / 100
                        let loop = ((phase * 24) + Double(index * 31)).truncatingRemainder(dividingBy: Double(geometry.size.height + 180))
                        let y = geometry.size.height + 90 - loop
                        let x = geometry.size.width * (0.12 + normalizedX * 0.76)
                        let drift = sin(phase * 0.65 + Double(index)) * 14
                        let size = CGFloat(8 + (index % 3) * 5)

                        Circle()
                            .fill(Color.white.opacity(isImmersive ? 0.14 : 0.08))
                            .frame(width: size, height: size)
                            .blur(radius: size > 10 ? 1.4 : 0.6)
                            .position(x: x + drift, y: y)
                    }

                    HumJellyfishDriftLayer(
                        phase: phase,
                        size: geometry.size,
                        isImmersive: isImmersive,
                        tint: resolved[2]
                    )
                }
            }
        }
    }
}

private struct HumJellyfishDriftLayer: View {
    let phase: TimeInterval
    let size: CGSize
    let isImmersive: Bool
    let tint: Color

    var body: some View {
        let motionPhase = phase * 0.2

        ForEach(0..<3, id: \.self) { index in
            let cycleDuration = 24.0 + Double(index) * 5.5
            let cycle = ((motionPhase + Double(index) * 7.0) / cycleDuration).truncatingRemainder(dividingBy: 1)
            let start = 0.14 + Double(index) * 0.07
            let end = start + 0.30
            let visibility = jellyVisibility(progress: cycle, start: start, end: end)
            let travel = max(0, min(1, (cycle - start) / max(end - start, 0.001)))
            let baseX = size.width * [0.22, 0.74, 0.48][index]
            let horizontalDrift = sin(motionPhase * (0.62 + Double(index) * 0.1) + Double(index) * 1.8)
            let x = baseX + CGFloat(horizontalDrift) * (18 + CGFloat(index) * 8)
            let y = size.height + 90 - CGFloat(travel) * (size.height + 220)
            let jellySize = 62 + CGFloat(index) * 16
            let scale = 0.84 + CGFloat(index) * 0.10 + CGFloat(sin(motionPhase * 1.1 + Double(index)) * 0.03)

            HumJellyfishView(
                phase: motionPhase + Double(index),
                tint: tint,
                size: jellySize
            )
            .scaleEffect(scale)
            .position(x: x, y: y)
            .opacity(visibility * (isImmersive ? 0.46 : 0.28))
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    private func jellyVisibility(progress: Double, start: Double, end: Double) -> Double {
        guard progress >= start, progress <= end else { return 0 }
        let normalized = (progress - start) / max(end - start, 0.001)
        let fadeIn = min(1, normalized / 0.24)
        let fadeOut = min(1, (1 - normalized) / 0.28)
        return min(fadeIn, fadeOut)
    }
}

private struct HumJellyfishView: View {
    let phase: TimeInterval
    let tint: Color
    let size: CGFloat

    private var tentacleGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.72),
                tint.opacity(0.30),
                Color.clear,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            HStack(alignment: .top, spacing: size * 0.055) {
                ForEach(0..<5, id: \.self) { index in
                    tentacle(index)
                }
            }
            .offset(y: size * 0.28)

            ZStack {
                HumJellyBellShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.82),
                                tint.opacity(0.42),
                                Color.clear.opacity(0.1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                HumJellyBellShape()
                    .stroke(Color.white.opacity(0.42), lineWidth: max(1, size * 0.022))

                Ellipse()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: size * 0.42, height: size * 0.10)
                    .blur(radius: size * 0.03)
                    .offset(x: -size * 0.08, y: size * 0.08)
            }
            .frame(width: size * 0.82, height: size * 0.50)
        }
        .frame(width: size, height: size * 1.15)
        .shadow(color: tint.opacity(0.12), radius: size * 0.10, y: size * 0.06)
        .blur(radius: 0.35)
    }

    @ViewBuilder
    private func tentacle(_ index: Int) -> some View {
        let height = size * (0.82 + CGFloat(index.isMultiple(of: 2) ? 0.02 : 0.14))
        let swayBase = sin(phase * 2.6 + Double(index) * 0.8) * Double(size * 0.09)
        let swayPulse = sin(phase * 1.8) * Double(size * 0.03)
        let sway = CGFloat(swayBase + swayPulse)

        HumJellyTentacleShape(sway: sway)
            .stroke(
                tentacleGradient,
                style: StrokeStyle(lineWidth: max(1.2, size * 0.026), lineCap: .round)
            )
            .frame(width: size * 0.12, height: height)
    }
}

private struct HumJellyBellShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.52),
            control1: CGPoint(x: rect.width * 0.84, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.height * 0.18)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.78, y: rect.height * 0.88),
            control: CGPoint(x: rect.maxX, y: rect.height * 0.94)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.22, y: rect.height * 0.88),
            control: CGPoint(x: rect.midX, y: rect.height)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.height * 0.52),
            control: CGPoint(x: rect.minX, y: rect.height * 0.94)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.height * 0.18),
            control2: CGPoint(x: rect.width * 0.16, y: rect.minY)
        )
        return path
    }
}

private struct HumJellyTentacleShape: Shape {
    let sway: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.midX + sway * 0.35, y: rect.maxY),
            control1: CGPoint(x: rect.midX + sway * 0.16, y: rect.height * 0.24),
            control2: CGPoint(x: rect.midX - sway, y: rect.height * 0.72)
        )
        return path
    }
}

private struct HumTankChrome: View {
    var cornerRadius: CGFloat = 38

    var body: some View {
        GeometryReader { geometry in
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

            ZStack {
                shape
                    .stroke(Color.white.opacity(0.24), lineWidth: 1.2)

                shape
                    .inset(by: 3)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.72),
                                Color.white.opacity(0.06),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )

                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.clear,
                                Color.white.opacity(0.03),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.24),
                                Color.clear,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: min(geometry.size.height * 0.22, 140))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .clipShape(shape)
                    .blendMode(.screen)
            }
            .shadow(color: Color.black.opacity(0.12), radius: 18, y: 8)
        }
        .allowsHitTesting(false)
    }
}

private struct HumMicButton: View {
    let stage: HumCreationStage
    let fillProgress: CGFloat
    let recordingProgress: CGFloat
    let waveformLevels: [CGFloat]

    var body: some View {
        TimelineView(.animation) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                Circle()
                    .fill(Color.black.opacity(stage == .idle ? 0.18 : 0.24))
                    .background {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.20),
                                        Color(red: 0.06, green: 0.21, blue: 0.34).opacity(stage == .idle ? 0.78 : 0.92),
                                    ],
                                    center: .topLeading,
                                    startRadius: 10,
                                    endRadius: 180
                                )
                            )
                    }

                MicWaterFillShape(
                    level: fillProgress,
                    phase: phase,
                    amplitude: stage == .idle ? 8 : 12
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.42, green: 0.84, blue: 0.98).opacity(0.95),
                            Color(red: 0.16, green: 0.58, blue: 0.93).opacity(0.98),
                            Color(red: 0.07, green: 0.32, blue: 0.76).opacity(1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Circle())

                if stage == .analyzing {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(Color.white.opacity(0.24 - Double(index) * 0.05), lineWidth: 1.4)
                            .scaleEffect(
                                0.56 + CGFloat(index) * 0.16
                                + CGFloat((sin(phase * 2.1 - Double(index)) + 1) * 0.08)
                            )
                    }
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: stage == .idle ? 46 : 42, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .offset(y: stage == .recording ? -14 : -6)
                }

                Circle()
                    .trim(from: 0, to: stage == .recording ? max(0.02, recordingProgress) : 0)
                    .stroke(
                        Color.white.opacity(0.98),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(6)
                    .opacity(stage == .recording ? 1 : 0)

                Circle()
                    .stroke(Color.white.opacity(0.28), lineWidth: 1.2)

                Circle()
                    .inset(by: 4)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.72),
                                Color.white.opacity(0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(0.22), radius: 26, y: 14)
        }
    }
}

private struct MicWaterFillShape: Shape {
    let level: CGFloat
    let phase: Double
    let amplitude: CGFloat

    func path(in rect: CGRect) -> Path {
        let clampedLevel = min(max(level, 0), 1)
        let waterY = rect.maxY - rect.height * clampedLevel
        let waveAmplitude = amplitude * max(0.2, clampedLevel)
        let step = max(rect.width / 28, 4)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: waterY))

        var x = rect.minX
        while x <= rect.maxX + step {
            let relativeX = (x - rect.minX) / max(rect.width, 1)
            let sine = sin(relativeX * .pi * 2.6 + phase * 2.2)
            let y = waterY + sine * waveAmplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct HumWaveformView: View {
    let levels: [CGFloat]
    let maxHeight: CGFloat
    let barWidth: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                let clampedLevel = min(max(level, 0), 1)
                let visualLevel = CGFloat(pow(Double(clampedLevel), 0.82))

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.92),
                                Color(red: 0.72, green: 0.90, blue: 1.00).opacity(0.74),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(
                        width: barWidth,
                        height: min(maxHeight, 8 + visualLevel * (maxHeight - 8))
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.78), value: levels)
    }
}

private struct HumAnalysisView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            let scanOffset = sin(phase * 1.2) * 20

            ZStack {
                HStack(alignment: .center, spacing: 7) {
                    ForEach(0..<11, id: \.self) { index in
                        let sample = (sin(phase * 2.1 + Double(index) * 0.72) + 1) * 0.5

                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.94),
                                        Color(red: 0.68, green: 0.89, blue: 1.0).opacity(0.58),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 5, height: 12 + sample * 28)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.80),
                                Color.clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 2)
                    .blur(radius: 0.8)
                    .offset(y: scanOffset)
            }
        }
    }
}

private enum HumHaptics {
    static func beginHold() {
        Task { @MainActor in
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.prepare()
            generator.impactOccurred(intensity: 0.72)
        }
    }

    static func fillStep() {
        Task { @MainActor in
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    static func recordingStarted() {
        Task { @MainActor in
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.prepare()
            generator.impactOccurred(intensity: 0.95)
        }
    }

    static func recordingEnded() {
        Task { @MainActor in
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.prepare()
            generator.impactOccurred(intensity: 0.9)
        }
    }

    static func reveal() {
        Task { @MainActor in
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    static func warning() {
        Task { @MainActor in
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
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
                    Text("Glass Premium")
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

    private func previewHeroHeight(for width: CGFloat) -> CGFloat {
        min(max(width * 0.92, 360), 420)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    AmbientScreenBackdrop(
                        configuration: draft.configuration,
                        renderStyle: .lightweight
                    )

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 22) {
                            composerHeader
                            previewSection(heroHeight: previewHeroHeight(for: geometry.size.width))
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
    private func previewSection(heroHeight: CGFloat) -> some View {
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
                        .frame(height: heroHeight)
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
        let inset = format.bodyInset
        let width = max(size.width - inset * 2, 1)
        let height = max(size.height, 1)
        let normalizedLocation = CGPoint(
            x: min(max((location.x - inset) / width, 0.04), 0.96),
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
        .frame(maxWidth: 360, alignment: .leading)
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
                                    Text("Glass Premium")
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
