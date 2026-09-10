# Glass Aquarium studio UI

The studio now shares the aquarium's ivory, sea-glass, and smoked-green palette. Quiet curved light traces sit behind native glass controls, serif titles, and readable system body text. Evening mode also changes live previews and cached studio stills to evening lighting.

## Screens and flow

- The aquarium menu opens Fish & props, Hum a bowl, or My bowls.
- My bowls is a scrolling collection with live aquarium windows, a visible humming entry, and native menus for sharing and deletion. Only visible, uncovered previews animate.
- Humming has an ivory glass instrument, a hold-to-record interaction, live input waveform, analysis motion, and a reveal using the actual glass renderer. VoiceOver has explicit start/finish actions. The existing audio analysis and recipe generation remain on device.
- The reveal has explicit Keep this bowl and Hum another actions. The existing Premium requirement for keeping hummed bowls is preserved.
- The editor keeps its preview and save action visible while Fish, Habitat, Friends, and Details organize the options. Habitat and companion editing frame the lower aquarium. Widget previews fit the available space. The obsolete vessel selector is removed because the approved immersive shell is shared; saved vessel values are retained.
- Premium uses the same materials and artwork, a concise list of benefits, native close/restore controls, and an inline purchase error. Purchases and entitlements were not changed during UI verification.
- The widget's uncached state uses the new neutral styling and asks the user to open their aquarium, instead of showing the old vector fish. Cached widget artwork is a still. An actual Home Screen widget was not installed for this pass.

## Verification

The app and extension build passed on the iPhone 17 Simulator. Native camera/dynamics checks passed, including new square/wide preview and habitat-framing assertions. The existing app/extension version mismatch warning remains.

Live UI checks covered aquarium-to-humming navigation, choosing manual creation from humming, selecting a fish and population, switching to Details, saving a decorative bowl, opening it in the aquarium, opening/dismissing Premium, and deleting the temporary test bowl. The original saved bowl was retained. Humming was also checked at the Simulator’s extra-extra-extra-large text size; the original large setting was restored. Permission-state content can scroll when it needs more room.

Humming listening, analysis, reveal, and denied-permission layouts were checked with DEBUG visual fixtures. These fixtures do not open the microphone or automatically save profiles. Live microphone input and physical-device performance were not measured.

## Captures

PNG files in this directory are actual Simulator renders. `studio-overview.jpg` assembles selected screens without changing their content.

DEBUG launch flags:

- `-AquariumLibraryUI`: open the collection.
- `-AquariumHumUI`: open humming.
- `-HumPreviewState recording|analyzing|preview|denied`: select a humming visual fixture.
- `-AquariumEditorUI`: open an unsaved editor draft.
- `-AquariumEditorSection Fish|Habitat|Friends|Details`: select an editor section.
- `-AquariumPremiumUI`: open Premium without a purchase.
- `-AquariumEvening`: combine with a route to check evening styling.

Normal launches use live controls and the saved aquarium selection.
