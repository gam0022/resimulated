out vec4 outColor;
void main( void ){vec4 color = vec4(0.0,0.0,0.0,1.0);mainImage( color, gl_FragCoord.xy );color.w = 1.0;outColor = color;}