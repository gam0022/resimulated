import { Chromatic } from "./chromatic"
import { mix, clamp, saturate, Vector3, remap, remap01, easeInOutCubic } from "./math"

// for Webpack DefinePlugin
declare var PRODUCTION: boolean;

export const chromatic = new Chromatic(
    109.714285714,// デモの長さ（秒）
    require("./shaders/vertex.glsl").default,

    // Image Shaders
    require("./shaders/common-header.glsl").default,
    [
        require("./shaders/raymarching-resimulated.glsl").default,
        require("./shaders/post-effect.glsl").default,
    ],

    // Bloom
    1,
    5,
    require("./shaders/bloom-prefilter.glsl").default,
    require("./shaders/bloom-downsample.glsl").default,
    require("./shaders/bloom-upsample.glsl").default,
    require("./shaders/bloom-final.glsl").default,

    // Sound Shader
    require("./shaders/sound-template.glsl").default,

    // Text Texture
    gl => {
        const canvas = document.createElement("canvas");
        const textCtx = canvas.getContext("2d");
        // window.document.body.appendChild(canvas);

        const texts = [
            "A 64k INTRO",
            "Graphics by gam0022",
            "Music by sadakkey",
            "RE: SIMULATED",
            "REALITY",
            "MERCURY",
            "FMS_Cat",
            "Ctrl-Alt-Test",
            "RGBA & TBC",
            "CNCD & Fairlight",
            "0x4015 & YET1",
            "kaneta\u{1F41B}",
            "gaz",
        ];

        canvas.width = 2048;
        canvas.height = 2048;
        textCtx.font = "110px arial";
        textCtx.textAlign = "center";
        textCtx.textBaseline = "middle";
        textCtx.fillStyle = "white";
        textCtx.clearRect(0, 0, canvas.width, canvas.height);

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

        if (this.input > this.begin + length) {
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

export const animateUniforms = (time: number, debugCamera: boolean, debugDisableReset: boolean) => {
    const bpm = 140;
    const beat = time * bpm / 60;

    let camera = new Vector3(0, 0, 10);
    let target = new Vector3(0, 0, 0);
    let ball = new Vector3(0, 0, -10);

    // reset values
    chromatic.uniformArray.forEach(uniform => {
        // debug時は値の毎フレームリセットをしない
        if (!PRODUCTION) {
            if (debugDisableReset) return;
            if (debugCamera && uniform.key.includes("gCamera")) return;
        }

        chromatic.uniforms[uniform.key] = uniform.initValue;
    });

    new Timeline(beat).then(8, t => {
        chromatic.uniforms.gBlend = -1.0 + easeInOutCubic(remap01(t, 0, 4));
        chromatic.uniforms.gTonemapExposure = 0.2;

        camera = new Vector3(0, 0.2, -13.0 - t * 0.1).add(Vector3.fbm(t).scale(0.01));
        target = new Vector3(0, 0, 0);

        chromatic.uniforms.gMandelboxScale = 1.8;
        chromatic.uniforms.gCameraLightIntensity = 0.4;
        chromatic.uniforms.gEmissiveIntensity = 0;
        chromatic.uniforms.gSceneEps = 0.003;
        chromatic.uniforms.gBallRadius = 0;
    }).then(8, t => {
        chromatic.uniforms.gTonemapExposure = 0.2;
        camera = new Vector3(0, 0.2, -17.0 - t * 0.1).add(Vector3.fbm(t).scale(0.01));
        target = new Vector3(0, 0, 0);

        chromatic.uniforms.gMandelboxScale = 1.8;
        chromatic.uniforms.gCameraLightIntensity = 1.2;
        chromatic.uniforms.gEmissiveIntensity = 0;
        chromatic.uniforms.gBallRadius = 0;
    }).then(16, t => {
        camera = new Vector3(-0.08503080276580499, 1.3346599987007965, -15.01732922836809).add(Vector3.fbm(t).scale(0.001));
        target = new Vector3(0.784904810273659, 3.3444920877098543, 7.36034431847018);
        chromatic.uniforms.gCameraFov = (t < 8 ? 2 : 5) + 0.05 * t;

        chromatic.uniforms.gMandelboxScale = 2.5010184112784057;
        chromatic.uniforms.gCameraLightIntensity = 1.4;
        chromatic.uniforms.gEmissiveIntensity = 0;
        chromatic.uniforms.gSceneEps = 0.0002645177773046626;
        chromatic.uniforms.gBallRadius = 0;
    }).then(16, t => {
        // ちょっとEmissive
        camera = new Vector3(0.05336320223924196, 3.2510840695253322 + 0.01 * t, -5.0872681523358665).add(Vector3.fbm(t).scale(0.001));
        target = new Vector3(-0.21247566790275868, 3.469965904363116, -0.4828265949411093);
        chromatic.uniforms.gCameraFov = 22.457765885219057;

        chromatic.uniforms.gMandelboxScale = 2.9815487838971206;
        chromatic.uniforms.gCameraLightIntensity = 0.01;
        chromatic.uniforms.gEmissiveIntensity = 1.8818642917049402;
        chromatic.uniforms.gEdgeEps = 0.0001;
        chromatic.uniforms.gEmissiveSpeed = 0.5;
        chromatic.uniforms.gBallRadius = 0;
    }).then(16, t => {
        // ちょっとEmissive2
        camera = new Vector3(-0.009156083313678657, 3.548031114215368, -5.16851465075457 + 0.5 * t).add(Vector3.fbm(t).scale(0.005));
        target = camera.add(new Vector3(0.1, 0.1, 1));
        chromatic.uniforms.gCameraFov = 23;

        chromatic.uniforms.gMandelboxScale = 2.9815487838971206;
        chromatic.uniforms.gCameraLightIntensity = 0.003;
        chromatic.uniforms.gEdgeEps = 0.0001;
        chromatic.uniforms.gEmissiveIntensity = 1.8818642917049402;
        chromatic.uniforms.gEmissiveSpeed = 0.5;
        chromatic.uniforms.gBallRadius = 0;
    }).then(16, t => {
        // 展開
        const camera1 = new Vector3(0, 2.8, -8);
        const camera2 = new Vector3(0, 0, -32);

        camera = Vector3.mix(camera1, camera2, saturate(0.1 * t));
        target = new Vector3(0, 0, 0);

        chromatic.uniforms.gMandelboxScale = 1.0 + 0.02 * t;
        chromatic.uniforms.gEmissiveIntensity = 6;
        chromatic.uniforms.gBallRadius = 0;
    }).then(16, t => {
        // Ballをズームするカット
        ball.z = -10 - 0.2 * t;
        camera = new Vector3(0, 0, 0.2 + 0.003 * t * t).add(ball).add(Vector3.fbm(t).scale(0.001));
        // camera = new Vector3(0, 0, remap01(easeInOutCubic(t / 16), -9.8, -9));
        target = ball;

        chromatic.uniforms.gMandelboxScale = 1.32 + 0 * Math.sin(t);
        chromatic.uniforms.gEmissiveIntensity = 6;
        chromatic.uniforms.gBallRadius = 0.1;
    }).then(8, t => {
        // Ballをズームするカット
        ball.z = -10 - 0.2 * t;
        camera = new Vector3(-0.2 - 0.05 * t, 0.2 + 0.05 * t, 1.0 + 0.05 * t).add(ball).add(Vector3.fbm(t).scale(0.001));
        target = ball;

        chromatic.uniforms.gMandelboxScale = 1.32 - 0.02 * t;
        chromatic.uniforms.gEmissiveIntensity = 6;
        chromatic.uniforms.gBallRadius = 0.1;
    }).then(8, t => {
        // サビ 1-1
        ball.z = -10 - 0.5 * t;
        camera = new Vector3(1, -0.2, -14).add(Vector3.fbm(t).scale(0.001));
        target = ball.add(new Vector3(-0.15, 0, 0));

        chromatic.uniforms.gMandelboxScale = 1.244560757418114;//1.2;
        chromatic.uniforms.gEmissiveIntensity = 6;
        chromatic.uniforms.gBallRadius = 0.1;
    }).then(8, t => {
        // サビ 1-2
        ball.z = -10 - 0.5 * t;
        camera = new Vector3(0.4, 0.5, -8).add(Vector3.fbm(t).scale(0.001));
        target = ball.add(new Vector3(-0.15, -0.15, 0));

        chromatic.uniforms.gMandelboxScale = 1.244560757418114;//1.2;
        chromatic.uniforms.gEmissiveIntensity = 6;
        chromatic.uniforms.gBallRadius = 0.1;
    }).then(8, t => {
        // サビ 1-3
        ball.z = -10 - 0.5 * t;
        camera = new Vector3(0, 0, -1).add(ball).add(Vector3.fbm(t).scale(0.001));
        target = ball.add(new Vector3(-0.15, 0, 0));
        chromatic.uniforms.gCameraFov = 43;

        chromatic.uniforms.gMandelboxScale = 1.2;
        chromatic.uniforms.gEmissiveIntensity = 6;
        chromatic.uniforms.gBallRadius = 0.1;

        // hue
        chromatic.uniforms.gEmissiveHueShiftBeat = 0.5;
    }).then(16, t => {
        // サビ後半
        ball.z = -20;
        camera = new Vector3(0, 0, -10).add(Vector3.fbm(t).scale(0.01));
        target = camera.add(new Vector3(0, 0, -1));

        chromatic.uniforms.gMandelboxScale = 1.2 - 0.01 * t;
        chromatic.uniforms.gEmissiveIntensity = 6;
        chromatic.uniforms.gBallRadius = 0.1;

        if (t > 8) {
            //chromatic.uniforms.gFoldRotate = 4 * 2 * Math.floor(t);
        }

        chromatic.uniforms.gEmissiveHueShiftBeat = 0.5;
        chromatic.uniforms.gEmissiveHueShiftZ = 0.3;
        chromatic.uniforms.gEmissiveHueShiftXY = 0.3;
    }).then(16, t => {
        // サビ後半
        ball.z = 10;
        camera = new Vector3(0, 0, -8 - t * 2.0).add(Vector3.fbm(t).scale(0.01));
        target = camera.add(new Vector3(0, 0, 1));

        chromatic.uniforms.gMandelboxScale = 1.2 - 0.0125 * t;
        chromatic.uniforms.gEmissiveIntensity = 6;
        chromatic.uniforms.gBallRadius = 0.1;
        chromatic.uniforms.gFoldRotate = 8;

        chromatic.uniforms.gEmissiveHueShiftBeat = 0.5;
        chromatic.uniforms.gEmissiveHueShiftZ = 0.3;
        chromatic.uniforms.gEmissiveHueShiftXY = 0.3;
    }).then(8, t => {
        // Revisonロゴ
        ball.z = -10 - 0.2 * t;
        camera = new Vector3(0, 0, 1 + 0.003 * t * t).add(ball);
        target = ball.scale(1);

        chromatic.uniforms.gMandelboxScale = 1.32 - 0.04 * t;
        chromatic.uniforms.gEmissiveIntensity = 6;
        chromatic.uniforms.gBallRadius = 0.1;

        chromatic.uniforms.gLogoIntensity = remap(t, 4, 8, 0.02, 2);
        if (t >= 7) {
            const a = Math.exp(-10 * (t - 7));
            chromatic.uniforms.gShockDistortion = a;
            chromatic.uniforms.gLogoIntensity += a;
        }

        chromatic.uniforms.gF0 = 0;
        chromatic.uniforms.gChromaticAberrationIntensity = 0.04 + 0.1 * saturate(Math.sin(Math.PI * 2 * t));
        chromatic.uniforms.gEmissiveHueShiftBeat = 0.3;
        chromatic.uniforms.gEmissiveHueShiftXY = 0.3;
    }).then(8, t => {
        // 不穏感
        ball.z = -10 - 0.2 * t;
        camera = new Vector3(-0.2 - 0.1 * t, 0.2 + 0.02 * t, 1 + 0.05 * t).add(ball).add(Vector3.fbm(t).scale(0.01));
        target = ball;
        chromatic.uniforms.gCameraFov = remap(t, 0, 8, 13, 20);

        chromatic.uniforms.gBallDistortion = remap(t, 0, 8, 0.01, 0.05);

        if (t < 2) {
            chromatic.uniforms.gBallDistortionFreq = 12;
        } else if (t < 4) {
            chromatic.uniforms.gBallDistortionFreq = 20;
        } else if (t < 6) {
            chromatic.uniforms.gBallDistortionFreq = 20 + t * 5;
        } else {
            chromatic.uniforms.gBallDistortionFreq = 30;
        }

        if (t >= 7) {
            const a = Math.exp(-10 * (t - 7));
            chromatic.uniforms.gShockDistortion = a;
        }

        chromatic.uniforms.gEmissiveHueShiftBeat = 0.3;

        chromatic.uniforms.gMandelboxScale = 1.1;
        chromatic.uniforms.gBallRadius = 0.1;
        chromatic.uniforms.gLogoIntensity = 1.0 + Math.sin(t * Math.PI * 2);
        chromatic.uniforms.gF0 = 0;
        chromatic.uniforms.gChromaticAberrationIntensity = 0.06 + 0.1 * Math.sin(10 * t);
        chromatic.uniforms.gEmissiveIntensity = 6;
    }).then(16, t => {
        // 爆発とディストーション
        ball.z = -12 - 0.2 * t;
        const a = Math.exp(-t * 0.3);
        camera = new Vector3(0.3 * a, 0.3 * a, 2 + 0.05 * t).add(ball).add(Vector3.fbm(t).scale(0.01));
        target = ball;

        const b = (t % 1);
        chromatic.uniforms.gBallDistortion = remap(t, 0, 8, 0.05, 0.1) * Math.exp(-5 * b);

        if (t < 2) {
            chromatic.uniforms.gBallDistortionFreq = 12;
        } else if (t < 4) {
            chromatic.uniforms.gBallDistortionFreq = 20;
        } else if (t < 6) {
            chromatic.uniforms.gBallDistortionFreq = 10 + t * 5;
        } else {
            chromatic.uniforms.gBallDistortionFreq = t * t;
        }

        if (t >= 4) {
            chromatic.uniforms.gShockDistortion = 4.0 * Math.exp(-10 * (t - 4));
        }

        chromatic.uniforms.gExplodeDistortion = easeInOutCubic(remap01(t, 4, 16));
        chromatic.uniforms.gBlend = easeInOutCubic(remap01(t, 13, 16));

        chromatic.uniforms.gMandelboxScale = 1.2;
        chromatic.uniforms.gEmissiveIntensity = 6;
        chromatic.uniforms.gChromaticAberrationIntensity = 0.04;

        chromatic.uniforms.gEmissiveHue = 0.01;
        chromatic.uniforms.gEmissiveHueShiftBeat = 0;
        chromatic.uniforms.gEmissiveHueShiftZ = remap01(t, 4, 16);
        chromatic.uniforms.gEmissiveHueShiftXY = remap01(t, 4, 16);
    }).then(32, t => {
        // 惑星でグリーティング
        chromatic.uniforms.gSceneId = 1;
        chromatic.uniforms.gPlanetId = 1;
        chromatic.uniforms.gSceneEps = 0.003;
        chromatic.uniforms.gTonemapExposure = 1;// あとで 1 に戻す

        camera = new Vector3(-1.38, -0.8550687112306142, 47.4).scale(Math.exp(-0.01 * t)).add(Vector3.fbm(t).scale(0.01));
        target = new Vector3(0, 0, 0);
        ball.z = 0;
        chromatic.uniforms.gCameraFov = 20 * Math.exp(-0.005 * t);

        if ((t % 4) > 3) {
            chromatic.uniforms.gGlitchIntensity = 0.05;
        }

        chromatic.uniforms.gBallRadius = 0;
        chromatic.uniforms.gBloomIntensity = 5;
        chromatic.uniforms.gBloomThreshold = 0.7;
        chromatic.uniforms.gBlend = easeInOutCubic(remap(t, 0, 8, 1, 0));
    }).then(32, t => {
        // クレジット
        chromatic.uniforms.gSceneId = 1;
        chromatic.uniforms.gSceneEps = 0.005;
        chromatic.uniforms.gTonemapExposure = 1;

        camera = new Vector3(-47.38, -0.85, 12.4).scale(Math.exp(-0.01 * t)).add(Vector3.fbm(t).scale(0.01));
        target = new Vector3(0, 0, 0);
        ball.z = 0;
        chromatic.uniforms.gCameraFov = 30 * Math.exp(-0.01 * t);

        if ((3 <= t && t < 4) || (10 <= t && t < 12) || (30 <= t && t < 32)) {
            chromatic.uniforms.gGlitchIntensity = 0.05;
        }

        chromatic.uniforms.gBallRadius = 0;
        chromatic.uniforms.gBloomIntensity = 5;
        chromatic.uniforms.gBloomThreshold = 0.7;
    }).over(t => {
        // 終わり(仮)
        chromatic.uniforms.gBlend = -1;
    });

    chromatic.uniforms.gBallZ = ball.z;

    if (!PRODUCTION && debugCamera) {
        return;
    }

    chromatic.uniforms.gCameraEyeX = camera.x;
    chromatic.uniforms.gCameraEyeY = camera.y;
    chromatic.uniforms.gCameraEyeZ = camera.z;
    chromatic.uniforms.gCameraTargetX = target.x;
    chromatic.uniforms.gCameraTargetY = target.y;
    chromatic.uniforms.gCameraTargetZ = target.z;
}