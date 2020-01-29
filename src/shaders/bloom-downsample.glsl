#version 300 es
precision highp float;
precision highp int;
precision mediump sampler3D;
uniform vec3 iResolution;
uniform float iTime;

// uniform sampler2D iPass0;
uniform sampler2D iPrevPass;

vec4 encodeHDR(vec3 rgb) {
    //return vec4(rgb, 1.0);

    rgb *= 1.0 / 8.0;
    float m = max(max(rgb.r, rgb.g), max(rgb.b, 1e-6));
    m = ceil(m * 255.0) / 255.0;
    return vec4(rgb / m, m);
}

vec3 decodeHDR(vec4 rgba)
{
    // return rgba.rgb;

    return rgba.rgb * rgba.a * 8.0;
}

vec3 tap4(sampler2D tex, vec2 uv, vec2 texelSize)
{
    vec4 d = texelSize.xyxy * vec4(-1.0, -1.0, 1.0, 1.0);

    vec3 s;
    s = decodeHDR(texture(tex, uv + d.xy));
    s += decodeHDR(texture(tex, uv + d.zy));
    s += decodeHDR(texture(tex, uv + d.xw));
    s += decodeHDR(texture(tex, uv + d.zw));

    return s * (1.0 / 4.0);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
	vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 texelSize = 1.0 / iResolution.xy;
    fragColor = encodeHDR(tap4(iPrevPass, uv, texelSize));
}

out vec4 outColor;
void main( void ){vec4 color = vec4(0.0,0.0,0.0,1.0);mainImage( color, gl_FragCoord.xy );outColor = color;}