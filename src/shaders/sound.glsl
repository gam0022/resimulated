#version 300 es
precision mediump float;
uniform float iSampleRate;
uniform float iBlockOffset;

float tri(in float freq, in float time)
{
    return -abs(1. - mod(freq * time * 2., 2.));
}

vec2 mainSound(float time)
{
    float freq = 440.;
    freq *= pow(1.06 * 1.06, floor(mod(time, 6.)));
    return vec2(
        tri(freq, time) * sin(time * 3.141592),
        tri(freq * 1.5, time) * sin(time * 3.141592));
}

out vec4 outColor;
void main()
{
    float t = iBlockOffset + ((gl_FragCoord.x - 0.5) + (gl_FragCoord.y - 0.5) * 512.0) / iSampleRate;
    vec2 y = mainSound(t);
    vec2 v = floor((0.5 + 0.5 * y) * 65536.0);
    vec2 vl = mod(v, 256.0) / 255.0;
    vec2 vh = floor(v / 256.0) / 255.0;
    outColor = vec4(vl.x, vh.x, vl.y, vh.y);
}