import { chromatic, animateUniforms } from './index.common'

window.addEventListener("load", ev => {
    const style = document.createElement("style");
    style.innerText = require("../dist/style.prod.min.css").default;
    document.head.appendChild(style);

    document.addEventListener("fullscreenchange", () => {
        document.body.style.cursor = window.document.fullscreenElement ? "none" : "auto";
    });

    const button = document.createElement("p");
    document.body.appendChild(button);
    button.innerHTML = "click to start";
    button.onclick = () => {
        document.body.requestFullscreen().then(() => {
            button.style.display = "none";

            // loading animation
            const loading = document.createElement("p");
            loading.innerHTML = 'Loading <div class="lds-facebook"><div></div><div></div><div></div></div>';
            document.body.appendChild(loading);

            chromatic.onRender = (time, timeDelta) => {
                animateUniforms(time, false, false);
            }

            chromatic.init();

            window.addEventListener("resize", () => {
                chromatic.setSize(window.innerWidth, window.innerHeight);
            });

            setTimeout(() => {
                chromatic.play();
                chromatic.playSound();
            }, 1000);
        });
    }
}, false);