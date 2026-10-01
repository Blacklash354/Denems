#pragma language glsl3
// GPU snowfall: a static cloud of quads wrapped around the camera in the vertex shader.
varying float vAlpha;
varying vec2 vUV;
#ifdef VERTEX
uniform mat4 viewProj;
uniform vec3 camPos;
uniform vec3 camRight;
uniform vec3 camUp;
uniform float time;
uniform vec3 wind;      // xz drift and fall speed in y
uniform float boxSize;
uniform float density;  // 0..1 portion of flakes visible
uniform float flipY;
uniform float shelter;  // inside the tank: flakes hidden near camera
attribute vec4 FlakeData; // xyz random position, w random seed
vec4 position(mat4 tp, vec4 vp) {
    vec3 p = FlakeData.xyz * boxSize;
    float seed = FlakeData.w;
    p += vec3(wind.x, -wind.y * (0.7 + seed * 0.6), wind.z) * time;
    p.x += sin(time * (1.0 + seed) + seed * 40.0) * 0.4;
    p.z += cos(time * (0.8 + seed) + seed * 23.0) * 0.4;
    vec3 rel = mod(p - camPos + boxSize * 0.5, boxSize) - boxSize * 0.5;
    vec3 wpos = camPos + rel;
    float dist = length(rel);
    float size = 0.035 + seed * 0.03;
    vec3 streak = normalize(vec3(wind.x, -wind.y, wind.z)) * min(length(wind) * 0.012, 0.25);
    vec2 corner = vp.xy; // -1..1
    vec3 offs = camRight * corner.x * size + camUp * corner.y * size + streak * corner.y;
    wpos += offs;
    vUV = corner * 0.5 + 0.5;
    float visible = step(seed, density);
    vAlpha = visible * smoothstep(boxSize * 0.5, boxSize * 0.2, dist) * smoothstep(0.2, 1.0, dist) * (1.0 - shelter * step(dist, 2.5));
    vec4 clip = viewProj * vec4(wpos, 1.0);
    clip.y *= flipY;
    return clip;
}
#endif
#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec2 d = vUV - 0.5;
    float a = (1.0 - smoothstep(0.2, 0.5, length(d))) * vAlpha;
    if (a < 0.05) discard;
    return vec4(color.rgb, a * color.a);
}
#endif
