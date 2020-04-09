import { chromatic, animateUniforms } from './index.common'

window.addEventListener("load", ev => {
    let finished = false;

    const style = document.createElement("style");
    style.innerText = require("../dist/style.prod.min.css").default;
    document.head.appendChild(style);

    document.addEventListener("fullscreenchange", () => {
        document.body.style.cursor = window.document.fullscreenElement ? "none" : "auto";
    });

    const container = document.createElement("div");
    container.className = "container";
    document.body.appendChild(container);

    const message = document.createElement("p");
    message.innerHTML = "RESOLUTION";
    container.appendChild(message);

    const resolutionSscale = document.createElement("select");
    resolutionSscale.innerHTML = `
    <option value="0.25">LOW 25%</option>
    <option value="0.5">REGULAR 50%</option>
    <option value="0.75">REGULAR 75%</option>
    <option value="1.0" selected>FULL 100%</option>
    `;
    message.appendChild(resolutionSscale);

    const button = document.createElement("p");
    container.appendChild(button);
    button.innerHTML = "CLICK TO START";
    button.className = "button";
    button.onclick = () => {
        button.remove();
        message.remove();

        // loading animation
        const loading = document.createElement("p");
        loading.innerHTML = 'LOADING <div class="lds-facebook"><div></div><div></div><div></div></div>';
        container.appendChild(loading);

        setTimeout(() => {
            document.body.requestFullscreen().then(() => {
                chromatic.onRender = (time, timeDelta) => {
                    animateUniforms(time, false, false);
                    if (!finished && time > chromatic.timeLength + 2.0) {
                        document.exitFullscreen();
                        finished = true;
                    }
                }

                chromatic.init();

                window.addEventListener("resize", () => {
                    const scale = parseFloat(resolutionSscale.value);
                    chromatic.setSize(window.innerWidth * scale, window.innerHeight * scale);
                });

                setTimeout(() => {
                    container.remove();
                    chromatic.play();
                    chromatic.playSound();
                }, 1000);
            });
        }, 1000);
    }
}, false);