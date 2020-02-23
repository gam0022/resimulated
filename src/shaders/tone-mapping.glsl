vec3 acesFilm(const vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

uniform float gTonemapExposure;  // 0.1 0.0 2

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec3 col = texture(iPrevPass, uv).rgb;
    col = acesFilm(col * gTonemapExposure);
    col = pow(col, vec3(1.0 / 2.2));
    fragColor = vec4(col, 1.0);
}