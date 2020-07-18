uniform float gFbmScale;  // 6 0 20
uniform float gMix;       // 0 0 1

// Thanks https://shadertoy.com/view/ttsGR4
float revisionLogo(vec2 p, float rot) {
    int[] pat = int[](0, ~0, 0x7C, 0xC0F03C00, 0xF7FBFF01, ~0, 0, 0x8320D39F, ~0, 0x1F0010, 0);
    int r = clamp(int(20. * length(p)), 0, 10);
    return float(pat[r] >> int(5.1 * atan(p.y, p.x) + 16. + (hash11(float(r * 1231)) - 0.5) * rot) & 1);
}

float revisionLogoMix(vec2 p, float rot) {
    int[] pat = int[](0, ~0, 0x7C, 0xC0F03C00, 0xF7FBFF01, ~0, 0, 0x8320D39F, ~0, 0x1F0010, 0);
    int r = clamp(int(mix(20. * length(p), (p.x) * 20.0, gMix)), 0, 10);
    return float(pat[r] >> int(mix(5.1 * atan(p.y, p.x) + 16., 40.0 * (p.y), gMix)) & 1);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy - 0.5;
    // fragColor = vec4(vec3(fbm(uv, floor(gFbmScale))), 1.0);
    fragColor = vec4(vec3(revisionLogoMix(uv, 1.0)), 1.0);
    // fragColor = vec4(length(uv), remap(atan(uv.x, uv.y), -PI, PI, 0.0, 1.0), 0.0, 1.0);
}