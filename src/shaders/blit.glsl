#version 300 es
precision highp float;
precision highp int;
precision mediump sampler3D;
uniform vec3 iResolution;
uniform float iTime;

uniform sampler2D iPrevPass;

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = texture(iPrevPass, uv);
}

out vec4 outColor;
void main( void ){vec4 color = vec4(0.0,0.0,0.0,1.0);mainImage( color, gl_FragCoord.xy );outColor = color;}