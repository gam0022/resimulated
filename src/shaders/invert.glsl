#version 300 es
precision highp float;
precision highp int;
precision mediump sampler3D;
uniform vec3 iResolution;
uniform float iTime;

// uniform sampler2D iPass0;
uniform sampler2D iPrevPass;

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord / iResolution.xy;

    // invert
    vec3 col = vec3(1.0) - texture(iPrevPass, uv).rgb;

    // Output to screen
    fragColor = vec4(col, 1.0);
}

out vec4 outColor;
void main( void ){vec4 color = vec4(0.0,0.0,0.0,1.0);mainImage( color, gl_FragCoord.xy );color.w = 1.0;outColor = color;}