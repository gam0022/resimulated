import { Chromatic } from "./chromatic"
import * as dat from 'dat.gui';

import * as three from 'three';
const THREE = require('three')
import 'imports-loader?THREE=three!../node_modules/three/examples/js/controls/OrbitControls.js'

import { saveAs } from 'file-saver';

window.addEventListener("load", ev => {
    const chromatic = new Chromatic(
        48,// デモの長さ（秒）
        require("./shaders/vertex.glsl").default,
        require("./shaders/common-header.glsl").default,
        [
            //require("./shaders/kaleidoscope.glsl").default,
            require("./shaders/raymarching-mandelbox.glsl").default,
            require("./shaders/tone-mapping.glsl").default,

            //require("./shaders/kaleidoscope.glsl").default,
            //require("./shaders/invert.glsl").default,
            //require("./shaders/dot-matrix.glsl").default,
            //require("./shaders/chromatic-aberration.glsl").default,
        ],

        1,
        5,
        require("./shaders/bloom-prefilter.glsl").default,
        require("./shaders/bloom-downsample.glsl").default,
        require("./shaders/bloom-upsample.glsl").default,
        require("./shaders/bloom-final.glsl").default,

        require("./shaders/sound-template.glsl").default,
    );

    const animateUniforms = (time: number) => {
        chromatic.globalUniformValues.gMandelboxScale = 3.0 + 3.0 * Math.sin(time);
    }

    const gui = new dat.GUI({ width: 1000, });

    const imageFunctions = {
        saveImage: () => {
            chromatic.canvas.toBlob(function (blob) {
                saveAs(blob, "chromatic.png");
            });
        }
    };
    gui.add(imageFunctions, "saveImage");

    chromatic.globalUniforms.forEach(unifrom => {
        gui.add(chromatic.globalUniformValues, unifrom.key, unifrom.min, unifrom.max).onChange(value => {
            chromatic.needsUpdate = true;
        });
    })

    const enableCameraDebug = "gCameraEyeX" in chromatic.globalUniformValues;

    // THREE.OrbitControls
    const camera = new three.PerspectiveCamera(75, 1.0, 1, 1000);

    if (enableCameraDebug) {
        camera.position.set(chromatic.globalUniformValues.gCameraEyeX, chromatic.globalUniformValues.gCameraEyeY, chromatic.globalUniformValues.gCameraEyeZ);
    }

    const controls = new THREE.OrbitControls(camera, chromatic.canvas);
    controls.target = new three.Vector3(chromatic.globalUniformValues.gCameraTargetX, chromatic.globalUniformValues.gCameraTargetY, chromatic.globalUniformValues.gCameraTargetZ);
    controls.zoomSpeed = 3.0;
    controls.screenSpacePanning = true;
    controls.mouseButtons = {
        LEFT: THREE.MOUSE.ROTATE,
        MIDDLE: THREE.MOUSE.PAN,
        RIGHT: THREE.MOUSE.DOLLY,
    };

    const prevCameraPosotion = camera.position.clone();
    const prevCameraTarget: three.Vector3 = controls.target.clone();


    // consts
    const pauseChar = "\uf04c";
    const playChar = "\uf04b";


    // HTMLElements
    const fpsSpan = document.getElementById("fps-span");
    const resolutionScaleSelect = <HTMLSelectElement>document.getElementById("resolution-scale");
    const stopButton = <HTMLInputElement>document.getElementById("stop-button");
    const playPauseButton = <HTMLInputElement>document.getElementById("play-pause-button");
    const timeInput = <HTMLInputElement>document.getElementById("time-input");
    const timeBar = <HTMLInputElement>document.getElementById("time-bar");
    const timeLengthInput = <HTMLInputElement>document.getElementById("time-length-input");
    const tickmarks = <HTMLDataListElement>document.getElementById("tickmarks");


    // Common Callbacks
    const onResolutionCange = () => {
        const resolutionScale = parseFloat(resolutionScaleSelect.value);
        chromatic.setSize(window.innerWidth * resolutionScale, window.innerHeight * resolutionScale);
        chromatic.needsUpdate = true;
    }

    const onTimeLengthUpdate = () => {
        timeBar.max = timeLengthInput.value;

        // tickmarksの子要素を全て削除します
        for (let i = tickmarks.childNodes.length - 1; i >= 0; i--) {
            tickmarks.removeChild(tickmarks.childNodes[i]);
        }

        // 1秒刻みにラベルを置きます
        for (let i = 0; i < timeLengthInput.valueAsNumber; i++) {
            const option = document.createElement("option");
            option.value = i.toString();
            option.label = i.toString();
            tickmarks.appendChild(option);
        }
    }


    // SessionStorage
    const saveToSessionStorage = () => {
        sessionStorage.setItem("time", chromatic.time.toString());
        sessionStorage.setItem("isPlaying", chromatic.isPlaying ? "true" : "false");
        sessionStorage.setItem("resolutionScale", resolutionScaleSelect.value);
        sessionStorage.setItem("timeLength", timeLengthInput.value);
    }

    const loadFromSessionStorage = () => {
        const timeStr = sessionStorage.getItem("time")
        if (timeStr) {
            chromatic.time = parseFloat(timeStr);
        }

        const isPlayingStr = sessionStorage.getItem("isPlaying");
        if (isPlayingStr) {
            chromatic.isPlaying = isPlayingStr === "true";
            playPauseButton.value = chromatic.isPlaying ? pauseChar : playChar;
        }

        const resolutionScaleStr = sessionStorage.getItem("resolutionScale");
        if (resolutionScaleStr) {
            resolutionScaleSelect.value = resolutionScaleStr;
        }

        const timeLengthStr = sessionStorage.getItem("timeLength");
        if (timeLengthStr) {
            timeLengthInput.value = timeLengthStr;
        } else {
            timeLengthInput.valueAsNumber = chromatic.timeLength;
        }

        onTimeLengthUpdate();
    }

    loadFromSessionStorage();
    onResolutionCange();

    window.addEventListener("beforeunload", ev => {
        saveToSessionStorage();
    })


    // Player
    chromatic.onRender = (time, timeDelta) => {
        timeBar.valueAsNumber = time;
        timeInput.valueAsNumber = time;

        const fps = 1.0 / timeDelta;
        fpsSpan.innerText = `${fps.toFixed(2)} FPS`;

        animateUniforms(time);
        gui.updateDisplay();
    }

    if (enableCameraDebug) {
        chromatic.onUpdate = () => {
            controls.update();

            if (!camera.position.equals(prevCameraPosotion) || !controls.target.equals(prevCameraTarget)) {
                chromatic.globalUniformValues.gCameraEyeX = camera.position.x;
                chromatic.globalUniformValues.gCameraEyeY = camera.position.y;
                chromatic.globalUniformValues.gCameraEyeZ = camera.position.z;

                chromatic.globalUniformValues.gCameraTargetX = controls.target.x;
                chromatic.globalUniformValues.gCameraTargetY = controls.target.y;
                chromatic.globalUniformValues.gCameraTargetZ = controls.target.z;

                gui.updateDisplay();
                chromatic.needsUpdate = true;
            }

            prevCameraPosotion.copy(camera.position);
            prevCameraTarget.copy(controls.target);
        }
    }

    if (chromatic.isPlaying) {
        chromatic.playSound();
    }


    // UI Events
    window.addEventListener("resize", onResolutionCange);

    resolutionScaleSelect.addEventListener("input", ev => {
        onResolutionCange();
    })

    stopButton.addEventListener("click", ev => {
        chromatic.isPlaying = false;
        chromatic.time = 0;
        playPauseButton.value = playChar;
        chromatic.stopSound();
    })

    playPauseButton.addEventListener("click", ev => {
        chromatic.isPlaying = !chromatic.isPlaying;
        playPauseButton.value = chromatic.isPlaying ? pauseChar : playChar;

        if (chromatic.isPlaying) {
            chromatic.playSound()
        } else {
            chromatic.stopSound();
        }
    })

    timeInput.addEventListener("input", ev => {
        chromatic.time = timeInput.valueAsNumber;
        playPauseButton.value = playChar;
        chromatic.isPlaying = false;

        if (chromatic.isPlaying) {
            chromatic.playSound()
        } else {
            chromatic.stopSound();
        }
    })

    timeBar.addEventListener("input", ev => {
        chromatic.time = timeBar.valueAsNumber;
        playPauseButton.value = playChar;
        chromatic.isPlaying = false;
        chromatic.stopSound();
    })

    timeLengthInput.addEventListener("input", ev => {
        onTimeLengthUpdate();
    })
}, false);