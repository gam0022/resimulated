uniform sampler2D iBeforeBloom;
uniform sampler2D iPairBloomDown;

uniform float gBloomSpread;  // 1.3 1 2

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 texelSize = 1.0 / iResolution.xy;
    vec3 col = texture(iPairBloomDown, uv).rgb;
    fragColor = vec4(col + gBloomSpread * tap4(iPrevPass, uv, texelSize), 1.0);
}