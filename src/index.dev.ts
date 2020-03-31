import { chromatic, animateUniforms } from './index.common'

import * as dat from 'dat.gui';
import { saveAs } from 'file-saver';
import { bufferToWave } from "./buffer-to-wave";

import * as three from 'three';
const THREE = require('three')
import 'imports-loader?THREE=three!../node_modules/three/examples/js/controls/OrbitControls.js'

window.addEventListener("load", ev => {
    chromatic.init();
    chromatic.play();


    // dat.GUI
    const gui = new dat.GUI({ width: 1000 });
    gui.useLocalStorage = true;

    const miscFolder = gui.addFolder("misc");

    const config = {
        debugCamera: false,
        debugParams: false,
        debugDisableReset: false,
        resolution: "1920x1080",
        timeMode: "beat",
        bpm: 140,
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
    gui.add(config, "debugDisableReset").onChange(value => {
        chromatic.needsUpdate = true;
    });
    miscFolder.add(config, "resolution", ["0.5", "0.75", "1.0", "1920x1080", "1600x900", "1280x720"]).onChange(value => {
        onResolutionCange();
    });
    miscFolder.add(config, "timeMode", ["time", "beat"]).onChange(value => {
        onTimeModeChange();
    });
    miscFolder.add(config, "bpm", 50, 300).onChange(value => {
        beatLengthInput.valueAsNumber = timeToBeat(timeLengthInput.valueAsNumber);
        onBeatLengthUpdate();
    });
    miscFolder.add(chromatic, "debugFrameNumber", -1, 30, 1).onChange(value => {
        chromatic.needsUpdate = true;
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

                animateUniforms(time, config.debugCamera, config.debugDisableReset);
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
        },
    };
    miscFolder.add(saevFunctions, "saveImage");
    miscFolder.add(saevFunctions, "saveImageSequence");
    miscFolder.add(saevFunctions, "saveSound");

    const groupFolders: { [index: string]: dat.GUI } = {};

    chromatic.uniformArray.forEach(unifrom => {
        let groupFolder = groupFolders[unifrom.group];
        if (!groupFolder) {
            groupFolder = gui.addFolder(unifrom.group);
            groupFolders[unifrom.group] = groupFolder;
        }

        if (typeof unifrom.initValue === "number") {
            groupFolder.add(chromatic.uniforms, unifrom.key, unifrom.min, unifrom.max).onChange(value => {
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
            groupFolder.addColor(chromatic.uniforms, unifrom.key).onChange(value => {
                chromatic.needsUpdate = true;
            });
        }
    })

    // Common Functions
    const timeToBeat = (time: number) => {
        return time * config.bpm / 60;
    }

    const beatToTime = (beat: number) => {
        return beat / config.bpm * 60;
    }


    // consts
    const pauseChar = "\uf04c";
    const playChar = "\uf04b";


    // HTMLElements
    const fpsSpan = document.getElementById("fps-span");
    const stopButton = <HTMLInputElement>document.getElementById("stop-button");
    const playPauseButton = <HTMLInputElement>document.getElementById("play-pause-button");
    const timeInput = <HTMLInputElement>document.getElementById("time-input");
    const beatInput = <HTMLInputElement>document.getElementById("beat-input");
    const timeBar = <HTMLInputElement>document.getElementById("time-bar");
    const beatBar = <HTMLInputElement>document.getElementById("beat-bar");
    const timeLengthInput = <HTMLInputElement>document.getElementById("time-length-input");
    const beatLengthInput = <HTMLInputElement>document.getElementById("beat-length-input");
    const timeTickmarks = <HTMLDataListElement>document.getElementById("time-tickmarks");
    const beatTickmarks = <HTMLDataListElement>document.getElementById("beat-tickmarks");


    // OnUpdates
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

    const onTimeModeChange = () => {
        const isTimeMode = config.timeMode === "time";

        const timeDisplay = isTimeMode ? "block" : "none";
        timeInput.style.display = timeDisplay;
        timeLengthInput.style.display = timeDisplay;
        timeBar.style.display = timeDisplay;

        const beatDisplay = isTimeMode ? "none" : "block";
        beatInput.style.display = beatDisplay;
        beatLengthInput.style.display = beatDisplay;
        beatBar.style.display = beatDisplay;
    }

    const onTimeLengthUpdate = () => {
        timeBar.max = timeLengthInput.value;

        // tickmarksの子要素を全て削除します
        for (let i = timeTickmarks.childNodes.length - 1; i >= 0; i--) {
            timeTickmarks.removeChild(timeTickmarks.childNodes[i]);
        }

        // 1秒刻みにラベルを置きます
        for (let i = 0; i < timeLengthInput.valueAsNumber; i++) {
            const option = document.createElement("option");
            option.value = i.toString();
            option.label = i.toString();
            timeTickmarks.appendChild(option);
        }
    }

    const onBeatLengthUpdate = () => {
        beatBar.max = beatLengthInput.value;

        // tickmarksの子要素を全て削除します
        for (let i = beatTickmarks.childNodes.length - 1; i >= 0; i--) {
            beatTickmarks.removeChild(beatTickmarks.childNodes[i]);
        }

        // 4ビート刻みにラベルを置きます
        for (let i = 0; i < beatLengthInput.valueAsNumber; i += 4) {
            const option = document.createElement("option");
            option.value = i.toString();
            option.label = i.toString();
            beatTickmarks.appendChild(option);
        }
    }


    // SessionStorage
    const saveToSessionStorage = () => {
        sessionStorage.setItem("debugCamera", config.debugCamera.toString());
        sessionStorage.setItem("debugParams", config.debugParams.toString());
        sessionStorage.setItem("debugDisableReset", config.debugDisableReset.toString());
        sessionStorage.setItem("resolution", config.resolution);
        sessionStorage.setItem("timeMode", config.timeMode);
        sessionStorage.setItem("bpm", config.bpm.toString());
        sessionStorage.setItem("debugFrameNumber", chromatic.debugFrameNumber.toString());

        sessionStorage.setItem("time", chromatic.time.toString());
        sessionStorage.setItem("isPlaying", chromatic.isPlaying.toString());
        sessionStorage.setItem("timeLength", timeLengthInput.value);

        sessionStorage.setItem("guiClosed", gui.closed.toString());

        for (const [key, uniform] of Object.entries(chromatic.uniforms)) {
            sessionStorage.setItem(key, uniform.toString());
        }
    }

    const loadFromSessionStorage = () => {
        const parseBool = (value: string) => {
            return value === "true"
        }

        const resolutionStr = sessionStorage.getItem("resolution");
        if (resolutionStr) {
            config.resolution = resolutionStr;
        }
        onResolutionCange();

        const debugCameraStr = sessionStorage.getItem("debugCamera");
        if (debugCameraStr) {
            config.debugCamera = parseBool(debugCameraStr);
        }

        const debugParamsStr = sessionStorage.getItem("debugParams");
        if (debugParamsStr) {
            config.debugParams = parseBool(debugParamsStr);
        }

        const debugDisableResetStr = sessionStorage.getItem("debugDisableReset");
        if (debugDisableResetStr) {
            config.debugDisableReset = parseBool(debugDisableResetStr);
        }

        const timeModeStr = sessionStorage.getItem("timeMode");
        if (timeModeStr) {
            config.timeMode = timeModeStr;
        }
        onTimeModeChange();

        const bpmStr = sessionStorage.getItem("bpm");
        if (bpmStr) {
            config.bpm = parseFloat(bpmStr);
        }

        const debugFrameNumberStr = sessionStorage.getItem("debugFrameNumber");
        if (debugFrameNumberStr) {
            chromatic.debugFrameNumber = parseFloat(debugFrameNumberStr);
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
            timeLengthInput.valueAsNumber = parseFloat(timeLengthStr);
        } else {
            timeLengthInput.valueAsNumber = chromatic.timeLength;
        }

        beatLengthInput.valueAsNumber = timeToBeat(timeLengthInput.valueAsNumber);
        onTimeLengthUpdate();
        onBeatLengthUpdate();

        const guiClosedStr = sessionStorage.getItem("guiClosed")
        if (guiClosedStr) {
            gui.closed = parseBool(guiClosedStr);
        }

        for (const [key, uniform] of Object.entries(chromatic.uniforms)) {
            const unifromStr = sessionStorage.getItem(key);
            if (unifromStr) {
                const ary = unifromStr.split(",");
                if (ary.length === 3) {
                    chromatic.uniforms[key] = ary.map(s => parseFloat(s));
                }
                else if (ary.length === 1) {
                    chromatic.uniforms[key] = parseFloat(unifromStr);
                }
            }
        }
    }

    loadFromSessionStorage();

    window.addEventListener("beforeunload", ev => {
        saveToSessionStorage();
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


    // Player
    chromatic.onRender = (time, timeDelta) => {
        timeInput.valueAsNumber = time;
        beatInput.valueAsNumber = timeToBeat(time);
        timeBar.valueAsNumber = time;
        beatBar.valueAsNumber = timeToBeat(time);

        const fps = 1.0 / timeDelta;
        fpsSpan.innerText = `${fps.toFixed(2)} FPS`;

        if (!config.debugParams) {
            animateUniforms(time, config.debugCamera, config.debugDisableReset);
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
    });

    playPauseButton.addEventListener("click", ev => {
        chromatic.isPlaying = !chromatic.isPlaying;
        playPauseButton.value = chromatic.isPlaying ? pauseChar : playChar;

        if (chromatic.isPlaying) {
            chromatic.playSound()
        } else {
            chromatic.stopSound();
        }
    });

    timeInput.addEventListener("input", ev => {
        if (chromatic.isPlaying) {
            chromatic.stopSound();
        }

        chromatic.time = timeInput.valueAsNumber;
        playPauseButton.value = playChar;
        chromatic.isPlaying = false;
        chromatic.needsUpdate = true;
    });

    beatInput.addEventListener("input", ev => {
        if (chromatic.isPlaying) {
            chromatic.stopSound();
        }

        chromatic.time = beatToTime(beatInput.valueAsNumber);
        playPauseButton.value = playChar;
        chromatic.isPlaying = false;
        chromatic.needsUpdate = true;
    });

    timeBar.addEventListener("input", ev => {
        if (chromatic.isPlaying) {
            chromatic.stopSound();
        }

        chromatic.time = timeBar.valueAsNumber;
        playPauseButton.value = playChar;
        chromatic.isPlaying = false;
        chromatic.needsUpdate = true;
    });

    beatBar.addEventListener("input", ev => {
        if (chromatic.isPlaying) {
            chromatic.stopSound();
        }

        chromatic.time = beatToTime(beatBar.valueAsNumber);
        playPauseButton.value = playChar;
        chromatic.isPlaying = false;
        chromatic.needsUpdate = true;
    });

    timeLengthInput.addEventListener("input", ev => {
        beatLengthInput.valueAsNumber = timeToBeat(timeLengthInput.valueAsNumber);
        onTimeLengthUpdate();
        onBeatLengthUpdate();
    });

    beatLengthInput.addEventListener("input", ev => {
        timeLengthInput.valueAsNumber = beatToTime(beatLengthInput.valueAsNumber);
        onTimeLengthUpdate();
        onBeatLengthUpdate();
    });
}, false);