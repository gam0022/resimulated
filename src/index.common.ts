import { Chromatiq } from "./chromatiq"
import { mix, clamp, saturate, Vector3, remap, remapFrom, remapTo, easeInOutCubic, easeInOutCubicVelocity } from "./math"

// for Webpack DefinePlugin
declare var PRODUCTION: boolean;

export const chromatiq = new Chromatiq(
    109.714285714,// デモの長さ（秒）
    require("./shaders/build-in/vertex.glsl").default,

    // Image Shaders
    require("./shaders/common-header.glsl").default,
    [
        require("./shaders/raymarching-mandel.glsl").default,
        require("./shaders/raymarching-universe.glsl").default,
        require("./shaders/raymarching-universe-kaneta-fms-cat.glsl").default,
        require("./shaders/text-resimulated.glsl").default,
        require("./shaders/post-effect.glsl").default,
        // require("./shaders/effects/debug-circle.glsl").default,
    ],

    // Bloom
    4,
    5,
    require("./shaders/build-in/bloom-prefilter.glsl").default,
    require("./shaders/build-in/bloom-downsample.glsl").default,
    require("./shaders/build-in/bloom-upsample.glsl").default,
    require("./shaders/build-in/bloom-final.glsl").default,

    // Sound Shader
    require("./shaders/sound-resimulated.glsl").default,

    // Text Texture
    gl => {
        const canvas = document.createElement("canvas");
        const textCtx = canvas.getContext("2d");
        // window.document.body.appendChild(canvas);

        // MAX: 4096 / 128 = 32
        const texts = [
            /* 0 */ "A 64K INTRO",
            /* 1 */ "GRAPHICS",
            /* 2 */ "gam0022",
            /* 3 */ "MUSIC",
            /* 4 */ "sadakkey",
            /* 5 */ "RE: SIMULATED",
            /* 6 */ "REALITY",

            // 7
            "MERCURY",

            // 8-12
            "RGBA & TBC",
            "Ctrl-Alt-Test",
            "Conspiracy",
            "Poo-Brain",
            "Fairlight",

            // 13
            "kaneta",

            // 14
            "FMS_Cat",

            // 15-20
            String.fromCharCode(0x00BD) + "-bit Cheese",
            "Prismbeings",
            "0x4015 & YET1",
            "LJ & Alcatraz",
            "logicoma",
            "Polarity",
        ];

        canvas.width = 2048;
        canvas.height = 4096;
        textCtx.clearRect(0, 0, canvas.width, canvas.height);

        textCtx.fillStyle = "black";
        textCtx.fillRect(0, 0, canvas.width, canvas.height);

        textCtx.font = "110px arial";
        textCtx.textAlign = "center";
        textCtx.textBaseline = "middle";
        textCtx.fillStyle = "white";
        texts.forEach((text, index) => {
            textCtx.fillText(text, canvas.width / 2, 64 + index * 128);
        });

        const tex = gl.createTexture();
        gl.bindTexture(gl.TEXTURE_2D, tex);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, canvas);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        return tex;
    }
);

class Timeline {
    begin: number;
    done: boolean;

    constructor(public input: number) {
        this.begin = 0;
        this.done = false;
    }

    then(length: number, event: (offset: number) => void) {
        if (this.done || this.input < this.begin) {
            return this;
        }

        if (this.input >= this.begin + length) {
            this.begin += length;
            return this;
        }

        event(this.input - this.begin);
        this.done = true;
        return this;
    }

    over(event: (offset: number) => void) {
        if (this.done) {
            return this;
        }

        event(this.input - this.begin);
        this.done = true;
        return this;
    }
}

const Planets = {
    MERCURY: 0 as const,
    MIX_A: 1 as const,
    KANETA: 2 as const,
    FMSCAT: 3 as const,
    MIX_B: 4 as const,
    EARTH: 5 as const,
}

export const animateUniforms = (time: number, debugCamera: boolean, debugDisableReset: boolean) => {
    const bpm = 140;
    const beat = time * bpm / 60;

    let camera = new Vector3(0, 0, 10);
    let target = new Vector3(0, 0, 0);
    let ball = new Vector3(0, 0, -10);

    // reset values
    chromatiq.uniformArray.forEach(uniform => {
        // debug時は値の毎フレームリセットをしない
        if (!PRODUCTION) {
            if (debugDisableReset) return;
            if (debugCamera && uniform.key.includes("gCamera")) return;
        }

        chromatiq.uniforms[uniform.key] = uniform.initValue;
    });

    new Timeline(beat).then(8, t => {
        chromatiq.uniforms.gBlend = -1.0 + easeInOutCubic(remapFrom(t, 0, 4));
        chromatiq.uniforms.gTonemapExposure = 0.2;

        camera = new Vector3(0, 0.2, -13.0 - t * 0.1).add(Vector3.fbm(t).scale(0.01));
        target = new Vector3(0, 0, 0);

        chromatiq.uniforms.gMandelboxScale = 1.8;
        chromatiq.uniforms.gCameraLightIntensity = 0.4;
        chromatiq.uniforms.gEmissiveIntensity = 0;
        chromatiq.uniforms.gSceneEps = 0.003;
        chromatiq.uniforms.gBallRadius = 0;
    }).then(8, t => {
        chromatiq.uniforms.gTonemapExposure = 0.2;
        camera = new Vector3(0, 0.2, -17.0 - t * 0.1).add(Vector3.fbm(t).scale(0.01));
        target = new Vector3(0, 0, 0);

        chromatiq.uniforms.gMandelboxScale = 1.8;
        chromatiq.uniforms.gCameraLightIntensity = 1.2;
        chromatiq.uniforms.gEmissiveIntensity = 0;
        chromatiq.uniforms.gBallRadius = 0;

        const k = t % 8;
        let kickTime = 0;
        let kickAmp = 0;
        if (k < 1.0) {
            kickTime = k;
            kickAmp = 1;
        } else if (k < 3.5) {
        } else if (k < 4) {
            kickTime = k - 3.5;
            kickAmp = 1;
        } else if (k < 5) {
            kickTime = k - 4;
            kickAmp = 1;
        } else if (k < 7) {
        } else {
            kickTime = k - 7;
            kickAmp = 1;
        }
        chromatiq.uniforms.gCameraLightIntensity += 10 * kickAmp * Math.exp(-60 * kickTime);
    }).then(16, t => {
        camera = new Vector3(-0.08503080276580499, 1.3346599987007965, -15.01732922836809).add(Vector3.fbm(t).scale(0.001));
        target = new Vector3(0.784904810273659, 3.3444920877098543, 7.36034431847018);
        chromatiq.uniforms.gCameraFov = (t < 8 ? 2 : 5) + 0.05 * t;

        chromatiq.uniforms.gMandelboxScale = 2.5010184112784057;
        chromatiq.uniforms.gCameraLightIntensity = 1.4;
        chromatiq.uniforms.gEmissiveIntensity = 0;
        chromatiq.uniforms.gSceneEps = 0.0002645177773046626;
        chromatiq.uniforms.gBallRadius = 0;

        if (t >= 0) {
            chromatiq.uniforms.gXSfhitGlitch = 0.1 * Math.exp(-4 * (t - 0));
        }

        const k = t % 8;
        let kickTime = 0;
        let kickAmp = 0;
        if (k < 1.0) {
            kickTime = k;
            kickAmp = 1;
        } else if (k < 3.5) {
        } else if (k < 4) {
            kickTime = k - 3.5;
            kickAmp = 1;
        } else if (k < 5) {
            kickTime = k - 4;
            kickAmp = 1;
        } else if (k < 7) {
        } else {
            kickTime = k - 7;
            kickAmp = 1;
        }

        chromatiq.uniforms.gCameraLightIntensity += (t < 4 ? 5 : 60) * kickAmp * Math.exp(-60 * kickTime);

    }).then(16, t => {
        // ちょっとEmissive
        camera = new Vector3(0.05336320223924196, 3.2510840695253322 + 0.01 * t, -5.0872681523358665).add(Vector3.fbm(t).scale(0.001));
        target = new Vector3(-0.21247566790275868, 3.469965904363116, -0.4828265949411093);
        chromatiq.uniforms.gCameraFov = 22.457765885219057;

        chromatiq.uniforms.gMandelboxScale = 2.9815487838971206;
        chromatiq.uniforms.gCameraLightIntensity = 0.01;
        chromatiq.uniforms.gEmissiveIntensity = 1.8818642917049402;
        chromatiq.uniforms.gEdgeEps = 0.0001;
        chromatiq.uniforms.gEmissiveSpeed = 0.5;
        chromatiq.uniforms.gBallRadius = 0;
    }).then(16, t => {
        // ちょっとEmissive2
        camera = new Vector3(-0.009156083313678657, 3.548031114215368, -5.16851465075457 + 0.5 * t).add(Vector3.fbm(t).scale(0.005));
        target = camera.add(new Vector3(0.1, 0.1, 1));
        chromatiq.uniforms.gCameraFov = 23;

        chromatiq.uniforms.gMandelboxScale = 2.9815487838971206;
        chromatiq.uniforms.gCameraLightIntensity = 0.003;
        chromatiq.uniforms.gEdgeEps = 0.0001;
        chromatiq.uniforms.gEmissiveIntensity = 1.8818642917049402;
        chromatiq.uniforms.gEmissiveSpeed = 0.5;
        chromatiq.uniforms.gBallRadius = 0;
    }).then(16, t => {
        // 展開
        const camera1 = new Vector3(0, 2.8, -8);
        const camera2 = new Vector3(0, 0, -32);

        camera = Vector3.mix(camera1, camera2, saturate(0.1 * t));
        target = new Vector3(0, 0, 0);

        chromatiq.uniforms.gMandelboxScale = 1.0 + 0.02 * t;
        chromatiq.uniforms.gEmissiveIntensity = 6;
        chromatiq.uniforms.gBallRadius = 0;
    }).then(16, t => {
        // Ballをズームするカット
        ball.z = -10 - 0.2 * t;
        camera = new Vector3(0, 0, 0.2 + 0.003 * t * t).add(ball).add(Vector3.fbm(t).scale(0.001));
        target = ball;

        chromatiq.uniforms.gMandelboxScale = 1.32 + 0 * Math.sin(t);
        chromatiq.uniforms.gEmissiveIntensity = 6;
        chromatiq.uniforms.gBallRadius = 0.1;
    }).then(8, t => {
        // Ballをズームするカット
        ball.z = -10 - 0.2 * t;
        camera = new Vector3(-0.2 - 0.05 * t, 0.2 + 0.05 * t, 1.0 + 0.05 * t).add(ball).add(Vector3.fbm(t).scale(0.001));
        target = ball;

        chromatiq.uniforms.gMandelboxScale = 1.32 - 0.02 * t;
        chromatiq.uniforms.gEmissiveIntensity = 6;
        chromatiq.uniforms.gBallRadius = 0.1;
    }).then(8, t => {
        // サビ 1-1
        ball.z = -10 - 0.5 * t;
        camera = new Vector3(1, -0.2, -14).add(Vector3.fbm(t).scale(0.001));
        target = ball.add(new Vector3(-0.15, 0, 0));

        chromatiq.uniforms.gMandelboxScale = 1.244560757418114;//1.2;
        chromatiq.uniforms.gEmissiveIntensity = 6;
        chromatiq.uniforms.gBallRadius = 0.1;
    }).then(8, t => {
        // サビ 1-2
        ball.z = -10 - 0.5 * t;
        camera = new Vector3(0.4, 0.5, -8).add(Vector3.fbm(t).scale(0.001));
        target = ball.add(new Vector3(-0.15, -0.15, 0));

        chromatiq.uniforms.gMandelboxScale = 1.244560757418114;//1.2;
        chromatiq.uniforms.gEmissiveIntensity = 6;
        chromatiq.uniforms.gBallRadius = 0.1;
    }).then(8, t => {
        // サビ 1-3
        ball.z = -10 - 0.5 * t;
        camera = new Vector3(0, 0, -1).add(ball).add(Vector3.fbm(t).scale(0.001));
        target = ball.add(new Vector3(-0.15, 0, 0));
        chromatiq.uniforms.gCameraFov = 43;

        chromatiq.uniforms.gMandelboxScale = 1.2;
        chromatiq.uniforms.gEmissiveIntensity = 6;
        chromatiq.uniforms.gBallRadius = 0.1;

        // hue
        chromatiq.uniforms.gEmissiveHueShiftBeat = 0.5;
    }).then(16, t => {
        // サビ後半
        ball.z = -20;
        camera = new Vector3(0, 0, -10).add(Vector3.fbm(t).scale(0.01));
        target = camera.add(new Vector3(0, 0, -1));

        chromatiq.uniforms.gMandelboxScale = 1.2 - 0.01 * t;
        chromatiq.uniforms.gEmissiveIntensity = 6;
        chromatiq.uniforms.gBallRadius = 0.1;

        chromatiq.uniforms.gEmissiveHueShiftBeat = 0.5;
        chromatiq.uniforms.gEmissiveHueShiftZ = 0.3;
        chromatiq.uniforms.gEmissiveHueShiftXY = 0.3;
    }).then(16, t => {
        // サビ後半
        ball.z = 10;
        camera = new Vector3(0, 0, -8 - t * 2.0).add(Vector3.fbm(t).scale(0.01));
        target = camera.add(new Vector3(0, 0, 1));

        chromatiq.uniforms.gMandelboxScale = 1.2 - 0.0125 * t;
        chromatiq.uniforms.gEmissiveIntensity = 6;
        chromatiq.uniforms.gBallRadius = 0.1;
        chromatiq.uniforms.gFoldRotate = 8;

        chromatiq.uniforms.gEmissiveHueShiftBeat = 0.5;
        chromatiq.uniforms.gEmissiveHueShiftZ = 0.3;
        chromatiq.uniforms.gEmissiveHueShiftXY = 0.3;
    }).then(8, t => {
        // Revisonロゴ
        ball.z = -10 - 0.2 * t;
        camera = new Vector3(0, 0, 1 + 0.003 * t * t).add(ball);
        target = ball.scale(1);

        chromatiq.uniforms.gMandelboxScale = 1.32 - 0.04 * t;
        chromatiq.uniforms.gEmissiveIntensity = 6;
        chromatiq.uniforms.gBallRadius = 0.1;

        chromatiq.uniforms.gLogoIntensity = remap(t, 4, 8, 0.02, 2);
        if (t >= 7) {
            const a = Math.exp(-10 * (t - 7));
            chromatiq.uniforms.gShockDistortion = a;
            chromatiq.uniforms.gLogoIntensity += a;
        }

        chromatiq.uniforms.gF0 = 0;
        chromatiq.uniforms.gChromaticAberrationIntensity = 0.04 + 0.1 * saturate(Math.sin(Math.PI * 2 * t));
        chromatiq.uniforms.gEmissiveHueShiftBeat = 0.3;
        chromatiq.uniforms.gEmissiveHueShiftXY = 0.3;
    }).then(8, t => {
        // 不穏感
        ball.z = -10 - 0.2 * t;
        camera = new Vector3(-0.2 - 0.1 * t, 0.2 + 0.02 * t, 1 + 0.05 * t).add(ball).add(Vector3.fbm(t).scale(0.01));
        target = ball;
        chromatiq.uniforms.gCameraFov = remap(t, 0, 8, 13, 20);

        chromatiq.uniforms.gBallDistortion = remap(t, 0, 8, 0.01, 0.05);

        if (t < 2) {
            chromatiq.uniforms.gBallDistortionFreq = 12;
        } else if (t < 4) {
            chromatiq.uniforms.gBallDistortionFreq = 20;
        } else if (t < 6) {
            chromatiq.uniforms.gBallDistortionFreq = 20 + t * 5;
        } else {
            chromatiq.uniforms.gBallDistortionFreq = 30;
        }

        if (t >= 4) {
            chromatiq.uniforms.gInvertRate = Math.exp(-10 * (t - 4));
        }

        if (t >= 7) {
            const a = Math.exp(-10 * (t - 7));
            chromatiq.uniforms.gShockDistortion = a;
        }

        chromatiq.uniforms.gEmissiveHueShiftBeat = 0.3;

        chromatiq.uniforms.gMandelboxScale = 1.1;
        chromatiq.uniforms.gBallRadius = 0.1;
        chromatiq.uniforms.gLogoIntensity = 1.0 + Math.sin(t * Math.PI * 2);
        chromatiq.uniforms.gF0 = 0;
        chromatiq.uniforms.gChromaticAberrationIntensity = 0.06 + 0.1 * Math.sin(10 * t);
        chromatiq.uniforms.gEmissiveIntensity = 6;
    }).then(16, t => {
        // 爆発とディストーション
        ball.z = -12 - 0.2 * t;
        const a = Math.exp(-t * 0.3);
        camera = new Vector3(0.3 * a, 0.3 * a, 2 + 0.05 * t).add(ball).add(Vector3.fbm(t).scale(0.01));
        target = ball;

        const b = (t % 1);
        chromatiq.uniforms.gBallDistortion = remap(t, 0, 8, 0.05, 0.1) * Math.exp(-5 * b);

        chromatiq.uniforms.gFlash = 1;

        if (t < 2) {
            chromatiq.uniforms.gBallDistortionFreq = 12;
            chromatiq.uniforms.gFlashSpeed = 5;
        } else if (t < 4) {
            chromatiq.uniforms.gBallDistortionFreq = 20;
            chromatiq.uniforms.gFlashSpeed = 10;
        } else if (t < 6) {
            chromatiq.uniforms.gBallDistortionFreq = 10 + t * 5;
            chromatiq.uniforms.gFlashSpeed = 15;
        } else {
            chromatiq.uniforms.gBallDistortionFreq = t * t;
            chromatiq.uniforms.gFlashSpeed = 30;
        }

        if (t >= 4) {
            chromatiq.uniforms.gShockDistortion = 4 * Math.exp(-10 * (t - 4));
            chromatiq.uniforms.gInvertRate = Math.exp(-10 * (t - 4));
        }

        if (t >= 8) {
            chromatiq.uniforms.gInvertRate = Math.exp(-20 * (t - 8));
        }

        chromatiq.uniforms.gExplodeDistortion = easeInOutCubic(remapFrom(t, 4, 16));
        chromatiq.uniforms.gBlend = easeInOutCubic(remapFrom(t, 13, 16));

        chromatiq.uniforms.gMandelboxScale = 1.2;
        chromatiq.uniforms.gBallRadius = 0.1;
        chromatiq.uniforms.gEmissiveIntensity = 6;
        chromatiq.uniforms.gChromaticAberrationIntensity = 0.04;

        chromatiq.uniforms.gEmissiveHue = 0.01;
        chromatiq.uniforms.gEmissiveHueShiftBeat = 0;
        chromatiq.uniforms.gEmissiveHueShiftZ = remapFrom(t, 4, 16);
        chromatiq.uniforms.gEmissiveHueShiftXY = remapFrom(t, 4, 16);
    }).then(32, t => {
        // 惑星でグリーティング
        chromatiq.uniforms.gSceneId = 1;
        chromatiq.uniforms.gSceneEps = 0.002;
        chromatiq.uniforms.gTonemapExposure = 1;

        target = new Vector3(0, 0, 0);
        let scale = Math.exp(-0.01 * t);
        chromatiq.uniforms.gCameraFov = 20 * Math.exp(-0.005 * (t % 4));

        if (t < 8) {
            chromatiq.uniforms.gPlanetsId = Planets.MERCURY;
            camera = new Vector3(-1.38, -0.8550687112306142, 47.4);
            chromatiq.uniforms.gCameraFov = 20 * Math.exp(-0.005 * t);
        } else if (t < 12) {
            chromatiq.uniforms.gPlanetsId = Planets.MERCURY;
            camera = new Vector3(5, 1, 30);
            chromatiq.uniforms.gCameraFov = mix(13, 20 * Math.exp(-0.005 * t), Math.exp(-20 * (t - 8)));
            // chromatiq.uniforms.gShockDistortion = 0.3 * Math.exp(-20 * (t - 10));
        } else if (t < 20) {
            chromatiq.uniforms.gPlanetsId = Planets.MIX_A;
            const l = remapFrom(t, 13, 20);
            const e = easeInOutCubic(l);
            target = new Vector3(0, 0, remapTo(e, 0, 400));
            camera = target.add(new Vector3(5, 5, 40).scale(remapTo(e, 1, 0.8)));
            chromatiq.uniforms.gShockDistortion = 1.5 * Math.exp(-10 * (t - 12));
            scale = 1;
            // chromatiq.uniforms.gCameraFov = remapTo(easeInOutCubic(easeInOutCubicVelocity(l)), 10, 40);
            chromatiq.uniforms.gCameraFov = mix(40 * Math.exp(-0.5 * e), 13, Math.exp(-0.1 * (t - 12)));
        } else if (t < 24) {
            chromatiq.uniforms.gPlanetsId = Planets.KANETA;
            camera = new Vector3(15, 1, 20);
        } else if (t < 28) {
            chromatiq.uniforms.gPlanetsId = Planets.FMSCAT;
            camera = new Vector3(-15, 3, 20);

            if (t >= 27) {
                chromatiq.uniforms.gGlitchIntensity = 0.05 * Math.exp(-5 * (t - 27));
            }
        } else {
            chromatiq.uniforms.gPlanetsId = Planets.MIX_B;
            target = new Vector3(1, 0, 0);
            camera = new Vector3(remapTo(1 - Math.exp(-20 * (t - 28)), 10, -15), -3, 50);
            chromatiq.uniforms.gShockDistortion = 0.3 * Math.exp(-20 * (t - 28));
        }

        camera = camera.scale(scale).add(Vector3.fbm(t).scale(0.01));

        chromatiq.uniforms.gBallRadius = 0;
        chromatiq.uniforms.gBloomIntensity = 5;
        chromatiq.uniforms.gBloomThreshold = 0.7;
        chromatiq.uniforms.gBlend = remapTo(easeInOutCubic(remapFrom(t, 0, 16)), 1, 0);
    }).then(32, t => {
        // クレジット
        chromatiq.uniforms.gSceneId = 1;
        chromatiq.uniforms.gPlanetsId = Planets.EARTH;
        chromatiq.uniforms.gSceneEps = 0.005;
        chromatiq.uniforms.gTonemapExposure = 1;

        camera = new Vector3(-47.38, -0.85, 12.4).scale(Math.exp(-0.01 * t)).add(Vector3.fbm(t).scale(0.01));
        target = new Vector3(0, 0, 0);
        ball.z = 0;
        chromatiq.uniforms.gCameraFov = 30 * Math.exp(-0.01 * t);

        if (t >= 0) {
            chromatiq.uniforms.gXSfhitGlitch = 0.05 * Math.exp(-1.55 * t);
        }

        if (t >= 7) {
            chromatiq.uniforms.gGlitchIntensity = 0.05 * Math.exp(-5 * (t - 7));
        }

        if (t >= 15) {
            chromatiq.uniforms.gGlitchIntensity = 0.05 * Math.exp(-5 * (t - 15));
        }

        if (t >= 21) {
            chromatiq.uniforms.gGlitchIntensity = 0.05 * Math.exp(-5 * (t - 21));
        }

        if (t >= 26) {
            chromatiq.uniforms.gInvertRate = Math.exp(-8 * (t - 26));
        }

        if (t >= 26.5) {
            chromatiq.uniforms.gXSfhitGlitch = 0.5 * Math.exp(-6 * (t - 26.5));
        }

        if (t >= 31) {
            chromatiq.uniforms.gGlitchIntensity = 0.05 * Math.exp(-5 * (t - 31));
        }

        if (t >= 31.5) {
            chromatiq.uniforms.gXSfhitGlitch = 0.5 * Math.exp(-10 * (t - 31.5));
        }

        chromatiq.uniforms.gBallRadius = 0;
        chromatiq.uniforms.gBloomIntensity = 5;
        chromatiq.uniforms.gBloomThreshold = 0.7;
    }).over(t => {
        // デモ終了後
        chromatiq.uniforms.gBlend = -1;
    });

    chromatiq.uniforms.gBallZ = ball.z;

    if (!PRODUCTION && debugCamera) {
        return;
    }

    chromatiq.uniforms.gCameraEyeX = camera.x;
    chromatiq.uniforms.gCameraEyeY = camera.y;
    chromatiq.uniforms.gCameraEyeZ = camera.z;
    chromatiq.uniforms.gCameraTargetX = target.x;
    chromatiq.uniforms.gCameraTargetY = target.y;
    chromatiq.uniforms.gCameraTargetZ = target.z;
}