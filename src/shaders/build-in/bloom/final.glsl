uniform sampler2D iBeforeBloom;
uniform sampler2D iPairBloomDown;

uniform float gBloomIntensity;  // 1 0 30

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 texelSize = 1.0 / iResolution.xy;
    vec3 col = texture(iBeforeBloom, uv).rgb;
    vec3 pair = texture(iPairBloomDown, uv).rgb;
    fragColor = vec4(col + gBloomIntensity * tap4(iPrevPass, uv, texelSize), 1.0);
}