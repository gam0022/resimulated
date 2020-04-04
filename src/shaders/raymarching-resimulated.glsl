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

uniform sampler2D iTextTexture;

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

vec2 uvSphere(vec3 n) {
    float u = 0.5 + atan(n.z, n.x) / TAU;
    float v = 0.5 - asin(n.y) / PI;
    return vec2(u, v);
}

uniform float gPlanetsId;  // 0 0 4 planets
#define PLANETS_MERCURY 0.0
#define PLANETS_MIX_A 1.0
#define PLANETS_KANETA_CAT 2.0
#define PLANETS_MIX_B 3.0
#define PLANETS_EARTH 4.0

float dMercury(vec3 p) {
    vec2 uv = uvSphere(normalize(p));
    uv.x += 0.01 * beat;
    float h = fbm(uv, 10.0);
    // TODO: クレーター
    return sdSphere(p, 1.0) + 0.05 * h;
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

float dKaneta(vec3 p) {
    p.xz = rotate(0.1 * (beat - 208.)) * p.xz;
    vec2 uv = uvSphere(normalize(p));
    float h = fbm(uv, 10.0);
    return thinkingFace(p).x + 0.02 * h;
}

float dEarth(vec3 p) {
    vec2 uv = uvSphere(normalize(p));
    uv.x += 0.01 * beat;
    float h = fbm(uv, 10.0);
    return sdSphere(p, 1.0) + 0.05 * h;
}

float dPlanets(vec3 p) {
    float d = INF;

    if (gPlanetsId == PLANETS_MERCURY) {
        d = min(d, dMercury(p));
    } else if (gPlanetsId == PLANETS_KANETA_CAT) {
        d = min(d, dKaneta(p));
    } else if (gPlanetsId == PLANETS_EARTH) {
        d = min(d, dEarth(p));
    }

    return d;
}

// unused
vec3 opRep(vec3 p, vec3 c) { return mod(p, c) - 0.5 * c; }

float map(vec3 p) {
    float d = INF;

    if (gSceneId == SCENE_MANDEL) {
        d = dStage(p);
    } else if (gSceneId == SCENE_UNIVERSE) {
        d = min(d, dPlanets(p));
    }

    if (gBallRadius > 0.0) {
        d = min(d, dBall(p));
    }

    return d;
}

// color functions
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, saturate(p - K.xxx), c.y);
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

    for (float i = 0.0; i < 300.0; i++) {
        d = abs(map(p));
        distance += d;
        p = ray.origin + distance * ray.direction;
        intersection.count = i;
        eps = gSceneEps * distance;
        if (abs(d) < eps) break;
    }

    if (distance < intersection.distance) {
        intersection.distance = distance;
        intersection.hit = true;
        intersection.position = p;
        intersection.normal = calcNormal(p, map, gSceneEps);

        if (gBallRadius > 0.0 && abs(dBall(p)) < eps) {
            intersection.baseColor = vec3(0.0);
            intersection.roughness = 0.0;
            intersection.metallic = 1.0;
            intersection.emission = vec3(0.0);
            intersection.transparent = false;
            intersection.refractiveIndex = 1.2;
            intersection.reflectance = 1.0;

            if (gLogoIntensity > 0.0) {
                float b = beat - 160.0;
                float r = remapFrom(b, 0.0, 7.0);
                r = r - 1.0;
                intersection.emission = vec3(gLogoIntensity) * revisionLogo(intersection.normal.xy * 0.6, 8.0 * r);
            }
        } else if (gSceneId == SCENE_UNIVERSE) {
            if (dPlanets(p) < eps * 10.0) {
                vec3 n = normalize(p);
                vec2 uv = uvSphere(n);
                uv.x += 0.01 * beat;
                float h = fbm(uv, 10.0);

                if (gPlanetsId == PLANETS_MERCURY) {
                    intersection.baseColor = vec3(1.0);
                    intersection.roughness = 0.4;
                    intersection.metallic = 0.01;
                    intersection.emission = vec3(0.0);
                } else if (gPlanetsId == PLANETS_KANETA_CAT) {
                    intersection.baseColor = vec3(1.0, 1.0, 0.5);
                    intersection.roughness = 0.4;
                    intersection.metallic = 0.01;
                    intersection.emission = vec3(0.0);
                } else if (gPlanetsId == PLANETS_EARTH) {
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

                intersection.transparent = false;
                intersection.refractiveIndex = 1.2;
                intersection.reflectance = 0.0;
            }
        } else if (gSceneId == SCENE_MANDEL) {
            intersection.baseColor = vec3(gBaseColor);
            intersection.roughness = gRoughness;
            intersection.metallic = gMetallic;

            float edge = calcEdge(p);
            float hue = gEmissiveHue + gEmissiveHueShiftZ * p.z + gEmissiveHueShiftXY * length(p.xy) + gEmissiveHueShiftBeat * beat;
            intersection.emission = gEmissiveIntensity * hsv2rgb(vec3(hue, 0.8, 1.0)) * pow(edge, gEdgePower) * saturate(cos(beat * gEmissiveSpeed * TAU - mod(0.5 * intersection.position.z, TAU)));

            intersection.transparent = false;
            intersection.reflectance = 0.0;
        }
    }
}

bool equals(float x, float y) { return abs(x - y) < 0.0001; }

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

        // 交点座標から法線を求める
        // 高速化のためにY軸から先に判定する
        if (equals(intersection.position.y, rt.y)) {
            intersection.normal = vec3(0.0, 1.0, 0.0);
            intersection.uv = uvw.xz;
        } else if (equals(intersection.position.y, lb.y)) {
            intersection.normal = vec3(0.0, -1.0, 0.0);
            intersection.uv = uvw.xz;
        } else if (equals(intersection.position.x, lb.x)) {
            intersection.normal = vec3(-1.0, 0.0, 0.0);
            intersection.uv = uvw.zy;
        } else if (equals(intersection.position.x, rt.x)) {
            intersection.normal = vec3(1.0, 0.0, 0.0);
            intersection.uv = uvw.zy;
        } else if (equals(intersection.position.z, lb.z)) {
            intersection.normal = vec3(0.0, 0.0, -1.0);
            intersection.uv = uvw.xy;
        } else if (equals(intersection.position.z, rt.z)) {
            intersection.normal = vec3(0.0, 0.0, 1.0);
            intersection.uv = uvw.xy;
        }
        return true;
    }

    return false;
}

vec2 textUv(vec2 uv, float id, vec2 p, float scale) {
    uv -= p;
    uv /= scale;

    float offset = 128.0 / 4096.0;
    float aspect = 2048.0 / 4096.0;
    uv.x = 0.5 + 0.5 * uv.x;
    uv.y = 0.5 - 0.5 * (aspect * uv.y + 1.0 - offset);
    uv.y = clamp(uv.y + offset * id, offset * id, offset * (id + 1.0));

    return uv;
}

void intersectScene(inout Intersection intersection, inout Ray ray) {
    intersection.distance = INF;
    intersectObjects(intersection, ray);

    if (gSceneId == SCENE_UNIVERSE && beat > 200.0) {
        Intersection textIntersection = intersection;
        if (intersectAABB(textIntersection, ray, vec3(-2.0, 0.0, 0.0), vec3(2.0, 4.0, 0.01))) {
            vec2 uv = 2.0 * textIntersection.uv - 1.0;
            float id = 7.0 + floor((beat - 200.0) / 2.0);
            vec3 t = texture(iTextTexture, textUv(uv, id, vec2(0.0, 0.0), 2.0)).rgb;
            // alpha test
            if (length(t) > 0.01) {
                intersection.emission = 0.5 * t;
                intersection.hit = true;
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

        vec3 sunColor = (gSceneId == SCENE_MANDEL) ? vec3(2.0, 1.0, 1.0) : vec3(1.0, 0.9, 0.8);
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

void text(vec2 uv, inout vec3 result) {
    vec3 col = vec3(0.0);
    float b = beat - 224.0;
    float t4 = mod(b, 4.0) / 4.0;
    float t8 = mod(b, 8.0) / 8.0;
    float brightness = 1.0;

    if (b < 0.0) {
        // nop
    } else if (b < 4.0) {
        // 0-4 (4)
        // A 64k INTRO
        col += texture(iTextTexture, textUv(uv, 0.0, vec2(0.0, 0.0), 3.0)).rgb;
        col *= remap(t4, 0.5, 1.0, 1.0, 0.0);
    } else if (b < 8.0) {
        // 4-8 (4)
        // gam0022 & sadakkey
        col += texture(iTextTexture, textUv(uv, 1.0, vec2(-1.0, 0.1), 1.0)).rgb;
        col += texture(iTextTexture, textUv(uv, 2.0, vec2(-1.0, -0.1), 1.0)).rgb;

        col += texture(iTextTexture, textUv(uv, 3.0, vec2(1.0, 0.1), 1.0)).rgb;
        col += texture(iTextTexture, textUv(uv, 4.0, vec2(1.0, -0.1), 1.0)).rgb;
        col *= remap(t4, 0.5, 1.0, 1.0, 0.0);
    } else if (b < 16.0) {
        // 8-16 (8)
        // RE: SIMULATED
        col += texture(iTextTexture, textUv(uv, 5.0, vec2(0.0, 0.0), 3.0)).rgb;
        col *= remap(t8, 0.25, 1.0, 0.0, 1.0);
    } else if (b < 20.0) {
        // 16-20 (4)
        // RE: SIMULATED -> RE
        float t = remapFrom(t4, 0.5, 1.0);
        // t = easeInOutCubic(t);
        t = pow(t4, 2.0);

        vec2 glitch = vec2(0.0);
        float fade = uv.x - remapTo(t, 1.6, -0.78);
        if (fade > 0.0) {
            glitch = hash23(vec3(floor(vec2(uv.x * 32.0, uv.y * 8.0)), beat));
            glitch.x = fade * fade * remapTo(glitch.x, 0.0, 0.05);
            glitch.y = fade * fade * remapTo(glitch.y, -0.4, 0.0);
            fade = saturate(1.0 - fade) * saturate(1.0 - abs(glitch.y));
        } else {
            fade = 1.0;
        }

        float a = saturate(cos(fract(b * TAU * 4.0)));
        col.r += fade * texture(iTextTexture, textUv(uv + glitch * mix(0.5, 1.0, a), 5.0, vec2(0.0, 0.0), 3.0)).r;
        col.g += fade * texture(iTextTexture, textUv(uv + glitch * mix(1.5, 1.0, a), 5.0, vec2(0.0, 0.0), 3.0)).g;
        col.b += fade * texture(iTextTexture, textUv(uv + glitch * mix(2.0, 1.0, a), 5.0, vec2(0.0, 0.0), 3.0)).b;
    } else if (b < 24.0) {
        // 20-24 (4)
        // RE
        col += texture(iTextTexture, textUv(uv, 6.0, vec2(-0.553, 0.0), 3.0)).rgb;
        if (uv.x > -0.78) {
            col *= 0.0;
        }
        brightness = remapTo(t4, 1.0, 0.5);
    } else {
        // 24-32 (8)
        // REALITY
        col += texture(iTextTexture, textUv(uv, 6.0, vec2(-0.553, 0.0), 3.0)).rgb;
        float t = remapFrom(t8, 0.5, 0.75);
        // t = easeInOutCubic(t);
        t = pow(t, 4.0);
        if (uv.x > remapTo(t, -0.78, 1.0)) {
            col *= 0.0;
        }
        col *= remap(t8, 0.75, 1.0, 1.0, 0.0);
        brightness = remapTo(t8, 0.5, 0.0);
    }

    result *= brightness;
    result += 0.3 * col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
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

    text(uv, color);

    fragColor = vec4(color, 1.0);
}