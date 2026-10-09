#pragma language glsl3
// Final pass: low-res pixel snapping, chromatic aberration, the PlayStation's 4x4 ordered
// dither into 15-bit colour, film grain, vignette, plus gameplay overlays (frost, radiation, optics).
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
uniform float crt;            // 0..1 CRT tube: curvature, scanlines, aperture grille, glow
uniform float vhs;            // 0..1 tape: line jitter and colour bleed

// the PS1 GPU's dither table: offsets added to the 8-bit colour before it is cut to 5 bits
float psxDither(vec2 p) {
    int x = int(mod(p.x, 4.0)), y = int(mod(p.y, 4.0));
    int i = x + y * 4;
    float m[16] = float[16](-4.0, 0.0, -3.0, 1.0, 2.0, -2.0, 3.0, -1.0, -3.0, 1.0, -4.0, 0.0, 3.0, -1.0, 2.0, -2.0);
    return m[i];
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
    // screen filters after "Retro Screen FX" by heyheythere (CC BY 4.0), see assets/psx/CREDITS.md
    float tube = 1.0;
    if (crt > 0.0 && optic < 0.5) {
        vec2 cc = uv * 2.0 - 1.0;
        cc += cc * (cc.yx * cc.yx) * 0.055 * crt;
        p = cc * 0.5 + 0.5;
        vec2 q = abs(cc) - 0.94;
        tube = (1.0 - smoothstep(0.0, 0.012, length(max(q, 0.0)) - 0.06)) * step(abs(cc.x), 1.0) * step(abs(cc.y), 1.0);
    }
    if (vhs > 0.0) {
        float line = floor(p.y * lowRes.y);
        float frame = floor(time * 30.0);
        p.x += (fract(sin(dot(vec2(line, frame), vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * vhs * 0.004;
        float band = p.y - fract(time * 0.12) * 1.3 + 0.15;
        p.x += smoothstep(0.08, 0.0, abs(band)) * vhs * 0.012 * sin(line * 1.7 + frame);
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
    if (vhs > 0.0) {
        // chroma smeared to the right, luma kept
        vec3 smear = vec3(0.0);
        for (int i = 1; i <= 4; i++) smear += Texel(tex, sp - vec2(float(i) * 1.5, 0.0) / lowRes).rgb;
        smear *= 0.25;
        float y = dot(c, vec3(0.299, 0.587, 0.114));
        c = mix(c, vec3(y) + (smear - dot(smear, vec3(0.299, 0.587, 0.114))), vhs * 0.8);
    }
    if (crt > 0.0) {
        // phosphor glow from bright neighbours
        vec3 glow = vec3(0.0);
        for (int i = 0; i < 6; i++) {
            float a = float(i) * 1.0472;
            glow += Texel(tex, sp + vec2(cos(a), sin(a)) * 2.5 / lowRes).rgb;
        }
        c += max(glow / 6.0 - 0.5, 0.0) * crt * 0.9;
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
    // PS1 dither + colour depth (colorLevels steps per channel: 32 = the console's 15-bit colour)
    float stepSize = 256.0 / colorLevels;
    c = floor(clamp(c * 255.0 + psxDither(pix) * stepSize / 8.0, 0.0, 255.0) / stepSize) / (colorLevels - 1.0);
    if (crt > 0.0) {
        float sl = 0.5 + 0.5 * cos(p.y * lowRes.y * 6.2831853);
        c *= (1.0 - crt * (1.0 - sl) * 0.42) * (1.0 + crt * 0.2);
        float stripe = mod(floor(sc.x), 3.0);
        vec3 grille = vec3(float(stripe == 0.0), float(stripe == 1.0), float(stripe == 2.0));
        c *= mix(vec3(1.0), grille * 2.1 + 0.3, crt * 0.16);
        c *= tube;
    }
    c *= mask;
    return vec4(c, 1.0);
}
