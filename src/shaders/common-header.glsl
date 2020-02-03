#version 300 es
precision highp float;
precision highp int;
precision mediump sampler3D;

uniform vec3 iResolution;
uniform float iTime;
uniform sampler2D iPrevPass;

void mainImage(out vec4 fragColor, in vec2 fragCoord);
out vec4 outColor;
void main( void ){
    vec4 col;
    mainImage(col, gl_FragCoord.xy);
    outColor = col;
}

#define saturate(x) clamp(x, 0.0, 1.0)