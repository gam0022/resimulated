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

    const button = document.createElement("p");
    container.appendChild(button);
    button.innerHTML = "CLICK TO START";
    button.onclick = () => {
        button.remove();

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
                    chromatic.setSize(window.innerWidth, window.innerHeight);
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