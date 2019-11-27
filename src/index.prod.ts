import { ShaderPlayer } from "./shader-play"

window.addEventListener("load", ev => {
    const player = new ShaderPlayer(
        require("./shaders/vertex.glsl").default,
        [
            require("./shaders/kaleidoscope.glsl").default,
            require("./shaders/invert.glsl").default,
            require("./shaders/dot-matrix.glsl").default,
            require("./shaders/chromatic-aberration.glsl").default,
        ]
    );

    const style = document.createElement("style");
    style.innerText = require("../dist/style.prod.min.css").default;
    document.head.appendChild(style);
}, false);