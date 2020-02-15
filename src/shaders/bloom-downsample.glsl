void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 texelSize = 1.0 / iResolution.xy;
    fragColor = vec4(tap4(iPrevPass, uv, texelSize), 1.0);
}