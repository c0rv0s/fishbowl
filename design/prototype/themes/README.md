# Bowl themes

Actual iPhone 17 Simulator renders, captured September 9, 2026.

Choose a theme in **Fish & props → Habitat → Bowl theme**. The three solid choices are Ivory, Blue, and Red. The five palettes are Neon Jungle, Lagoon, Rose Quartz, Sunset, and Midnight.

- Neon Jungle uses green walls with tapered, irregular pink tiger stripes.
- Sunset uses orange walls with two broad yellow spots with soft gradient edges.
- Theme colors coordinate the real-time lighting, glass highlights, reflections, bubbles, and edge optics. Patterns are attached to the curved walls, so they remain in place when the camera moves.
- Bowl geometry, viewing cut, and parallax behavior are unchanged. Theme changes blend without rebuilding the fish and props or resetting their movement.
- The selected theme is saved per bowl and retained in widget snapshots. Older saves default to Ivory. All themes are available without Premium.

`themes-overview.jpg` compares all eight themes. `pattern-themes.jpg` shows the final Neon Jungle and Sunset designs. Individual PNGs are full-resolution Simulator screenshots; `neonJungle-evening.png` checks evening lighting. Screenshots use the existing debug freeze option for consistent framing.

## Validation

- Debug iOS Simulator app and widget extension build passed.
- Native catalog check passed, including Metal shader compilation, all eight theme save round trips, legacy/unknown-theme fallback, free-tier retention, distinct encoded theme configurations, and finite palette data.
- Simulator UI: selected Neon Jungle, checked the medium widget preview, created a temporary bowl, reopened it with Neon Jungle still selected, changed it to Sunset, and saved again. Read-back of the shared saved-profile data confirmed both changes.
- Removed only the temporary test bowl and verified the original My First Fish bowl remained.
- Inspected all eight daylight renders and the final Neon Jungle evening render. No physical-device validation was performed.

The build retains an existing app/widget version warning; project version settings were not changed for themes.
