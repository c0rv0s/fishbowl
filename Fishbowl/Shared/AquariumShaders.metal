#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

[[ stitchable ]] half4 aquariumFishGlassRefract(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float2 sceneNormal,
    float intensity
) {
    float2 safeSize = max(size, float2(1.0, 1.0));

    if (intensity <= 0.001) {
        return layer.sample(position);
    }

    float2 normal = sceneNormal;
    float normalLength = length(normal);
    if (normalLength <= 0.0001) {
        normal = float2(1.0, 0.0);
    } else {
        normal /= normalLength;
    }

    float2 tangent = float2(-normal.y, normal.x);
    float2 uv = position / safeSize;
    float2 centered = uv - 0.5;
    float normalCoord = dot(centered, normal) * 2.0;
    float tangentCoord = dot(centered, tangent) * 2.0;
    float edgeWeight = pow(clamp((normalCoord + 0.14) / 1.14, 0.0, 1.0), 1.18);
    float tangentAbs = abs(tangentCoord);
    float normalShift = edgeWeight * intensity * (0.140 + tangentAbs * tangentAbs * 0.110);
    float tangentialShift = sign(tangentCoord) * edgeWeight * intensity * pow(tangentAbs, 1.14) * 0.130;
    float innerWeight = pow(clamp((-normalCoord + 0.08) / 1.08, 0.0, 1.0), 1.24);
    float2 warped = centered
        - normal * (normalShift - innerWeight * intensity * 0.042)
        - tangent * tangentialShift;
    float2 samplePosition = (warped + 0.5) * safeSize;
    float fringeWeight = edgeWeight * edgeWeight * (0.22 + tangentAbs * 0.18);
    float2 fringeShift = normal * (0.8 + intensity * 1.9) * edgeWeight;
    half4 centerColor = layer.sample(samplePosition);
    half4 warmColor = layer.sample(samplePosition - fringeShift);
    half4 coolColor = layer.sample(samplePosition + fringeShift * 1.25);
    half4 refractedColor = centerColor;
    refractedColor.r = mix(centerColor.r, warmColor.r, half(fringeWeight));
    refractedColor.b = mix(centerColor.b, coolColor.b, half(fringeWeight));

    return refractedColor;
}
