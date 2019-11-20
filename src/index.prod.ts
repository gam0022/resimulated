import { ShaderPlayer } from "./shader-play"

window.addEventListener("load", ev => {
    const player = new ShaderPlayer();

    const style = document.createElement("style");
    style.innerText = require("./style.prod.css").default;
    document.head.appendChild(style);
}, false);