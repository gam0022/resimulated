uniform float gChromaticAberrationIntensity;  // 0.03 0 0.1 post
uniform float gChromaticAberrationDistance;   // 0.45 0 1

uniform float gVignetteIntensity;   // 1.34 0 3
uniform float gVignetteSmoothness;  // 2 0 5
uniform float gVignetteRoundness;   // 1 0 1

uniform float gTonemapExposure;  // 0.1 0.0 2
uniform float gBlend;            // 0 -1 1

vec3 chromaticAberration(vec2 uv) {
    vec2 d = abs(uv - 0.5);
    float f = mix(0.5, dot(d, d), gChromaticAberrationDistance);
    f *= f * gChromaticAberrationIntensity;
    d = vec2(f);

    vec3 col;
    col.r = texture(iPrevPass, uv + d).r;
    col.g = texture(iPrevPass, uv).g;
    col.b = texture(iPrevPass, uv - d).b;
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
    col = blend(col);
    fragColor = vec4(col, 1.0);
}