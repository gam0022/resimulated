import { Chromatic } from "./chromatic"
import { mix, clamp, saturate, Vector3 } from "./math"

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

            // FIXME: 削減可能
            const config = { debugCamera: false };

            const animateUniforms = (time: number) => {
                chromatic.globalUniformValues.gMandelboxScale = mix(1.0, 3.0, saturate(0.1 * time));

                if (!config.debugCamera) {
                    const camera1 = new Vector3(0, 2.8, -8);
                    const camera2 = new Vector3(0, 0, -32);

                    const camera = Vector3.mix(camera1, camera2, saturate(0.1 * time));
                    chromatic.globalUniformValues.gCameraEyeX = camera.x;
                    chromatic.globalUniformValues.gCameraEyeY = camera.y;
                    chromatic.globalUniformValues.gCameraEyeZ = camera.z;

                    chromatic.globalUniformValues.gCameraTargetX = 0;
                    chromatic.globalUniformValues.gCameraTargetY = 2.75;
                    chromatic.globalUniformValues.gCameraTargetZ = 0;
                }
            }

            chromatic.onRender = (time, timeDelta) => {
                animateUniforms(time);
            }

            chromatic.playSound();
        });
    }
}, false);