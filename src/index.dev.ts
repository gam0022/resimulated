import { ShaderPlayer } from "./shader-play"

window.addEventListener("load", ev => {
    const player = new ShaderPlayer(
        60,
        require("./shaders/vertex.glsl").default,
        [
            require("./shaders/kaleidoscope.glsl").default,
            require("./shaders/invert.glsl").default,
            require("./shaders/dot-matrix.glsl").default,
            require("./shaders/chromatic-aberration.glsl").default,
        ],
        require("./shaders/sound.glsl").default
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
        player.setSize(window.innerWidth * resolutionScale, window.innerHeight * resolutionScale);
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

    onResolutionCange();
    onTimeLengthUpdate();


    // SessionStorage
    const saveToSessionStorage = () => {
        sessionStorage.setItem("time", player.time.toString());
        sessionStorage.setItem("isPlaying", player.isPlaying ? "true" : "false");
        sessionStorage.setItem("resolutionScale", resolutionScaleSelect.value);
        sessionStorage.setItem("timeLength", timeLengthInput.value);
    }

    const loadFromSessionStorage = () => {
        const timeStr = sessionStorage.getItem("time")
        if (timeStr) {
            player.time = parseFloat(timeStr);
        }

        const isPlayingStr = sessionStorage.getItem("isPlaying");
        if (isPlayingStr) {
            player.isPlaying = isPlayingStr === "true";
            playPauseButton.value = player.isPlaying ? pauseChar : playChar;
        }

        const resolutionScaleStr = sessionStorage.getItem("resolutionScale");
        if (resolutionScaleStr) {
            resolutionScaleSelect.value = resolutionScaleStr;
        }

        const timeLengthStr = sessionStorage.getItem("timeLength");
        if (timeLengthStr) {
            timeLengthInput.value = timeLengthStr;
            onTimeLengthUpdate();
        }
    }

    loadFromSessionStorage();
    window.addEventListener("beforeunload", ev => {
        saveToSessionStorage();
    })


    // Player
    player.onRender = (time, timeDelta) => {
        timeBar.valueAsNumber = time;
        timeInput.valueAsNumber = time;
        const fps = 1.0 / timeDelta;
        fpsSpan.innerText = `${fps.toFixed(2)} FPS`;
    }

    if (player.isPlaying) {
        player.playSound();
    }


    // UI Events
    window.addEventListener("resize", onResolutionCange);

    resolutionScaleSelect.addEventListener("input", ev => {
        onResolutionCange();
    })

    stopButton.addEventListener("click", ev => {
        player.isPlaying = false;
        player.time = 0;
        playPauseButton.value = playChar;
        player.stopSound();
    })

    playPauseButton.addEventListener("click", ev => {
        player.isPlaying = !player.isPlaying;
        playPauseButton.value = player.isPlaying ? pauseChar : playChar;

        if (player.isPlaying) {
            player.playSound()
        } else {
            player.stopSound();
        }
    })

    timeInput.addEventListener("input", ev => {
        player.time = timeInput.valueAsNumber;
        playPauseButton.value = playChar;
        player.isPlaying = false;

        if (player.isPlaying) {
            player.playSound()
        } else {
            player.stopSound();
        }
    })

    timeBar.addEventListener("input", ev => {
        player.time = timeBar.valueAsNumber;
        playPauseButton.value = playChar;
        player.isPlaying = false;
        player.stopSound();
    })

    timeLengthInput.addEventListener("input", ev => {
        onTimeLengthUpdate();
    })
}, false);