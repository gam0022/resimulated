void text(vec2 uv, inout vec3 result) {
    vec3 col = vec3(0.0);
    float b = beat - 224.0;
    float t4 = mod(b, 4.0) / 4.0;
    float t8 = mod(b, 8.0) / 8.0;
    float brightness = 1.0;

    if (b < 4.0) {
        // 0-4 (4)
        // nop
    } else if (b < 8.0) {
        // 4-8 (4)
        // A 64k INTRO
        col += texture(iTextTexture, textUv(uv, 0.0, vec2(0.0, 0.0), 3.0)).rgb;
        col *= remap(t4, 0.5, 1.0, 1.0, 0.0);
    } else if (b < 12.0) {
        // 8-12 (4)
        // gam0022 & sadakkey
        col += texture(iTextTexture, textUv(uv, 1.0, vec2(-1.0, 0.1), 1.0)).rgb;
        col += texture(iTextTexture, textUv(uv, 2.0, vec2(-1.0, -0.1), 1.0)).rgb;

        col += texture(iTextTexture, textUv(uv, 3.0, vec2(1.0, 0.1), 1.0)).rgb;
        col += texture(iTextTexture, textUv(uv, 4.0, vec2(1.0, -0.1), 1.0)).rgb;
        col *= remap(t4, 0.5, 1.0, 1.0, saturate(cos(TAU * b * iTime)));
    } else if (b < 16.0) {
        // 12-16 (4)
        // RE: SIMULATED
        col += texture(iTextTexture, textUv(uv, 5.0, vec2(0.0, 0.0), 3.0)).rgb;
        col *= remap(t8, 0.5, 1.0, 0.0, 1.0);
    } else if (b < 20.0) {
        // 16-20 (4)
        // RE: SIMULATED -> RE
        float t = remapFrom(t4, 0.75, 1.0);
        // t = easeInOutCubic(t);
        // t = pow(t4, 1.4);

        vec2 glitch = vec2(0.0);
        float fade = uv.x - remapTo(t, 1.6, -0.78);
        if (fade > 0.0) {
            glitch = hash23(vec3(floor(vec2(uv.x * 32.0, uv.y * 8.0)), beat));
            glitch.x = fade * fade * remapTo(glitch.x, 0.0 * t, 0.05 * t);
            glitch.y = fade * fade * remapTo(glitch.y, -0.4 * t, 0.3 * t);
            fade = saturate(1.0 - fade) * saturate(1.0 - abs(glitch.y));
        } else {
            fade = 1.0;
        }

        float a = saturate(cos(fract(b * TAU * 4.0)));
        col.r += fade * texture(iTextTexture, textUv(uv + glitch * mix(0.5, 1.0, a), 5.0, vec2(0.0, 0.0), 3.0)).r;
        col.g += fade * texture(iTextTexture, textUv(uv + glitch * mix(1.5, 1.0, a), 5.0, vec2(0.0, 0.0), 3.0)).g;
        col.b += fade * texture(iTextTexture, textUv(uv + glitch * mix(2.0, 1.0, a), 5.0, vec2(0.0, 0.0), 3.0)).b;
    } else if (b < 24.0) {
        // 20-24 (4)
        // RE
        col += texture(iTextTexture, textUv(uv, 6.0, vec2(-0.553, 0.0), 3.0)).rgb;
        if (uv.x > -0.78) {
            col *= 0.0;
        }
        brightness = remapTo(t4, 1.0, 0.0);
    } else {
        // 24-32 (8)
        // RE -> REALITY
        col += texture(iTextTexture, textUv(uv, 6.0, vec2(-0.553, 0.0), 3.0)).rgb;
        float t = remapFrom(t8, 0.75, 0.85);
        // t = easeInOutCubic(t);
        t = pow(t, 4.0);
        if (uv.x > remapTo(t, -0.78, 1.0)) {
            col *= 0.0;
        }
        col *= remap(t8, 0.75, 1.0, 1.0, 0.0);
        brightness = 0.8 <= t8 && t8 < 0.84 ? 1.0 : 0.0;
    }

    result *= brightness;
    result += 0.3 * col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec3 col = texture(iPrevPass, uv).rgb;

    uv = (fragCoord * 2.0 - iResolution.xy) / min(iResolution.x, iResolution.y);
    text(uv, col);
    fragColor = vec4(col, 1.0);
}