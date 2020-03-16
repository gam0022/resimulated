import { chromatic, animateUniforms } from './index.common'

import * as dat from 'dat.gui';
import { saveAs } from 'file-saver';
import { bufferToWave } from "./buffer-to-wave";

import * as three from 'three';
const THREE = require('three')
import 'imports-loader?THREE=three!../node_modules/three/examples/js/controls/OrbitControls.js'

window.addEventListener("load", ev => {
    chromatic.play();

    const gui = new dat.GUI({ width: 1000, });

    const config = {
        debugCamera: false,
        debugParams: false,
        resolution: "1920x1080",
    }

    gui.add(config, "debugCamera").onChange(value => {
        if (value) {
            camera.position.x = chromatic.uniforms.gCameraEyeX;
            camera.position.y = chromatic.uniforms.gCameraEyeY;
            camera.position.z = chromatic.uniforms.gCameraEyeZ;
            controls.target.x = chromatic.uniforms.gCameraTargetX;
            controls.target.y = chromatic.uniforms.gCameraTargetY;
            controls.target.z = chromatic.uniforms.gCameraTargetZ;
        }

        chromatic.needsUpdate = true;
    });
    gui.add(config, "debugParams").onChange(value => {
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
                const time = frame / fps;
                timeBar.valueAsNumber = time;
                timeInput.valueAsNumber = time;
                chromatic.time = time;

                animateUniforms(time, config.debugCamera);
                chromatic.render();

                const filename = `chromatic${frame.toString().padStart(4, "0")}.png`;
                chromatic.canvas.toBlob(blob => {
                    saveAs(blob, filename);

                    if (frame < fps * timeLengthInput.valueAsNumber) {
                        requestAnimationFrame(update);
                    }
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

    chromatic.uniformArray.forEach(unifrom => {
        if (typeof unifrom.initValue === "number") {
            gui.add(chromatic.uniforms, unifrom.key, unifrom.min, unifrom.max).onChange(value => {
                if (config.debugCamera) {
                    switch (unifrom.key) {
                        case "gCameraEyeX":
                            camera.position.x = value;
                            break;
                        case "gCameraEyeY":
                            camera.position.y = value;
                            break;
                        case "gCameraEyeZ":
                            camera.position.z = value;
                            break;
                        case "gCameraTargetX":
                            controls.target.x = value;
                            break;
                        case "gCameraTargetY":
                            controls.target.y = value;
                            break;
                        case "gCameraTargetZ":
                            controls.target.z = value;
                            break;
                    }
                }

                chromatic.needsUpdate = true;
            });
        } else {
            gui.addColor(chromatic.uniforms, unifrom.key).onChange(value => {
                chromatic.needsUpdate = true;
            });
        }
    })

    // THREE.OrbitControls
    const camera = new three.PerspectiveCamera(75, 1.0, 1, 1000);

    if (config.debugCamera) {
        camera.position.set(chromatic.uniforms.gCameraEyeX, chromatic.uniforms.gCameraEyeY, chromatic.uniforms.gCameraEyeZ);
        camera.lookAt(chromatic.uniforms.gCameraTargetX, chromatic.uniforms.gCameraTargetY, chromatic.uniforms.gCameraTargetZ);
    }

    const controls = new THREE.OrbitControls(camera, chromatic.canvas);
    controls.target = new three.Vector3(chromatic.uniforms.gCameraTargetX, chromatic.uniforms.gCameraTargetY, chromatic.uniforms.gCameraTargetZ);
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
        sessionStorage.setItem("debugCamera", config.debugCamera.toString());
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

        const cameraDebugStr = sessionStorage.getItem("debugCamera");
        if (cameraDebugStr) {
            config.debugCamera = parseBool(cameraDebugStr);
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

        if (!config.debugParams) {
            animateUniforms(time, config.debugCamera);
        }

        gui.updateDisplay();
    }

    chromatic.onUpdate = () => {
        if (config.debugCamera) {
            controls.update();

            if (!camera.position.equals(prevCameraPosotion) || !controls.target.equals(prevCameraTarget)) {
                chromatic.uniforms.gCameraEyeX = camera.position.x;
                chromatic.uniforms.gCameraEyeY = camera.position.y;
                chromatic.uniforms.gCameraEyeZ = camera.position.z;
                chromatic.uniforms.gCameraTargetX = controls.target.x;
                chromatic.uniforms.gCameraTargetY = controls.target.y;
                chromatic.uniforms.gCameraTargetZ = controls.target.z;

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