const float INF = 1e+10;
const float OFFSET = 0.1;

uniform float gSceneId;   // 0 0 2 scene
uniform float gSceneEps;  // 0.002 0.00001 0.01
#define SCENE_MANDEL 0.0
#define SCENE_UNIVERSE 1.0

uniform float gCameraEyeX;     // 0 -100 100 camera
uniform float gCameraEyeY;     // 2.8 -100 100
uniform float gCameraEyeZ;     // -8 -100 100
uniform float gCameraTargetX;  // 0 -100 100
uniform float gCameraTargetY;  // 2.75 -100 100
uniform float gCameraTargetZ;  // 0 -100 100
uniform float gCameraFov;      // 13 0 180

uniform float gMandelboxScale;   // 2.7 1 5 mandel
uniform float gMandelboxRepeat;  // 10 1 100
uniform float gEdgeEps;          // 0.0005 0.0001 0.01
uniform float gEdgePower;        // 1 0.1 10
uniform float gBaseColor;        // 0.5
uniform float gRoughness;        // 0.1
uniform float gMetallic;         // 0.4

struct Ray {
    vec3 origin;
    vec3 direction;
};

struct Camera {
    vec3 eye, target;
    vec3 forward, right, up;
};
Camera camera;

Ray cameraShootRay(Camera c, vec2 uv) {
    c.forward = normalize(c.target - c.eye);
    c.right = normalize(cross(c.forward, c.up));
    c.up = normalize(cross(c.right, c.forward));

    Ray r;
    r.origin = c.eye;
    r.direction = normalize(uv.x * c.right + uv.y * c.up + c.forward / tan(gCameraFov / 360.0 * PI));

    return r;
}

struct Intersection {
    bool hit;
    vec3 position;
    float distance;
    vec3 normal;
    vec2 uv;
    int count;

    vec3 baseColor;
    float roughness;
    float reflectance;
    float metallic;
    vec3 emission;

    vec3 color;
};

#define calcNormal(p, dFunc, eps)                                                                                                                                                 \
    normalize(vec2(eps, -eps).xyy *dFunc(p + vec2(eps, -eps).xyy) + vec2(eps, -eps).yyx * dFunc(p + vec2(eps, -eps).yyx) + vec2(eps, -eps).yxy * dFunc(p + vec2(eps, -eps).yxy) + \
              vec2(eps, -eps).xxx * dFunc(p + vec2(eps, -eps).xxx))

float sdSphere(vec3 p, float r) { return length(p) - r; }

float sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
    vec3 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

mat2 rotate(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, s, -s, c);
}

float dMandelFast(vec3 p, float scale, int n) {
    vec4 q0 = vec4(p, 1.0);
    vec4 q = q0;

    for (int i = 0; i < n; i++) {
        // q.xz = mul(rotate(_MandelRotateXZ), q.xz);
        q.xyz = clamp(q.xyz, -1.0, 1.0) * 2.0 - q.xyz;
        q = q * scale / clamp(dot(q.xyz, q.xyz), 0.3, 1.0) + q0;
    }

    return length(q.xyz) / abs(q.w);
}

vec2 foldRotate(vec2 p, float s) {
    float a = PI / s - atan(p.x, p.y);
    float n = TAU / s;
    a = floor(a / n) * n;
    p = rotate(a) * p;
    return p;
}

uniform float gFoldRotate;  // 1 0 20

float dStage(vec3 p) {
    float b = max(beat - 128.0, 0.0) + (p.z + 10.0);
    p.xy = foldRotate(p.xy, gFoldRotate);
    return dMandelFast(p, gMandelboxScale, int(gMandelboxRepeat));
}

uniform float gBallZ;               // 0 -100 100 ball
uniform float gBallRadius;          // 0 0 0.2
uniform float gLogoIntensity;       // 0 0 4
uniform float gBallDistortion;      // 0.0 0 0.1
uniform float gBallDistortionFreq;  // 30 0 100

float dBall(vec3 p) {
    return sdSphere(p - vec3(0, 0, gBallZ), gBallRadius) - gBallDistortion * sin(gBallDistortionFreq * p.x + beat) * sin(gBallDistortionFreq * p.y + beat) * sin(gBallDistortionFreq * p.z + beat);
}

float map(vec3 p) {
    float d = dStage(p);

    if (gBallRadius > 0.0) {
        d = min(d, dBall(p));
    }

    return d;
}

// https://www.shadertoy.com/view/lttGDn
float calcEdge(vec3 p) {
    float edge = 0.0;
    vec2 e = vec2(gEdgeEps, 0);

    // Take some distance function measurements from either side of the hit
    // point on all three axes.
    float d1 = map(p + e.xyy), d2 = map(p - e.xyy);
    float d3 = map(p + e.yxy), d4 = map(p - e.yxy);
    float d5 = map(p + e.yyx), d6 = map(p - e.yyx);
    float d = map(p) * 2.;  // The hit point itself - Doubled to cut down on
                            // calculations. See below.

    // Edges - Take a geometry measurement from either side of the hit point.
    // Average them, then see how much the value differs from the hit point
    // itself. Do this for X, Y and Z directions. Here, the sum is used for the
    // overall difference, but there are other ways. Note that it's mainly sharp
    // surface curves that register a discernible difference.
    edge = abs(d1 + d2 - d) + abs(d3 + d4 - d) + abs(d5 + d6 - d);
    // edge = max(max(abs(d1 + d2 - d), abs(d3 + d4 - d)), abs(d5 + d6 - d)); //
    // Etc.

    // Once you have an edge value, it needs to normalized, and smoothed if
    // possible. How you do that is up to you. This is what I came up with for
    // now, but I might tweak it later.
    edge = smoothstep(0., 1., sqrt(edge / e.x * 2.));

    // Return the normal.
    // Standard, normalized gradient mearsurement.
    return edge;
}

// Thanks https://shadertoy.com/view/ttsGR4
float revisionLogo(vec2 p, float rot) {
    int[] pat = int[](0, ~0, 0x7C, 0xC0F03C00, 0xF7FBFF01, ~0, 0, 0x8320D39F, ~0, 0x1F0010, 0);
    int r = clamp(int(20. * length(p)), 0, 10);
    return float(pat[r] >> int(5.1 * atan(p.y, p.x) + 16. + (hash11(float(r * 1231)) - 0.5) * rot) & 1);
}

uniform float gEmissiveIntensity;     // 6.0 0 20 emissive
uniform float gEmissiveSpeed;         // 1 0 2
uniform float gEmissiveHue;           // 0.33947042613522904 0 1
uniform float gEmissiveHueShiftBeat;  // 0 0 1
uniform float gEmissiveHueShiftZ;     // 0 0 1
uniform float gEmissiveHueShiftXY;    // 0 0 1

uniform float gF0;                    // 0.95 0 1 lighting
uniform float gCameraLightIntensity;  // 1 0 10

float fresnelSchlick(float f0, float cosTheta) { return f0 + (1.0 - f0) * pow((1.0 - cosTheta), 5.0); }

void intersectObjects(inout Intersection intersection, inout Ray ray) {
    float d;
    float distance = 0.0;
    vec3 p = ray.origin;
    float eps;

    for (int i = 0; i < 300; i++) {
        d = map(p);
        distance += d;
        p = ray.origin + distance * ray.direction;
        intersection.count = i;
        eps = gSceneEps * distance;
        if (d < eps) break;
    }

    if (distance < intersection.distance) {
        intersection.distance = distance;
        intersection.hit = true;
        intersection.position = p;
        intersection.normal = calcNormal(p, map, gSceneEps);

        if (gBallRadius > 0.0 && dBall(p) < eps) {
            intersection.baseColor = vec3(0.0);
            intersection.roughness = 0.0;
            intersection.metallic = 1.0;
            intersection.emission = vec3(0.0);
            intersection.reflectance = 1.0;

            if (gLogoIntensity > 0.0) {
                float b = beat - 160.0;
                float r = remapFrom(b, 0.0, 7.0);
                r = r - 1.0;
                intersection.emission = vec3(gLogoIntensity) * revisionLogo(intersection.normal.xy * 0.6, 8.0 * r);
            }
        } else {
            intersection.baseColor = vec3(gBaseColor);
            intersection.roughness = gRoughness;
            intersection.metallic = gMetallic;

            float edge = calcEdge(p);
            float hue = gEmissiveHue + gEmissiveHueShiftZ * p.z + gEmissiveHueShiftXY * length(p.xy) + gEmissiveHueShiftBeat * beat;
            intersection.emission = gEmissiveIntensity * hsv2rgb(vec3(hue, 0.8, 1.0)) * pow(edge, gEdgePower) * saturate(cos(beat * gEmissiveSpeed * TAU - mod(0.5 * intersection.position.z, TAU)));
            intersection.reflectance = 0.0;
        }
    }
}

void intersectScene(inout Intersection intersection, inout Ray ray) {
    intersection.distance = INF;
    intersectObjects(intersection, ray);
}

#define FLT_EPS 5.960464478e-8

float roughnessToExponent(float roughness) { return clamp(2.0 * (1.0 / (roughness * roughness)) - 2.0, FLT_EPS, 1.0 / FLT_EPS); }

vec3 evalPointLight(inout Intersection i, vec3 v, vec3 lp, vec3 radiance) {
    vec3 n = i.normal;
    vec3 p = i.position;
    vec3 ref = mix(vec3(0.04), i.baseColor, i.metallic);

    vec3 l = lp - p;
    float len = length(l);
    l /= len;

    vec3 h = normalize(l + v);

    vec3 diffuse = mix(1.0 - ref, vec3(0.0), i.metallic) * i.baseColor / PI;
    float m = roughnessToExponent(i.roughness);
    vec3 specular = ref * pow(max(0.0, dot(n, h)), m) * (m + 2.0) / (8.0 * PI);
    return (diffuse + specular) * radiance * max(0.0, dot(l, n)) / (len * len);
}

vec3 evalDirectionalLight(inout Intersection i, vec3 v, vec3 lightDir, vec3 radiance) {
    vec3 n = i.normal;
    vec3 p = i.position;
    vec3 ref = mix(vec3(0.04), i.baseColor, i.metallic);

    vec3 l = lightDir;
    vec3 h = normalize(l + v);

    vec3 diffuse = mix(1.0 - ref, vec3(0.0), i.metallic) * i.baseColor / PI;
    float m = roughnessToExponent(i.roughness);
    vec3 specular = ref * pow(max(0.0, dot(n, h)), m) * (m + 2.0) / (8.0 * PI);
    return (diffuse + specular) * radiance * max(0.0, dot(l, n));
}

// http://www.fractalforums.com/new-theories-and-research/very-simple-formula-for-fractal-patterns/
float fractal(vec3 p, int n) {
    float strength = 7.0;
    float accum = 0.25;
    float prev = 0.;
    float tw = 0.;
    for (int i = 0; i < n; i++) {
        float mag = dot(p, p);
        p = abs(p) / mag + vec3(-.5, -.4, -1.5);
        float w = exp(-float(i) / 7.);
        accum += w * exp(-strength * pow(abs(mag - prev), 2.2));
        tw += w;
        prev = mag;
    }
    return max(0., 5. * accum / tw - .7);
}

void calcRadiance(inout Intersection intersection, inout Ray ray) {
    intersection.hit = false;
    intersectScene(intersection, ray);

    if (intersection.hit) {
        intersection.color = intersection.emission;
        intersection.color += evalPointLight(intersection, -ray.direction, camera.eye, gCameraLightIntensity * vec3(80.0, 80.0, 100.0));

        vec3 sunColor = vec3(2.0, 1.0, 1.0);
        intersection.color += evalDirectionalLight(intersection, -ray.direction, vec3(-0.48666426339228763, 0.8111071056538127, 0.3244428422615251), sunColor);

        // fog
        // intersection.color = mix(intersection.color, vec3(0.01), 1.0 - exp(-0.01 * intersection.distance));
    } else {
        intersection.color = vec3(0.01);
    }
}

uniform float gShockDistortion;    // 0 0 1 distortion
uniform float gExplodeDistortion;  // 0 0 1

vec2 distortion(vec2 uv) {
    float l = length(uv);
    // uv += 1.5 * uv * sin(l + beat * PIH);

    uv += -gShockDistortion * uv * cos(l);

    float explode = 30.0 * gExplodeDistortion * exp(-2.0 * l);
    explode = mix(explode, 2.0 * sin(l + 10.0 * gExplodeDistortion), 10.0 * gExplodeDistortion);
    uv += explode * uv;
    return uv;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    if (gSceneId != SCENE_MANDEL) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / min(iResolution.x, iResolution.y);
    uv = distortion(uv);

    camera.eye = vec3(gCameraEyeX, gCameraEyeY, gCameraEyeZ);
    camera.target = vec3(gCameraTargetX, gCameraTargetY, gCameraTargetZ);
    camera.up = vec3(0.0, 1.0, 0.0);  // y-up
    Ray ray = cameraShootRay(camera, uv);

    vec3 color = vec3(0.0);
    vec3 reflection = vec3(1.0);
    Intersection intersection;

    for (int bounce = 0; bounce < 2; bounce++) {
        calcRadiance(intersection, ray);
        color += reflection * intersection.color;
        if (!intersection.hit || intersection.reflectance == 0.0) break;

        reflection *= intersection.reflectance;
        ray.origin = intersection.position + intersection.normal * OFFSET;
        vec3 l = reflect(ray.direction, intersection.normal);
        reflection *= fresnelSchlick(gF0, dot(l, intersection.normal));
        ray.direction = l;
    }

    fragColor = vec4(color, 1.0);
}