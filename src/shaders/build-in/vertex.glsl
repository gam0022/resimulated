#version 300 es

invariant gl_Position;
in vec2 vert2d;

void main(void) { gl_Position = vec4(vert2d, 0, 1); }
