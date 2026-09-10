import AVFoundation
import StoreKit
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var studio: BowlStudio
    var onOpenProfile: ((BowlProfile) -> Void)?
    var startsWithHumming = false
    @StateObject private var premiumStore = PremiumStore()
    @State private var composerDraft: BowlProfile?
    @State private var deletingProfile: BowlProfile?
    @State private var isPremiumSheetPresented = false
    @State private var showsHumming = false
    @State private var openComposerAfterHum = false
    @State private var didPresentInitialRoute = false

    private var libraryProfiles: [BowlProfile] {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-AquariumLibraryStress") {
            return AquariumPerformanceDiagnostics.libraryFixtures
        }
        #endif
        return studio.profiles
    }

    init(studio: BowlStudio = BowlStudio(), startsWithHumming: Bool = false, onOpenProfile: ((BowlProfile) -> Void)? = nil) {
        self.studio = studio
        self.startsWithHumming = startsWithHumming
        self.onOpenProfile = onOpenProfile
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidGlassBackdrop()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("My bowls").font(.system(.largeTitle, design: .serif).weight(.regular))
                            Text("Little worlds, made yours.").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Button {
                            if studio.canCreateProfile { showsHumming = true }
                            else { isPremiumSheetPresented = true }
                        } label: {
                            HStack(spacing: 17) {
                                Image(systemName: "waveform").font(.system(size: 24, weight: .light))
                                    .frame(width: 54, height: 54)
                                    .glassEffect(.regular.tint(GlassPalette.mist.opacity(0.25)), in: .circle)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Hum a new bowl").font(.system(.title3, design: .serif))
                                    Text("A little sound becomes a little world.").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.right").font(.subheadline)
                            }
                            .padding(18)
                            .background(.white.opacity(0.20), in: .rect(cornerRadius: 28))
                        }
                        .buttonStyle(GlassPressStyle())
                        .accessibilityIdentifier("library.hum")

                        ForEach(libraryProfiles) { profile in
                            TankHomePage(profile: profile, isActive: !showsHumming && composerDraft == nil && !isPremiumSheetPresented, onDelete: { deletingProfile = profile }, onOpen: {
                                studio.selectProfile(profile.id)
                                onOpenProfile?(profile)
                            }, onGlassMeal: { studio.feedProfile(id: profile.id) })
                        }
                        if libraryProfiles.isEmpty {
                            Text("Your first aquarium is waiting. Hum a tune or choose the fish yourself.")
                                .font(.body).foregroundStyle(.secondary).padding(.vertical, 30)
                        }
                        HStack {
                            Text("\(libraryProfiles.count) of \(premiumStore.tankLimit) bowls")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            if !premiumStore.isPremiumUnlocked {
                                Button("Explore Premium") { isPremiumSheetPresented = true }.font(.subheadline)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .frame(maxWidth: 620)
                    .padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 30)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back to aquarium", systemImage: "chevron.left") { dismiss() }
                        .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create a bowl", systemImage: "plus") {
                        if studio.canCreateProfile { composerDraft = studio.makeDraftProfile() }
                        else { isPremiumSheetPresented = true }
                    }.labelStyle(.iconOnly)
                }
            }
        }
        .foregroundStyle(colorScheme.fishbowlPrimaryText)
        .tint(GlassPalette.sea)
        .fullScreenCover(item: $composerDraft) { draft in
            TankComposerScreen(initialProfile: draft, premiumStore: premiumStore) { profile in
                _ = studio.saveProfile(profile)
                composerDraft = nil
            } onCancel: { composerDraft = nil }
        }
        .fullScreenCover(isPresented: $showsHumming, onDismiss: {
            if openComposerAfterHum { openComposerAfterHum = false; composerDraft = studio.makeDraftProfile() }
        }) {
            GeometryReader { geometry in
                AddTankPage(slotNumber: studio.profiles.count + 1, tankLimit: premiumStore.tankLimit,
                            safeAreaInsets: geometry.safeAreaInsets, premiumStore: premiumStore,
                            onCreate: { openComposerAfterHum = true; showsHumming = false }, onGenerated: { profile in
                    _ = studio.saveProfile(profile)
                    showsHumming = false
                })
            }
        }
        .sheet(isPresented: $isPremiumSheetPresented) { PremiumUnlockSheet(store: premiumStore) }
        .confirmationDialog("Delete this bowl?", isPresented: Binding(get: { deletingProfile != nil }, set: {
            if !$0 { deletingProfile = nil }
        }), titleVisibility: .visible, presenting: deletingProfile) { profile in
            Button("Delete \(profile.name)", role: .destructive) {
                studio.deleteProfile(id: profile.id); deletingProfile = nil
            }
            Button("Cancel", role: .cancel) { deletingProfile = nil }
        } message: { profile in
            Text("Remove \(profile.name) from your collection.")
        }
        .task { await premiumStore.prepare() }
        #if DEBUG
        .task {
            if ProcessInfo.processInfo.arguments.contains("-AquariumLibraryStress") {
                await AquariumPerformanceDiagnostics.scrollLibrary()
            }
        }
        #endif
        .onAppear {
            guard !didPresentInitialRoute else { return }
            didPresentInitialRoute = true
            if startsWithHumming {
                if studio.canCreateProfile { showsHumming = true }
                else { isPremiumSheetPresented = true }
            }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-AquariumHumUI") { showsHumming = true }
            if ProcessInfo.processInfo.arguments.contains("-AquariumPremiumUI") { isPremiumSheetPresented = true }
            #endif
        }
    }
}

private struct TankHomePage: View {
    @Environment(\.colorScheme) private var colorScheme
    let profile: BowlProfile
    var isActive = true
    let onDelete: () -> Void
    let onOpen: () -> Void
    let onGlassMeal: () -> Void
    @State private var shareImage: UIImage?
    @State private var isPreparingShare = false
    @State private var isVisible = false

    private var snapshot: AquariumPetSnapshot { profile.petSnapshot(at: .now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .firstTextBaseline) {
                Text(profile.name).font(.system(.title, design: .serif)).lineLimit(2)
                Spacer(minLength: 8)
                Menu {
                    Button("Share aquarium", systemImage: "square.and.arrow.up") {
                        isPreparingShare = true
                        Task {
                            shareImage = await renderShareImage()
                            isPreparingShare = false
                        }
                    }
                    .disabled(isPreparingShare)
                    Button("Delete bowl", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Options for \(profile.name)")
                .buttonStyle(.plain)
            }
            ZStack {
                if isVisible {
                    AquariumCatalogPreview(configuration: profile.configuration, profile: profile,
                                           animated: isActive, interactive: true, onMeal: onGlassMeal)
                } else { AquariumPreviewPlaceholder(animated: false) }
            }
                .aspectRatio(0.94, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 30))
                .onScrollVisibilityChange(threshold: 0.01) { isVisible = $0 }
                .onDisappear { isVisible = false }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.configuration.descriptor).font(.subheadline.weight(.medium))
                    Text(profile.mode == .decorative ? "Decorative · Always at ease" : snapshot.statusLine)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button("Open", systemImage: "arrow.up.right", action: onOpen)
                    .buttonStyle(.glass).accessibilityLabel("Open \(profile.name)")
            }
            Divider().opacity(0.4).padding(.top, 8)
        }
        .sheet(isPresented: Binding(get: { shareImage != nil }, set: { if !$0 { shareImage = nil } })) {
            if let shareImage { ActivityView(activityItems: [shareImage]) }
        }
    }

    private func renderShareImage() async -> UIImage? {
        await AquariumSnapshotRenderer.prepare(configuration: profile.configuration, format: .widgetLarge, snapshot: snapshot, daylight: colorScheme != .dark)
        let content = PhotoShareCard(profile: profile).environment(\.colorScheme, colorScheme).frame(width: 430, height: 430)
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: 430, height: 430)
        renderer.scale = 3
        return renderer.uiImage
    }
}

private struct AddTankPage: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LiquidGlassBackdrop()
                if stage == .preview, let generatedDraft {
                    previewLayer(for: generatedDraft, in: geometry.size)
                        .transition(.opacity)
                } else {
                    ScrollView {
                        captureLayer(in: geometry.size)
                            .frame(minHeight: geometry.size.height)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .overlay(alignment: .topTrailing) {
                IconGlassButton(systemImage: "xmark") {
                    resetCreationFlow(clearStatus: true)
                    dismiss()
                }
                .padding(.trailing, 24).padding(.top, 12)
                .accessibilityLabel("Close humming")
                .accessibilityIdentifier("hum.close")
            }
            .sheet(isPresented: $isPremiumSheetPresented) { PremiumUnlockSheet(store: premiumStore) }
            .onReceive(humCreationTicker) { handleTick($0) }
            .onDisappear {
                analyzeTask?.cancel()
                isTouchActive = false
                recorder.cancelCapture()
                if stage == .recording || stage == .opening { resetCreationFlow(clearStatus: true) }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: stage)
            #if DEBUG
            .onAppear {
                let args = ProcessInfo.processInfo.arguments
                guard let index = args.firstIndex(of: "-HumPreviewState"), args.indices.contains(index + 1) else { return }
                // Visual fixtures never open the microphone or save a bowl.
                switch args[index + 1] {
                case "recording": stage = .recording; recordingProgress = 0.46; recorder.showVisualFixture(denied: false)
                case "analyzing": stage = .analyzing
                case "preview":
                    let analysis = HumAudioAnalysis(averageLevel: 0.28, peakLevel: 0.43, variance: 0.007, pitch: 190, duration: 6)
                    generatedDraft = HumGeneratedBowl(profile: HumBowlGenerator.makeProfile(from: analysis), analysis: analysis)
                    stage = .preview
                case "denied": recorder.showVisualFixture(denied: true); statusMessage = "Microphone access is off. Allow access in Settings to hum a bowl."
                default: break
                }
            }
            #endif
        }
        .foregroundStyle(colorScheme.fishbowlPrimaryText)
        .tint(GlassPalette.sea)
    }

    private func captureLayer(in size: CGSize) -> some View {
        let compact = size.height < 700
        let diameter = min(size.width * 0.58, compact ? 205 : 238)
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text(stageTitle)
                    .font(.system(size: compact ? 36 : 43, weight: .regular, design: .serif))
                    .tracking(-1.1).fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(colorScheme.fishbowlPrimaryText)
                Text(stage == .idle ? "Let your voice shape an aquarium." :
                     stage == .recording ? "Stay with your sound. Release when you're ready." :
                     stage == .analyzing ? "Finding the colors and movement in your hum." : "Making room for your sound.")
                    .font(.subheadline).foregroundStyle(colorScheme.fishbowlSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, compact ? 65 : 84)
            .padding(.trailing, 18)

            Spacer(minLength: 24)
            ZStack {
                HumMicButton(stage: stage, fillProgress: micFillProgress,
                             recordingProgress: recordingProgress, waveformLevels: recorder.waveformLevels)
                    .frame(width: diameter, height: diameter)
                    .allowsHitTesting(false)
                if stage == .analyzing {
                    HumAnalysisView().frame(width: diameter * 0.56, height: 70).allowsHitTesting(false)
                }
                Color.clear.contentShape(Circle())
                    .frame(width: diameter + 28, height: diameter + 28)
                    .highPriorityGesture(micHoldGesture)
                    .allowsHitTesting(stage != .analyzing)
                    .accessibilityElement()
                    .accessibilityLabel(stage == .recording ? "Finish humming" : "Start humming")
                    .accessibilityHint("Hold to record your hum, then release. With VoiceOver, double tap to start or finish.")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        if stage == .recording { finishRecording() }
                        else if stage == .idle { isTouchActive = true; beginRecordingSequence() }
                    }
                    .accessibilityIdentifier("hum.record")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)

            VStack(spacing: 13) {
                if stage == .recording {
                    HumWaveformView(levels: recorder.waveformLevels, maxHeight: 40, barWidth: 3)
                        .frame(width: 210, height: 44)
                    Text(recordingCounterLine).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                } else {
                    Text(stage == .idle ? "Hold the glass & hum" : stage == .analyzing ? "Your bowl is taking shape" : "Opening the microphone")
                        .font(.subheadline.weight(.medium))
                    Text(stage == .idle ? "Up to 8 seconds. Any little melody will do." : "")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity).frame(minHeight: 80)
            Spacer(minLength: 24)
            if let statusMessage { statusChip(statusMessage).padding(.bottom, 16) }
            if recorder.permissionDenied {
                Button("Open microphone settings", action: openSettings)
                    .buttonStyle(.glass).padding(.bottom, 14)
            }
            if stage == .idle {
                Button("Choose the fish myself", systemImage: "slider.horizontal.3", action: onCreate)
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity).padding(.vertical, 17)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .buttonStyle(GlassPressStyle())
                Text("Your sound stays on this device.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.top, 16)
            }
        }
        .frame(maxWidth: 480)
        .padding(.horizontal, 30).padding(.bottom, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var micFillProgress: CGFloat {
        switch stage {
        case .idle: max(0.16, entryProgress)
        case .opening, .recording, .analyzing: 0.76
        case .preview: 0
        }
    }

    private func previewLayer(for generatedDraft: HumGeneratedBowl, in size: CGSize) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(generatedDraft.profile.name)
                        .font(.system(.largeTitle, design: .serif)).tracking(-0.6)
                    Text(generatedDraft.analysis.headline)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.trailing, 35)
                AquariumCatalogPreview(configuration: generatedDraft.profile.configuration,
                                       profile: generatedDraft.profile, animated: !isPremiumSheetPresented)
                    .frame(height: min(size.height * 0.42, 365))
                    .clipShape(.rect(cornerRadius: 32))
                VStack(alignment: .leading, spacing: 9) {
                    Text(generatedDraft.profile.configuration.descriptor)
                        .font(.system(.title3, design: .serif))
                    Text(generatedDraft.analysis.detailLine)
                        .font(.caption).foregroundStyle(.secondary)
                }
                if premiumStore.isPremiumUnlocked {
                    Button("Keep this bowl", systemImage: "checkmark", action: keepGeneratedBowl)
                        .buttonStyle(StudioPrimaryButtonStyle())
                } else {
                    Text("Keep your creation with Glass Premium.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button("Explore Premium", systemImage: "sparkle") { isPremiumSheetPresented = true }
                        .buttonStyle(StudioPrimaryButtonStyle())
                }
                Button("Hum another", systemImage: "arrow.counterclockwise") { resetCreationFlow(clearStatus: true) }
                    .font(.subheadline).frame(maxWidth: .infinity).padding(.vertical, 10)
            }
            .frame(maxWidth: 480).padding(.horizontal, 26).padding(.top, 76).padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
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
            return "Hum a little\nworld to life."
        case .opening:
            return "Listening"
        case .recording:
            return "Listening to you."
        case .analyzing:
            return "A world from\nyour sound."
        case .preview:
            return ""
        }
    }

    private var recordingCounterLine: String {
        let elapsed = maxRecordingDuration * Double(recordingProgress)
        return String(format: "%.1f / 8 seconds", elapsed)
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
                statusMessage = "Microphone ready. Hold the glass to begin."
                resetCreationFlow(clearStatus: false)
                return
            case .denied:
                statusMessage = "Microphone access is off. You can allow it in Settings."
                HumHaptics.warning()
                resetCreationFlow(clearStatus: false)
                return
            }

            guard isTouchActive, stage == .opening else {
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
                statusMessage = "The microphone could not start. Please try again."
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

    private func statusChip(_ text: String) -> some View {
        Label(text, systemImage: "info.circle")
            .font(.caption).foregroundStyle(colorScheme.fishbowlSecondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GlassPalette.mist.opacity(0.18), in: .rect(cornerRadius: 18))
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

    #if DEBUG
    func showVisualFixture(denied: Bool) {
        permissionDenied = denied
        waveformLevels = (0..<24).map { index in 0.08 + CGFloat(abs(sin(Double(index) * 0.7))) * 0.72 }
    }
    #endif

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

        let firstFeature = picker.pick(recipe.featurePool)
        let features = analysis.averageLevel > 0.52
            ? [firstFeature, picker.pick(recipe.featurePool.filter { $0 != firstFeature })]
            : [firstFeature]

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
                featurePiece: firstFeature,
                featurePieces: features
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
                fishPool: [.royalBetta, .glassGold, .opalAngelfish, .sunsetRasbora, .moonStingray, .pearlSeahorse, .crystalPuffer, .leafySeaDragon],
                substratePool: [.pearlSand, .moonGravel],
                decorationPool: [.minimal, .glassPearls],
                featurePool: [.bubbleStone, .moonLantern, .pearlShell],
                companionPool: [.snail, .shrimp, .seaUrchin],
                personality: .dreamy,
                adjectives: ["Soft", "Silent", "Pearl", "Velvet"],
                nouns: ["Lagoon", "Glass", "Drift", "Hush"]
            )

        case .tide:
            return HumBowlRecipe(
                vesselPool: [.orb, .panorama],
                fishPool: [.moonKoi, .leopardShark, .glassGold, .silverArowana, .humpbackWhale, .ribbonEel, .glassSailfish, .blueTang],
                substratePool: [.obsidianSand, .moonGravel],
                decorationPool: [.riverRocks, .glassPearls],
                featurePool: [.driftwoodArch, .moonLantern, .kelp, .seaFan],
                companionPool: [.crab, .snail, .seaCucumber, .miniSubmarine, .seaUrchin],
                personality: .shy,
                adjectives: ["Blue", "Midnight", "Tidal", "Deep"],
                nouns: ["Current", "Basin", "Reef", "Pool"]
            )

        case .bloom:
            return HumBowlRecipe(
                vesselPool: [.gallery, .panorama],
                fishPool: [.moonKoi, .opalAngelfish, .glassGold, .royalBetta, .velvetDiscus, .sunburstButterfly, .pearlSeahorse, .mandarinDragonet, .leafySeaDragon],
                substratePool: [.pearlSand, .coralBloom, .moonGravel],
                decorationPool: [.glassPearls, .riverRocks, .coralGarden],
                featurePool: [.moonLantern, .bubbleStone, .kelp, .pearlShell, .seaFan],
                companionPool: [.shrimp, .nudibranchRibbon, .snail],
                personality: .playful,
                adjectives: ["Lush", "Bloom", "Golden", "Warm"],
                nouns: ["Bowl", "Lantern", "Garden", "Glow"]
            )

        case .spark:
            return HumBowlRecipe(
                vesselPool: [.panorama, .gallery],
                fishPool: [.neonGuppy, .emberTetra, .opalAngelfish, .moonKoi, .sunsetRasbora, .mandarinDragonet, .blueTang, .ribbonEel],
                substratePool: [.obsidianSand, .coralBloom, .moonGravel],
                decorationPool: [.coralGarden, .glassPearls, .riverRocks],
                featurePool: [.kelp, .moonLantern, .driftwoodArch],
                companionPool: [.crab, .shrimp, .nudibranchFlame, .miniSubmarine],
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

private struct HumMicButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let stage: HumCreationStage
    let fillProgress: CGFloat
    let recordingProgress: CGFloat
    let waveformLevels: [CGFloat]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let breath = 1 + sin(phase * 0.75) * 0.015
            ZStack {
                ForEach(0..<2, id: \.self) { index in
                    Circle().stroke(GlassPalette.sea.opacity(0.09 - Double(index) * 0.025), lineWidth: 1)
                        .scaleEffect((1.19 + Double(index) * 0.18) * breath)
                }
                Circle().fill(.white.opacity(colorScheme == .dark ? 0.05 : 0.34))
                    .glassEffect(.regular, in: .circle)
                MicWaterFillShape(level: fillProgress, phase: phase, amplitude: reduceMotion ? 0 : 7)
                    .fill(LinearGradient(colors: [GlassPalette.mist.opacity(0.46), GlassPalette.sea.opacity(0.74)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(.circle)
                Circle().fill(RadialGradient(colors: [.white.opacity(0.64), .clear, GlassPalette.sea.opacity(0.17)],
                                            center: .topLeading, startRadius: 0, endRadius: 230))
                Ellipse().fill(.white.opacity(0.72)).frame(width: 61, height: 16)
                    .blur(radius: 5).rotationEffect(.degrees(-38)).offset(x: -53, y: -62)
                if stage != .analyzing {
                    Image(systemName: stage == .recording ? "waveform" : "mic")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.90) : GlassPalette.ink.opacity(0.78))
                        .contentTransition(.symbolEffect(.replace))
                }
                Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.96), GlassPalette.sea.opacity(0.19), .white.opacity(0.76)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                Circle().trim(from: 0, to: stage == .recording ? max(0.01, recordingProgress) : 0)
                    .stroke(GlassPalette.sea, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90)).padding(-7)
            }
            .shadow(color: GlassPalette.sea.opacity(0.13), radius: 28, x: 0, y: 22)
        }
        .accessibilityHidden(true)
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
                                GlassPalette.sea,
                                GlassPalette.mist,
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 13) {
                ForEach(0..<3, id: \.self) { index in
                    Circle().fill(GlassPalette.sea.opacity(0.55)).frame(width: 12, height: 12)
                        .overlay { Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1) }
                        .offset(y: sin(phase * 1.8 + Double(index) * 1.3) * 7)
                }
            }
        }
        .accessibilityLabel("Creating your aquarium")
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

private struct AquariumThemePicker: View {
    @Binding var selection: AquariumTheme

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                StudioSectionHeading(title: "Bowl theme", detail: "Wall colors with matching light and reflections.")
                VStack(alignment: .leading, spacing: 10) {
                    Text("Solid colors").font(.subheadline.weight(.medium))
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(AquariumTheme.wallColors) { theme in
                            AquariumThemeTile(theme: theme, selected: selection == theme) { selection = theme }
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Palettes").font(.subheadline.weight(.medium))
                    ScrollViewReader { scroll in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(AquariumTheme.palettes) { theme in
                                    AquariumThemeTile(theme: theme, selected: selection == theme) { selection = theme }
                                        .frame(width: 136).id(theme)
                                }
                            }
                            .padding(2)
                        }
                        .onAppear { scroll.scrollTo(selection, anchor: .center) }
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

private struct AquariumThemeTile: View {
    @ScaledMetric(relativeTo: .caption) private var labelHeight: CGFloat = 36
    let theme: AquariumTheme
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 17)
                        .fill(LinearGradient(colors: theme.swatchColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    RoundedRectangle(cornerRadius: 17)
                        .fill(RadialGradient(colors: [.white.opacity(0.30), .clear], center: .topLeading,
                                             startRadius: 0, endRadius: 100))
                    if theme == .sunset {
                        RoundedRectangle(cornerRadius: 17)
                            .fill(RadialGradient(colors: [.yellow.opacity(0.90), .yellow.opacity(0.30), .clear],
                                                 center: UnitPoint(x: 0.24, y: 0.23), startRadius: 0, endRadius: 39))
                        RoundedRectangle(cornerRadius: 17)
                            .fill(RadialGradient(colors: [.yellow.opacity(0.90), .yellow.opacity(0.30), .clear],
                                                 center: UnitPoint(x: 0.75, y: 0.77), startRadius: 0, endRadius: 38))
                    }
                    Canvas { context, size in
                        if theme == .neonJungle {
                            for index in -1..<6 {
                                let x = CGFloat(index) * size.width / 4.6
                                let bend = index.isMultiple(of: 2) ? 13.0 : -10.0
                                var stripe = Path()
                                stripe.move(to: CGPoint(x: x, y: -4))
                                stripe.addCurve(to: CGPoint(x: x + bend, y: size.height + 4),
                                                control1: CGPoint(x: x + 31, y: size.height * 0.30),
                                                control2: CGPoint(x: x - 17, y: size.height * 0.70))
                                stripe.addCurve(to: CGPoint(x: x + 10, y: -4),
                                                control1: CGPoint(x: x - 4, y: size.height * 0.62),
                                                control2: CGPoint(x: x + 38, y: size.height * 0.34))
                                stripe.closeSubpath()
                                context.fill(stripe, with: .color(Color(red: 0.95, green: 0.15, blue: 0.57)))
                            }
                        }
                        for index in 0..<3 {
                            let x = CGFloat(index) * size.width * 0.35
                            var curve = Path()
                            curve.move(to: CGPoint(x: x - 20, y: -5))
                            curve.addCurve(to: CGPoint(x: x + 55, y: size.height + 5),
                                           control1: CGPoint(x: x + 90, y: size.height * 0.35),
                                           control2: CGPoint(x: x - 30, y: size.height * 0.68))
                            context.stroke(curve, with: .color(.white.opacity(index == 1 ? 0.38 : 0.15)), lineWidth: 1.2)
                        }
                    }
                    .clipShape(.rect(cornerRadius: 17))
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold)).foregroundStyle(.white)
                            .padding(6).background(.black.opacity(0.55), in: .circle)
                            .padding(7)
                    }
                }
                .frame(height: 66)
                .overlay {
                    RoundedRectangle(cornerRadius: 17)
                        .strokeBorder(selected ? GlassPalette.sea : .white.opacity(0.45), lineWidth: selected ? 2 : 1)
                }
                Text(theme.title).font(.caption.weight(.medium))
                    .frame(height: labelHeight, alignment: .topLeading)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel(theme.title)
        .accessibilityValue(theme.summary)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint("Changes the bowl walls and lighting")
        .accessibilityIdentifier("theme.\(theme.rawValue)")
    }
}

private enum StudioEditorSection: String, CaseIterable, Identifiable {
    case fish = "Fish", habitat = "Habitat", companions = "Friends", details = "Details"
    var id: Self { self }
}

private struct KeyboardDismissTapObserver: UIViewRepresentable {
    let onTap: (CGPoint) -> Void

    func makeUIView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.isUserInteractionEnabled = false
        view.onTap = onTap
        return view
    }

    func updateUIView(_ view: ObserverView, context: Context) { view.onTap = onTap }

    static func dismantleUIView(_ view: ObserverView, coordinator: ()) { view.detach() }

    final class ObserverView: UIView, UIGestureRecognizerDelegate {
        var onTap: ((CGPoint) -> Void)?
        private weak var observedWindow: UIWindow?
        private lazy var tap: UITapGestureRecognizer = {
            let recognizer = TapObserver(target: self, action: #selector(didTap))
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesEnded = false
            recognizer.delegate = self
            return recognizer
        }()

        override func didMoveToWindow() {
            super.didMoveToWindow()
            detach()
            observedWindow = window
            window?.addGestureRecognizer(tap)
        }

        func detach() {
            observedWindow?.removeGestureRecognizer(tap)
            observedWindow = nil
        }

        @objc private func didTap() {
            guard tap.state == .ended else { return }
            onTap?(tap.location(in: self))
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            // The window also contains the keyboard; observe only this screen's content.
            return bounds.contains(touch.location(in: self))
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }

    final class TapObserver: UITapGestureRecognizer {
        // Native menus must neither cancel this observer nor lose their own tap.
        override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
        override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    }
}

private struct TankComposerScreen: View {
    private enum ScrollTarget: Hashable { case name }

    @Environment(\.colorScheme) private var colorScheme

    @State private var draft: BowlProfile
    @State private var editorSection: StudioEditorSection = .fish
    @State private var previewFormat: AquariumDisplayFormat = .studioHero
    @State private var isPremiumSheetPresented = false
    @FocusState private var isNameFieldFocused: Bool
    @State private var nameFieldFrame: CGRect = .zero
    @Namespace private var composerCoordinateSpace
    @ObservedObject var premiumStore: PremiumStore

    let onSave: (BowlProfile) -> Void
    let onCancel: () -> Void
    var isEditing = false

    init(
        initialProfile: BowlProfile,
        premiumStore: PremiumStore,
        isEditing: Bool = false,
        onSave: @escaping (BowlProfile) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: initialProfile)
        self.premiumStore = premiumStore
        self.onSave = onSave
        self.onCancel = onCancel
        self.isEditing = isEditing
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

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LiquidGlassBackdrop()
                VStack(spacing: 18) {
                    composerHeader
                    previewSection(heroHeight: min(geometry.size.height * 0.35, 320))
                    Picker("Edit aquarium", selection: $editorSection) {
                        ForEach(StudioEditorSection.allCases) { section in
                            Text(section.rawValue).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("editor.sections")
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 18) { controlsSection }
                                .padding(.bottom, 28)
                        }
                        .scrollIndicators(.hidden)
                        .scrollDismissesKeyboard(.interactively)
                        .scrollEdgeEffectStyle(.soft, for: .top)
                        .onChange(of: isNameFieldFocused) { revealNameField(using: proxy) }
                        .onChange(of: geometry.size.height) { revealNameField(using: proxy) }
                    }
                    .id(editorSection)
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, 22).padding(.top, 12)
                .frame(maxWidth: .infinity)
            }
            .contentShape(Rectangle())
            .background(KeyboardDismissTapObserver { location in
                // Keep cursor placement and text selection inside the field working.
                guard isNameFieldFocused, !nameFieldFrame.contains(location) else { return }
                isNameFieldFocused = false
            })
            .coordinateSpace(name: composerCoordinateSpace)
        }
        .foregroundStyle(colorScheme.fishbowlPrimaryText)
        .tint(GlassPalette.sea)
        .sheet(isPresented: $isPremiumSheetPresented) { PremiumUnlockSheet(store: premiumStore) }
        .task { await premiumStore.prepare() }
        .onChange(of: editorSection) { isNameFieldFocused = false }
        #if DEBUG
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if let index = args.firstIndex(of: "-AquariumFeatures"), args.indices.contains(index + 1) {
                draft.configuration.featurePieces = args[index + 1].split(separator: ",").compactMap { FeaturePieceStyle(rawValue: String($0)) }
            }
            if let index = args.firstIndex(of: "-AquariumEditorSection"), args.indices.contains(index + 1),
               let section = StudioEditorSection(rawValue: args[index + 1]) { editorSection = section }
            if let index = args.firstIndex(of: "-AquariumTheme"), args.indices.contains(index + 1),
               let theme = AquariumTheme(rawValue: args[index + 1]) { draft.configuration.theme = theme }
        }
        #endif
    }

    private func revealNameField(using proxy: ScrollViewProxy) {
        guard isNameFieldFocused else { return }
        // Recenter after keyboard resizing as well as the initial focus change.
        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo(ScrollTarget.name, anchor: .center)
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
        HStack(spacing: 14) {
            IconGlassButton(systemImage: "xmark", action: onCancel)
            Text(isEditing ? "Your aquarium" : "A new bowl")
                .font(.system(.title2, design: .serif)).lineLimit(1).minimumScaleFactor(0.75)
            Spacer(minLength: 0)
            Button(isEditing ? "Save" : "Create") { onSave(sanitizedDraft) }
                .font(.subheadline.weight(.medium))
                .buttonStyle(.glassProminent).tint(GlassPalette.sea).foregroundStyle(.white).controlSize(.large)
                .accessibilityIdentifier("editor.save")
        }
    }

    private func previewSection(heroHeight: CGFloat) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if previewFormat == .studioHero {
                    AquariumCatalogPreview(configuration: previewConfiguration, animated: !isPremiumSheetPresented,
                                           focusY: editorSection == .habitat || editorSection == .companions ? -1.0 : nil)
                        .frame(height: heroHeight)
                } else {
                    WidgetSizePreview(configuration: previewConfiguration, format: previewFormat,
                                      petSnapshot: draft.petSnapshot(at: .now))
                        .frame(height: heroHeight)
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(.rect(cornerRadius: 30))
            Menu {
                Picker("Preview", selection: $previewFormat) {
                    Text("Aquarium").tag(AquariumDisplayFormat.studioHero)
                    Text("Small widget").tag(AquariumDisplayFormat.widgetSmall)
                    Text("Medium widget").tag(AquariumDisplayFormat.widgetMedium)
                    Text("Large widget").tag(AquariumDisplayFormat.widgetLarge)
                }
            } label: {
                Label("Preview", systemImage: "rectangle.on.rectangle")
                    .font(.caption.weight(.medium)).padding(.horizontal, 12).padding(.vertical, 10)
            }
            .glassEffect(.regular.interactive(), in: .capsule)
            .padding(12)
        }
    }

    private var detailsSection: some View {
        GlassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    StudioSectionHeading(
                        title: "Details",
                        detail: "Name your bowl and choose how to care for it."
                    )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Bowl name")
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)

                    TextField("My little aquarium", text: $draft.name)
                        .font(.system(size: 16, weight: .medium, design: .default))
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
                        .onGeometryChange(for: CGRect.self) { geometry in
                            geometry.frame(in: .named(composerCoordinateSpace))
                        } action: { nameFieldFrame = $0 }
                        .id(ScrollTarget.name)
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

    @ViewBuilder
    private var controlsSection: some View {
        switch editorSection {
        case .fish:
            fishControls
            personalityControls
        case .habitat:
            AquariumThemePicker(selection: $draft.configuration.theme)
            habitatControls
        case .companions: companionControls
        case .details: detailsSection
        }
    }

    private var fishControls: some View {
        GlassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    StudioSectionHeading(
                        title: "Fish",
                        detail: "Choose a glass sculpture, then its company."
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
                                    subtitle: nil,
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
                                    Text("Fish \(slot + 2)")
                                        .font(.system(size: 11, weight: .semibold, design: .default))
                                        .tracking(1.2)
                                        .foregroundStyle(.secondary)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 10) {
                                            SelectablePill(
                                                title: "None",
                                                subtitle: nil,
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
    }

    private var personalityControls: some View {
        GlassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    StudioSectionHeading(
                        title: "Personality",
                        detail: "Set the pace of this little world."
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
    }

    private var habitatControls: some View {
        GlassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    StudioSectionHeading(
                        title: "Habitat",
                        detail: "Soft sand and a few sculpted pieces."
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

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Choose up to two feature pieces. We'll arrange them together.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ForEach(0..<2, id: \.self) { slot in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Feature piece \(slot + 1)")
                                    .font(.subheadline.weight(.medium))
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(orderedFeaturePieces) { option in
                                            SelectablePill(
                                                title: option == .none ? "None" : option.title,
                                                subtitle: option == .none ? nil : option.summary,
                                                isSelected: draft.configuration.feature(at: slot) == option,
                                                badge: premiumBadge(isPremium: option.isPremium),
                                                isLocked: option.isPremium && !premiumStore.isPremiumUnlocked
                                            ) {
                                                if option.isPremium && !premiumStore.isPremiumUnlocked {
                                                    isPremiumSheetPresented = true
                                                } else {
                                                    draft.configuration.setFeature(option, at: slot)
                                                }
                                            }
                                            .accessibilityIdentifier("feature.\(slot).\(option.rawValue)")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
    }

    private var companionControls: some View {
        GlassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    StudioSectionHeading(
                        title: "Companions",
                        detail: premiumStore.isPremiumUnlocked
                        ? "Up to three little companions."
                        : "A little company for your aquarium."
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(0..<visibleCompanionSlotCount, id: \.self) { slot in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Companion \(slot + 1)")
                                    .font(.system(size: 11, weight: .semibold, design: .default))
                                    .tracking(1.2)
                                    .foregroundStyle(.secondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        SelectablePill(
                                            title: "None",
                                            subtitle: nil,
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
        draft.configuration.featurePieces = draft.configuration.resolvedFeaturePieces
        if !premiumStore.isPremiumUnlocked {
            draft.configuration = draft.configuration.sanitizedForFreeTier()
        }
        return draft
    }
}

struct GlassBowlEditor: View {
    @StateObject private var premiumStore = PremiumStore()
    let profile: BowlProfile
    let isEditing: Bool
    let onSave: (BowlProfile) -> Void
    let onCancel: () -> Void

    var body: some View {
        TankComposerScreen(initialProfile: profile, premiumStore: premiumStore, isEditing: isEditing,
                           onSave: onSave, onCancel: onCancel)
    }
}

private struct WidgetSizePreview: View {
    let configuration: AquariumConfiguration
    let format: AquariumDisplayFormat
    let petSnapshot: AquariumPetSnapshot
    var body: some View {
        GeometryReader { geometry in
            let preferredWidth = format == .widgetSmall ? min(180, geometry.size.width * 0.6) : geometry.size.width - 28
            let width = min(preferredWidth, max(0, geometry.size.height - 24) * format.aspectRatio)
            AquariumGlassStillView(configuration: configuration, format: format, phase: 0, petSnapshot: petSnapshot)
                .frame(width: width, height: width / format.aspectRatio)
                .clipShape(.rect(cornerRadius: 26))
                .shadow(color: GlassPalette.ink.opacity(0.10), radius: 12, y: 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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

                AquariumGlassStillView(
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
                .font(.system(size: 11, weight: .semibold, design: .default))
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
    enum RenderStyle { case full, lightweight }
    let configuration: AquariumConfiguration
    var renderStyle: RenderStyle = .full
    var body: some View { LiquidGlassBackdrop() }
}

private struct ActionGlassButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    var body: some View {
        Button(title, systemImage: systemImage, action: action)
            .font(.subheadline.weight(.medium)).buttonStyle(.glass).controlSize(.large)
    }
}

private struct IconGlassButton: View {
    let systemImage: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage).font(.system(size: 17, weight: .regular))
                .frame(width: 46, height: 46)
                .contentShape(Circle())
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel(systemImage == "xmark" ? "Close" : systemImage == "trash" ? "Delete bowl" : "Share aquarium")
    }
}

private struct StudioPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.body.weight(.medium))
            .frame(maxWidth: .infinity).padding(.vertical, 17)
            .foregroundStyle(.white)
            .background(GlassPalette.sea, in: .capsule)
            .overlay { Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1) }
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

private struct PremiumBullet: View {
    @Environment(\.colorScheme) private var colorScheme

    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(GlassPalette.sea)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            Text(text)
                .font(.system(size: 15, weight: .medium, design: .default))
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
            fishSpecies: .moonStingray,
            fishCount: .duet,
            additionalFishSpecies: [.pearlSeahorse],
            companion: .miniSubmarine,
            substrate: .moonGravel,
            decoration: .glassPearls,
            featurePiece: .pearlShell
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidGlassBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("More room to imagine.")
                                .font(.system(.largeTitle, design: .serif)).tracking(-0.7)
                            Text("Glass Premium").font(.subheadline.weight(.medium)).foregroundStyle(GlassPalette.sea)
                        }
                        AquariumGlassStillView(configuration: showcaseConfiguration, format: .widgetMedium,
                                               phase: 0, petSnapshot: .decorative(at: .now))
                            .clipShape(.rect(cornerRadius: 28))
                        VStack(alignment: .leading, spacing: 18) {
                            PremiumBullet(text: "Keep the aquariums you create by humming")
                            PremiumBullet(text: "A collection of up to 12 bowls")
                            PremiumBullet(text: "Every glass fish, with mixed-species schools")
                            PremiumBullet(text: "All sculpted props and up to three companions")
                        }
                        if let statusMessage = store.statusMessage {
                            Label(statusMessage, systemImage: "info.circle")
                                .font(.caption).foregroundStyle(.secondary)
                                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                .background(GlassPalette.mist.opacity(0.16), in: .rect(cornerRadius: 18))
                        }
                        VStack(spacing: 15) {
                            Button { Task { await store.purchasePremium() } } label: {
                                HStack(spacing: 10) {
                                    if store.isBusy { ProgressView().tint(.white) }
                                    Text(store.purchaseButtonTitle)
                                }
                            }
                            .buttonStyle(StudioPrimaryButtonStyle()).disabled(store.isBusy)
                            Text("One purchase. Yours to keep.").font(.caption).foregroundStyle(.secondary)
                            Button("Restore purchases") { Task { await store.restorePurchases() } }
                                .font(.subheadline).disabled(store.isBusy)
                            #if DEBUG
                            DisclosureGroup("Developer options") {
                                Button(store.isPreviewUnlocked ? "Disable preview unlock" : "Use preview unlock") { store.togglePreviewUnlock() }
                                    .font(.caption).padding(.vertical, 10)
                            }.font(.caption).foregroundStyle(.secondary).padding(.top, 12)
                            #endif
                        }
                    }
                    .frame(maxWidth: 540).padding(.horizontal, 26).padding(.vertical, 22)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly)
                }
            }
        }
        .foregroundStyle(colorScheme.fishbowlPrimaryText)
        .tint(GlassPalette.sea)
        .task { await store.prepare() }
        .onChange(of: store.isPremiumUnlocked) { _, unlocked in if unlocked { dismiss() } }
    }
}


private extension ColorScheme {
    var fishbowlPrimaryText: Color {
        self == .dark ? Color(red: 0.90, green: 0.95, blue: 0.92) : GlassPalette.ink
    }

    var fishbowlSecondaryText: Color {
        self == .dark ? Color.white.opacity(0.68) : GlassPalette.ink.opacity(0.68)
    }

    var fishbowlTertiaryText: Color {
        self == .dark ? Color.white.opacity(0.60) : GlassPalette.ink.opacity(0.64)
    }

    var fishbowlElevatedFill: Color {
        self == .dark
        ? GlassPalette.night.opacity(0.86)
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
            statusMessage = "Purchases are unavailable right now. Please try again later."
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
        var copy = self
        if vesselStyle == .orb && style != .orb { copy.vesselStyle = style }
        return copy
    }

    var ambientBackdropColors: [Color] {
        [
            fishPalette.dropFirst().first ?? fishPalette.first ?? Color.white,
            decoration.accentColors[1],
            substrate.accentColors[2],
        ]
    }
}
