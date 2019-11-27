#version 300 es
precision highp float;
precision highp int;
precision mediump sampler3D;
uniform vec3 iResolution;
uniform float iTime;

uniform sampler2D iPrevPass;

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord / iResolution.xy;

    vec3 col;

    vec2 offset = vec2(1.0, 1.0) * 0.01;
    col.r = texture(iPrevPass, uv - offset).r;
    col.g = texture(iPrevPass, uv).g;
    col.b = texture(iPrevPass, uv + offset).b;

    // Output to screen
    fragColor = vec4(col, 1.0);
}

out vec4 outColor;
void main( void ){vec4 color = vec4(0.0,0.0,0.0,1.0);mainImage( color, gl_FragCoord.xy );color.w = 1.0;outColor = color;}