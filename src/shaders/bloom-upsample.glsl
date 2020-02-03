uniform sampler2D iBeforeBloom;
uniform sampler2D iPairBloomDown;

vec3 tap4(sampler2D tex, vec2 uv, vec2 texelSize)
{
    vec4 d = texelSize.xyxy * vec4(-1.0, -1.0, 1.0, 1.0);

    vec3 s;
    s = texture(tex, uv + d.xy).rgb;
    s += texture(tex, uv + d.zy).rgb;
    s += texture(tex, uv + d.xw).rgb;
    s += texture(tex, uv + d.zw).rgb;

    return s * (1.0 / 4.0);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
	vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 texelSize = 1.0 / iResolution.xy * 0.25;
    vec3 col = texture(iPairBloomDown, uv).rgb;
    fragColor = vec4(col + tap4(iPrevPass, uv, texelSize), 1.0);
}