import { Chromatic } from "./chromatic"

window.addEventListener("load", ev => {
    const chromatic = new Chromatic(
        48,
        require("./shaders/vertex.glsl").default,
        [
            require("./shaders/kaleidoscope.glsl").default,
            require("./shaders/invert.glsl").default,
            require("./shaders/dot-matrix.glsl").default,
            require("./shaders/chromatic-aberration.glsl").default,
        ],
        [],
        require("./shaders/sound-template.glsl").default
    );
    chromatic.playSound();

    const style = document.createElement("style");
    style.innerText = require("../dist/style.prod.min.css").default;
    document.head.appendChild(style);
}, false);