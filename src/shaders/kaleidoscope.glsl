#define PI 3.14159265359
#define PI2 6.28318530718
#define EPS 0.0001

#define BPM 120.0
#define LEN 32.0
#define _beat (iTime * BPM / 60.0)
#define beat (mod(_beat, LEN))

float sdRect(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return max(d.x, d.y) + min(max(d.x, d.y), 0.0);
}

mat2 rot(float x) { return mat2(cos(x), sin(x), -sin(x), cos(x)); }

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, saturate(p - K.xxx), c.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord.xy * 2.0 - iResolution.xy) / min(iResolution.x, iResolution.y);

    // https://www.shadertoy.com/view/MdKfWR
    vec2 q = p;
    float d = 9999.0;
    float z = PI2 * (beat + 16.0) / LEN;
    for (int i = 0; i < 5; ++i) {
        q = abs(q) - 0.5;
        q *= rot(0.7);
        q = abs(q) - 0.5;
        q *= rot(z);
        q *= 1.5;
        float k = sdRect(q, vec2(0.5, 0.3 + q.x));
        d = min(d, k);
    }

    float s = saturate(abs(0.2 / q.x));
    vec3 col = hsv2rgb(vec3((beat + 16.0) / LEN, 1.0 - 0.6 * s, s)) * saturate(-2.0 * d);
    col = pow(col * 2.0, vec3(2.0));
    fragColor = vec4(col, 1.0);
}