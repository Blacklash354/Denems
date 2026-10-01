#pragma language glsl3
// PSX-style world shader: Gouraud (per-vertex) lighting, vertex snapping,
// partially affine texture mapping and per-vertex distance fog.

varying vec4 vLight;
varying float vFog;
#ifdef VERTEX
noperspective out vec3 vAff;
#else
noperspective in vec3 vAff;
#endif

uniform vec3 fogColor;

#ifdef VERTEX
uniform mat4 viewProj;
uniform mat4 model;
uniform vec3 camPos;
uniform vec3 sunDir;
uniform vec3 sunColor;
uniform vec3 ambient;
uniform vec3 interiorAmbient;
uniform float uInterior;
uniform float uEmissive;
uniform vec4 uTint;
uniform vec2 uvOffset;
uniform vec2 fogRange;
uniform float fogMax;
uniform vec2 snapRes;
uniform float affine;
uniform vec4 lights[10];
uniform vec4 lightCols[10];
uniform int numLights;
uniform vec4 spotPos;   // xyz, intensity
uniform vec4 spotDir;   // xyz, cos(cutoff)
uniform float flipY;
attribute vec3 VertexNormal;

vec4 position(mat4 transformProjection, vec4 vertexPosition) {
    vec4 wp = model * vertexPosition;
    vec3 n = normalize(mat3(model) * VertexNormal);

    float ndl = max(dot(n, sunDir), 0.0);
    float sky = 0.75 + 0.25 * n.y;
    vec3 outside = ambient * sky + sunColor * ndl;
    vec3 lit = mix(outside, interiorAmbient * (0.8 + 0.2 * n.y), uInterior);

    for (int i = 0; i < 10; i++) {
        if (i >= numLights) break;
        vec3 d = lights[i].xyz - wp.xyz;
        float dist = length(d);
        float att = max(0.0, 1.0 - dist / lights[i].w);
        att *= att;
        float l = max(dot(n, d / max(dist, 0.001)), 0.0) * 0.75 + 0.25;
        lit += lightCols[i].rgb * (lightCols[i].a * att * l);
    }
    if (spotPos.w > 0.0) {
        vec3 d = wp.xyz - spotPos.xyz;
        float dist = max(length(d), 0.001);
        vec3 dn = d / dist;
        float cone = smoothstep(spotDir.w, spotDir.w + 0.06, dot(dn, spotDir.xyz));
        float att = max(0.0, 1.0 - dist / 34.0);
        float l = max(dot(n, -dn), 0.0) * 0.8 + 0.2;
        lit += vec3(1.0, 0.93, 0.78) * (spotPos.w * cone * att * att * l);
    }
    lit = mix(lit, vec3(1.0), uEmissive);
    vLight = vec4(VertexColor.rgb * lit * uTint.rgb, VertexColor.a * uTint.a);

    float fd = length(wp.xyz - camPos);
    vFog = clamp((fd - fogRange.x) / (fogRange.y - fogRange.x), 0.0, fogMax);

    vec4 clip = viewProj * wp;
    // vertex snapping (PSX jitter)
    if (clip.w > 0.0) {
        vec2 ndc = clip.xy / clip.w;
        ndc = floor(ndc * snapRes + 0.5) / snapRes;
        clip.xy = ndc * clip.w;
    }
    // partially affine texture mapping
    float q = pow(max(clip.w, 0.05), -(1.0 - affine));
    vAff = vec3((VertexTexCoord.xy + uvOffset) * q, q);
    clip.y *= flipY;
    return clip;
}
#endif

#ifdef PIXEL
uniform float alphaCut;
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec2 uv = vAff.xy / vAff.z;
    vec4 t = Texel(tex, uv);
    if (t.a < alphaCut) discard;
    vec3 c = t.rgb * vLight.rgb;
    c = mix(c, fogColor, vFog);
    return vec4(c, vLight.a * t.a);
}
#endif
