import { Chromatic } from "./chromatic"

window.addEventListener("load", ev => {
    const chromatic = new Chromatic(
        48,// デモの長さ（秒）
        require("./shaders/vertex.glsl").default,
        [
            require("./shaders/kaleidoscope.glsl").default,
            //require("./shaders/raymarching.glsl").default,
            require("./shaders/blit.glsl").default,

            //require("./shaders/kaleidoscope.glsl").default,
            //require("./shaders/invert.glsl").default,
            //require("./shaders/dot-matrix.glsl").default,
            //require("./shaders/chromatic-aberration.glsl").default,
        ],

        1,
        3,
        require("./shaders/bloom-prefilter.glsl").default,
        require("./shaders/bloom-downsample.glsl").default,
        require("./shaders/bloom-upsample.glsl").default,
        require("./shaders/bloom-final.glsl").default,

        require("./shaders/sound-template.glsl").default
    );
    chromatic.playSound();

    const style = document.createElement("style");
    style.innerText = require("../dist/style.prod.min.css").default;
    document.head.appendChild(style);
}, false);