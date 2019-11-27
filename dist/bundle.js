!function(e){var n={};function r(o){if(n[o])return n[o].exports;var t=n[o]={i:o,l:!1,exports:{}};return e[o].call(t.exports,t,t.exports,r),t.l=!0,t.exports}r.m=e,r.c=n,r.d=function(e,n,o){r.o(e,n)||Object.defineProperty(e,n,{enumerable:!0,get:o})},r.r=function(e){"undefined"!=typeof Symbol&&Symbol.toStringTag&&Object.defineProperty(e,Symbol.toStringTag,{value:"Module"}),Object.defineProperty(e,"__esModule",{value:!0})},r.t=function(e,n){if(1&n&&(e=r(e)),8&n)return e;if(4&n&&"object"==typeof e&&e&&e.__esModule)return e;var o=Object.create(null);if(r.r(o),Object.defineProperty(o,"default",{enumerable:!0,value:e}),2&n&&"string"!=typeof e)for(var t in e)r.d(o,t,function(n){return e[n]}.bind(null,t));return o},r.n=function(e){var n=e&&e.__esModule?function(){return e.default}:function(){return e};return r.d(n,"a",n),n},r.o=function(e,n){return Object.prototype.hasOwnProperty.call(e,n)},r.p="",r(r.s=6)}([function(e,n,r){"use strict";r.r(n),n.default="#version 300 es\n\ninvariant gl_Position;\nin vec2 vert2d;\n\nvoid main(void) {\n  gl_Position = vec4(vert2d, 0, 1);\n}\n"},function(e,n,r){"use strict";r.r(n),n.default="#version 300 es\nprecision highp float;\nprecision highp int;\nprecision mediump sampler3D;\nuniform vec3 iResolution;\nuniform float iTime;\n\n#define saturate(x) clamp(x, 0.0, 1.0)\n#define PI 3.14159265359\n#define PI2 6.28318530718\n#define EPS 0.0001\n\n#define BPM 120.0\n#define LEN 32.0\n#define _beat (iTime * BPM / 60.0)\n#define beat (mod(_beat, LEN))\n\nfloat sdRect(vec2 p, vec2 b) {\n    vec2 d = abs(p) - b;\n    return max(d.x, d.y) + min(max(d.x, d.y), 0.0);\n}\n\nmat2 rot(float x)\n{\n    return mat2(cos(x), sin(x), -sin(x), cos(x));\n}\n\nvec3 hsv2rgb(vec3 c)\n{\n\tvec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);\n\tvec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);\n\treturn c.z * mix(K.xxx, saturate(p - K.xxx), c.y);\n}\n\nvoid mainImage( out vec4 fragColor, in vec2 fragCoord )\n{\n    vec2 p = (fragCoord.xy * 2.0 - iResolution.xy) / min(iResolution.x, iResolution.y);\n\n    // https://www.shadertoy.com/view/MdKfWR\n    vec2 q = p;\n    float d = 9999.0;\n    float z = PI2 * (beat + 16.0) / LEN;\n    for (int i = 0; i < 5; ++i) {\n        q = abs(q) - 0.5;\n        q *= rot(0.7);\n        q = abs(q) - 0.5;\n        q *= rot(z);\n        q *= 1.5;\n        float k = sdRect(q, vec2(0.5, 0.3 + q.x));\n        d = min(d, k);\n    }\n\n    float s = saturate(abs(0.2 / q.x));\n    vec3 col = hsv2rgb(vec3((beat + 16.0) / LEN, 1.0 - 0.6 * s, s)) * saturate(-2.0 * d);\n    col = pow(col * 2.0, vec3(2.0));\n    fragColor = vec4(col,1.0);\n}\n\nout vec4 outColor;\nvoid main( void ){vec4 color = vec4(0.0,0.0,0.0,1.0);mainImage( color, gl_FragCoord.xy );color.w = 1.0;outColor = color;}"},function(e,n,r){"use strict";r.r(n),n.default="#version 300 es\nprecision highp float;\nprecision highp int;\nprecision mediump sampler3D;\nuniform vec3 iResolution;\nuniform float iTime;\n\n// uniform sampler2D iPass0;\nuniform sampler2D iPrevPass;\n\nvoid mainImage( out vec4 fragColor, in vec2 fragCoord )\n{\n    // Normalized pixel coordinates (from 0 to 1)\n    vec2 uv = fragCoord / iResolution.xy;\n\n    // invert\n    vec3 col = vec3(1.0) - texture(iPrevPass, uv).rgb;\n\n    // Output to screen\n    fragColor = vec4(col, 1.0);\n}\n\nout vec4 outColor;\nvoid main( void ){vec4 color = vec4(0.0,0.0,0.0,1.0);mainImage( color, gl_FragCoord.xy );color.w = 1.0;outColor = color;}"},function(e,n,r){"use strict";r.r(n),n.default="#version 300 es\nprecision highp float;\nprecision highp int;\nprecision mediump sampler3D;\nuniform vec3 iResolution;\nuniform float iTime;\n\n// uniform sampler2D iPass0;\nuniform sampler2D iPrevPass;\n\n#define saturate(x) clamp(x, 0.0, 1.0)\n\nfloat sdCircle(vec2 p, float r) {\n    return length(p) - r;\n}\n\n// Dot Matrix\nvoid mainImage( out vec4 fragColor, in vec2 fragCoord )\n{\n    vec2 uv = (fragCoord / iResolution.xy) * 2.0 - 1.0;\n\n    float ny = 20.0;\n    float nx = ny * iResolution.x / iResolution.y;\n    vec2 num = vec2(nx, ny);\n\n    vec3 col;\n    vec2 uvDot = (((floor(uv * num) + 0.5) / num) + 1.0) * 0.5;\n    vec3 lum = texture(iPrevPass, uvDot).rgb;\n\n    vec2 uvGrid = fract(uv * num);\n    vec2 pGrid = uvGrid - 0.5;\n    col = (lum + 0.05) * 5.0 * saturate(-sdCircle(pGrid, 0.5));\n\n    fragColor = vec4(col, 1.0);\n}\n\nout vec4 outColor;\nvoid main( void ){vec4 color = vec4(0.0,0.0,0.0,1.0);mainImage( color, gl_FragCoord.xy );color.w = 1.0;outColor = color;}"},function(e,n,r){"use strict";r.r(n),n.default="#version 300 es\nprecision highp float;\nprecision highp int;\nprecision mediump sampler3D;\nuniform vec3 iResolution;\nuniform float iTime;\n\nuniform sampler2D iPrevPass;\n\nvoid mainImage( out vec4 fragColor, in vec2 fragCoord )\n{\n    // Normalized pixel coordinates (from 0 to 1)\n    vec2 uv = fragCoord / iResolution.xy;\n\n    vec3 col;\n\n    vec2 offset = vec2(1.0, 1.0) * 0.01;\n    col.r = texture(iPrevPass, uv - offset).r;\n    col.g = texture(iPrevPass, uv).g;\n    col.b = texture(iPrevPass, uv + offset).b;\n\n    // Output to screen\n    fragColor = vec4(col, 1.0);\n}\n\nout vec4 outColor;\nvoid main( void ){vec4 color = vec4(0.0,0.0,0.0,1.0);mainImage( color, gl_FragCoord.xy );color.w = 1.0;outColor = color;}"},function(e,n,r){"use strict";r.r(n),n.default="body{background-color:#000;margin:0;padding:0;color:#fff}canvas{display:block;position:absolute;top:0;left:0;right:0;bottom:0;margin:auto}#c{display:none}"},function(e,n,r){"use strict";var o;r.r(n),function(e){e[e.Image=0]="Image",e[e.FinalImage=1]="FinalImage",e[e.Audio=2]="Audio"}(o||(o={}));var t=function(){},i=function(){function e(e,n){var r=this;this.isPlaying=!0,this.time=0;var i=document.createElement("canvas");i.width=window.innerWidth,i.height=window.innerHeight,window.document.body.appendChild(i),this.uniforms={iResolution:{type:"v3",value:[i.width,i.height,0]},iTime:{type:"f",value:0},iPrevPass:{type:"t",value:0}};var a=this.gl=i.getContext("webgl2");if(a){a.enable(a.CULL_FACE);var u=[[1,1],[-1,1],[1,-1],[-1,-1]],c=new Float32Array([].concat.apply([],u)),l=a.createBuffer();a.bindBuffer(a.ARRAY_BUFFER,l),a.bufferData(a.ARRAY_BUFFER,c,a.STATIC_DRAW),a.bindBuffer(a.ARRAY_BUFFER,null);var f=[[0,1,2],[3,2,1]],s=new Uint16Array([].concat.apply([],f)),v=a.createBuffer();a.bindBuffer(a.ELEMENT_ARRAY_BUFFER,v),a.bufferData(a.ELEMENT_ARRAY_BUFFER,s,a.STATIC_DRAW),a.bindBuffer(a.ELEMENT_ARRAY_BUFFER,null);var d=a.createVertexArray(),m=function(e,n){var r=a.createShader(n);return a.shaderSource(r,e),a.compileShader(r),a.getShaderParameter(r,a.COMPILE_STATUS)||console.log(e,a.getShaderInfoLog(r)),r},g=function(e,n,o){!function(e){a.bindVertexArray(d),a.bindBuffer(a.ARRAY_BUFFER,l),a.bindBuffer(a.ELEMENT_ARRAY_BUFFER,v);var n=a.getAttribLocation(e,"vert2d"),r=a.FLOAT,o=u[0].length,t=o*Float32Array.BYTES_PER_ELEMENT;a.enableVertexAttribArray(n),a.vertexAttribPointer(n,o,r,!1,t,0),a.bindVertexArray(null)}(e);var c=new t;return c.type=o,c.index=n,c.program=e,c.locations=function(e){var n={};return Object.keys(r.uniforms).forEach((function(r){n[r]=a.getUniformLocation(e,r)})),n}(e),r.setupFrameBuffer(c,i.width,i.height),c};n.forEach((function(e,n){r.uniforms["iPass"+n]={type:"t",value:n}})),this.imagePasses=n.map((function(n,r,t){return g((i=n,u=[m(e,a.VERTEX_SHADER),m(i,a.FRAGMENT_SHADER)],c=a.createProgram(),u.forEach((function(e){return a.attachShader(c,e)})),a.linkProgram(c),a.getProgramParameter(c,a.LINK_STATUS)||console.log(a.getProgramInfoLog(c)),c),r,r<t.length-1?o.Image:o.FinalImage);var i,u,c}));var E=0,p=0,R=function(e){requestAnimationFrame(R);var n=.001*(e-E);(r.isPlaying||p!==r.time)&&(r.uniforms.iTime.value=r.time,r.imagePasses.forEach((function(e){return function(e){a.useProgram(e.program),a.bindFramebuffer(a.FRAMEBUFFER,e.frameBuffer),a.clear(a.COLOR_BUFFER_BIT|a.DEPTH_BUFFER_BIT);for(var n=0,o=Object.entries(r.uniforms);n<o.length;n++){var t=o[n],i=t[0],u=t[1],c="iPrevPass"===i;"t"!==u.type||c||(a.activeTexture(a.TEXTURE0+u.value),a.bindTexture(a.TEXTURE_2D,r.imagePasses[u.value].texture));var l={f:a.uniform1f,v3:a.uniform3fv,t:a.uniform1i},v=c?Math.max(e.index-1,0):u.value;l[u.type].call(a,e.locations[i],v)}a.bindVertexArray(d);var m=0*f[0].length;a.drawElements(a.TRIANGLES,s.length,a.UNSIGNED_SHORT,m);var g=a.getError();g!==a.NO_ERROR&&console.log(g),a.bindVertexArray(null),a.useProgram(null)}(e)})),r.time+=n,p=r.time),E=e};R(0)}else console.log("WebGL 2 is not supported...")}return e.prototype.setupFrameBuffer=function(e,n,r){if(e.type!==o.FinalImage){var t=this.gl;e.frameBuffer=t.createFramebuffer(),t.bindFramebuffer(t.FRAMEBUFFER,e.frameBuffer),e.texture=t.createTexture(),t.bindTexture(t.TEXTURE_2D,e.texture),t.texImage2D(t.TEXTURE_2D,0,t.RGBA,n,r,0,t.RGBA,t.UNSIGNED_BYTE,null),t.texParameteri(t.TEXTURE_2D,t.TEXTURE_MAG_FILTER,t.LINEAR),t.texParameteri(t.TEXTURE_2D,t.TEXTURE_MIN_FILTER,t.LINEAR),t.texParameteri(t.TEXTURE_2D,t.TEXTURE_WRAP_S,t.CLAMP_TO_EDGE),t.texParameteri(t.TEXTURE_2D,t.TEXTURE_WRAP_T,t.CLAMP_TO_EDGE),t.framebufferTexture2D(t.FRAMEBUFFER,t.COLOR_ATTACHMENT0,t.TEXTURE_2D,e.texture,0),t.bindTexture(t.TEXTURE_2D,null),t.bindRenderbuffer(t.RENDERBUFFER,null),t.bindFramebuffer(t.FRAMEBUFFER,null)}},e.prototype.setSize=function(e,n){},e}();window.addEventListener("load",(function(e){new i(r(0).default,[r(1).default,r(2).default,r(3).default,r(4).default]);var n=document.createElement("style");n.innerText=r(5).default,document.head.appendChild(n)}),!1)}]);