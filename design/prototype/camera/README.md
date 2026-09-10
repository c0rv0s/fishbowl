# Wider interior views

The immersive camera now travels about 2.4 times farther sideways on a tall phone and 40 percent farther vertically. Tilt and drag retain their existing sensitivity and smoothing. The front viewing window stays fixed, and the neutral view is unchanged.

The side limit is calculated from the bottom viewing rays and the bowl's sand cross-section, leaving a small margin inside the sand mesh. This allows more side travel while keeping the bottom glass lip out of view. The limit adapts to screen width and vertical position. Combined horizontal and vertical movement uses a circular travel envelope for softer diagonal limits.

Flat widget cameras and studio preview cameras are unchanged.

## Validation

- App and widget Simulator build passed.
- Native dynamics checks passed, including wider horizontal/vertical travel, fixed front-window projection, Reduce Motion, equal pitch/yaw input sensitivity, and frame-rate independence.
- Bottom-edge rays remain inside the bowl across a 21 by 21 grid of camera offsets for three phone aspect ratios.
- Widget layout checks passed for every fish, prop, friend, and widget size.
- Actual Simulator captures show left, right, up, down, and downward diagonal limits. The normal interactive app was restored afterward. Physical phone tilt was not tested.

The directional debug flags can now be combined to capture diagonal views.
