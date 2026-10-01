#pragma language glsl3
// Overcast nuclear-winter sky: gradient, weak orange sun glow and drifting cloud bands.
varying vec3 vDir;
#ifdef VERTEX
uniform mat4 viewProj;
uniform vec3 camPos;
uniform float flipY;
vec4 position(mat4 tp, vec4 vp) {
    vDir = vp.xyz;
    vec4 clip = viewProj * vec4(camPos + vp.xyz * 300.0, 1.0);
    clip.y *= flipY;
    clip.z = clip.w * 0.9999;
    return clip;
}
#endif
#ifdef PIXEL
uniform vec3 horizonColor;
uniform vec3 zenithColor;
uniform vec3 sunDirSky;
uniform vec3 sunGlow;
uniform float time;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec3 d = normalize(vDir);
    float h = clamp(d.y, -0.2, 1.0);
    vec3 c = mix(horizonColor, zenithColor, smoothstep(0.0, 0.6, h));
    float s = max(dot(d, sunDirSky), 0.0);
    c += sunGlow * (pow(s, 64.0) * 1.6 + pow(s, 6.0) * 0.35) * smoothstep(-0.1, 0.05, d.y);
    vec2 cp = d.xz / max(d.y + 0.15, 0.05);
    float cl = noise(cp * 1.2 + vec2(time * 0.01, 0.0)) * 0.6 + noise(cp * 3.1 - vec2(0.0, time * 0.02)) * 0.4;
    c = mix(c, c * 0.7, smoothstep(0.45, 0.8, cl) * smoothstep(0.0, 0.3, d.y));
    c = mix(c, horizonColor, smoothstep(0.08, -0.05, d.y));
    return vec4(c, 1.0);
}
#endif
