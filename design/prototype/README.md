# Vetro aquarium prototype

A calm, animated aquarium inspired by the user's Murano glass references in `../reference/`. The full fish and prop catalog uses sculpted glass geometry and procedural materials. The current default pairs an amber-and-pearl fish with deeper teal Lagoon walls, three grouped cobalt-and-gold stones, broad rounded fronds, and soft ivory sand. See `atelier/README.md` for the icon-inspired glass and lighting revision. Fine pointed reeds and scattered glass chips were removed following the user's direction.

## Controls

- Tilt or drag left/right and up/down to look around. Roughly 22 degrees of tilt reaches the viewing limit. The wider camera range reveals more of the sides and adapts to the bowl's sand boundary; see `camera/README.md`.
- Tap the water to feed and reveal the glass options button.
- Options include daylight/evening lighting, tilt, recentering, **Fish & props**, and **My bowls**.
- Fish & props opens the bowl editor with a live glass preview. Saving opens that aquarium; editing a saved bowl updates it in place. My bowls previews saved designs with the same renderer and provides an Open aquarium button.
- Center view recalibrates the resting device orientation. Reduce Motion disables camera parallax. Rendering and motion sensing pause while the aquarium is inactive.

## Rendering and scope

The rounded bowl shell, water shaders, and fixed viewing window are preserved from the approved clear-water version. The sand meets the screen edge, with the front glass lip outside the visible frame. A final optical pass bends the live image near the screen edges, adds subtle color dispersion and moving reflections, and leaves the center clear. Reflections fade before the bottom edge to preserve the flush view.

The interior is authored as three-dimensional meshes and procedural Metal materials. The fish has a tapered spindle body, low swept fins, a curved tail with rounded lobes, and small inset eyes on both sides. Finer pearl bands follow the body through its amber glass. Its fins move while it swims. The glass fronds sway gently. The stones have smooth irregular forms with flowing cobalt, aqua, and gold inclusions.

A separate render pass captures the live bowl and floor for refraction through the colored glass. View-dependent highlights, color absorption, translucent fronds and fins, soft shadows, and colored light pools support the glass appearance. HDR scene buffers preserve bright reflections for a soft bloom before display.

Twenty-two small bubbles rise at different speeds from three areas of the sand, drift gently, and fade at the water surface. They sample the completed sculpture image, so the fish, plants, and stones are visible through their diverging lenses. The retained depth buffer correctly hides bubbles behind objects. Colored glass still samples the bowl and floor, and bubbles do not refract one another. These are art-directed real-time approximations, not a full optical or fluid simulation.

No generated photo texture is used by the current renderer. The earlier generated betta, stone, and sand assets and their prompts remain as records of the prior direction in `../assets/prompts.md`.

## Converted catalog

All eleven existing species have distinct geometry, fins, and glass color treatments. Royal Betta has cobalt and cyan fans; Moon Koi has pearl, coral, and dark inclusions; Sunset Rasbora retains the approved amber-and-pearl design; Glass Goldfish uses champagne glass and a flowing tail; Neon Guppy uses turquoise and rose; Ember Tetra uses ember and gold; Opal Angelfish has tall fins and blue bands; Leopard Shark has a swept silhouette and smoked spotted glass; Velvet Discus has an amethyst disc and gold swirls; Silver Arowana has an elongated silver-aqua body; Humpback Whale has cobalt glass, an opal belly, long flippers, and horizontal flukes.

All six companions are glass sculptures: snail, shrimp, crab, sea cucumber, flame nudibranch, and ribbon nudibranch. Decorations include grouped river stones, grouped glass pearls, and a rounded coral garden. Feature pieces include the low bubble stone, amber driftwood arch, moon lantern, and broad kelp fronds. Every substrate is a smooth sand treatment, including Moon Sand, whose stored enum value remains moonGravel. The bowl shell and edge optics remain unchanged.

Saved configurations, mixed species, population counts, and existing premium gates are preserved. Saved pet hunger, feeding, death, and baby state are connected to the new renderer. Only the main fish follows food; additional fish swim independently. The unsaved demonstration remains transient.

App previews and share cards use stills from the same Metal renderer. The app also prepares square and wide images in the shared app-group cache for widgets. Widgets read these cached stills, with a neutral Open your aquarium placeholder until the app has prepared the relevant image. Widget images are not live animations. The immersive view uses the approved rounded shell for all existing vessel choices; vessel data is retained. The editor no longer offers vessel choices that do not affect this shell.

## Validation — 2026-09-09

- The current Simulator build passed with Xcode 26.6 and the Metal shaders compiled at runtime.
- Native checks passed for horizontal and vertical parallax, the fixed front window, pitch/yaw mapping, equal drag sensitivity, feeding/cooldown, Reduce Motion, valid mesh geometry, glass surface normals, and flush bottom coverage through the phone tilt range.
- The bowl dimensions, shell-generation code, and water/glass-wall shader functions were compared directly against the preceding version and preserved.
- `murano-center.png` records the latest composition, `murano-right.png` shows a side view, and `murano-preview.mp4` is an 18-second recording of the live aquarium. The older `rounded-*` and `flush-*` screenshots record the preceding naturalistic aquarium.
- Simulator interaction checks confirmed feeding and recovery, diagonal parallax, and daylight/evening lighting with readable menu controls.
- The liquid-effects update passed the native checks and Simulator build. Visual checks covered daylight, evening, side parallax, and both the four-sample and single-sample render paths. `liquid-center.png`, `liquid-right.png`, and `liquid-evening.png` show the update; `liquid-preview.mp4` records live rising bubbles, feeding, and parallax.
- The subsequent fish refinement passed the native geometry/dynamics checks and Simulator build. `sleek-fish.png` and `sleek-fish-right.png` show the current silhouette; live inspection also covered both swimming directions after feeding. The earlier videos show the previous fish shape.
- The full catalog conversion passed the Simulator build, native dynamics checks, and a new catalog check that compiles the Metal shader library and validates every fish, companion, decoration, and feature mesh. It checks finite geometry, indices, normals, distinct species silhouettes, companion ground contact, scaled feeding alignment, and a mixed-species configuration round trip.
- Simulator checks covered every catalog asset, creating and reopening a saved bowl, editing that bowl without adding another, and the wide still preview. Test bowls were removed afterward. Shared app-group still files were verified; an actual Home Screen widget was not added or visually tested.
- `catalog/` contains runtime captures of every fish and companion, selected props, and a mixed-species aquarium. The contact sheets are assembled from those captures.
- The local build retains an existing app/extension version mismatch warning (app 1.0.1, extension 1.0); those version settings were left as found.
- This iteration is being checked in Simulator only, as requested. Physical tilt feel, sustained phone performance, battery use, and thermal behavior remain unmeasured.

Run the native checks from the repository root:

```sh
xcrun swiftc -module-cache-path /private/tmp/fishbowl-swift-module-cache \
  Fishbowl/App/Immersive/AquariumDynamics.swift \
  Fishbowl/App/Immersive/AquariumGeometry.swift \
  scripts/qa/aquarium-dynamics-check.swift \
  -o /private/tmp/fishbowl-dynamics-check
/private/tmp/fishbowl-dynamics-check

xcrun swiftc -module-cache-path /private/tmp/fishbowl-swift-module-cache \
  Fishbowl/Shared/AquariumConfiguration.swift \
  Fishbowl/App/Immersive/AquariumDynamics.swift \
  Fishbowl/App/Immersive/AquariumGeometry.swift \
  Fishbowl/App/Immersive/AquariumCatalog.swift \
  Fishbowl/App/Immersive/AquariumDepthShaders.swift \
  scripts/qa/aquarium-catalog-check.swift \
  -o /private/tmp/fishbowl-catalog-check
/private/tmp/fishbowl-catalog-check
```

DEBUG launch flags `-AquariumLookLeft`, `-AquariumLookRight`, `-AquariumLookUp`, and `-AquariumLookDown` hold a camera offset. Combine one with `-AquariumFreeze` for comparable screenshots. `-AquariumEvening` starts in evening light, and `-AquariumNoMSAA` exercises the single-sample fallback. Normal launches use live controls and the device-supported sample count.

Catalog capture flags accept enum raw values: `-AquariumSpecies`, `-AquariumCompanion`, `-AquariumDecoration`, `-AquariumFeature`, and `-AquariumSubstrate`. `-AquariumTrio` adds Moon Koi and Opal Angelfish to the selected primary species. Start without an active saved bowl when using these overrides. The catalog check requires access to a Metal device; a filesystem-only sandbox cannot run that portion.

The studio UI was subsequently updated to match the aquarium. See `ui/README.md` for screens, navigation checks, and current captures.
