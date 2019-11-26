import { ShaderPlayer } from "./shader-play"

window.addEventListener("load", ev => {
    const player = new ShaderPlayer(
        require("./vertex.glsl").default,
        [
            require("./kaleidoscope.glsl").default,
            require("./invert.glsl").default,
            require("./chromatic-aberration.glsl").default,
        ]
    );

    const style = document.createElement("style");
    style.innerText = require("../dist/style.prod.min.css").default;
    document.head.appendChild(style);
}, false);