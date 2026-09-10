# Flat aquarium widgets

Widgets now use a fixed, straight-on orthographic view of the selected bowl. The renderer keeps its fish, population, props, friends, wall theme, sand, and lighting, then arranges them in a shallow composition with a waterline and a thin sand base. Fish stay in profile, without perspective size changes. Small orb widgets are circular; gallery bowls and larger widgets use a rounded rectangular frame.

The widget uses the same glass meshes and materials as the app. Its snapshot camera and framing are separate from the immersive renderer, so the app retains its tilt parallax and bowl geometry. Snapshot cache v8 includes each widget format and the original vessel style. Day and evening variants are prepared for all three sizes.

## Validation

- Simulator app and widget build passed.
- Native widget checks passed: depth-independent projection, all 11 fish at each population size, every decoration/feature combination, and all six friends fit the three layouts.
- Catalog geometry and runtime Metal shader checks passed. Existing aquarium dynamics checks passed.
- All three sizes were inspected in the actual WidgetKit gallery. Small and medium widgets were installed and inspected on the Simulator Home Screen using the existing saved “My First Fish” bowl.
- Ivory, Sunset coral, and Neon Jungle mixed-population fixtures were inspected in all sizes, plus an evening render. These debug fixtures do not modify saved bowls.
- The frozen immersive regression render differs from the preceding reference in only nine pixels, by at most one channel value, confirming no visible change to the main aquarium.

`widget-preview.jpg` shows two representative renders. `widget-overview.jpg` shows all nine fixture renders. `home-screen.png` shows the installed widgets; `immersive-regression.png` records the main-view regression check. No physical device testing was performed.
