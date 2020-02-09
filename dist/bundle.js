!function(e){var n={};function t(o){if(n[o])return n[o].exports;var r=n[o]={i:o,l:!1,exports:{}};return e[o].call(r.exports,r,r.exports,t),r.l=!0,r.exports}t.m=e,t.c=n,t.d=function(e,n,o){t.o(e,n)||Object.defineProperty(e,n,{enumerable:!0,get:o})},t.r=function(e){"undefined"!=typeof Symbol&&Symbol.toStringTag&&Object.defineProperty(e,Symbol.toStringTag,{value:"Module"}),Object.defineProperty(e,"__esModule",{value:!0})},t.t=function(e,n){if(1&n&&(e=t(e)),8&n)return e;if(4&n&&"object"==typeof e&&e&&e.__esModule)return e;var o=Object.create(null);if(t.r(o),Object.defineProperty(o,"default",{enumerable:!0,value:e}),2&n&&"string"!=typeof e)for(var r in e)t.d(o,r,function(n){return e[n]}.bind(null,r));return o},t.n=function(e){var n=e&&e.__esModule?function(){return e.default}:function(){return e};return t.d(n,"a",n),n},t.o=function(e,n){return Object.prototype.hasOwnProperty.call(e,n)},t.p="",t(t.s=10)}([function(e,n,t){"use strict";t.r(n),n.default="#version 300 es\n\ninvariant gl_Position;\nin vec2 vert2d;\n\nvoid main(void) {\n    gl_Position = vec4(vert2d, 0, 1);\n}\n"},function(e,n,t){"use strict";t.r(n),n.default="#version 300 es\nprecision highp float;precision highp int;precision mediump sampler3D;\nvoid mainImage(out vec4 fragColor, in vec2 fragCoord);\nout vec4 outColor;void main(void){vec4 c;mainImage(c, gl_FragCoord.xy);outColor = c;}\n#define saturate(x) clamp(x, 0.0, 1.0)\n\nuniform vec3 iResolution;\nuniform float iTime;\nuniform sampler2D iPrevPass;\n\nvec3 tap4(sampler2D tex, vec2 uv, vec2 texelSize)\n{\n    vec4 d = texelSize.xyxy * vec4(-1.0, -1.0, 1.0, 1.0);\n\n    vec3 s;\n    s = texture(tex, uv + d.xy).rgb;\n    s += texture(tex, uv + d.zy).rgb;\n    s += texture(tex, uv + d.xw).rgb;\n    s += texture(tex, uv + d.zw).rgb;\n\n    return s * (1.0 / 4.0);\n}\n"},function(e,n,t){"use strict";t.r(n),n.default="#ifdef DEBUG_AO\n#define BOUNCE_LIMIT (1)\n#else\n#define BOUNCE_LIMIT (2)\n#endif\n\n\n// consts\nconst float INF = 1e+10;\nconst float EPS = 0.01;\nconst float EPS_N = 1e-4;\nconst float OFFSET = EPS * 10.0;\n\nconst float PI = 3.14159265359;\nconst float TAU = 6.28318530718;\nconst float PIH = 1.57079632679;\n\nconst float GROUND_BASE = 0.0;\n\n\n// globals\nconst vec3 lightDir = vec3( -0.48666426339228763, 0.8111071056538127, 0.3244428422615251 );\n\n// ray\nstruct Ray {\n    vec3 origin;\n    vec3 direction;\n};\n\n// camera\nstruct Camera {\n    vec3 eye, target;\n    vec3 forward, right, up;\n    float zoom;\n};\n\nRay cameraShootRay(Camera c, vec2 uv) {\n    c.forward = normalize(c.target - c.eye);\n    c.right = normalize(cross(c.forward, c.up));\n    c.up = normalize(cross(c.right, c.forward));\n\n    Ray r;\n    r.origin = c.eye;\n    r.direction = normalize(uv.x * c.right + uv.y * c.up + c.zoom * c.forward);\n\n    return r;\n}\n\n// intersection\nstruct Intersection {\n    bool hit;\n    vec3 position;\n    float distance;\n    vec3 normal;\n    vec2 uv;\n    float count;\n\n    vec3 ambient;\n    vec3 diffuse;\n    vec3 specular;\n    vec3 emission;\n\n    bool transparent;\n    vec3 reflectance;\n    float refractiveIndex;\n\n    vec3 color;\n};\n\n// util\n\n#define calcNormal(p, dFunc) normalize(vec2(EPS_N, -EPS_N).xyy * dFunc(p + vec2(EPS_N, -EPS_N).xyy) + vec2(EPS_N, -EPS_N).yyx * dFunc(p + vec2(EPS_N, -EPS_N).yyx ) + vec2(EPS_N, -EPS_N).yxy * dFunc(p + vec2(EPS_N, -EPS_N).yxy) + vec2(EPS_N, -EPS_N).xxx * dFunc(p + vec2(EPS_N, -EPS_N).xxx))\n\n// Distance Functions\nfloat sdBox( vec3 p, vec3 b ) {\n    vec3 d = abs(p) - b;\n    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));\n}\n\nfloat dSphere(vec3 p, float r) {\n    return length(p) - r;\n}\n\nmat2 rotate(float a) {\n\tfloat c = cos(a), s = sin(a);\n\treturn mat2(c, s, -s, c);\n}\n\nfloat dMenger(vec3 z0, vec3 offset, float scale) {\n    vec4 z = vec4(z0, 1.0);\n    for (int n = 0; n < 5; n++) {\n        z = abs(z);\n\n        if (z.x < z.y) z.xy = z.yx;\n        if (z.x < z.z) z.xz = z.zx;\n        if (z.y < z.z) z.yz = z.zy;\n\n        z *= scale;\n        z.xyz -= offset * (scale - 1.0);\n\n        if (z.z < -0.5 * offset.z * (scale - 1.0)) {\n            z.z += offset.z * (scale - 1.0);\n        }\n    }\n    return length(max(abs(z.xyz) - vec3(1.0), 0.0)) / z.w;\n}\n\nfloat dMandelFast(vec3 p, float scale, int n) {\n    vec4 q0 = vec4(p, 1.0);\n    vec4 q = q0;\n\n    for (int i = 0; i < n; i++) {\n        // q.xz = mul(rotate(_MandelRotateXZ), q.xz);\n        q.xyz = clamp( q.xyz, -1.0, 1.0 ) * 2.0 - q.xyz;\n        q = q * scale / clamp( dot( q.xyz, q.xyz ), 0.3, 1.0 ) + q0;\n    }\n\n    return length( q.xyz ) / abs( q.w );\n }\n\nvec2 foldRotate(vec2 p, float s) {\n    float a = PI / s - atan(p.x, p.y);\n    float n = TAU / s;\n    a = floor(a / n) * n;\n    p = rotate(a) * p;\n    return p;\n}\n\nvec3 opRep(vec3 p, vec3 c) {\n\treturn mod(p, c) - 0.5 * c;\n}\n\nuniform float gMandelboxScale;// 2.7 1 5\nuniform float gMandelboxRepeat;// 10 1 100\n\nfloat map(vec3 p) {;\n\tfloat d = dMandelFast(p, gMandelboxScale, int(gMandelboxRepeat));\n\treturn d;\n}\n\n// color functions\nvec3 hsv2rgb(vec3 c) {\n    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);\n    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);\n    return c.z * mix(K.xxx, saturate(p - K.xxx), c.y);\n}\n\n// https://www.shadertoy.com/view/lttGDn\nfloat calcEdge(vec3 p) {\n    float edge = 0.0;\n    vec2 e = vec2(.001, 0);\n\n    // Take some distance function measurements from either side of the hit point on all three axes.\n\tfloat d1 = map(p + e.xyy), d2 = map(p - e.xyy);\n\tfloat d3 = map(p + e.yxy), d4 = map(p - e.yxy);\n\tfloat d5 = map(p + e.yyx), d6 = map(p - e.yyx);\n\tfloat d = map(p)*2.;\t// The hit point itself - Doubled to cut down on calculations. See below.\n\n    // Edges - Take a geometry measurement from either side of the hit point. Average them, then see how\n    // much the value differs from the hit point itself. Do this for X, Y and Z directions. Here, the sum\n    // is used for the overall difference, but there are other ways. Note that it's mainly sharp surface\n    // curves that register a discernible difference.\n    edge = abs(d1 + d2 - d) + abs(d3 + d4 - d) + abs(d5 + d6 - d);\n    //edge = max(max(abs(d1 + d2 - d), abs(d3 + d4 - d)), abs(d5 + d6 - d)); // Etc.\n\n    // Once you have an edge value, it needs to normalized, and smoothed if possible. How you\n    // do that is up to you. This is what I came up with for now, but I might tweak it later.\n    edge = smoothstep(0., 1., sqrt(edge/e.x*2.));\n\n    // Return the normal.\n    // Standard, normalized gradient mearsurement.\n    return edge;\n}\n\nvoid intersectObjects(inout Intersection intersection, inout Ray ray) {\n    float d;\n    float distance = 0.0;\n    vec3 p = ray.origin;\n\n    for (float i = 0.0; i < 100.0; i++) {\n        d = abs(map(p));\n        distance += d;\n        p = ray.origin + distance * ray.direction;\n        intersection.count = i;\n        if (d < EPS || distance > 100.0) break;\n    }\n\n    if (abs(d) < EPS && distance < intersection.distance) {\n        intersection.distance = distance;\n        intersection.hit = true;\n        intersection.position = p;\n        intersection.normal = calcNormal(p, map);\n        //if (abs(map(p)) < EPS) {\n        {\n            intersection.ambient = vec3(0.5);\n            intersection.diffuse = vec3(0.3);\n            intersection.specular = vec3(0.5);\n\n            float edge = calcEdge(p);\n            intersection.emission = vec3(0.0 * edge);\n\n            intersection.transparent = false;\n            intersection.reflectance = vec3(0.0);\n        }\n    }\n}\n\nvoid intersectScene(inout Intersection intersection, inout Ray ray) {\n    intersection.distance = INF;\n    intersectObjects(intersection, ray);\n}\n\nfloat calcAo(in vec3 p, in vec3 n){\n    float k = 1.0, occ = 0.0;\n    for(int i = 0; i < 5; i++){\n        float len = 0.15 + float(i) * 0.15;\n        float distance = map(n * len + p);\n        occ += (len - distance) * k;\n        k *= 0.5;\n    }\n    return saturate(1.0 - occ);\n}\n\nfloat calcShadow(in vec3 p, in vec3 rd) {\n    float d;\n    float distance = OFFSET;\n    float bright = 1.0;\n    float shadowIntensity = 0.8;\n    float shadowSharpness = 10.0;\n\n    for (int i = 0; i < 30; i++) {\n        d = map(p + rd * distance);\n        if (d < EPS) return shadowIntensity;\n        bright = min(bright, shadowSharpness * d / distance);\n        distance += d;\n    }\n\n    return shadowIntensity + (1.0 - shadowIntensity) * bright;\n}\n\nvoid calcRadiance(inout Intersection intersection, inout Ray ray, int bounce) {\n    intersection.hit = false;\n    intersectScene(intersection, ray);\n\n    if (intersection.hit) {\n        // shading\n        float diffuse = saturate(dot(lightDir, intersection.normal));\n        float specular = pow(saturate(dot(reflect(lightDir, intersection.normal), ray.direction)), 10.0);\n\n        float ao = calcAo(intersection.position, intersection.normal);\n        float shadow = calcShadow(intersection.position, lightDir);\n\n        #ifdef DEBUG_AO\n        intersection.color = vec3(ao);\n        #else\n        intersection.color =\n            intersection.ambient * ao +\n            intersection.diffuse * diffuse * shadow +\n            intersection.specular * specular * shadow +\n            intersection.emission;\n        #endif\n\n        // fog\n        //intersection.color = mix(intersection.color, vec3(0.6),\n        //                         1.0 - exp(-0.0001 * intersection.distance * intersection.distance * intersection.distance));\n    } else {\n        intersection.color = vec3(0.8);\n    }\n}\n\nvoid mainImage(out vec4 fragColor, in vec2 fragCoord) {\n    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / min(iResolution.x, iResolution.y);\n\n    // camera and ray\n    Camera camera;\n    camera.eye = vec3(0.0, 0.0, 40.0 * sin(iTime));\n    camera.target = vec3(0.0);\n    camera.up = vec3(0.0, 1.0, 0.0);// y-up\n    camera.zoom = 9.0;\n    Ray ray = cameraShootRay(camera, uv);\n\n    vec3 color = vec3(0.0);\n    vec3 reflection = vec3(1.0);\n    Intersection intersection;\n\n    for (int bounce = 0; bounce < BOUNCE_LIMIT; bounce++) {\n        calcRadiance(intersection, ray, bounce);\n        color += reflection * intersection.color;\n        if (!intersection.hit) break;\n        reflection *= intersection.reflectance;\n\n        bool isIncoming = dot(ray.direction, intersection.normal) < 0.0;\n        vec3 orientingNormal = isIncoming ? intersection.normal : -intersection.normal;\n\n        bool isTotalReflection = false;\n        if (intersection.transparent) {\n            float nnt = isIncoming ? 1.0 / intersection.refractiveIndex : intersection.refractiveIndex;\n            ray.origin = intersection.position - orientingNormal * OFFSET;\n            ray.direction = refract(ray.direction, orientingNormal, nnt);\n            isTotalReflection = (ray.direction == vec3(0.0));\n        }\n\n        if (isTotalReflection || !intersection.transparent) {\n            ray.origin = intersection.position + orientingNormal * OFFSET;\n            ray.direction = reflect(ray.direction, orientingNormal);\n        }\n    }\n\n    fragColor = vec4(color, 1.0);\n}"},function(e,n,t){"use strict";t.r(n),n.default="void mainImage(out vec4 fragColor, in vec2 fragCoord)\n{\n    vec2 uv = fragCoord / iResolution.xy;\n    fragColor = texture(iPrevPass, uv);\n}"},function(e,n,t){"use strict";t.r(n),n.default="float brightness(vec3 c) {\n    return max(max(c.r, c.g), c.b);\n}\n\n// https://github.com/Unity-Technologies/PostProcessing/blob/v1/PostProcessing/Runtime/Components/BloomComponent.cs#L78-L109\nvoid mainImage(out vec4 fragColor, in vec2 fragCoord) {\n    float softKnee = 0.5;\n    float lthresh = 0.8;\n\n\tvec2 uv = fragCoord.xy / iResolution.xy;\n    vec4 color = texture(iPrevPass, uv);\n    vec3 m = color.rgb;\n    float br = brightness(m);\n\n    float knee = lthresh * softKnee + 1e-5f;\n    vec3 curve = vec3(lthresh - knee, knee * 2.0, 0.25 / knee);\n    float rq = clamp(br - curve.x, 0.0, curve.y);\n    rq = curve.z * rq * rq;\n\n    m *= max(rq, br - lthresh) / max(br, 1e-5);\n    fragColor = vec4(m, color.a);\n}"},function(e,n,t){"use strict";t.r(n),n.default="void mainImage(out vec4 fragColor, in vec2 fragCoord) {\n\tvec2 uv = fragCoord.xy / iResolution.xy;\n    vec2 texelSize = 1.0 / iResolution.xy;\n    fragColor = vec4(tap4(iPrevPass, uv, texelSize), 1.0);\n}"},function(e,n,t){"use strict";t.r(n),n.default="uniform sampler2D iBeforeBloom;\nuniform sampler2D iPairBloomDown;\n\nvoid mainImage(out vec4 fragColor, in vec2 fragCoord) {\n\tvec2 uv = fragCoord.xy / iResolution.xy;\n    vec2 texelSize = 1.0 / iResolution.xy * 0.25;\n    vec3 col = texture(iPairBloomDown, uv).rgb;\n    fragColor = vec4(col + tap4(iPrevPass, uv, texelSize), 1.0);\n}"},function(e,n,t){"use strict";t.r(n),n.default="uniform sampler2D iBeforeBloom;\nuniform sampler2D iPairBloomDown;\n\nuniform float gBloomIntensity;// 10 0 100\n\nvoid mainImage(out vec4 fragColor, in vec2 fragCoord) {\n\tvec2 uv = fragCoord.xy / iResolution.xy;\n    vec2 texelSize = 1.0 / iResolution.xy * 0.25;\n    vec3 col = texture(iBeforeBloom, uv).rgb;\n    vec3 pair = texture(iPairBloomDown, uv).rgb;\n    fragColor = vec4(col + pair + gBloomIntensity * tap4(iPrevPass, uv, texelSize), 1.0);\n}"},function(e,n,t){"use strict";t.r(n),n.default="#version 300 es\nprecision mediump float;\nuniform float iSampleRate;\nuniform float iBlockOffset;\n\n//--------------------\n// ここから下を書き換える\n//--------------------\n\n#define BPM 140.0\n\n#define PI 3.141592654\n#define TAU 6.283185307\n\n// ------\n// general functions\n\nfloat timeToBeat( float t ) { return t / 60.0 * BPM; }\nfloat beatToTime( float b ) { return b / BPM * 60.0; }\n\nfloat noteToFreq( float n ) {\n    return 440.0 * pow( 2.0, ( n - 69.0 ) / 12.0 );\n}\n\nfloat chord( float n ) {\n    return (\n        n < 1.0 ? 55.0 :\n        n < 2.0 ? 58.0 :\n        n < 3.0 ? 62.0 :\n                  65.0\n    );\n}\n\n// https://www.shadertoy.com/view/4djSRW\nvec4 noise( float p ) {\n    vec4 p4 = fract(vec4(p) * vec4(.1031, .1030, .0973, .1099));\n    p4 += dot(p4, p4.wzxy+33.33);\n    return fract((p4.xxyz+p4.yzzw)*p4.zywx);\n}\n\n// ------\n// primitive oscillators\n\nfloat sine( float phase ) {\n    return sin( TAU * phase );\n}\n\nfloat saw( float phase ) {\n    return 2.0 * fract( phase ) - 1.0;\n}\n\nfloat square( float phase ) {\n    return fract( phase ) < 0.5 ? -1.0 : 1.0;\n}\n\n// ------\n// drums\n\nfloat kick( float time ) {\n    float amp = exp( -5.0 * time );\n    float phase = 50.0 * time\n                - 10.0 * exp( -70.0 * time );\n    return amp * sine( phase );\n}\n\nvec2 hihat( float time ) {\n    float amp = exp( -50.0 * time );\n    return amp * noise( time * 100.0 ).xy;\n}\n\n// ------\n// synths\n\nvec2 bass( float note, float time ) {\n    float freq = noteToFreq( note );\n    return vec2( square( freq * time ) + sine( freq * time ) ) / 2.0;\n}\n\nvec2 pad( float note, float time ) {\n    float freq = noteToFreq( note );\n    float vib = 0.2 * sine( 3.0 * time );\n    return vec2(\n        saw( freq * 0.99 * time + vib ),\n        saw( freq * 1.01 * time + vib )\n    );\n}\n\nvec2 arp( float note, float time ) {\n    float freq = noteToFreq( note );\n    float fmamp = 0.1 * exp( -50.0 * time );\n    float fm = fmamp * sine( time * freq * 7.0 );\n    float amp = exp( -20.0 * time );\n    return amp * vec2(\n        sine( freq * 0.99 * time + fm ),\n        sine( freq * 1.01 * time + fm )\n    );\n}\n\n// ------\n// main\n\nvec2 mainSound( float time ) {\n    float beat = timeToBeat( time );\n    vec2 ret = vec2( 0.0 );\n\n    // ---\n    // kick\n\n    float kickTime = beatToTime( mod( beat, 1.0 ) );\n    ret += 0.8 * kick( kickTime );\n\n    float sidechain = smoothstep( 0.0, 0.4, kickTime );\n\n    // ---\n    // hihat\n\n    float hihatTime = beatToTime( mod( beat + 0.5, 1.0 ) );\n    ret += 0.5 * hihat( hihatTime );\n\n    // ---\n    // bass\n\n    float bassNote = chord( 0.0 ) - 24.0;\n    ret += sidechain * 0.6 * bass( bassNote, time );\n\n    // ---\n    // chord\n\n    ret += sidechain * 0.6 * vec2(\n        pad( chord( 0.0 ), time )\n      + pad( chord( 1.0 ), time )\n      + pad( chord( 2.0 ), time )\n      + pad( chord( 3.0 ), time )\n    ) / 4.0;\n\n    // ---\n    // arp\n\n    float arpTime = beatToTime( mod( beat, 0.25 ) );\n    float[8] arpNotes = float[](\n        69.0, 70.0, 71.0, 72.0, 69.0, 70.0, 69.0, 72.0\n    );\n    float arpNote = arpNotes[int(mod(beat, 8.0))];\n\n    ret += sidechain * 0.5 * vec2( arp( arpNote, arpTime ) );\n\n    // ---\n\n    return clamp( ret, -1.0, 1.0 );\n}\n\n//--------------------\n// ここまでを書き換える\n//--------------------\n\nout vec4 outColor;\nvoid main()\n{\n    float t = iBlockOffset + ((gl_FragCoord.x - 0.5) + (gl_FragCoord.y - 0.5) * 512.0) / iSampleRate;\n    vec2 y = mainSound(t);\n    vec2 v = floor((0.5 + 0.5 * y) * 65536.0);\n    vec2 vl = mod(v, 256.0) / 255.0;\n    vec2 vh = floor(v / 256.0) / 255.0;\n    outColor = vec4(vl.x, vh.x, vl.y, vh.y);\n}"},function(e,n,t){"use strict";t.r(n),n.default="body{background-color:#000;margin:0;padding:0;color:#fff}canvas{display:block;position:absolute;top:0;left:0;right:0;bottom:0;margin:auto}#c{display:none}"},function(e,n,t){"use strict";var o;t.r(n),function(e){e[e.Image=0]="Image",e[e.FinalImage=1]="FinalImage",e[e.Bloom=2]="Bloom",e[e.BloomUpsample=3]="BloomUpsample",e[e.Sound=4]="Sound"}(o||(o={}));var r=function(){},a=512,i=512,c=function(){function e(e,n,t,c,s,l,f,u,d,m,v,p,g){var h=this;void 0===p&&(p=[]),void 0===g&&(g={}),this.timeLength=e,this.isPlaying=!0,this.needsUpdate=!1,this.time=0;var y=this.audioContext=new window.AudioContext,x=document.createElement("canvas");x.width=window.innerWidth,x.height=window.innerHeight,window.document.body.appendChild(x);var E=this.gl=x.getContext("webgl2");if(E)if(E.getExtension("EXT_color_buffer_float"))if(E.getExtension("OES_texture_float_linear")){E.enable(E.CULL_FACE);var b=[[1,1],[-1,1],[1,-1],[-1,-1]],R=new Float32Array([].concat.apply([],b)),T=E.createBuffer();E.bindBuffer(E.ARRAY_BUFFER,T),E.bufferData(E.ARRAY_BUFFER,R,E.STATIC_DRAW),E.bindBuffer(E.ARRAY_BUFFER,null);var S=[[0,1,2],[3,2,1]],_=new Uint16Array([].concat.apply([],S)),P=E.createBuffer();E.bindBuffer(E.ELEMENT_ARRAY_BUFFER,P),E.bufferData(E.ELEMENT_ARRAY_BUFFER,_,E.STATIC_DRAW),E.bindBuffer(E.ELEMENT_ARRAY_BUFFER,null);var B=E.createVertexArray(),F=t.split("\n").length,w=function(e,n){var t=E.createShader(n);if(E.shaderSource(t,e),E.compileShader(t),!E.getShaderParameter(t,E.COMPILE_STATUS)){var o=E.getShaderInfoLog(t).replace(/(\d+):(\d+)/g,(function(e,n,t){var o=parseInt(t);return o<=F?n+":"+o+" (common header)":n+":"+(o-F)}));console.log(e,o)}return t},z=function(e){var t=[w(n,E.VERTEX_SHADER),w(e,E.FRAGMENT_SHADER)],o=E.createProgram();return t.forEach((function(e){return E.attachShader(o,e)})),E.linkProgram(o),E.getProgramParameter(o,E.LINK_STATUS)||console.log(E.getProgramInfoLog(o)),o},A=function(e,n,t,a){!function(e){E.bindVertexArray(B),E.bindBuffer(E.ARRAY_BUFFER,T),E.bindBuffer(E.ELEMENT_ARRAY_BUFFER,P);var n=E.getAttribLocation(e,"vert2d"),t=E.FLOAT,o=b[0].length,r=o*Float32Array.BYTES_PER_ELEMENT;E.enableVertexAttribArray(n),E.vertexAttribPointer(n,o,t,!1,r,0),E.bindVertexArray(null)}(e);var i=new r;if(i.type=t,i.index=n,i.scale=a,i.program=e,i.uniforms={iResolution:{type:"v3",value:[x.width*i.scale,x.height*i.scale,0]},iTime:{type:"f",value:0},iPrevPass:{type:"t",value:Math.max(i.index-1,0)},iBeforeBloom:{type:"t",value:Math.max(s-1,0)},iBlockOffset:{type:"f",value:0},iSampleRate:{type:"f",value:y.sampleRate}},h.imagePasses.forEach((function(e,n){i.uniforms["iPass"+n]={type:"t",value:n}})),t===o.BloomUpsample){var c=n-(s+l);i.uniforms.iPairBloomDown={type:"t",value:n-2*c}}return i.locations=function(e){var n={};return Object.keys(e.uniforms).forEach((function(t){n[t]=E.getUniformLocation(e.program,t)})),n}(i),h.setupFrameBuffer(i),i},I=function(e){E.useProgram(e.program),E.bindFramebuffer(E.FRAMEBUFFER,e.frameBuffer),E.clear(E.COLOR_BUFFER_BIT|E.DEPTH_BUFFER_BIT);for(var n=0,t=Object.entries(e.uniforms);n<t.length;n++){var o=t[n],r=o[0],a=o[1];"t"===a.type&&0===r.indexOf("iPass")&&(E.activeTexture(E.TEXTURE0+a.value),E.bindTexture(E.TEXTURE_2D,h.imagePasses[a.value].texture)),{f:E.uniform1f,v3:E.uniform3fv,t:E.uniform1i}[a.type].call(E,e.locations[r],a.value)}E.bindVertexArray(B);var i=0*S[0].length;E.drawElements(E.TRIANGLES,_.length,E.UNSIGNED_SHORT,i);var c=E.getError();c!==E.NO_ERROR&&console.log(c),E.bindVertexArray(null),E.useProgram(null)};0,this.imagePasses=[];var C=0;c.forEach((function(e,n,r){if(n===s){h.imagePasses.push(A(z(t+f),C,o.Bloom,1)),C++;for(var a=1,i=0;i<l;i++)a*=.5,h.imagePasses.push(A(z(t+u),C,o.Bloom,a)),C++;for(i=0;i<l-1;i++)a*=2,h.imagePasses.push(A(z(t+d),C,o.BloomUpsample,a)),C++;h.imagePasses.push(A(z(t+m),C,o.BloomUpsample,1)),C++}h.imagePasses.push(A(z(t+e),C,n<r.length-1?o.Image:o.FinalImage,1)),C++}));for(var N=y.createBuffer(2,y.sampleRate*e,y.sampleRate),U=a*i,D=y.sampleRate*e/U,O=z(v),q=A(O,0,o.Sound,1),M=0;M<D;M++){q.uniforms.iBlockOffset.value=M*U/y.sampleRate,I(q);var k=new Uint8Array(a*i*4);E.readPixels(0,0,a,i,E.RGBA,E.UNSIGNED_BYTE,k);for(var L=N.getChannelData(0),X=N.getChannelData(1),G=0;G<U;G++)L[M*U+G]=(k[4*G+0]+256*k[4*G+1])/65535*2-1,X[M*U+G]=(k[4*G+2]+256*k[4*G+3])/65535*2-1}this.audioSource=y.createBufferSource(),this.audioSource.buffer=N,this.audioSource.loop=!0,this.audioSource.connect(y.destination);var j=0,Y=0,H=function(e){requestAnimationFrame(H);var n=.001*(e-j);(h.isPlaying||Y!==h.time||h.needsUpdate)&&(h.imagePasses.forEach((function(e){e.uniforms.iTime.value=h.time,I(e)})),h.isPlaying&&(h.time+=n),Y=h.time),h.needsUpdate=!1,j=e};H(0)}else alert("need OES_texture_float_linear");else alert("need EXT_color_buffer_float");else console.log("WebGL 2 is not supported...")}return e.prototype.setupFrameBuffer=function(e){if(e.type!==o.FinalImage){var n=this.gl,t=e.uniforms.iResolution.value[0],r=e.uniforms.iResolution.value[1],c=n.FLOAT,s=n.RGBA32F,l=n.LINEAR;e.type===o.Sound&&(t=a,r=i,c=n.UNSIGNED_BYTE,s=n.RGBA,l=n.NEAREST),e.frameBuffer=n.createFramebuffer(),n.bindFramebuffer(n.FRAMEBUFFER,e.frameBuffer),e.texture=n.createTexture(),n.bindTexture(n.TEXTURE_2D,e.texture),n.texImage2D(n.TEXTURE_2D,0,s,t,r,0,n.RGBA,c,null),n.texParameteri(n.TEXTURE_2D,n.TEXTURE_MAG_FILTER,l),n.texParameteri(n.TEXTURE_2D,n.TEXTURE_MIN_FILTER,l),n.texParameteri(n.TEXTURE_2D,n.TEXTURE_WRAP_S,n.CLAMP_TO_EDGE),n.texParameteri(n.TEXTURE_2D,n.TEXTURE_WRAP_T,n.CLAMP_TO_EDGE),n.framebufferTexture2D(n.FRAMEBUFFER,n.COLOR_ATTACHMENT0,n.TEXTURE_2D,e.texture,0),n.bindTexture(n.TEXTURE_2D,null),n.bindRenderbuffer(n.RENDERBUFFER,null),n.bindFramebuffer(n.FRAMEBUFFER,null)}},e.prototype.setSize=function(e,n){},e.prototype.stopSound=function(){this.audioSource.stop()},e.prototype.playSound=function(){var e=this.audioContext.createBufferSource();e.buffer=this.audioSource.buffer,e.loop=this.audioSource.loop,e.connect(this.audioContext.destination),this.audioSource=e,this.audioSource.start(this.audioContext.currentTime,this.time%this.timeLength)},e}();window.addEventListener("load",(function(e){new c(48,t(0).default,t(1).default,[t(2).default,t(3).default],1,3,t(4).default,t(5).default,t(6).default,t(7).default,t(8).default).playSound();var n=document.createElement("style");n.innerText=t(9).default,document.head.appendChild(n)}),!1)}]);