void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord / iResolution.xy;

    // invert
    vec3 col = vec3(1.0) - texture(iPrevPass, uv).rgb;

    // Output to screen
    fragColor = vec4(col, 1.0);
}