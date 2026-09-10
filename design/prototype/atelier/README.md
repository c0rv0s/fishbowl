# Icon-inspired live glass

The app icon is the material and lighting reference for this revision. The live scene now uses deeper teal Lagoon walls with warm studio lighting, an amber fish with clear champagne fins, and stronger reflections across the existing glass props. The unsaved demonstration starts in Lagoon. Saved bowls retain their chosen theme, and Ivory remains available.

The amber fish has fuller rounded tail lobes, folded three-dimensional fins, and fine amber glass rims. Its body is slightly deeper and has subtle variations in its surface. Its display scale leaves room for the wider tail. The shared fish catalog also gains folded fins and the revised glass shader.

Glass samples the scene through a refracted ray, with color absorption based on thickness, a curved rear-interface approximation for fish, visible pearl bands inside the amber body, and warm/cool studio reflections. The renderer resolves the rocks, plants, and friends before drawing the fish, so fish can refract the live habitat. Bubbles then refract the completed scene. Each pass reads a separate resolved texture; the single-sample path copies its backdrop before drawing.

This is procedural real-time Metal rendering with approximated internal reflection, rather than a full path-traced reconstruction of the generated icon. There are no new baked scene images. Camera parallax, feeding, companion movement, the bowl geometry, and the flush sand boundary remain in use. Widget cameras retain their flat projection and get the updated materials through snapshot cache v10.

## Validation

- Debug app and widget Simulator build passed. The existing app/extension version warning is unchanged.
- Native Metal compilation and catalog checks passed for all 11 fish, six friends, every prop, material thickness/normals, feeding alignment, theme persistence, and legacy save loading.
- Dynamics checks passed for camera limits, flush sand coverage, feeding, frame-rate independence, and Reduce Motion.
- Widget checks passed for all catalog elements and three layouts. Exported small, medium, and large widgets were visually inspected with the new materials.
- Actual Simulator views checked daylight, evening, Ivory, the wider side view, a mixed-species coral habitat, and both four-sample and single-sample render paths.
- Live Simulator interaction confirmed tap-to-feed and diagonal dragging. The app was left running with normal animation.
- No physical-device performance or thermal measurement was performed. The extra habitat resolve adds GPU bandwidth, while reusing the existing color textures.

`before-after.jpg` compares unretouched Simulator screenshots. `visual-checks.jpg` collects the runtime checks. Full screenshots and widget PNGs are alongside these files.
