# Sea garden additions

September 9, 2026. Procedural glass sculptures rendered by the app's Metal renderer.

- **Leafy Sea Dragon**: premium fish with a curved jade body, narrow snout, trailing tail, and eleven translucent champagne-edged leaves. Leaf flutter fades to zero at each joint so the leaves stay attached during swimming.
- **Sea Urchin**: premium friend with an amethyst core, 74 short rounded spines, and ten tiny tube feet. It follows the existing surface routes over rocks and through arches, with an eased 25-second activity / 20-second rest rhythm and subtle foot and spine movement.
- **Sea Fan**: premium habitat feature with a seafoam stem, broad curled fan, and translucent lilac rim.

All three are included in editor choices, appropriate humming recipes, save/load data, premium fallback handling, and widget configuration. Existing bowl walls and framing are unchanged.

## Validation

- App and widget Simulator build passed. One existing warning remains: app version 1.0.1 and extension version 1.0 differ.
- Catalog check passed for all 20 fish, eight friends, all props, valid geometry and Metal shaders, feeding alignment, premium gates, and save round trips.
- Movement check passed across all 28 habitat combinations, including rock contacts, arch passage, individual rests, reduced motion, and 30/60 fps.
- Widget geometry check passed for all fish at all populations, all props, and all friends in the three widget layouts.
- Simulator editor tap-through verified Leafy Sea Dragon, Sea Urchin, and Sea Fan labels and their premium sheets. No purchase or saved-bowl creation was performed.
- Actual day/evening renders and small/medium/large widget exports were visually reviewed on iPhone 17 Simulator, iOS 26.5.

## Captures

- `day.png`: straight-on aquarium with the three additions and the existing mini submarine.
- `evening.png`: evening lighting, with the urchin at 90 seconds along its surface route.
- `sea-garden-widgetSmall.png`, `sea-garden-widgetMedium.png`, `sea-garden-widgetLarge.png`: actual orthographic widget renders.
- `catalog-check.log`, `widget-check.log`, `motion-check.log`: local validation output.

Reproduce the still scene using `-AquariumSpecies leafySeaDragon -AquariumFriends seaUrchin,miniSubmarine -AquariumFeature seaFan -AquariumFreeze`. Add `-AquariumWidgetExport` to write the diagnostic widgets, or `-AquariumEvening -AquariumCompanionTime 90` for the evening pose. Omit `-AquariumFreeze` for live motion.
