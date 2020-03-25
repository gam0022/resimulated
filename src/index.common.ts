import { Chromatic } from "./chromatic"
import { mix, clamp, saturate, Vector3, remap, remap01, easeInOutCubic } from "./math"

// for Webpack DefinePlugin
declare var PRODUCTION: boolean;

export const chromatic = new Chromatic(
    82.28571428571429,// デモの長さ（秒）
    require("./shaders/vertex.glsl").default,
    require("./shaders/common-header.glsl").default,
    [
        //require("./shaders/kaleidoscope.glsl").default,
        require("./shaders/raymarching-mandelbox.glsl").default,
        require("./shaders/tone-mapping.glsl").default,

        //require("./shaders/kaleidoscope.glsl").default,
        //require("./shaders/invert.glsl").default,
        //require("./shaders/dot-matrix.glsl").default,
        //require("./shaders/chromatic-aberration.glsl").default,
    ],

    1,
    5,
    require("./shaders/bloom-prefilter.glsl").default,
    require("./shaders/bloom-downsample.glsl").default,
    require("./shaders/bloom-upsample.glsl").default,
    require("./shaders/bloom-final.glsl").default,

    require("./shaders/sound-template.glsl").default,
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
}

export const animateUniforms = (time: number, debugCamera: boolean, debugParams: boolean) => {
    const bpm = 140;
    const beat = time * bpm / 60;

    let camera = new Vector3(0, 0, 10);
    let target = new Vector3(0, 0, 0);

    // reset values
    chromatic.uniformArray.forEach(uniform => {
        // debug中は値のリセットをしない
        if (!PRODUCTION) {
            if (debugParams) return;
            if (debugCamera && uniform.key.includes("gCamera")) return;
        }

        chromatic.uniforms[uniform.key] = uniform.initValue;
    });

    new Timeline(beat).then(8, t => {
        camera = new Vector3(0, 0.2, -13.0 - t * 0.1).add(Vector3.fbm(t).scale(0.01));
        target = new Vector3(0, 0, 0);

        chromatic.uniforms.gMandelboxScale = 1.8;
        chromatic.uniforms.gCameraLightIntensity = 0.4;
        chromatic.uniforms.gEmissiveIntensity = 0;
        chromatic.uniforms.gSceneEps = 0.003;
        chromatic.uniforms.gBallRadius = 0;
    }).then(8, t => {
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
        camera = new Vector3(0, 0, -9.8 + 0.003 * t * t);
        // camera = new Vector3(0, 0, remap01(easeInOutCubic(t / 16), -9.8, -9));
        target = new Vector3(0, 0, -10);

        chromatic.uniforms.gMandelboxScale = 1.32 + 0 * Math.sin(t);
        chromatic.uniforms.gEmissiveIntensity = 6;
        chromatic.uniforms.gBallRadius = 0.1;
    }).then(8, t => {
        // Ballをズームするカット
        camera = new Vector3(0.2 + 0.05 * t, 0.2 + 0.05 * t, -9.0 + 0.05 * t);
        target = new Vector3(0, 0, -10);

        chromatic.uniforms.gMandelboxScale = 1.32 - 0.02 * t;
        chromatic.uniforms.gEmissiveIntensity = 6;
        chromatic.uniforms.gBallRadius = 0.1;
    }).then(1600, t => {
        camera = new Vector3(0, 0, 25.0).add(Vector3.fbm(t).scale(0.01));
        target = new Vector3(0, 0, 0);
        chromatic.uniforms.gMandelboxScale = 1.0;
        chromatic.uniforms.gEmissiveIntensity = 6;
    });

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