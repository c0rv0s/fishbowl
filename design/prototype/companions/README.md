# Companion movement

[Normal-speed Simulator preview](friends-normal-speed.mp4). [Slow companions route audit at 10x speed](slow-friends-audit-10x.mp4).

The snail starts attached to the visible curved left wall. It follows the existing bowl ellipsoid and faces inward. Its spiral is visible from either side.

Shrimp swim a three-dimensional circuit, rising over nearby sculptures with room for their antennae and tail. Crabs travel sideways with alternating leg strokes. Both sea slugs and the cucumber crawl more slowly, with a small traveling body contraction.

Each species has independent movement and rest periods. Raised-cosine acceleration eases into and out of a trip. At rest, crab feet settle, snails and crawlers stay put, and shrimp retain a small hover and paddle movement. Antennae and claws have subtle idle movement. Reduce Motion slows travel and articulation.

The route planner reads the actual glass prop triangles. It includes the curved flanks and tops of rocks, joins them to the sand where they meet, and leaves room beneath the arch. Thin plants, lanterns, and arch legs are obstacles. Feet can bridge a small gap between neighboring stones. Prop changes rebuild the route; visible previews share a bounded habitat cache. No navigation searches run during a frame. Surface orientation and movement also drive the live shadow pass.

The bowl walls, viewing cut, parallax, fish behavior, and saved configuration format are unchanged. Widget stills use the new companion starting poses through the v5 snapshot cache.

## Validation

- App and widget Simulator build passed.
- Native Metal compilation and catalog geometry checks passed for all fish, companions, and props, including crab/shrimp articulation groups.
- The companion check passed all 20 decoration/feature combinations, rock crest traversal, arch passage, swimming clearance, snail attachment and visibility, independent rests, eased starts/stops, orientation, reduced motion, and 30/60 Hz sampling.
- Existing camera/parallax, feeding, and finite geometry checks passed.
- Simulator motion captures checked common companions and the three slower crawlers. Accelerated captures are for reviewing long routes; the user preview runs at normal speed.
- An optimized native Mac measurement built the rock habitats in 0.15–0.18 seconds and sampled 30,000 companion poses in about 4 milliseconds. This measures route planning and pose sampling, not device GPU frame rate.

Run the companion check from the repository root:

```sh
xcrun swiftc -g -module-cache-path /private/tmp/fishbowl-swift-module-cache \
  Fishbowl/Shared/AquariumConfiguration.swift \
  Fishbowl/App/Immersive/AquariumDynamics.swift \
  Fishbowl/App/Immersive/AquariumGeometry.swift \
  Fishbowl/App/Immersive/AquariumCatalog.swift \
  Fishbowl/App/Immersive/AquariumCompanionMotion.swift \
  scripts/qa/aquarium-companion-check.swift \
  -o /private/tmp/fishbowl-companion-check
/private/tmp/fishbowl-companion-check
```

## Simulator fixtures

Debug-only launch arguments affect the unsaved live scene:

- `-AquariumFriends snail,shrimp,crab` or `seaCucumber,nudibranchFlame,nudibranchRibbon`
- `-AquariumFeature driftwoodArch`
- `-AquariumCompanionTime 85` advances only the companion timeline.
- `-AquariumCompanionRate 10` accelerates only the companion timeline for route audits. Default is 1.
- `-AquariumFreeze` freezes a deterministic pose, including articulation.

These do not alter saved bowls, microphone behavior, or purchase state.
