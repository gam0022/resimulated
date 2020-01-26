#version 300 es
precision highp float;
precision highp int;
precision mediump sampler3D;
uniform vec3 iResolution;
uniform float iTime;

#define saturate(x) clamp(x, 0.0, 1.0)
#ifdef DEBUG_AO
#define BOUNCE_LIMIT (1)
#else
#define BOUNCE_LIMIT (10)
#endif


// consts
const float INF = 1e+10;
const float EPS = 1e-3;
const float EPS_N = 1e-4;
const float OFFSET = EPS * 10.0;

const float PI = 3.14159265359;
const float TAU = 6.28318530718;
const float PIH = 1.57079632679;

const float GROUND_BASE = 0.0;


// globals
const vec3 lightDir = vec3( -0.48666426339228763, 0.8111071056538127, 0.3244428422615251 );

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

    bool transparent;
    vec3 reflectance;
    float refractiveIndex;

    vec3 color;
};

// util

#define calcNormal(p, dFunc) normalize(vec2(EPS_N, -EPS_N).xyy * dFunc(p + vec2(EPS_N, -EPS_N).xyy) + vec2(EPS_N, -EPS_N).yyx * dFunc(p + vec2(EPS_N, -EPS_N).yyx ) + vec2(EPS_N, -EPS_N).yxy * dFunc(p + vec2(EPS_N, -EPS_N).yxy) + vec2(EPS_N, -EPS_N).xxx * dFunc(p + vec2(EPS_N, -EPS_N).xxx))

float sdGround(in vec3 p) {
    return p.y + GROUND_BASE;
}

void intersectGround(inout Intersection intersection, inout Ray ray) {
    float t = -(ray.origin.y + GROUND_BASE) / ray.direction.y;
    if (t > 0.0) {
        intersection.distance = t;
        intersection.hit = true;
        intersection.position = ray.origin + t * ray.direction;
        intersection.normal = vec3(0.0, 1.0, 0.0);
        intersection.ambient = vec3(0.5) * mod(floor(intersection.position.x) + floor(intersection.position.z), 2.0);
        intersection.diffuse = vec3(0.3);
        intersection.specular = vec3(0.5);
        intersection.transparent = false;
        intersection.reflectance = vec3(0.1);
    }
}

// Distance Functions
float sdBox( vec3 p, vec3 b ) {
    vec3 d = abs(p) - b;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float dSphere(vec3 p, float r) {
    return length(p) - r;
}

float dSphereCenter(vec3 p) {
    return dSphere(p - vec3(0.0, 1.0, -0.5), 1.0);
}

float dSphereLeft(vec3 p) {
    return dSphere(p - vec3(2.5, 1.0, 0.0), 1.0);
}

float dBar(vec2 p, float width) {
    vec2 d = abs(p) - width;
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) + 0.01 * width;
}

float dCrossBar(vec3 p, float x) {
    float bar_x = dBar(p.yz, x);
    float bar_y = dBar(p.zx, x);
    float bar_z = dBar(p.xy, x);
    return min(bar_z, min(bar_x, bar_y));
}

float dMengerSponge(vec3 p) {
    float d = sdBox(p, vec3(1.0));
    float one_third = 1.0 / 3.0;
    for (float i = 0.0; i < 3.0; i++) {
        float k = pow(one_third, i);
        float kh = k * 0.5;
        d = max(d, -dCrossBar(mod(p + kh, k * 2.0) - kh, k * one_third));
    }
    return d;
}

float dMengerSpongeRight(vec3 p) {
    return dMengerSponge(p - vec3(-2.5, 1.0, 0.0));
}

float dObjects(vec3 p) {
    float d = dSphereCenter(p);
    d = min(d, dSphereLeft(p));
    d = min(d, dMengerSpongeRight(p));
    return d;
}

float dScene(vec3 p) {
    float d = dObjects(p);
    d = min(d, sdGround(p));
    return d;
}

// color functions
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, saturate(p - K.xxx), c.y);
}

void intersectObjects(inout Intersection intersection, inout Ray ray) {
    float d;
    float distance = 0.0;
    vec3 p = ray.origin;

    for (float i = 0.0; i < 100.0; i++) {
        d = abs(dObjects(p));
        distance += d;
        p = ray.origin + distance * ray.direction;
        intersection.count = i;
        if (d < EPS || distance > 100.0) break;
    }

    if (abs(d) < EPS && distance < intersection.distance) {
        intersection.distance = distance;
        intersection.hit = true;
        intersection.position = p;
        intersection.normal = calcNormal(p, dScene);
        if (abs(dSphereLeft(p)) < EPS) {
            intersection.ambient = vec3(0.0);
            intersection.diffuse = vec3(0.0);
            intersection.specular = vec3(0.5);
            intersection.transparent = false;
            intersection.reflectance = vec3(0.9);
        } else if (abs(dSphereCenter(p)) < EPS) {
            intersection.ambient = vec3(0.3, 0.3, 0.6) * 1.2 * 0.;
            intersection.diffuse = vec3(0.3, 0.3, 0.6) * 0.5 * 0.;
            intersection.specular = vec3(0.5);
            intersection.transparent = true;
            intersection.reflectance = vec3(0.8, 0.8, 1.0);
            intersection.refractiveIndex = 2.2;
        } else if (abs(dMengerSpongeRight(p)) < EPS) {
            intersection.ambient = vec3(0.1, 0.2, 0.1) * 2.0;
            intersection.diffuse = vec3(0.1, 0.2, 0.1) * 0.2;
            intersection.specular = vec3(0.0);
            intersection.transparent = false;
            intersection.reflectance = vec3(0.0);
        }
    }
}

void intersectScene(inout Intersection intersection, inout Ray ray) {
    intersection.distance = INF;
    intersectGround(intersection, ray);
    intersectObjects(intersection, ray);
}

float calcAo(in vec3 p, in vec3 n){
    float k = 1.0, occ = 0.0;
    for(int i = 0; i < 5; i++){
        float len = 0.15 + float(i) * 0.15;
        float distance = dScene(n * len + p);
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
        d = dScene(p + rd * distance);
        if (d < EPS) return shadowIntensity;
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
        intersection.color =
            intersection.ambient * ao +
            intersection.diffuse * diffuse * shadow +
            intersection.specular * specular * shadow;
        #endif

        // fog
        intersection.color = mix(intersection.color, vec3(0.6),
                                 1.0 - exp(-0.0001 * intersection.distance * intersection.distance * intersection.distance));
    } else {
        intersection.color = vec3(0.8);
    }
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / min(iResolution.x, iResolution.y);
    // vec2 mouseUV = iMouse.xy / iResolution.xy;
    float cameraR = 8.0;

    vec2 mouseUV = vec2(0.45, 0.8);

    // camera and ray
    Camera camera;
    camera.eye.x = cameraR * sin(mouseUV.y * PIH) * cos(mouseUV.x * PI + PI);
    camera.eye.z = cameraR * sin(mouseUV.y * PIH) * sin(mouseUV.x * PI + PI);
    camera.eye.y = cameraR * cos(mouseUV.y * PIH);
    camera.target = vec3(-0.3, 1.0, 0.0);
    camera.up = vec3(0.0, 1.0, 0.0);// y-up
    camera.zoom = 3.0;
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

    fragColor = vec4(color,1.0);
}

out vec4 outColor;
void main( void ){vec4 color = vec4(0.0,0.0,0.0,1.0);mainImage( color, gl_FragCoord.xy );color.w = 1.0;outColor = color;}