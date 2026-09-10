# Two feature pieces

September 9, 2026.

The Habitat editor now has two feature slots. Either slot can be cleared, and duplicate pieces are allowed. Item-level premium access is unchanged, so two Bubble Stones are available without an unlock. Removing a piece preserves the other selection.

Pairs share a deterministic arrangement in the Metal scene and companion surface model. Tall sculptures sit toward the back, small pieces sit to the right, and the decoration base is reduced and grouped in the foreground. Each sculpture keeps its own glass material, animation, shadow, and refraction. Lantern light pools follow their arranged positions, including a pair of lanterns. Arches retain enough width for crawling friends to pass through.

Widgets use three separated groups when a decoration and two feature pieces are present. Old single-piece saves migrate automatically; the new array is included in saved profiles, humming compositions, premium checks, detail text, and snapshot cache identities. Legacy 2D views also show both pieces.

## Validation

- Final app and widget Simulator build passed. The existing app/extension version warning remains.
- `aquarium-feature-pairs-check.swift`: all 84 unordered pairs with repetition across the four decoration bases passed footprint separation, bowl containment, resting phone-view framing, stable slot ordering, save migration, editing, premium checks, and cache identity checks.
- `aquarium-companion-check.swift`: all 112 empty, single, and paired habitat combinations passed rock contacts, arch passage, swimming clearance, resting behavior, and reduced-motion checks.
- Swimmer clearance covers the full footprint against the rendered triangles, including thin frond edges that could fall between radial samples.
- `aquarium-widget-check.swift`: all combinations fit small, medium, and large widget layouts, including circular clipping bounds.
- The full fish catalog and Metal shader check passed.
- Simulator editor testing added a second Bubble Stone, removed the first while preserving the other, added it again, and confirmed a premium item in slot two opens the premium sheet. No purchase or bowl creation was performed.
- Simulator renders reviewed a Sea Fan with Pearl Shell, Kelp with Sea Fan, and Driftwood Arch with Moon Lantern, plus actual widget exports.

Use `-AquariumFeatures seaFan,pearlShell -AquariumFreeze` for a still paired scene. `-AquariumWidgetExport` exports the paired, tall-pair, and arch-pair widget fixtures. Remove `-AquariumFreeze` for live movement.
