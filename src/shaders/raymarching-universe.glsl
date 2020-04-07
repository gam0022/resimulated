#define STRIP_FIXED

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

// consts
const float INF = 1e+10;
const float OFFSET = 0.1;

// ray
struct Ray {
    vec3 origin;
    vec3 direction;
};

// camera
struct Camera {
    vec3 eye, target;
    vec3 forward, right, up;
};

Ray cameraShootRay(Camera c, vec2 uv) {
    c.forward = normalize(c.target - c.eye);
    c.right = normalize(cross(c.forward, c.up));
    c.up = normalize(cross(c.right, c.forward));

    Ray r;
    r.origin = c.eye;
    r.direction = normalize(uv.x * c.right + uv.y * c.up + c.forward / tan(gCameraFov / 360.0 * PI));

    return r;
}

// intersection
struct Intersection {
    bool hit;
    vec3 position;
    float distance;
    vec3 normal;
    vec2 uv;
    float count;

    vec3 baseColor;
    float roughness;
    float reflectance;
    float metallic;
    vec3 emission;

    bool transparent;
    float refractiveIndex;

    vec3 color;
};

// util
#define calcNormal(p, dFunc, eps)                                                                                                                                                 \
    normalize(vec2(eps, -eps).xyy *dFunc(p + vec2(eps, -eps).xyy) + vec2(eps, -eps).yyx * dFunc(p + vec2(eps, -eps).yyx) + vec2(eps, -eps).yxy * dFunc(p + vec2(eps, -eps).yxy) + \
              vec2(eps, -eps).xxx * dFunc(p + vec2(eps, -eps).xxx))

// Distance Functions
float sdSphere(vec3 p, float r) { return length(p) - r; }

float sdCircle(vec2 p, float r) { return length(p) - r; }

float sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
    vec3 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

mat2 rotate(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, s, -s, c);
}

vec2 uvSphere(vec3 n) {
    float u = 0.5 + atan(n.z, n.x) / TAU;
    float v = 0.5 - asin(n.y) / PI;
    return vec2(u, v);
}

uniform float gPlanetsId;  // 0 0 4 planets
#define PLANETS_MERCURY 0.0
#define PLANETS_MIX_A 1.0
#define PLANETS_KANETA 2.0
#define PLANETS_FMSCAT 3.0
#define PLANETS_MIX_B 4.0
#define PLANETS_EARTH 5.0

#define PLANETS_PAT_MAX 6
#define PLANETS_NUM_MAX 6

vec3[PLANETS_PAT_MAX * PLANETS_NUM_MAX] planetCenters = vec3[](
    // MERCURY
    vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0),
    // MIX_A
    vec3(-10.0, 1.0, 3.0), vec3(-6.0, -1.0, 2.0), vec3(0.0, 0.0, 0.0), vec3(6.0, 0.0, 8.0), vec3(8.0, 3.0, 2.0), vec3(0.0),
    // KANETA
    vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0),
    // PLANETS_FMSCAT
    vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0),
    // MIX_B
    vec3(-7.0, 1.0, 3.0), vec3(-3.0, -3.5, 2.0), vec3(0.0, 0.0, 0.0), vec3(6.0, 0.0, 8.0), vec3(6.0, -3.0, 2.0), vec3(6.0, 5.0, -3.0),
    // EARTH
    vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0));

int[PLANETS_PAT_MAX] planetNums = int[](1, 5, 1, 1, 6, 1);
float[PLANETS_PAT_MAX] planetTextIds = float[](7.0, 8.0, 13.0, 14.0, 15.0, 0.0);

float voronoi(in vec3 p) {
    vec3 ip = floor(p);
    vec3 fp = fract(p);
    float rid = -1.;
    vec2 r = vec2(2.);
    for (int i = -1; i <= 0; i++)
        for (int j = -1; j <= 0; j++)
            for (int k = -1; k <= 0; k++) {
                vec3 g = vec3(i, j, k);
                // float h = hash(ip - g);
                vec3 pp = fp + g + hash33(ip - g) * .6;
                float d = dot(pp, pp);

                if (d < r.x) {
                    r.y = r.x;
                    r.x = d;
                    // rid = h +.5;
                } else if (d < r.y) {
                    r.y = d;
                }
            }
    return r.x;
}

// https://www.shadertoy.com/view/llSGRw
float craters(vec3 p) {
    float v = voronoi(p);
    return sin(sqrt(v) * TAU) * exp(-4. * v);
}

float hMercury(vec3 p) {
    p.xz = rotate(beat * 0.05) * p.xz;
    float f = 1.2;

    float r = 0.0;
    for (int i = 0; i < 5; i++) {
        r += abs(craters(p * f)) / f;
        f *= 2.7;
    }
    return r;
}

float dMercury(vec3 p) {
    float d = sdSphere(p, 1.0);

    if (d < 1.0) {
        d += 0.075 * hMercury(p);
    }

    return d;
}

uniform vec3 gPlanetPalA;  // 127 127 127
uniform vec3 gPlanetPalB;  // 110 115 115
uniform vec3 gPlanetPalC;  // 256 178 102
uniform vec3 gPlanetPalD;  // 130 130 25

float hPlanetsMix(vec2 p, float seed) {
    vec3 rand = hash31(seed);
    p.y *= 4.0 * rand.x;
    return fbm(p + 0.05 * rand.y * fbm(p, 32.0 * rand.z), 8.0);
}

vec3 pal(in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d) { return a + b * cos(TAU * (c * t + d)); }

float dPlanetsMix(vec3 p) {
    float d = INF;

    for (int i = 0; i < planetNums[int(gPlanetsId)]; i++) {
        vec3 center = planetCenters[PLANETS_NUM_MAX * int(gPlanetsId) + i];
        vec3 q = p - center;
        float s = sdSphere(q, 1.0);
        if (s < 1.0) {
            vec2 uv = uvSphere(normalize(q));
            float seed = gPlanetPalD.x * gPlanetsId + gPlanetPalD.y * float(i);
            s -= 0.05 * hPlanetsMix(uv, seed);
        }
        d = min(d, s);
    }

    return d;
}

vec2 opU(vec2 d1, vec2 d2) { return (d1.x < d2.x) ? d1 : d2; }

vec2 opS(vec2 d1, vec2 d2) { return (-d1.x > d2.x) ? vec2(-d1.x, d1.y) : d2; }

vec2 opSU(vec2 d1, vec2 d2, float k) {
    float h = clamp(0.5 + 0.5 * (d2.x - d1.x) / k, 0.0, 1.0);
    return vec2(mix(d2.x, d1.x, h) - k * h * (1.0 - h), d1.y);
}

mat2 rot(float th) {
    vec2 a = sin(vec2(1.5707963, 0) + th);
    return mat2(a, -a.y, a.x);
}

#define MAT_BODY 1.0
#define MAT_FACE 2.0
#define MAT_HAND 3.0
#define MAT_BROW 4.0

// https://www.shadertoy.com/view/wslSRr
vec2 thinkingFace(vec3 p) {
    vec2 face = vec2(sdSphere(p, 1.0), MAT_BODY);

    vec3 q = p;
    q.x = abs(q.x);
    q.xz *= rot(-.3);
    q.yz *= rot(-0.25 + 0.05 * step(0.0, p.x));
    q.y *= 0.8;
    q.z *= 2.0;
    q.z -= 2.0;
    vec2 eye = vec2(sdSphere(q, .11) * 0.5, MAT_FACE);

    q = p;
    q.x = abs(q.x);
    q.xz *= rot(-.35);
    q.yz *= rot(-0.62 + 0.26 * step(0.0, p.x) + pow(abs(q.x), 1.7) * 0.5);
    q.z -= 1.0;
    vec2 brow = vec2(sdCapsule(q, vec3(0.2, 0.0, 0.0), vec3(-.2, 0.0, 0.0), .05) * 0.5, MAT_BROW);

    q = p;
    q.yz *= rot(0.2 + pow(abs(p.x), 1.8));
    q.xy *= rot(-0.25);
    q.z -= 1.0;
    vec2 mouth = vec2(sdCapsule(q, vec3(0.2, 0.0, 0.0), vec3(-.2, 0.0, 0.0), .045), MAT_BROW);

    p -= vec3(-.25, -.73, 1.0);
    p.xy *= rot(0.2);
    q = p;
    q = (q * vec3(1.2, 1.0, 2.0));
    q -= vec3(0.0, 0.01, 0.0);
    vec2 hand = vec2(sdSphere(q, .3) * 0.5, MAT_HAND);

    q = p;

    vec2 finger1 = vec2(sdCapsule(q - vec3(0.3, 0.2, 0.02), vec3(0.2, 0.0, 0.0), vec3(-.2, 0.0, 0.0), .07), MAT_HAND);
    vec2 finger2 = vec2(sdCapsule(q * vec3(1.2, 1.0, .8) - vec3(0.2, 0.06, 0.02), vec3(0.1, 0.0, 0.0), vec3(-.1, 0.0, 0.0), .08), MAT_HAND);
    vec2 finger3 = vec2(sdCapsule(q * vec3(1.2, 1.0, .8) - vec3(0.15, -0.08, 0.015), vec3(0.1, 0.0, 0.0), vec3(-.1, 0.0, 0.0), .08), MAT_HAND);
    vec2 finger4 = vec2(sdCapsule(q * vec3(1.2, 1.0, .9) - vec3(0.1, -0.2, -0.01), vec3(0.1, 0.0, 0.0), vec3(-.1, 0.0, 0.0), .08), MAT_HAND);

    p -= vec3(-0.1, 0.3, 0.0);
    q = p;
    q.x -= q.y * 0.7;

    vec2 finger5 = vec2(sdCapsule(p, vec3(0.0, -0.2, 0.0) - q, vec3(0.0, 0.2, 0.0), .1 - p.y * 0.15), MAT_HAND);
    vec2 finger = opU(finger1, opU(finger5, opSU(finger2, opSU(finger3, finger4, 0.035), 0.035)));

    hand = opSU(hand, finger, 0.02);

    vec2 d = opU(eye, face);
    d = opU(brow, d);
    d = opS(mouth, d);
    d = opU(hand, d);
    return d;
}

void transformKaneta(inout vec3 p) { p.xz = rotate(remapTo(easeInOutCubic(remapFrom(beat, 212.0, 216.0)), -1.7, 0.7)) * p.xz; }

float hKaneta(vec3 p) {
    vec2 uv = uvSphere(normalize(p));
    return fbm(uv, 20.0);
}

float dKaneta(vec3 p) {
    transformKaneta(p);

#ifdef STRIP_FIXED
    float d = sdSphere(p, 1.0);  // thinkingFace のコンパイルに時間がかかるのでSphereで代用
#else
    float d = thinkingFace(p).x;
#endif

    if (d < 1.0) {
        d -= 0.02 * hKaneta(p);
    }

    return d;
}

float sminCubic(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * h * k * (1.0 / 6.0);
}

float hFmsCat(vec3 p) {
    vec2 uv = uvSphere(normalize(p));
    vec2 grid = vec2(100.0, 50.0) * sin(remap(beat, 216.0, 220.0, 0.5, PI));
    uv = floor(uv * grid) / grid;
    return fbm(uv, 5.0);
}

float dFmsCat(vec3 p) {
    float d = sdSphere(p, 1.0);
    float k = 0.3;
    vec3 size = vec3(remap(p.y, -0.5, 1.5, 0.3, 0.5), 0.3 + 0.3 * abs(p.x), remap(p.y, 0.0, 1.3, 0.1, 0.0));
    d = sminCubic(d, sdBox(p - vec3(-0.5, 0.5, 0.0), size), k);
    d = sminCubic(d, sdBox(p - vec3(0.5, 0.5, 0.0), size), k);

    if (d < 1.0) {
        d -= 0.05 * hFmsCat(p);
    }

    return d;
}

void transformEarth(inout vec3 p) { p.xz = rotate(0.1 * beat) * p.xz; }

float hEarth(vec3 p, out vec2 uv) {
    uv = uvSphere(normalize(p));
    return fbm(uv, 10.0);
}

float dEarth(vec3 p) {
    transformEarth(p);
    float d = sdSphere(p, 1.0);

    if (d < 1.0) {
        vec2 uv;
        d -= 0.05 * hEarth(p, uv);
    }

    return d;
}

float dPlanets(vec3 p) {
    float d = INF;

    if (gPlanetsId == PLANETS_MERCURY) {
        d = min(d, dMercury(p));
    } else if (gPlanetsId == PLANETS_MIX_A || gPlanetsId == PLANETS_MIX_B) {
        d = min(d, dPlanetsMix(p));
    } else if (gPlanetsId == PLANETS_KANETA) {
        d = min(d, dKaneta(p));
    } else if (gPlanetsId == PLANETS_FMSCAT) {
        d = min(d, dFmsCat(p));
    } else if (gPlanetsId == PLANETS_EARTH) {
        d = min(d, dEarth(p));
    }

    return d;
}

vec3 opRep(in vec3 p, in vec3 c) { return mod(p + 0.5 * c, c) - 0.5 * c; }

// Rising Box by gaz
// https://www.shadertoy.com/view/MtSBRw
float dGomi(vec3 p) {
    vec3 g = vec3(floor(p.xz / 4.0), 0);
    p.xz = mod(p.xz, 4.0) - 2.0;
    float n = max(0.5, hash11(dot(g.xy, vec2(10, 180))));
    // p.y -= n * n * iTime * 7.;
    float s = 10. * hash11(dot(g.xy, vec2(5, 10)));
    if (s < 8.5) return 1.0;
    g.z = floor(p.y / s);
    p.y = mod(p.y, s) - s / 2.;
    if (hash11(dot(g, vec3(5, 70, 1))) < 0.6) return 1.0;
    float d = sdSphere(p, 0.01 * s);

    if (d < 1.0) {
        vec2 uv = uvSphere(normalize(p));
        d -= 0.05 * fbm(uv, 10.0);
    }

    return d;
}

float map(vec3 p) {
    float d = dPlanets(p);

    if (gPlanetsId != PLANETS_EARTH) {
        d = min(d, dGomi(p));
    }

    return d;
}

float logicoma(vec2 uv) {
    float d = sdCircle(uv - vec2(0.0, -0.5), 0.05);
    d = min(d, sdCircle(uv - vec2(-0.5, 0.5), 0.05));
    d = min(d, sdCircle(uv - vec2(0.5, 0.5), 0.05));
    return d < 0.0 ? 1.0 : 0.0;
}

float dMenger(vec3 z0, vec3 offset, float scale) {
    vec4 z = vec4(z0, 1.0);
    for (int n = 0; n < 4; n++) {
        z = abs(z);

        if (z.x < z.y) z.xy = z.yx;
        if (z.x < z.z) z.xz = z.zx;
        if (z.y < z.z) z.yz = z.zy;

        z *= scale;
        z.xyz -= offset * (scale - 1.0);

        if (z.z < -0.5 * offset.z * (scale - 1.0)) {
            z.z += offset.z * (scale - 1.0);
        }
    }
    return (length(max(abs(z.xyz) - vec3(1.0, 1.0, 1.0), 0.0)) - 0.05) / z.w;
}

uniform float gYosshinX;   // 2.071136418317427 0 5
uniform float gYosshinY;   // 1.1 0 5
uniform float gYosshinZ;   // 0.8 0 5
uniform float gYosshinS;   // 2.6 0 5
uniform float gYosshinS2;  // 0.5050689006252655 0 5

float yosshin(vec3 p) {
    p /= gYosshinS2;
    float d = dMenger(p, vec3(gYosshinX, gYosshinY, gYosshinZ), gYosshinS);
    return d < 0.0 ? 1.0 : 0.0;
}

uniform float gF0;                    // 0.95 0 1 lighting
uniform float gCameraLightIntensity;  // 1 0 10

float fresnelSchlick(float f0, float cosTheta) { return f0 + (1.0 - f0) * pow((1.0 - cosTheta), 5.0); }

void intersectObjects(inout Intersection intersection, inout Ray ray) {
    float d;
    float distance = 0.0;
    vec3 p = ray.origin;
    float eps = 0.02;

    for (float i = 0.0; i < 200.0; i++) {
        d = map(p);
        distance += d;
        p = ray.origin + distance * ray.direction;
        intersection.count = i;
        if (d < eps) break;
    }

    if (d < eps) {
        intersection.distance = distance;
        intersection.hit = true;
        intersection.position = p;
        intersection.normal = calcNormal(p, map, gSceneEps);

        if (dPlanets(p) < eps) {
            if (gPlanetsId == PLANETS_MERCURY) {
                intersection.baseColor = vec3(0.7);
                intersection.roughness = 0.4;
                intersection.metallic = 0.01;
                intersection.emission = vec3(0.0);
            } else if (gPlanetsId == PLANETS_MIX_A || gPlanetsId == PLANETS_MIX_B) {
                int id;
                vec2 uv;
                vec3 dir;
                vec3 offset;

                for (int i = 0; i < planetNums[int(gPlanetsId)]; i++) {
                    vec3 center = planetCenters[PLANETS_NUM_MAX * int(gPlanetsId) + i];
                    offset = p - center;
                    float d = sdSphere(offset, 1.0);
                    if (abs(d) < eps * 100.0) {
                        id = i;
                        dir = normalize(offset);
                        uv = uvSphere(dir);
                        break;
                    }
                }

                float seed = gPlanetPalD.x * gPlanetsId + gPlanetPalD.y * float(id);
                float h = hPlanetsMix(uv, seed);
                vec3 rand = hash31(seed);
                intersection.baseColor = pal(h, gPlanetPalA, gPlanetPalB, gPlanetPalC, rand);
                intersection.roughness = 0.4;
                intersection.metallic = 0.8 * rand.x;
                intersection.emission = vec3(0.0);
                // intersection.normal = calcNormal(p, dPlanetsMix, 0.01);

                if (gPlanetsId == PLANETS_MIX_B && id == 4) {
                    intersection.emission = vec3(0.5, 0.5, 0.8) * logicoma(dir.xy);
                }

                if (gPlanetsId == PLANETS_MIX_B && id == 2) {
                    intersection.baseColor = vec3(0.1);
                    intersection.emission = vec3(0.3, 0.3, 0.5) * yosshin(offset);
                    intersection.metallic = 0.5;
                }
            } else if (gPlanetsId == PLANETS_KANETA) {
                transformKaneta(p);
                float h = hKaneta(p);
                intersection.baseColor = mix(vec3(0.8, 0.5, 0.2), vec3(0.9, 0.95, 0.5), h);
                intersection.roughness = 0.4;
                intersection.metallic = 0.01;
                intersection.emission = vec3(0.0);
            } else if (gPlanetsId == PLANETS_FMSCAT) {
                float h = hFmsCat(p);
                intersection.baseColor = pal(sin(h * remap(beat, 216.0, 220.0, 1.0, 5.0) + 0.25 * beat * TAU), vec3(0.5, 0.5, 0.5), vec3(0.5, 0.5, 0.5), vec3(1.0, 1.0, 1.0), vec3(0.0, 0.33, 0.67));
                intersection.roughness = 0.4;
                intersection.metallic = 0.01;
                intersection.emission = 0.2 * intersection.baseColor;
            } else if (gPlanetsId == PLANETS_EARTH) {
                transformEarth(p);
                vec2 uv;
                float h = hEarth(p, uv);

                if (h > 0.67) {
                    // land
                    intersection.baseColor = mix(vec3(0.03, 0.21, 0.14), vec3(240., 204., 170.) / 255., remapFrom(h, 0.72, 0.99));
                    intersection.roughness = 0.4;
                    intersection.metallic = 0.01;
                    intersection.emission = vec3(0.0);
                    intersection.emission = vec3(0.07, 0.1, 0.07) * remapFrom(h, 0.67, 0.8);
                } else {
                    // sea
                    intersection.baseColor = mix(vec3(0.01, 0.03, 0.05), vec3(3.0, 18.0, 200.0) / 255.0, remapFrom(h, 0.0, 0.6));
                    intersection.roughness = 0.1;
                    intersection.metallic = 0.134;
                    intersection.emission = vec3(0.1, 0.3, 1.0) * remapFrom(h, 0.1, 0.67);
                }

                intersection.emission *= fresnelSchlick(0.15, saturate(dot(-ray.direction, intersection.normal)));

                float cloud = fbm(uv, 15.0);
                intersection.baseColor = mix(intersection.baseColor, vec3(1.5), pow(cloud, 4.0));
            }
        } else {
            // gomi
            intersection.baseColor = vec3(0.7);
            intersection.roughness = 0.4;
            intersection.metallic = 0.01;
            intersection.emission = vec3(0.0);
        }

        intersection.transparent = false;
        intersection.refractiveIndex = 1.2;
        intersection.reflectance = 0.0;
    }
}

// http://gamedev.stackexchange.com/questions/18436/most-efficient-aabb-vs-ray-collision-algorithms
bool intersectAABB(inout Intersection intersection, inout Ray ray, vec3 lb, vec3 rt) {
    vec3 dirfrac;
    dirfrac.x = 1.0 / ray.direction.x;
    dirfrac.y = 1.0 / ray.direction.y;
    dirfrac.z = 1.0 / ray.direction.z;

    float t1 = (lb.x - ray.origin.x) * dirfrac.x;
    float t2 = (rt.x - ray.origin.x) * dirfrac.x;
    float t3 = (lb.y - ray.origin.y) * dirfrac.y;
    float t4 = (rt.y - ray.origin.y) * dirfrac.y;
    float t5 = (lb.z - ray.origin.z) * dirfrac.z;
    float t6 = (rt.z - ray.origin.z) * dirfrac.z;

    float tmin = max(max(min(t1, t2), min(t3, t4)), min(t5, t6));
    float tmax = min(min(max(t1, t2), max(t3, t4)), max(t5, t6));

    if (tmin <= tmax && 0.0 <= tmin && tmin < intersection.distance) {
        intersection.hit = true;
        intersection.position = ray.origin + ray.direction * (tmin > 0.0 ? tmin : tmax);
        intersection.distance = tmin;

        vec3 uvw = (intersection.position - lb) / (rt - lb);
        intersection.normal = vec3(0.0, 0.0, 1.0);
        intersection.uv = uvw.xy;
        return true;
    }

    return false;
}

void intersectScene(inout Intersection intersection, inout Ray ray) {
    intersection.distance = INF;
    intersectObjects(intersection, ray);

    if (beat < 224.0) {
        Intersection textIntersection = intersection;

        for (int i = 0; i < planetNums[int(gPlanetsId)]; i++) {
            vec3 center = planetCenters[PLANETS_NUM_MAX * int(gPlanetsId) + i];
            if (intersectAABB(textIntersection, ray, center + vec3(-2.0, 1.5, 0.0), center + vec3(2.0, 2.5, 0.01))) {
                vec2 uv = (2.0 * textIntersection.uv - 1.0) * vec2(1.0, 0.25);
                float id = planetTextIds[int(gPlanetsId)] + float(i);
                vec3 t = texture(iTextTexture, textUv(uv, id, vec2(0.0, 0.0), 2.0)).rgb;
                // alpha test
                if (length(t) > 0.01) {
                    intersection.emission = 0.5 * t;
                    intersection.hit = true;
                    break;
                }
            }
        }
    }
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

vec3 skyboxUniverse(vec2 uv) {
    // stars
    vec3 col = vec3(1.2) * pow(fbm(uv * 200.0), 10.0);

    float b = saturate(cos(TAU * beat / 8.0));

    float f = fractal(vec3(0.2 * uv + vec2(0.3, 0.1), 1.7 + (beat - 192.0) * 0.001), 28);
    col = mix(col, 0.3 * vec3(1.3 * f * f * f * b, 1.8 * f * f, f), f);

    f = fractal(vec3(0.2 * uv + vec2(0.8, 0.2), 2.7 + (beat - 192.0) * 0.002), 15);
    col = mix(col, 0.05 * vec3(1.9 * f * f * f, 1.3 * f * f, 1.3 * f * f), f * 0.5);

    return col;
}

void calcRadiance(inout Intersection intersection, inout Ray ray) {
    intersection.hit = false;
    intersectScene(intersection, ray);

    if (intersection.hit) {
        intersection.color = intersection.emission;
        intersection.color += evalPointLight(intersection, -ray.direction, vec3(gCameraEyeX, gCameraEyeY, gCameraEyeZ), gCameraLightIntensity * vec3(80.0, 80.0, 100.0));
        // intersection.color += evalPointLight(intersection, -ray.direction, vec3(gCameraEyeX, gCameraEyeY, gCameraEyeZ + 4.0), vec3(0.0));

        vec3 sunColor = vec3(1.0, 0.9, 0.8);
        intersection.color += evalDirectionalLight(intersection, -ray.direction, vec3(-0.48666426339228763, 0.8111071056538127, 0.3244428422615251), sunColor);

        // fog
        // intersection.color = mix(intersection.color, vec3(0.6),
        //                         1.0 - exp(-0.0001 * intersection.distance *
        //                         intersection.distance *
        //                         intersection.distance));
    } else {
        intersection.color = vec3(0.01);

        if (gSceneId == SCENE_UNIVERSE) {
            float rdo = ray.direction.y + 0.6;
            vec2 uv = (ray.direction.xz + ray.direction.xz * 250000.0 / rdo) * 0.000008;
            intersection.color += skyboxUniverse(uv);
        }
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
    if (gSceneId != SCENE_UNIVERSE) {
        vec2 uv = fragCoord / iResolution.xy;
        fragColor = texture(iPrevPass, uv);
        return;
    }

    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / min(iResolution.x, iResolution.y);
    uv = distortion(uv);

    Camera camera;
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

        bool isIncoming = dot(ray.direction, intersection.normal) < 0.0;
        vec3 orientingNormal = isIncoming ? intersection.normal : -intersection.normal;

        bool isTotalReflection = false;
        if (intersection.transparent) {
            float nnt = isIncoming ? 1.0 / intersection.refractiveIndex : intersection.refractiveIndex;
            ray.origin = intersection.position - orientingNormal * OFFSET;
            ray.direction = refract(ray.direction, orientingNormal, nnt);
            isTotalReflection = (ray.direction == vec3(0.0));
            bounce = 0;
        }

        if (isTotalReflection || !intersection.transparent) {
            ray.origin = intersection.position + orientingNormal * OFFSET;
            vec3 l = reflect(ray.direction, orientingNormal);
            reflection *= fresnelSchlick(gF0, dot(l, orientingNormal));
            ray.direction = l;
        }
    }

    fragColor = vec4(color, 1.0);
}