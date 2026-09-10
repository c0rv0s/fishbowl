import SwiftUI

/// The editor and library use the same geometry, materials, and lighting as the aquarium.
struct AquariumCatalogPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var experience: AquariumExperience
    let configuration: AquariumConfiguration
    var profile: BowlProfile?
    var animated = false
    var interactive = false
    var onMeal: (() -> Void)?
    var focusY: Float?

    init(configuration: AquariumConfiguration, profile: BowlProfile? = nil,
         animated: Bool = false, interactive: Bool = false, onMeal: (() -> Void)? = nil, focusY: Float? = nil) {
        self.configuration = configuration; self.profile = profile
        self.focusY = focusY
        self.animated = animated; self.interactive = interactive; self.onMeal = onMeal
        let experience = AquariumExperience()
        experience.configuration = configuration
        experience.profile = profile
        experience.tiltEnabled = false
        experience.previewFocusY = focusY
        experience.onMealConsumed = onMeal
        _experience = State(initialValue: experience)
    }

    var body: some View {
        ZStack {
            AquariumMetalView(experience: experience, active: animated && scenePhase == .active,
                              reduceMotion: reduceMotion, preview: true, interactive: interactive)
                .allowsHitTesting(interactive && experience.hasRenderedFrame)
                .accessibilityHidden(!experience.hasRenderedFrame)
            if !experience.hasRenderedFrame {
                AquariumPreviewPlaceholder(unavailable: experience.errorMessage != nil)
                    .transition(.opacity)
            }
        }
            .clipShape(.rect(cornerRadius: 28))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: experience.hasRenderedFrame)
            .onAppear { experience.daylight = colorScheme != .dark }
            .onChange(of: colorScheme) { experience.daylight = colorScheme != .dark }
            .onChange(of: configuration) { experience.configuration = configuration }
            .onChange(of: focusY) { experience.previewFocusY = focusY }
            .onChange(of: profile) { experience.profile = profile }
    }
}

struct AquariumPreviewPlaceholder: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var animated = true
    var unavailable = false

    private var isAnimating: Bool { animated && !unavailable && !reduceMotion && scenePhase == .active }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                colorScheme == .dark ? GlassPalette.night : GlassPalette.ivory
                LinearGradient(colors: [GlassPalette.mist.opacity(0.30), .white.opacity(0.08), GlassPalette.sea.opacity(0.16)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Ellipse()
                    .stroke(.white.opacity(colorScheme == .dark ? 0.08 : 0.35), lineWidth: 1)
                    .frame(width: geometry.size.width * 1.35, height: geometry.size.height * 1.2)
                    .rotationEffect(.degrees(-28))
                    .offset(x: -geometry.size.width * 0.25, y: geometry.size.height * 0.15)
                if !unavailable {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isAnimating)) { context in
                        let progress = isAnimating
                            ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.8) / 2.8
                            : 0.5
                        LinearGradient(colors: [.clear, .white.opacity(colorScheme == .dark ? 0.12 : 0.40), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: geometry.size.width * 0.55, height: geometry.size.height * 2)
                            .rotationEffect(.degrees(22))
                            .offset(x: geometry.size.width * (progress * 2.6 - 1.3))
                    }
                }
                VStack(spacing: 12) {
                    Image(systemName: "fish")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundStyle(GlassPalette.sea.opacity(colorScheme == .dark ? 0.65 : 0.42))
                    if unavailable {
                        Text("Preview unavailable")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(unavailable ? "Aquarium preview unavailable" : "Loading aquarium preview")
        .accessibilityIdentifier(unavailable ? "aquarium.preview.unavailable" : "aquarium.preview.loading")
    }
}
