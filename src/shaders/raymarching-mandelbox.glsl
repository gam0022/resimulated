#ifdef DEBUG_AO
#define BOUNCE_LIMIT (1)
#else
#define BOUNCE_LIMIT (2)
#endif


// consts
const float INF = 1e+10;
const float EPS = 0.01;
const float OFFSET = EPS * 10.0;

const float GROUND_BASE = 0.0;

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

    vec3 baseColor;
    float roughness;
    float reflectance;// vec3 ?
    float metallic;
    vec3 emission;

    bool transparent;
    float refractiveIndex;

    vec3 color;
};

// util

#define calcNormal(p, dFunc) normalize(vec2(gSceneEps, -gSceneEps).xyy * dFunc(p + vec2(gSceneEps, -gSceneEps).xyy) + vec2(gSceneEps, -gSceneEps).yyx * dFunc(p + vec2(gSceneEps, -gSceneEps).yyx ) + vec2(gSceneEps, -gSceneEps).yxy * dFunc(p + vec2(gSceneEps, -gSceneEps).yxy) + vec2(gSceneEps, -gSceneEps).xxx * dFunc(p + vec2(gSceneEps, -gSceneEps).xxx))

// Distance Functions
float sdBox( vec3 p, vec3 b ) {
    vec3 d = abs(p) - b;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float dSphere(vec3 p, float r) {
    return length(p) - r;
}

mat2 rotate(float a) {
	float c = cos(a), s = sin(a);
	return mat2(c, s, -s, c);
}

float dMenger(vec3 z0, vec3 offset, float scale) {
    vec4 z = vec4(z0, 1.0);
    for (int n = 0; n < 5; n++) {
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
    return length(max(abs(z.xyz) - vec3(1.0), 0.0)) / z.w;
}

float dMandelFast(vec3 p, float scale, int n) {
    vec4 q0 = vec4(p, 1.0);
    vec4 q = q0;

    for (int i = 0; i < n; i++) {
        // q.xz = mul(rotate(_MandelRotateXZ), q.xz);
        q.xyz = clamp( q.xyz, -1.0, 1.0 ) * 2.0 - q.xyz;
        q = q * scale / clamp( dot( q.xyz, q.xyz ), 0.3, 1.0 ) + q0;
    }

    return length( q.xyz ) / abs( q.w );
 }

vec2 foldRotate(vec2 p, float s) {
    float a = PI / s - atan(p.x, p.y);
    float n = TAU / s;
    a = floor(a / n) * n;
    p = rotate(a) * p;
    return p;
}

vec3 opRep(vec3 p, vec3 c) {
	return mod(p, c) - 0.5 * c;
}

uniform float gMandelboxScale;// 2.7 1 5
uniform float gMandelboxRepeat;// 10 1 100

float map(vec3 p) {;
	float d = dMandelFast(p, gMandelboxScale, int(gMandelboxRepeat));
	return d;
}

// color functions
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, saturate(p - K.xxx), c.y);
}

uniform float gEdgeEps;// 0.0005 0.0001 0.01

// https://www.shadertoy.com/view/lttGDn
float calcEdge(vec3 p) {
    float edge = 0.0;
    vec2 e = vec2(gEdgeEps, 0);

    // Take some distance function measurements from either side of the hit point on all three axes.
	float d1 = map(p + e.xyy), d2 = map(p - e.xyy);
	float d3 = map(p + e.yxy), d4 = map(p - e.yxy);
	float d5 = map(p + e.yyx), d6 = map(p - e.yyx);
	float d = map(p)*2.;	// The hit point itself - Doubled to cut down on calculations. See below.

    // Edges - Take a geometry measurement from either side of the hit point. Average them, then see how
    // much the value differs from the hit point itself. Do this for X, Y and Z directions. Here, the sum
    // is used for the overall difference, but there are other ways. Note that it's mainly sharp surface
    // curves that register a discernible difference.
    edge = abs(d1 + d2 - d) + abs(d3 + d4 - d) + abs(d5 + d6 - d);
    //edge = max(max(abs(d1 + d2 - d), abs(d3 + d4 - d)), abs(d5 + d6 - d)); // Etc.

    // Once you have an edge value, it needs to normalized, and smoothed if possible. How you
    // do that is up to you. This is what I came up with for now, but I might tweak it later.
    edge = smoothstep(0., 1., sqrt(edge/e.x*2.));

    // Return the normal.
    // Standard, normalized gradient mearsurement.
    return edge;
}

uniform float gSceneEps;// 0.001 0.00001 0.001

uniform float gBaseColor;// 0.5
uniform float gRoughness;// 0.1
uniform float gMetallic;// 0.4

#define beat (iTime * 2.0)

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
        if (d < eps) break;
    }

    if (distance < intersection.distance) {
        intersection.distance = distance;
        intersection.hit = true;
        intersection.position = p;
        intersection.normal = calcNormal(p, map);
        //if (abs(map(p)) < EPS) {
        {
            intersection.baseColor = vec3(gBaseColor);
            intersection.roughness = gRoughness;
            intersection.metallic = gMetallic;

            float edge = calcEdge(p);
            intersection.emission = vec3(0.5, 2.5, 0.5) * edge * saturate(cos(beat * 2.0 - mod(0.5 * intersection.position.z, TAU)));

            intersection.transparent = false;
            intersection.reflectance = 0.0;
        }
    }
}

void intersectScene(inout Intersection intersection, inout Ray ray) {
    intersection.distance = INF;
    intersectObjects(intersection, ray);
}

float calcAo(in vec3 p, in vec3 n){
    float k = 1.0, occ = 0.0;
    for(int i = 0; i < 5; i++){
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
        if (d < EPS) return shadowIntensity;
        bright = min(bright, shadowSharpness * d / distance);
        distance += d;
    }

    return shadowIntensity + (1.0 - shadowIntensity) * bright;
}


float gCameraEyeX;// 0 -100 100
float gCameraEyeY;// 2.8 -100 100
float gCameraEyeZ;// -8 -100 100

float gCameraTargetX;// 0 -100 100
float gCameraTargetY;// 2.75 -100 100
float gCameraTargetZ;// 0 -100 100

#define FLT_EPS  5.960464478e-8

float roughnessToExponent(float roughness)
{
    return clamp(2.0 * (1.0 / (roughness * roughness)) - 2.0, FLT_EPS, 1.0 / FLT_EPS);
}

vec3 evalPointLight(inout Intersection i, vec3 v, vec3 lp, vec3 radiance) {
    vec3 n = i.normal;
    vec3 p = i.position;
    vec3 ref = mix(vec3(i.reflectance), i.baseColor, i.metallic);

    vec3 l = lp - p;
    float len = length(l);
    l /= len;

    vec3 h = normalize(l + v);

    vec3 diffuse = mix(1.0 - ref, vec3(0.0), i.metallic) * i.baseColor / PI;

    float m = roughnessToExponent(i.roughness);
    vec3 specular = ref * pow(max(0.0, dot(n, h) ), m) * (m + 2.0) / (8.0 * PI);
    return (diffuse + specular) * radiance * max(0.0, dot(l, n)) / (len * len);
}

vec3 evalDirectionalLight(inout Intersection i, vec3 v, vec3 lightDir, vec3 radiance) {
    vec3 n = i.normal;
    vec3 p = i.position;
    vec3 ref = mix(vec3(i.reflectance), i.baseColor, i.metallic);

    vec3 l = lightDir;
    vec3 h = normalize(l + v);

    vec3 diffuse = mix(1.0 - ref, vec3(0.0), i.metallic) * i.baseColor / PI;

    float m = roughnessToExponent(i.roughness);
    vec3 specular = ref * pow(max(0.0, dot(n, h) ), m) * (m + 2.0) / (8.0 * PI);
    return (diffuse + specular) * radiance * max(0.0, dot(l, n));
}

void calcRadiance(inout Intersection intersection, inout Ray ray, int bounce) {
    intersection.hit = false;
    intersectScene(intersection, ray);

    if (intersection.hit) {
        intersection.color = intersection.emission;
        intersection.color += evalPointLight(intersection, -ray.direction, vec3(gCameraEyeX, gCameraEyeY, gCameraEyeZ), vec3(80.0, 80.0, 100.0));
        intersection.color += evalPointLight(intersection, -ray.direction, vec3(gCameraEyeX, gCameraEyeY, gCameraEyeZ + 4.0), vec3(0.0));
        intersection.color += evalDirectionalLight(intersection, -ray.direction, vec3(-0.48666426339228763, 0.8111071056538127, 0.3244428422615251), vec3(2.0, 1.0, 1.0));

        // fog
        //intersection.color = mix(intersection.color, vec3(0.6),
        //                         1.0 - exp(-0.0001 * intersection.distance * intersection.distance * intersection.distance));
    } else {
        intersection.color = vec3(0.01);
    }
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // test
    gCameraEyeX = 0.0;// 0 -100 100
    gCameraEyeY = 2.8;// 2.8 -100 100
    gCameraEyeZ = -8.0;// -8 -100 100

    gCameraTargetX = 0.0;// 0 -100 100
    gCameraTargetY = 2.75;// 2.75 -100 100
    gCameraTargetZ = 0.0;// 0 -100 100

    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / min(iResolution.x, iResolution.y);

    // camera and ray
    Camera camera;
    camera.eye = vec3(gCameraEyeX, gCameraEyeY, gCameraEyeZ);
    camera.target = vec3(gCameraTargetX, gCameraTargetY, gCameraTargetZ);
    camera.up = vec3(0.0, 1.0, 0.0);// y-up
    camera.zoom = 9.0;
    Ray ray = cameraShootRay(camera, uv);

    vec3 color = vec3(0.0);
    vec3 reflection = vec3(1.0);
    Intersection intersection;

    for (int bounce = 0; bounce < BOUNCE_LIMIT; bounce++) {
        calcRadiance(intersection, ray, bounce);
        color += reflection * intersection.color;
        if (!intersection.hit) break;
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