#version 300 es
precision highp float;
precision highp int;
precision mediump sampler3D;
uniform vec3 iResolution;
uniform float iTime;

uniform sampler2D iPrevPass;

vec4 BlurColor (in vec2 Coord, in sampler2D Tex, in float MipBias)
{
	vec2 TexelSize = MipBias/iResolution.xy;

    vec4  Color = texture(Tex, Coord, MipBias);
    Color += texture(Tex, Coord + vec2(TexelSize.x,0.0), MipBias);
    Color += texture(Tex, Coord + vec2(-TexelSize.x,0.0), MipBias);
    Color += texture(Tex, Coord + vec2(0.0,TexelSize.y), MipBias);
    Color += texture(Tex, Coord + vec2(0.0,-TexelSize.y), MipBias);
    Color += texture(Tex, Coord + vec2(TexelSize.x,TexelSize.y), MipBias);
    Color += texture(Tex, Coord + vec2(-TexelSize.x,TexelSize.y), MipBias);
    Color += texture(Tex, Coord + vec2(TexelSize.x,-TexelSize.y), MipBias);
    Color += texture(Tex, Coord + vec2(-TexelSize.x,-TexelSize.y), MipBias);

    return Color/9.0;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    float Threshold = 0.1;
	float Intensity = 1.0;
	float BlurSize = 2.0;

	vec2 uv = fragCoord.xy/iResolution.xy;

    vec4 Color = texture(iPrevPass, uv);

    vec4 Highlight = clamp(BlurColor(uv, iPrevPass, BlurSize)-Threshold,0.0,1.0)*1.0/(1.0-Threshold);

    fragColor = 1.0-(1.0-Color)*(1.0-Highlight*Intensity); //Screen Blend Mode
}

out vec4 outColor;
void main( void ){vec4 color = vec4(0.0,0.0,0.0,1.0);mainImage( color, gl_FragCoord.xy );outColor = color;}