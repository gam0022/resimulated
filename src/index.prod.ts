import { Chromatic } from "./chromatic"
import { mix, clamp, saturate, Vector3 } from "./math"

// for Webpack DefinePlugin
declare var PRODUCTION: boolean;

window.addEventListener("load", ev => {
    const style = document.createElement("style");
    style.innerText = require("../dist/style.prod.min.css").default;
    document.head.appendChild(style);

    const button = document.createElement('p');
    document.body.appendChild(button);
    button.innerHTML = 'click me!';
    button.onclick = () => {
        document.body.requestFullscreen().then(() => {
            const chromatic = new Chromatic(
                48,// デモの長さ（秒）
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

            const config = { debugCamera: false };

            const animateUniforms = (time: number) => {
                const bpm = 140;
                const beat = time * bpm / 60;

                let camera = new Vector3(0, 0, 10);
                let target = new Vector3(0, 0, 0);

                if (beat < 8) {
                    const b = beat;
                    camera = new Vector3(0, 0.2, -13.0 - b * 0.1).add(Vector3.fbm(b).scale(0.01));
                    target = new Vector3(0, 0, 0);

                    chromatic.globalUniformValues.gMandelboxScale = 1.8;
                    chromatic.globalUniformValues.gCameraLightIntensity = 0.7;
                    chromatic.globalUniformValues.gEmissiveIntensity = 0;
                } else if (beat < 16) {
                    const b = beat - 8;
                    camera = new Vector3(0, 0.2, -17.0 - b * 0.1).add(Vector3.fbm(b).scale(0.01));
                    target = new Vector3(0, 0, 0);

                    chromatic.globalUniformValues.gMandelboxScale = 1.8;
                    chromatic.globalUniformValues.gCameraLightIntensity = 1.2;
                    chromatic.globalUniformValues.gEmissiveIntensity = 0;
                } else if (beat < 32) {
                    const b = beat - 16;
                    const camera1 = new Vector3(0, 2.8, -8);
                    const camera2 = new Vector3(0, 0, -32);

                    camera = Vector3.mix(camera1, camera2, saturate(0.1 * b));
                    target = new Vector3(0, 0, 0);

                    chromatic.globalUniformValues.gMandelboxScale = 1.0 + 0.02 * b;
                    chromatic.globalUniformValues.gEmissiveIntensity = 6;
                } else {
                    const b = beat - 32.0;
                    camera = new Vector3(0, 0, 25.0).add(Vector3.fbm(b).scale(0.01));
                    target = new Vector3(0, 0, 0);
                    chromatic.globalUniformValues.gMandelboxScale = 1.0;
                    chromatic.globalUniformValues.gEmissiveIntensity = 6;
                }

                if (!PRODUCTION && config.debugCamera) {
                    return;
                }

                chromatic.globalUniformValues.gCameraEyeX = camera.x;
                chromatic.globalUniformValues.gCameraEyeY = camera.y;
                chromatic.globalUniformValues.gCameraEyeZ = camera.z;
                chromatic.globalUniformValues.gCameraTargetX = target.x;
                chromatic.globalUniformValues.gCameraTargetY = target.y;
                chromatic.globalUniformValues.gCameraTargetZ = target.z;
            }

            chromatic.onRender = (time, timeDelta) => {
                animateUniforms(time);
            }

            chromatic.playSound();
        });
    }
}, false);