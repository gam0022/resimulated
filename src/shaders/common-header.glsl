#version 300 es
precision highp float;
precision highp int;
precision mediump sampler3D;

void mainImage(out vec4 fragColor, in vec2 fragCoord);

out vec4 outColor;
void main(void) {
    vec4 c;
    mainImage(c, gl_FragCoord.xy);
    outColor = c;
}

// consts
const float PI = 3.14159265359;
const float TAU = 6.28318530718;
const float PIH = 1.57079632679;

#define saturate(x) clamp(x, 0.0, 1.0)

uniform vec3 iResolution;
uniform float iTime;
uniform sampler2D iPrevPass;

// noise
// https://www.shadertoy.com/view/4djSRW
float hash11(float p) {
    p = fract(p * .1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// https://www.shadertoy.com/view/4dlGW2
// Tileable Noise
float hashScale(in vec2 p, in float scale) {
    // This is tiling part, adjusts with the scale...
    p = mod(p, scale);
    return fract(sin(dot(p, vec2(27.16898, 38.90563))) * 5151.5473453);
}

float noise(in vec2 p, in float scale) {
    vec2 f;

    p *= scale;

    f = fract(p);  // Separate integer from fractional
    p = floor(p);

    f = f * f * (3.0 - 2.0 * f);  // Cosine interpolation approximation

    float res = mix(mix(hashScale(p, scale), hashScale(p + vec2(1.0, 0.0), scale), f.x), mix(hashScale(p + vec2(0.0, 1.0), scale), hashScale(p + vec2(1.0, 1.0), scale), f.x), f.y);
    return res;
}

float fbm(in vec2 p, float scale) {
    float f = 0.0;

    p = mod(p, scale);
    float amp = 0.6;

    for (int i = 0; i < 5; i++) {
        f += noise(p, scale) * amp;
        amp *= .5;
        // Scale must be multiplied by an integer value...
        scale *= 2.;
    }

    return f;
}

// https://www.shadertoy.com/view/lsf3WH
// Noise - value - 2D by iq
float noise(in vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i + vec2(0.0, 0.0)), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float easeInOutCubic(float t) { return t < 0.5 ? 4.0 * t * t * t : (t - 1.0) * (2.0 * t - 2.0) * (2.0 * t - 2.0) + 1.0; }

float fbm(in vec2 uv) {
    float f = 0.0;
    mat2 m = mat2(1.6, 1.2, -1.2, 1.6);
    f = 0.5000 * noise(uv);
    uv = m * uv;
    f += 0.2500 * noise(uv);
    uv = m * uv;
    f += 0.1250 * noise(uv);
    uv = m * uv;
    f += 0.0625 * noise(uv);
    uv = m * uv;
    return f;
}

// https://www.shadertoy.com/view/3tX3R4
float clamp2(float x, float min, float max) { return (min < max) ? clamp(x, min, max) : clamp(x, max, min); }
float remap(float val, float im, float ix, float om, float ox) { return clamp2(om + (val - im) * (ox - om) / (ix - im), om, ox); }
float remap01(float val, float im, float ix) { return remap(val, im, ix, 0.0, 1.0); }  // TODO: optimize

vec3 tap4(sampler2D tex, vec2 uv, vec2 texelSize) {
    vec4 d = texelSize.xyxy * vec4(-1.0, -1.0, 1.0, 1.0);

    vec3 s;
    s = texture(tex, uv + d.xy).rgb;
    s += texture(tex, uv + d.zy).rgb;
    s += texture(tex, uv + d.xw).rgb;
    s += texture(tex, uv + d.zw).rgb;

    return s * (1.0 / 4.0);
}

#define BPM 140.0
#define beat (iTime * BPM / 60.0)
