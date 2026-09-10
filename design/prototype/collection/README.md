# Glass collection — September 9, 2026

Eight new premium fish: Moon Stingray, Ribbon Eel, Pearl Seahorse, Crystal Puffer, Sunburst Butterflyfish, Mandarin Dragonet, Blue Tang, and Glass Sailfish.

The miniature submarine is a premium **friend**, following the revised brief. Its hull is 42% of the original prop's size. It cruises through the swimming corridor, follows gentle ascents and turns, pauses to hover, and spins its propeller. Pearl Shell is the new premium habitat prop.

The live bowl, editor previews, humming recipes, premium selection locks, saved configurations, and all three flat widget formats include the additions. The original bowl walls, camera controls and existing fish remain in place.

Validation:
- Simulator Debug build: app and widget succeeded. Existing app/widget version mismatch warning (1.0.1 versus 1.0) remains.
- Native Metal catalog check: all 19 fish, 7 friends, all props, finite geometry/normals/thickness, unique shader IDs and silhouettes, and food alignment from both directions at all population sizes.
- Persistence/access checks: every new fish is premium, free fallbacks are free, extra-fish slots sanitize, new friend and shell round-trip, and the old seahorse migration remains intact.
- Widget layout check: all 19 species at every population, friends and props fit small, medium and large formats.
- Companion motion check: all 24 decoration/feature combinations, rock climbing, arch passage, shrimp/submarine clearance, independent rests, smooth starts/stops, and reduced motion.
- Camera/dynamics regression check passed.
- Simulator picker: all eight new fish have Premium labels; selecting Moon Stingray opens the premium sheet without changing the selected fish. Mini Submarine appears only under Friends, opens the premium sheet when locked, and Pearl Shell appears under Habitat. No purchase was made.

Images are actual Simulator/Metal renders. `widgets/` contains all eight new fish in three widget sizes, each with the submarine and shell. `collection-preview.jpg` presents the medium-widget renders together.
