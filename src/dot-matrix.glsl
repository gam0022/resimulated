#version 300 es
precision highp float;
precision highp int;
precision mediump sampler3D;
uniform vec3 iResolution;
uniform float iTime;

// uniform sampler2D iPass0;
uniform sampler2D iPrevPass;

#define saturate(x) clamp(x, 0.0, 1.0)

float sdCircle(vec2 p, float r) {
    return length(p) - r;
}

// Dot Matrix
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord / iResolution.xy) * 2.0 - 1.0;

    float ny = 20.0;
    float nx = ny * iResolution.x / iResolution.y;
    vec2 num = vec2(nx, ny);

    vec3 col;
    vec2 uvDot = (((floor(uv * num) + 0.5) / num) + 1.0) * 0.5;
       vec3 lum = texture(iPrevPass, uvDot).rgb;

    vec2 uvGrid = fract(uv * num);
    vec2 pGrid = uvGrid - 0.5;
    col = (lum + 0.05) * 5.0 * saturate(-sdCircle(pGrid, 0.5));

    fragColor = vec4(col, 1.0);
}

out vec4 outColor;
void main( void ){vec4 color = vec4(0.0,0.0,0.0,1.0);mainImage( color, gl_FragCoord.xy );color.w = 1.0;outColor = color;}