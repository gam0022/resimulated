uniform float gChromaticAberrationIntensity;  // 0.03 0 0.1 post
uniform float gChromaticAberrationDistance;   // 0.45 0 1

uniform float gVignetteIntensity;   // 1.34 0 3
uniform float gVignetteSmoothness;  // 2 0 5
uniform float gVignetteRoundness;   // 1 0 1

uniform float gTonemapExposure;  // 0.1 0.0 2
uniform float gFlash;            // 0 0 1
uniform float gFlashSpeed;       // 0 0 60
uniform float gBlend;            // 0 -1 1

uniform float gGlitchIntensity;  // 0 0 0.1
uniform float gXSfhitGlitch;     // 0 0 0.1
uniform float gInvertRate;       // 0 0 1

vec3 chromaticAberration(vec2 uv) {
    uv.x += gXSfhitGlitch * (fbm(vec2(232.0 * uv.y, beat)) - 0.5);

    vec2 d = abs(uv - 0.5);
    float f = mix(0.5, dot(d, d), gChromaticAberrationDistance);
    f *= f * gChromaticAberrationIntensity;
    vec2 shift = vec2(f);

    float a = 2.0 * hash11(beat) - 1.0;
    vec2 grid = hash23(vec3(floor(vec2(uv.x * (4.0 + 8.0 * a), (uv.y + a) * 32.0)), beat));
    grid = 2.0 * grid - 1.0;
    shift += gGlitchIntensity * grid;

    vec3 col;
    col.r = texture(iPrevPass, uv + shift).r;
    col.g = texture(iPrevPass, uv).g;
    col.b = texture(iPrevPass, uv - shift).b;
    return col;
}

float vignette(vec2 uv) {
    vec2 d = abs(uv - 0.5) * gVignetteIntensity;
    float roundness = (1.0 - gVignetteRoundness) * 6.0 + gVignetteRoundness;
    d = pow(d, vec2(roundness));
    return pow(saturate(1.0 - dot(d, d)), gVignetteSmoothness);
}

vec3 acesFilm(const vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

vec3 invert(vec3 c, vec2 uv) {
    if (hash12(vec2(floor(uv.y * gInvertRate * 32.0), beat)) < gInvertRate) {
        return vec3(1.0) - c;
    } else {
        return c;
    }
}

vec3 flash(vec3 c) {
    c = mix(c, vec3(1.0), gFlash * saturate(cos(iTime * PI * gFlashSpeed)));
    return c;
}

vec3 blend(vec3 c) {
    c = mix(c, vec3(1.0), saturate(gBlend));
    c = mix(c, vec3(0.0), saturate(-gBlend));
    return c;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec3 col = chromaticAberration(uv);
    col *= vignette(uv);
    col = acesFilm(col * gTonemapExposure);
    col = pow(col, vec3(1.0 / 2.2));
    col = invert(col, uv);
    col = flash(col);
    col = blend(col);
    fragColor = vec4(col, 1.0);
}