import { ShaderPlayer } from "./shader-play"

window.addEventListener("load", ev => {
    const player = new ShaderPlayer(
        require("./vertex.glsl").default,
        require("./fragment.glsl").default,
        [
            require("./buffer0.glsl").default,
        ]
    );


    // consts
    const pauseChar = "\uf04c";
    const playChar = "\uf04b";


    // HTMLElements
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
    player.onRender = (time) => {
        timeBar.valueAsNumber = time;
        timeInput.valueAsNumber = time;
    }


    // UI Events
    window.addEventListener("resize", onResolutionCange);

    resolutionScaleSelect.addEventListener("input", ev => {
        onResolutionCange();
    })

    stopButton.addEventListener("click", (event) => {
        player.isPlaying = false;
        player.time = 0;
        playPauseButton.value = playChar;
    })

    playPauseButton.addEventListener("click", (event) => {
        player.isPlaying = !player.isPlaying;
        playPauseButton.value = player.isPlaying ? pauseChar : playChar;
    })

    timeInput.addEventListener("input", (event) => {
        player.time = timeInput.valueAsNumber;
        playPauseButton.value = playChar;
        player.isPlaying = false;
    })

    timeBar.addEventListener("input", (event) => {
        player.time = timeBar.valueAsNumber;
        playPauseButton.value = playChar;
        player.isPlaying = false;
    })

    timeLengthInput.addEventListener("input", (event) => {
        onTimeLengthUpdate();
    })
}, false);