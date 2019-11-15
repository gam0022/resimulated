#version 300 es

precision highp float;

//invariant gl_FragCoord;
uniform Screen {
  vec2 wh;
} screen;
uniform Timer {
  int count;
} timer;
out vec4 fragColor;

vec4 colorSpace(vec2 coord)
{
  float other = 1.0 - (coord.x + coord.y) / 2.0;
  return vec4(coord, other, 1.0);
}

// mandelbrot with animation
vec4 mandel(vec2 coord)
{
  vec2 c = 3.0 * (coord - vec2(2.0 / 3.0, 0.5));
  vec2 z = c;
  const float pi = acos(-1.0);
  int limit = int(20.0 * pow(sin(2.0 * pi * float(timer.count) / 256.0), 2.0));
  float color = 0.0;
  for (int i = 0; i < limit; i++) {
    vec2 z1 = vec2(z.x * z.x - z.y * z.y + c.x, 2.0 * z.x * z.y + c.y);
    if (dot(z1, z1) > 4.0) {
      color = float(i) / float(limit);
      break;
    } else {
      z = z1;
    }
  }
  return vec4(color, 0.0, 0.0, 1.0);
}

void main(void)
{
  vec2 coord = gl_FragCoord.xy / screen.wh;
  //fragColor = colorSpace(coord);
  fragColor = mandel(coord);
  //fragColor = clamp(mandel(coord) + colorSpace(coord), vec4(0.0), vec4(1.0));
}
