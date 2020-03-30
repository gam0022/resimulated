import { chromatic, animateUniforms } from './index.common'

window.addEventListener("load", ev => {
    const style = document.createElement("style");
    style.innerText = require("../dist/style.prod.min.css").default;
    document.head.appendChild(style);

    const button = document.createElement('p');
    document.body.appendChild(button);
    button.innerHTML = 'click me!';
    button.onclick = () => {
        document.body.requestFullscreen().then(() => {
            chromatic.onRender = (time, timeDelta) => {
                animateUniforms(time, false, false);
            }

            chromatic.init();

            setTimeout(() => {
                chromatic.play();
                chromatic.playSound();
            }, 1000);
        });
    }
}, false);