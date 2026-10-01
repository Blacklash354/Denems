#pragma language glsl3
// Camera-facing particles (smoke, sparks, flashes) with fog.
varying float vFog;
uniform vec3 fogColor;
#ifdef VERTEX
uniform mat4 viewProj;
uniform vec3 camPos;
uniform vec2 fogRange;
uniform float flipY;
vec4 position(mat4 tp, vec4 vp) {
    vFog = clamp((length(vp.xyz - camPos) - fogRange.x) / (fogRange.y - fogRange.x), 0.0, 1.0);
    vec4 clip = viewProj * vec4(vp.xyz, 1.0);
    clip.y *= flipY;
    return clip;
}
#endif
#ifdef PIXEL
uniform float additive;
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec4 t = Texel(tex, tc) * color;
    if (additive > 0.5) return vec4(t.rgb * t.a * (1.0 - vFog), 1.0);
    return vec4(mix(t.rgb, fogColor, vFog * 0.8), t.a);
}
#endif
