import { chromatiq, animateUniforms } from './index.common'

import * as dat from 'dat.gui';
import { saveAs } from 'file-saver';
import { bufferToWave } from "./buffer-to-wave";

import * as three from 'three';
const THREE = require('three')
import 'imports-loader?THREE=three!../node_modules/three/examples/js/controls/OrbitControls.js'

import Stats from 'three/examples/jsm/libs/stats.module';

window.addEventListener("load", ev => {
    chromatiq.init();
    chromatiq.play();

    // stats.js
    const stats = Stats();
    stats.showPanel(0); // 0: fps, 1: ms, 2: mb, 3+: custom
    document.body.appendChild(stats.dom);

    // dat.GUI
    const gui = new dat.GUI();
    gui.useLocalStorage = true;

    const config = {
        debugCamera: false,
        debugParams: false,
        debugDisableReset: false,
        resolution: "1920x1080",
        timeMode: "beat",
        bpm: 140,
    }

    const debugFolder = gui.addFolder("debug");
    debugFolder.add(config, "debugCamera").onChange(value => {
        if (value) {
            camera.position.x = chromatiq.uniforms.gCameraEyeX;
            camera.position.y = chromatiq.uniforms.gCameraEyeY;
            camera.position.z = chromatiq.uniforms.gCameraEyeZ;
            controls.target.x = chromatiq.uniforms.gCameraTargetX;
            controls.target.y = chromatiq.uniforms.gCameraTargetY;
            controls.target.z = chromatiq.uniforms.gCameraTargetZ;
        }

        chromatiq.needsUpdate = true;
    });
    debugFolder.add(config, "debugParams").onChange(value => {
        chromatiq.needsUpdate = true;
    });
    debugFolder.add(config, "debugDisableReset").onChange(value => {
        chromatiq.needsUpdate = true;
    });

    const miscFolder = gui.addFolder("misc");
    miscFolder.add(config, "resolution", ["0.5", "0.75", "1.0", "3840x2160", "2560x1440", "1920x1080", "1600x900", "1280x720", "512x512"]).onChange(value => {
        onResolutionCange();
    });
    miscFolder.add(config, "timeMode", ["time", "beat"]).onChange(value => {
        onTimeModeChange();
    });
    miscFolder.add(config, "bpm", 50, 300).onChange(value => {
        beatLengthInput.valueAsNumber = timeToBeat(timeLengthInput.valueAsNumber);
        onBeatLengthUpdate();
    });
    // NOTE: 使用頻度が低いのでmisc送りに
    miscFolder.add(chromatiq, "debugFrameNumber", -1, 30, 1).onChange(value => {
        chromatiq.needsUpdate = true;
    });

    const saevFunctions = {
        saveImage: () => {
            chromatiq.canvas.toBlob(blob => {
                saveAs(blob, "chromatiq.png");
            });
        },
        saveImageSequence: () => {
            if (chromatiq.isPlaying) {
                chromatiq.stopSound();
            }

            chromatiq.isPlaying = false;
            chromatiq.needsUpdate = false;
            playPauseButton.value = playChar;

            const fps = 60;
            let frame = 0;
            const update = (timestamp: number) => {
                const time = frame / fps;
                timeBar.valueAsNumber = time;
                timeInput.valueAsNumber = time;
                chromatiq.time = time;

                animateUniforms(time, config.debugCamera, config.debugDisableReset);
                chromatiq.render();

                const filename = `chromatiq${frame.toString().padStart(4, "0")}.png`;
                chromatiq.canvas.toBlob(blob => {
                    saveAs(blob, filename);

                    if (frame <= Math.ceil(fps * timeLengthInput.valueAsNumber)) {
                        requestAnimationFrame(update);
                    }
                });

                frame++;
            }

            requestAnimationFrame(update);
        },
        saveSound: () => {
            const sampleLength = Math.ceil(chromatiq.audioContext.sampleRate * chromatiq.timeLength);
            const waveBlob = bufferToWave(chromatiq.audioSource.buffer, sampleLength);
            saveAs(waveBlob, "chromatiq.wav");
        },
    };
    miscFolder.add(saevFunctions, "saveImage");
    miscFolder.add(saevFunctions, "saveImageSequence");
    miscFolder.add(saevFunctions, "saveSound");

    const groupFolders: { [index: string]: dat.GUI } = {};

    chromatiq.uniformArray.forEach(unifrom => {
        let groupFolder = groupFolders[unifrom.group];
        if (!groupFolder) {
            groupFolder = gui.addFolder(unifrom.group);
            groupFolders[unifrom.group] = groupFolder;
        }

        if (typeof unifrom.initValue === "number") {
            groupFolder.add(chromatiq.uniforms, unifrom.key, unifrom.min, unifrom.max).onChange(value => {
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

                chromatiq.needsUpdate = true;
            });
        } else {
            groupFolder.addColor(chromatiq.uniforms, unifrom.key).onChange(value => {
                chromatiq.needsUpdate = true;
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
    const frameDecButton = <HTMLInputElement>document.getElementById("frame-dec-button");
    const frameIncButton = <HTMLInputElement>document.getElementById("frame-inc-button");
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
            chromatiq.setSize(parseInt(ret[1]), parseInt(ret[2]));
        } else {
            // Scaled Resolution
            const resolutionScale = parseFloat(config.resolution);
            chromatiq.setSize(window.innerWidth * resolutionScale, window.innerHeight * resolutionScale);
        }

        chromatiq.needsUpdate = true;
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
        sessionStorage.setItem("guiWidth", gui.width.toString());
        sessionStorage.setItem("debugCamera", config.debugCamera.toString());
        sessionStorage.setItem("debugParams", config.debugParams.toString());
        sessionStorage.setItem("debugDisableReset", config.debugDisableReset.toString());
        sessionStorage.setItem("resolution", config.resolution);
        sessionStorage.setItem("timeMode", config.timeMode);
        sessionStorage.setItem("bpm", config.bpm.toString());
        sessionStorage.setItem("debugFrameNumber", chromatiq.debugFrameNumber.toString());

        sessionStorage.setItem("time", chromatiq.time.toString());
        sessionStorage.setItem("isPlaying", chromatiq.isPlaying.toString());
        sessionStorage.setItem("timeLength", timeLengthInput.value);

        sessionStorage.setItem("guiClosed", gui.closed.toString());

        for (const [key, uniform] of Object.entries(chromatiq.uniforms)) {
            sessionStorage.setItem(key, uniform.toString());
        }
    }

    const loadFromSessionStorage = () => {
        const parseBool = (value: string) => {
            return value === "true"
        }

        const guiWidthStr = sessionStorage.getItem("guiWidth");
        if (guiWidthStr) {
            gui.width = parseFloat(guiWidthStr);
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
            chromatiq.debugFrameNumber = parseFloat(debugFrameNumberStr);
        }

        const timeStr = sessionStorage.getItem("time")
        if (timeStr) {
            chromatiq.time = parseFloat(timeStr);
        }

        const isPlayingStr = sessionStorage.getItem("isPlaying");
        if (isPlayingStr) {
            chromatiq.isPlaying = parseBool(isPlayingStr);
            playPauseButton.value = chromatiq.isPlaying ? pauseChar : playChar;
        }

        const timeLengthStr = sessionStorage.getItem("timeLength");
        if (timeLengthStr) {
            timeLengthInput.valueAsNumber = parseFloat(timeLengthStr);
        } else {
            timeLengthInput.valueAsNumber = chromatiq.timeLength;
        }

        beatLengthInput.valueAsNumber = timeToBeat(timeLengthInput.valueAsNumber);
        onTimeLengthUpdate();
        onBeatLengthUpdate();

        const guiClosedStr = sessionStorage.getItem("guiClosed")
        if (guiClosedStr) {
            gui.closed = parseBool(guiClosedStr);
        }

        for (const [key, uniform] of Object.entries(chromatiq.uniforms)) {
            const unifromStr = sessionStorage.getItem(key);
            if (unifromStr) {
                const ary = unifromStr.split(",");
                if (ary.length === 3) {
                    chromatiq.uniforms[key] = ary.map(s => parseFloat(s));
                }
                else if (ary.length === 1) {
                    chromatiq.uniforms[key] = parseFloat(unifromStr);
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
        camera.position.set(chromatiq.uniforms.gCameraEyeX, chromatiq.uniforms.gCameraEyeY, chromatiq.uniforms.gCameraEyeZ);
        camera.lookAt(chromatiq.uniforms.gCameraTargetX, chromatiq.uniforms.gCameraTargetY, chromatiq.uniforms.gCameraTargetZ);
    }

    const controls = new THREE.OrbitControls(camera, chromatiq.canvas);
    controls.target = new three.Vector3(chromatiq.uniforms.gCameraTargetX, chromatiq.uniforms.gCameraTargetY, chromatiq.uniforms.gCameraTargetZ);
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
    chromatiq.onRender = (time, timeDelta) => {
        timeInput.valueAsNumber = time;
        beatInput.valueAsNumber = timeToBeat(time);
        timeBar.valueAsNumber = time;
        beatBar.valueAsNumber = timeToBeat(time);

        const fps = 1.0 / timeDelta;
        fpsSpan.innerText = `${fps.toFixed(2)} FPS`;

        stats.begin();

        if (!config.debugParams) {
            animateUniforms(time, config.debugCamera, config.debugDisableReset);
        }
    }

    chromatiq.onPostRender = () => {
        stats.end();
        stats.update();
        gui.updateDisplay();
    }

    chromatiq.onUpdate = () => {
        if (config.debugCamera) {
            controls.update();

            if (!camera.position.equals(prevCameraPosotion) || !controls.target.equals(prevCameraTarget)) {
                chromatiq.uniforms.gCameraEyeX = camera.position.x;
                chromatiq.uniforms.gCameraEyeY = camera.position.y;
                chromatiq.uniforms.gCameraEyeZ = camera.position.z;
                chromatiq.uniforms.gCameraTargetX = controls.target.x;
                chromatiq.uniforms.gCameraTargetY = controls.target.y;
                chromatiq.uniforms.gCameraTargetZ = controls.target.z;

                gui.updateDisplay();
                chromatiq.needsUpdate = true;
            }

            prevCameraPosotion.copy(camera.position);
            prevCameraTarget.copy(controls.target);
        }
    }

    if (chromatiq.isPlaying) {
        chromatiq.playSound();
    }


    // UI Events
    window.addEventListener("resize", onResolutionCange);

    stopButton.addEventListener("click", ev => {
        if (chromatiq.isPlaying) {
            chromatiq.stopSound();
        }

        chromatiq.isPlaying = false;
        chromatiq.needsUpdate = true;
        chromatiq.time = 0;
        playPauseButton.value = playChar;
    });

    playPauseButton.addEventListener("click", ev => {
        chromatiq.isPlaying = !chromatiq.isPlaying;
        playPauseButton.value = chromatiq.isPlaying ? pauseChar : playChar;

        if (chromatiq.isPlaying) {
            chromatiq.playSound()
        } else {
            chromatiq.stopSound();
        }
    });

    frameDecButton.addEventListener("click", ev => {
        if (chromatiq.isPlaying) {
            chromatiq.stopSound();
        }

        chromatiq.isPlaying = false;
        chromatiq.needsUpdate = true;
        chromatiq.time -= 1 / 60;
    });

    frameIncButton.addEventListener("click", ev => {
        if (chromatiq.isPlaying) {
            chromatiq.stopSound();
        }

        chromatiq.isPlaying = false;
        chromatiq.needsUpdate = true;
        chromatiq.time += 1 / 60;
    });

    timeInput.addEventListener("input", ev => {
        if (chromatiq.isPlaying) {
            chromatiq.stopSound();
        }

        chromatiq.time = timeInput.valueAsNumber;
        playPauseButton.value = playChar;
        chromatiq.isPlaying = false;
        chromatiq.needsUpdate = true;
    });

    beatInput.addEventListener("input", ev => {
        if (chromatiq.isPlaying) {
            chromatiq.stopSound();
        }

        chromatiq.time = beatToTime(beatInput.valueAsNumber);
        playPauseButton.value = playChar;
        chromatiq.isPlaying = false;
        chromatiq.needsUpdate = true;
    });

    timeBar.addEventListener("input", ev => {
        if (chromatiq.isPlaying) {
            chromatiq.stopSound();
        }

        chromatiq.time = timeBar.valueAsNumber;
        playPauseButton.value = playChar;
        chromatiq.isPlaying = false;
        chromatiq.needsUpdate = true;
    });

    beatBar.addEventListener("input", ev => {
        if (chromatiq.isPlaying) {
            chromatiq.stopSound();
        }

        chromatiq.time = beatToTime(beatBar.valueAsNumber);
        playPauseButton.value = playChar;
        chromatiq.isPlaying = false;
        chromatiq.needsUpdate = true;
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