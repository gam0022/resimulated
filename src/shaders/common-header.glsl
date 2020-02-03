#version 300 es
precision highp float;precision highp int;precision mediump sampler3D;
void mainImage(out vec4 fragColor, in vec2 fragCoord);
out vec4 outColor;void main(void){vec4 c;mainImage(c, gl_FragCoord.xy);outColor = c;}
#define saturate(x) clamp(x, 0.0, 1.0)

uniform vec3 iResolution;
uniform float iTime;
uniform sampler2D iPrevPass;
