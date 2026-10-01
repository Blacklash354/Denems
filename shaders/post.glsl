#pragma language glsl3
// Final pass: low-res pixel snapping, chromatic aberration, ordered dithering with
// color banding, film grain, vignette, plus gameplay overlays (frost, radiation, optics).
uniform vec2 lowRes;
uniform float time;
uniform float grain;
uniform float aberration;
uniform float colorLevels;
uniform vec4 screenTint;     // rgb, amount
uniform float frost;
uniform float radiation;
uniform float optic;         // 0 none, 1 cannon optic, 2 MG sight
uniform float aspect;
uniform float blur;          // damage/flash blur
uniform float brightness;

float bayer(vec2 p) {
    int x = int(mod(p.x, 4.0)), y = int(mod(p.y, 4.0));
    int i = x + y * 4;
    float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
    return m[i] / 16.0 - 0.5;
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + time * 0.0) * 43758.5453); }

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 p = uv;
    float mask = 1.0;
    if (optic > 0.5) {
        vec2 d = (uv - 0.5) * vec2(aspect, 1.0);
        float r = length(d);
        float R = optic > 1.5 ? 0.36 : 0.46;
        // glass barrel distortion
        vec2 dd = d * (1.0 + 0.18 * r * r / (R * R));
        p = 0.5 + dd / vec2(aspect, 1.0);
        mask = 1.0 - smoothstep(R - 0.02, R, r);
    }
    vec2 pix = floor(p * lowRes);
    vec2 sp = (pix + 0.5) / lowRes;
    vec2 off = (sp - 0.5) * aberration / lowRes * 2.0;
    vec3 c;
    c.r = Texel(tex, sp + off).r;
    c.g = Texel(tex, sp).g;
    c.b = Texel(tex, sp - off).b;
    if (blur > 0.0) {
        vec3 b = Texel(tex, sp + vec2(1.5, 0.0) / lowRes).rgb + Texel(tex, sp - vec2(1.5, 0.0) / lowRes).rgb
               + Texel(tex, sp + vec2(0.0, 1.5) / lowRes).rgb + Texel(tex, sp - vec2(0.0, 1.5) / lowRes).rgb;
        c = mix(c, b * 0.25, blur);
    }
    c *= brightness;
    // vignette
    vec2 v = uv - 0.5;
    c *= 1.0 - dot(v, v) * 0.9;
    // frost creeping from the edges
    if (frost > 0.0) {
        float e = max(abs(v.x) * 2.0, abs(v.y) * 2.0);
        float n = hash(floor(uv * lowRes * 0.5));
        float f = smoothstep(1.0 - frost * 0.6, 1.0, e + n * 0.15);
        c = mix(c, vec3(0.75, 0.85, 0.95), f * 0.7);
        c = mix(c, vec3(dot(c, vec3(0.33))), frost * 0.35);
    }
    // radiation sparkle noise
    if (radiation > 0.0) {
        float n = fract(sin(dot(pix + floor(time * 30.0) * 17.0, vec2(12.9898, 78.233))) * 43758.5453);
        c += vec3(0.5, 0.7, 0.4) * step(1.0 - radiation * 0.006, n);
        c = mix(c, c * vec3(0.9, 1.05, 0.85), radiation * 0.5);
    }
    c = mix(c, screenTint.rgb, screenTint.a);
    // grain
    float g = fract(sin(dot(pix + fract(time * 7.0) * 113.0, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
    c += g * grain;
    // ordered dither + color banding
    float levels = colorLevels;
    c = floor(c * levels + bayer(pix) + 0.5) / levels;
    c *= mask;
    return vec4(c, 1.0);
}
