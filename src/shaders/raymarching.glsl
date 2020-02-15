#ifdef DEBUG_AO
#define BOUNCE_LIMIT (1)
#else
#define BOUNCE_LIMIT (2)
#endif

// consts
const float INF = 1e+10;
const float EPS = 0.2;
const float EPS_N = 1e-4;
const float OFFSET = EPS * 10.0;

const float PI = 3.14159265359;
const float TAU = 6.28318530718;
const float PIH = 1.57079632679;

const float GROUND_BASE = 0.0;

// globals
const vec3 lightDir = vec3(-0.48666426339228763, 0.8111071056538127, 0.3244428422615251);

// ray
struct Ray {
    vec3 origin;
    vec3 direction;
};

// camera
struct Camera {
    vec3 eye, target;
    vec3 forward, right, up;
    float zoom;
};

Ray cameraShootRay(Camera c, vec2 uv) {
    c.forward = normalize(c.target - c.eye);
    c.right = normalize(cross(c.forward, c.up));
    c.up = normalize(cross(c.right, c.forward));

    Ray r;
    r.origin = c.eye;
    r.direction = normalize(uv.x * c.right + uv.y * c.up + c.zoom * c.forward);

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

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
    vec3 emission;

    bool transparent;
    vec3 reflectance;
    float refractiveIndex;

    vec3 color;
};

// util

#define calcNormal(p, dFunc)                                                                                                                                                                           \
    normalize(vec2(EPS_N, -EPS_N).xyy *dFunc(p + vec2(EPS_N, -EPS_N).xyy) + vec2(EPS_N, -EPS_N).yyx * dFunc(p + vec2(EPS_N, -EPS_N).yyx) +                                                             \
              vec2(EPS_N, -EPS_N).yxy * dFunc(p + vec2(EPS_N, -EPS_N).yxy) + vec2(EPS_N, -EPS_N).xxx * dFunc(p + vec2(EPS_N, -EPS_N).xxx))

// Distance Functions
float sdBox(vec3 p, vec3 b) {
    vec3 d = abs(p) - b;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

float dSphere(vec3 p, float r) { return length(p) - r; }

mat2 rotate(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, s, -s, c);
}

float dMenger(vec3 z0, vec3 offset, float scale) {
    vec4 z = vec4(z0, 1.0);
    for (int n = 0; n < 5; n++) {
        z = abs(z);

        if (z.x < z.y)
            z.xy = z.yx;
        if (z.x < z.z)
            z.xz = z.zx;
        if (z.y < z.z)
            z.yz = z.zy;

        z *= scale;
        z.xyz -= offset * (scale - 1.0);

        if (z.z < -0.5 * offset.z * (scale - 1.0)) {
            z.z += offset.z * (scale - 1.0);
        }
    }
    return length(max(abs(z.xyz) - vec3(1.0), 0.0)) / z.w;
}

vec2 foldRotate(vec2 p, float s) {
    float a = PI / s - atan(p.x, p.y);
    float n = TAU / s;
    a = floor(a / n) * n;
    p = rotate(a) * p;
    return p;
}

vec3 opRep(vec3 p, vec3 c) { return mod(p, c) - 0.5 * c; }

float map(vec3 p) {
    p -= vec3(2.0);
    p = opRep(p, vec3(4.0, 4.0, 2.0));
    p.xy = foldRotate(p.xy, 8.0);
    float d = dMenger(p, vec3(0.8, 1.1 + 0.3 * sin(iTime), 0.5), 2.3);
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
    vec2 e = vec2(.001, 0);

    // Take some distance function measurements from either side of the hit
    // point on all three axes.
    float d1 = map(p + e.xyy), d2 = map(p - e.xyy);
    float d3 = map(p + e.yxy), d4 = map(p - e.yxy);
    float d5 = map(p + e.yyx), d6 = map(p - e.yyx);
    float d = map(p) * 2.; // The hit point itself - Doubled to cut down on
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

void intersectObjects(inout Intersection intersection, inout Ray ray) {
    float d;
    float distance = 0.0;
    vec3 p = ray.origin;

    for (float i = 0.0; i < 100.0; i++) {
        d = abs(map(p));
        distance += d;
        p = ray.origin + distance * ray.direction;
        intersection.count = i;
        if (d < EPS || distance > 100.0)
            break;
    }

    if (abs(d) < EPS && distance < intersection.distance) {
        intersection.distance = distance;
        intersection.hit = true;
        intersection.position = p;
        intersection.normal = calcNormal(p, map);
        // if (abs(map(p)) < EPS) {
        {
            intersection.ambient = vec3(0.0);
            intersection.diffuse = vec3(0.0);
            intersection.specular = vec3(0.0);

            float edge = calcEdge(p);
            intersection.emission = vec3(edge);

            intersection.transparent = false;
            intersection.reflectance = vec3(0.0);
        }
    }
}

void intersectScene(inout Intersection intersection, inout Ray ray) {
    intersection.distance = INF;
    intersectObjects(intersection, ray);
}

float calcAo(in vec3 p, in vec3 n) {
    float k = 1.0, occ = 0.0;
    for (int i = 0; i < 5; i++) {
        float len = 0.15 + float(i) * 0.15;
        float distance = map(n * len + p);
        occ += (len - distance) * k;
        k *= 0.5;
    }
    return saturate(1.0 - occ);
}

float calcShadow(in vec3 p, in vec3 rd) {
    float d;
    float distance = OFFSET;
    float bright = 1.0;
    float shadowIntensity = 0.8;
    float shadowSharpness = 10.0;

    for (int i = 0; i < 30; i++) {
        d = map(p + rd * distance);
        if (d < EPS)
            return shadowIntensity;
        bright = min(bright, shadowSharpness * d / distance);
        distance += d;
    }

    return shadowIntensity + (1.0 - shadowIntensity) * bright;
}

void calcRadiance(inout Intersection intersection, inout Ray ray, int bounce) {
    intersection.hit = false;
    intersectScene(intersection, ray);

    if (intersection.hit) {
        // shading
        float diffuse = saturate(dot(lightDir, intersection.normal));
        float specular = pow(saturate(dot(reflect(lightDir, intersection.normal), ray.direction)), 10.0);

        float ao = calcAo(intersection.position, intersection.normal);
        float shadow = calcShadow(intersection.position, lightDir);

#ifdef DEBUG_AO
        intersection.color = vec3(ao);
#else
        intersection.color = intersection.ambient * ao + intersection.diffuse * diffuse * shadow + intersection.specular * specular * shadow + intersection.emission;
#endif

        // fog
        intersection.color = mix(intersection.color, vec3(0.6), 1.0 - exp(-0.0001 * intersection.distance * intersection.distance * intersection.distance));
    } else {
        intersection.color = vec3(0.8);
    }
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / min(iResolution.x, iResolution.y);

    // camera and ray
    Camera camera;
    camera.eye = vec3(0.0, 0.0, iTime);
    camera.target = camera.eye + vec3(0.05 * sin((iTime)), 0.0, 1.0);
    camera.up = vec3(0.0, 1.0, 0.0); // y-up
    camera.zoom = 9.0;
    Ray ray = cameraShootRay(camera, uv);

    vec3 color = vec3(0.0);
    vec3 reflection = vec3(1.0);
    Intersection intersection;

    for (int bounce = 0; bounce < BOUNCE_LIMIT; bounce++) {
        calcRadiance(intersection, ray, bounce);
        color += reflection * intersection.color;
        if (!intersection.hit)
            break;
        reflection *= intersection.reflectance;

        bool isIncoming = dot(ray.direction, intersection.normal) < 0.0;
        vec3 orientingNormal = isIncoming ? intersection.normal : -intersection.normal;

        bool isTotalReflection = false;
        if (intersection.transparent) {
            float nnt = isIncoming ? 1.0 / intersection.refractiveIndex : intersection.refractiveIndex;
            ray.origin = intersection.position - orientingNormal * OFFSET;
            ray.direction = refract(ray.direction, orientingNormal, nnt);
            isTotalReflection = (ray.direction == vec3(0.0));
        }

        if (isTotalReflection || !intersection.transparent) {
            ray.origin = intersection.position + orientingNormal * OFFSET;
            ray.direction = reflect(ray.direction, orientingNormal);
        }
    }

    fragColor = vec4(color, 1.0);
}