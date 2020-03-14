import { Chromatic } from "./chromatic"
import { mix, clamp, saturate, Vector3 } from "./math"

import * as dat from 'dat.gui';

import * as three from 'three';
const THREE = require('three')
import 'imports-loader?THREE=three!../node_modules/three/examples/js/controls/OrbitControls.js'

import { saveAs } from 'file-saver';
import { bufferToWave } from "./buffer-to-wave";

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
        chromatic.globalUniformValues.gMandelboxScale = mix(1.0, 3.0, saturate(0.1 * time));

        if (!config.cameraDebug) {
            const camera1 = new Vector3(0, 2.8, -8);
            const camera2 = new Vector3(0, 0, -32);

            const camera = Vector3.mix(camera1, camera2, saturate(0.1 * time));
            chromatic.globalUniformValues.gCameraEyeX = camera.x;
            chromatic.globalUniformValues.gCameraEyeY = camera.y;
            chromatic.globalUniformValues.gCameraEyeZ = camera.z;

            chromatic.globalUniformValues.gCameraTargetX = 0;
            chromatic.globalUniformValues.gCameraTargetY = 2.75;
            chromatic.globalUniformValues.gCameraTargetZ = 0;
        }
    }

    const gui = new dat.GUI({ width: 1000, });

    const config = {
        cameraDebug: true,
        resolution: "1920x1080",
    }

    gui.add(config, "cameraDebug").onChange(value => {
        chromatic.needsUpdate = true;
    });
    gui.add(config, "resolution", ["0.5", "0.75", "1.0", "1920x1080", "1600x900", "1280x720"]).onChange(value => {
        onResolutionCange();
    });

    const saevFunctions = {
        saveImage: () => {
            chromatic.canvas.toBlob(blob => {
                saveAs(blob, "chromatic.png");
            });
        },
        saveImageSequence: () => {
            if (chromatic.isPlaying) {
                chromatic.stopSound();
            }

            chromatic.isPlaying = false;
            chromatic.needsUpdate = false;
            playPauseButton.value = playChar;

            const fps = 60;
            let frame = 0;
            const update = (timestamp: number) => {
                if (frame < fps * chromatic.timeLength) {
                    requestAnimationFrame(update);
                }

                const time = frame / fps;
                timeBar.valueAsNumber = time;
                timeInput.valueAsNumber = time;
                chromatic.time = time;

                animateUniforms(time);
                chromatic.render();

                const filename = `chromatic${frame.toString().padStart(4, "0")}.png`;
                chromatic.canvas.toBlob(blob => {
                    saveAs(blob, filename);
                });

                frame++;
            }

            requestAnimationFrame(update);
        },
        saveSound: () => {
            const waveBlob = bufferToWave(chromatic.audioSource.buffer, chromatic.audioContext.sampleRate * chromatic.timeLength);
            saveAs(waveBlob, "chromatic.wav");
        }
    };
    gui.add(saevFunctions, "saveImage");
    gui.add(saevFunctions, "saveImageSequence");
    gui.add(saevFunctions, "saveSound");

    chromatic.globalUniforms.forEach(unifrom => {
        gui.add(chromatic.globalUniformValues, unifrom.key, unifrom.min, unifrom.max).onChange(value => {
            chromatic.needsUpdate = true;
        });
    })

    // THREE.OrbitControls
    const camera = new three.PerspectiveCamera(75, 1.0, 1, 1000);

    if (config.cameraDebug) {
        camera.position.set(chromatic.globalUniformValues.gCameraEyeX, chromatic.globalUniformValues.gCameraEyeY, chromatic.globalUniformValues.gCameraEyeZ);
        camera.lookAt(chromatic.globalUniformValues.gCameraTargetX, chromatic.globalUniformValues.gCameraTargetY, chromatic.globalUniformValues.gCameraTargetZ);
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
    const stopButton = <HTMLInputElement>document.getElementById("stop-button");
    const playPauseButton = <HTMLInputElement>document.getElementById("play-pause-button");
    const timeInput = <HTMLInputElement>document.getElementById("time-input");
    const timeBar = <HTMLInputElement>document.getElementById("time-bar");
    const timeLengthInput = <HTMLInputElement>document.getElementById("time-length-input");
    const tickmarks = <HTMLDataListElement>document.getElementById("tickmarks");


    // Common Callbacks
    const onResolutionCange = () => {
        const ret = config.resolution.match(/(\d+)x(\d+)/);
        if (ret) {
            // Fixed Resolution
            chromatic.setSize(parseInt(ret[1]), parseInt(ret[2]));
        } else {
            // Scaled Resolution
            const resolutionScale = parseFloat(config.resolution);
            chromatic.setSize(window.innerWidth * resolutionScale, window.innerHeight * resolutionScale);
        }

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
        sessionStorage.setItem("cameraDebug", config.cameraDebug.toString());
        sessionStorage.setItem("resolution", config.resolution);

        sessionStorage.setItem("time", chromatic.time.toString());
        sessionStorage.setItem("isPlaying", chromatic.isPlaying.toString());
        sessionStorage.setItem("timeLength", timeLengthInput.value);
    }

    const loadFromSessionStorage = () => {
        const parseBool = (value: string) => {
            return value === "true"
        }

        const resolutionStr = sessionStorage.getItem("resolution");
        if (resolutionStr) {
            config.resolution = resolutionStr;
        }

        const cameraDebugStr = sessionStorage.getItem("cameraDebug");
        if (cameraDebugStr) {
            config.cameraDebug = parseBool(cameraDebugStr);
        }

        const timeStr = sessionStorage.getItem("time")
        if (timeStr) {
            chromatic.time = parseFloat(timeStr);
        }

        const isPlayingStr = sessionStorage.getItem("isPlaying");
        if (isPlayingStr) {
            chromatic.isPlaying = parseBool(isPlayingStr);
            playPauseButton.value = chromatic.isPlaying ? pauseChar : playChar;
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

    chromatic.onUpdate = () => {
        if (config.cameraDebug) {
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

    stopButton.addEventListener("click", ev => {
        if (chromatic.isPlaying) {
            chromatic.stopSound();
        }

        chromatic.isPlaying = false;
        chromatic.needsUpdate = true;
        chromatic.time = 0;
        playPauseButton.value = playChar;
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
        if (chromatic.isPlaying) {
            chromatic.stopSound();
        }

        chromatic.time = timeInput.valueAsNumber;
        playPauseButton.value = playChar;
        chromatic.isPlaying = false;
        chromatic.needsUpdate = true;
    })

    timeBar.addEventListener("input", ev => {
        if (chromatic.isPlaying) {
            chromatic.stopSound();
        }

        chromatic.time = timeBar.valueAsNumber;
        playPauseButton.value = playChar;
        chromatic.isPlaying = false;
        chromatic.needsUpdate = true;
    })

    timeLengthInput.addEventListener("input", ev => {
        onTimeLengthUpdate();
    })
}, false);