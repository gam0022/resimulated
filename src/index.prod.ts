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

    const resolutionMessage = document.createElement("p");
    resolutionMessage.innerHTML = "RESOLUTION: ";
    container.appendChild(resolutionMessage);

    const resolutionScale = document.createElement("select");
    resolutionScale.innerHTML = `
    <option value="0.25">LOW 25%</option>
    <option value="0.5">REGULAR 50%</option>
    <option value="0.75">REGULAR 75%</option>
    <option value="1.0" selected>FULL 100%</option>
    `;
    resolutionMessage.appendChild(resolutionScale);

    const button = document.createElement("p");
    container.appendChild(button);
    button.innerHTML = "CLICK TO START";
    button.className = "button";
    button.onclick = () => {
        button.remove();
        resolutionMessage.remove();

        // loading animation
        const loading = document.createElement("p");
        loading.innerHTML = 'LOADING <div class="lds-facebook"><div></div><div></div><div></div></div>';
        container.appendChild(loading);

        const loadingMessage = document.createElement("p");
        loadingMessage.innerHTML = "It takes about one minute. Please wait.";
        loadingMessage.style.fontSize = "50px";
        container.appendChild(loadingMessage);

        document.body.requestFullscreen().then(() => {
            setTimeout(() => {
                chromatic.onRender = (time, timeDelta) => {
                    animateUniforms(time, false, false);
                    if (!finished && time > chromatic.timeLength + 2.0) {
                        document.exitFullscreen();
                        finished = true;
                    }
                }

                chromatic.init();
                container.remove();

                const onResize = () => {
                    const scale = parseFloat(resolutionScale.value);
                    chromatic.setSize(window.innerWidth * scale, window.innerHeight * scale);
                };

                window.addEventListener("resize", onResize);
                onResize();

                setTimeout(() => {
                    chromatic.play();
                    chromatic.playSound();
                }, 2500);
            }, 1000);
        });
    }
}, false);