# Aquarium performance fixes

September 9, 2026. Verified on an Apple M3 Pro and the iPhone 17 / iOS 26.5 Simulator.

The four reviewed issues are addressed:

- Geometry, GPU mesh construction, shader compilation, and companion route preparation run on a resource actor. Immutable meshes and pipelines are shared. Habitat geometry has a three-entry cache; twelve cached routes retain only finished paths. Scene changes install completed resources together and reject obsolete requests.
- Widget images use one serialized, reusable renderer. GPU completion is awaited asynchronously; image readback copying, PNG encoding, and disk access run off the main actor. Owned offscreen textures handle size changes without display drawables. Duplicate requests reuse cached results; idle snapshot resources are released after three seconds.
- The library uses a lazy stack and creates Metal previews only for visible rows. Offscreen previews are dismantled.
- The final screen pass uses one sample and no depth attachment. The actual 3D scene retains its original 4x MSAA, lighting, refraction, and geometry.

## Validation

Debug and Release app/widget builds passed. The project's existing app/extension version mismatch is unchanged.

- Optimized host check: cold preparation took 651.6 ms off the main actor while 105 UI heartbeats continued; largest gap was 6.8 ms. Cached catalog lookup took 0.060 ms. These are local observations, not device frame-time measurements.
- Simulator regressions passed rapid A/B/A layout changes, identical-art profile switching, mixed day/night/baby/empty snapshots, correct image dimensions, renderer reuse, and presentation attachment checks. During fresh snapshot generation, the largest UI heartbeat gap was 13.4 ms.
- All 112 existing companion habitat checks passed, including climbing, arch passage, resting, orientation, reduced motion, and 30/60 fps simulation consistency.
- The 12-bowl library fixture visited every row and returned to the top: at most two previews after layout settled, four briefly during replacement, and one at the end. Fixtures never change saved bowls. Opening, changing fish in, and closing the editor restored the library preview. The share sheet opened successfully.
- The frozen live scene and all three fresh seahorse widget sizes matched the pre-change PNG pixels exactly. See `render-comparison.txt` and the adjacent images.

The Simulator was restored to the normal animated seahorse scene. No physical-device FPS, battery, or thermal measurements were taken.

## Repeating the regressions

Compile `scripts/qa/aquarium-performance-check.swift` with Swift 6, optimization, `DEBUG`, and its shared geometry/dynamics/catalog/motion/shader/resource-store dependencies. It verifies actor responsiveness, cache identity, cancellation, and route-free widget preparation.

Launch a Debug build with `-AquariumPerformanceCheck -AquariumRefreshSnapshots` to write the snapshot and scene-switch checks under `Documents/PerformanceDiagnostics`. Launch with `-AquariumLibraryStress` to scroll the ephemeral twelve-bowl fixture and write `Documents/library-preview-counts.txt`. Both diagnostic paths are excluded from Release builds.
