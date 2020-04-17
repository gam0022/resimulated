uniform float gFbmScale;  // 6 0 20

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = vec4(vec3(fbm(uv, floor(gFbmScale))), 1.0);
}