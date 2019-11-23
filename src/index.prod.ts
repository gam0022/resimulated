import { ShaderPlayer } from "./shader-play"

window.addEventListener("load", ev => {
    const player = new ShaderPlayer(
        require("./vertex.glsl").default,
        require("./fragment.glsl").default,
        []
    );

    const style = document.createElement("style");
    style.innerText = require("../dist/style.prod.min.css").default;
    document.head.appendChild(style);
}, false);