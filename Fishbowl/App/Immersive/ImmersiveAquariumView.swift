import SwiftUI

struct ImmersiveAquariumView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var experience = AquariumExperience()
    @StateObject private var studio = BowlStudio()
    @State private var editorDraft: BowlProfile?
    @State private var openEditorOnDismiss = false
    @State private var showsMenu = false
    @State private var showsLibrary = false
    @State private var openLibraryOnDismiss = false
    @State private var startsLibraryWithHumming = false
    @State private var showsControl = true
    @State private var showsHint = false
    @State private var didPresentDiagnosticUI = false
    @AppStorage("aquarium.depth.hasSeenHint") private var hasSeenHint = false
    @AppStorage("aquarium.depth.selectedProfile") private var selectedGlassProfile = ""

    private var usesLightControls: Bool { !experience.daylight || experience.configuration.theme.prefersLightControls }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(red: 0.01, green: 0.06, blue: 0.05).ignoresSafeArea()
            AquariumMetalView(experience: experience,
                              active: scenePhase == .active && !showsLibrary && editorDraft == nil,
                              reduceMotion: reduceMotion)
                .ignoresSafeArea()

            if let error = experience.errorMessage {
                VStack(spacing: 18) {
                    Text("The aquarium couldn't start")
                        .font(.title2)
                    Text(error).font(.body).foregroundStyle(.secondary)
                    Button("Open my bowls") { showsLibrary = true }
                        .buttonStyle(.glass)
                }
                .multilineTextAlignment(.center)
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if showsHint {
                Text("Tilt or drag to look. Tap to feed.\nDouble tap to center the view.")
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(usesLightControls ? Color.white.opacity(0.85) : Color.black.opacity(0.65))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 90)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            Button {
                showsMenu = true
                experience.recentInteraction += 1
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(experience.daylight ? Color(white: 0.18) : .white)
                    .frame(width: 52, height: 52)
                    .contentShape(Circle())
            }
            .glassEffect(.clear.interactive(), in: .circle)
            .accessibilityLabel("Aquarium options")
            .opacity(showsControl || showsMenu || voiceOverEnabled || reduceMotion ? 1 : 0)
            .allowsHitTesting(showsControl || showsMenu || voiceOverEnabled || reduceMotion)
            .padding(.trailing, 24)
            .padding(.bottom, 20)
        }
        .preferredColorScheme(usesLightControls ? .dark : .light)
        .sheet(isPresented: $showsMenu, onDismiss: {
            experience.recentInteraction += 1
            if openLibraryOnDismiss { openLibraryOnDismiss = false; showsLibrary = true }
            if openEditorOnDismiss {
                openEditorOnDismiss = false
                editorDraft = experience.profile ?? BowlProfile(name: "Vetro", configuration: experience.configuration, mode: .decorative)
            }
        }) {
            options
                .presentationDetents([.height(490)])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(experience.daylight ? .light : .dark)
        }
        .fullScreenCover(isPresented: $showsLibrary, onDismiss: { experience.recentInteraction += 1 }) {
            ContentView(studio: studio, startsWithHumming: startsLibraryWithHumming) { profile in
                open(profile)
                showsLibrary = false
            }
            .preferredColorScheme(experience.daylight ? .light : .dark)
        }

        .fullScreenCover(item: $editorDraft) { draft in
            GlassBowlEditor(profile: draft, isEditing: studio.profiles.contains { $0.id == draft.id }) { profile in
                if let saved = studio.saveProfile(profile) { open(saved) }
                editorDraft = nil
            } onCancel: {
                editorDraft = nil
            }
            .preferredColorScheme(experience.daylight ? .light : .dark)
        }
        .onChange(of: studio.profiles) {
            guard let id = experience.profile?.id else { return }
            if let profile = studio.profiles.first(where: { $0.id == id }) {
                experience.profile = profile
                experience.configuration = profile.configuration
            } else {
                experience.profile = nil
                experience.configuration = .murano
                selectedGlassProfile = ""
            }
        }
        .onAppear {
            #if DEBUG
            if !didPresentDiagnosticUI {
                didPresentDiagnosticUI = true
                if ProcessInfo.processInfo.arguments.contains("-AquariumEvening") { experience.daylight = false }
            if ProcessInfo.processInfo.arguments.contains("-AquariumHumUI") || ProcessInfo.processInfo.arguments.contains("-AquariumLibraryUI") || ProcessInfo.processInfo.arguments.contains("-AquariumLibraryStress") || ProcessInfo.processInfo.arguments.contains("-AquariumPremiumUI") { showsLibrary = true }
            if ProcessInfo.processInfo.arguments.contains("-AquariumEditorUI") {
                editorDraft = BowlProfile(name: "Vetro", configuration: .murano, mode: .decorative)
            }
            }
            #endif
            if let id = UUID(uuidString: selectedGlassProfile), let profile = studio.profiles.first(where: { $0.id == id }) { open(profile) }
            experience.onMealConsumed = {
                if let id = experience.profile?.id { studio.feedProfile(id: id) }
            }
        }
        .task(id: studio.profiles) { await AquariumSnapshotRenderer.prepareProfiles(studio.profiles) }
        .task(id: experience.recentInteraction) {
            withAnimation(.easeOut(duration: 0.25)) { showsControl = true }
            do { try await Task.sleep(for: .seconds(6)) } catch { return }
            guard !showsMenu else { return }
            withAnimation(.easeInOut(duration: 1.2)) { showsControl = false }
        }
        .task {
            guard !hasSeenHint else { return }
            withAnimation { showsHint = true }
            do { try await Task.sleep(for: .seconds(7)) } catch { return }
            withAnimation(.easeOut(duration: 1)) { showsHint = false }
            hasSeenHint = true
        }
    }

    private var options: some View {
        @Bindable var settings = experience
        return VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .firstTextBaseline) {
                Text(experience.profile?.name ?? "Vetro")
                    .font(.system(size: 30, weight: .regular, design: .serif))
                Spacer()
                Button("Done") { showsMenu = false }
            }
            .padding(.top, 16)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(experience.configuration.uniqueFishSpecies.map(\.title).joined(separator: " · ")).font(.headline)
                    Text(experience.isFeeding ? "Following the food" : (experience.profile?.petSnapshot(at: .now).statusLine ?? "A quiet little world"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Feed") { experience.onFeed?(); showsMenu = false }
                    .buttonStyle(.glass)
                    .disabled(experience.isFeeding || experience.profile?.petSnapshot(at: .now).isAlive == false)
                    .accessibilityLabel("Feed the glass fish")
            }

            Toggle("Daylight", isOn: $settings.daylight)
            Toggle("Tilt to look", isOn: $settings.tiltEnabled)
                .disabled(reduceMotion)
            Button("Fish & props", systemImage: "slider.horizontal.3") {
                if experience.profile != nil || studio.canCreateProfile { openEditorOnDismiss = true }
                else { openLibraryOnDismiss = true }
                showsMenu = false
            }
            Button("Hum a bowl", systemImage: "waveform") {
                startsLibraryWithHumming = true
                openLibraryOnDismiss = true
                showsMenu = false
            }
            HStack {
                Button("Center view") { experience.onCenter?(); showsMenu = false }
                Spacer()
                Button("My bowls") { startsLibraryWithHumming = false; openLibraryOnDismiss = true; showsMenu = false }
            }
            .padding(.top, 2)
        }
        .tint(experience.daylight ? Color(red: 0.18, green: 0.35, blue: 0.29) : Color(red: 0.70, green: 0.87, blue: 0.79))
        .padding(.horizontal, 26)
        .padding(.bottom, 24)
    }

    private func open(_ profile: BowlProfile) {
        studio.selectProfile(profile.id)
        experience.profile = profile
        experience.configuration = profile.configuration
        selectedGlassProfile = profile.id.uuidString
    }
}

#Preview { ImmersiveAquariumView() }
