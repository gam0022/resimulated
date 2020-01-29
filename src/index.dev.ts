import { Chromatic } from "./chromatic"

window.addEventListener("load", ev => {
    const chromatic = new Chromatic(
        48,// デモの長さ（秒）
        require("./shaders/vertex.glsl").default,
        [
            require("./shaders/raymarching.glsl").default,
            require("./shaders/bloom-prefilter.glsl").default,
            require("./shaders/bloom-downsample.glsl").default,
            //require("./shaders/bloom-downsample.glsl").default,
            //require("./shaders/bloom-downsample.glsl").default,
            require("./shaders/blit.glsl").default,

            //require("./shaders/kaleidoscope.glsl").default,
            //require("./shaders/invert.glsl").default,
            //require("./shaders/dot-matrix.glsl").default,
            //require("./shaders/chromatic-aberration.glsl").default,
        ],
        [
            1,
            1,
            0.5,
            0.25,
            0.5,
            1,
            1,
        ],
        require("./shaders/sound-template.glsl").default
    );


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
    }

    onResolutionCange();

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
    window.addEventListener("beforeunload", ev => {
        saveToSessionStorage();
    })


    // Player
    chromatic.onRender = (time, timeDelta) => {
        timeBar.valueAsNumber = time;
        timeInput.valueAsNumber = time;
        const fps = 1.0 / timeDelta;
        fpsSpan.innerText = `${fps.toFixed(2)} FPS`;
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