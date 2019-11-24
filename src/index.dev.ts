import { ShaderPlayer } from "./shader-play"

window.addEventListener("load", ev => {
    const player = new ShaderPlayer(
        require("./vertex.glsl").default,
        require("./fragment.glsl").default,
        [
            require("./buffer0.glsl").default,
        ]
    );

    let resolutionScale = 0.5;
    const onResolutionCange = () => {
        player.setSize(window.innerWidth * resolutionScale, window.innerHeight * resolutionScale);
    }

    onResolutionCange();
    window.addEventListener("resize", onResolutionCange);

    const resolutionScaleSelect = <HTMLSelectElement>document.getElementById("resolution-scale");
    resolutionScaleSelect.addEventListener("input", ev => {
        resolutionScale = parseFloat(resolutionScaleSelect.value);
        onResolutionCange();
    })

    const pauseChar = "\uf04c";
    const playChar = "\uf04b";

    const stopButton = <HTMLInputElement>document.getElementById("stop-button");
    stopButton.addEventListener("click", (event) => {
        player.isPlaying = false;
        player.time = 0;
        playPauseButton.value = playChar;
    })

    const playPauseButton = <HTMLInputElement>document.getElementById("play-pause-button");
    playPauseButton.addEventListener("click", (event) => {
        player.isPlaying = !player.isPlaying;
        playPauseButton.value = player.isPlaying ? pauseChar : playChar;
    })

    const time_str = sessionStorage.getItem("time")
    if (time_str !== null) {
        const time = parseFloat(time_str);
        player.time = time;
    }

    const timeInput = <HTMLInputElement>document.getElementById("time-input");
    timeInput.addEventListener("input", (event) => {
        player.time = timeInput.valueAsNumber;
        playPauseButton.value = playChar;
        player.isPlaying = false;
    })

    const timeBar = <HTMLInputElement>document.getElementById("time-bar");
    timeBar.addEventListener("input", (event) => {
        player.time = timeBar.valueAsNumber;
        playPauseButton.value = playChar;
        player.isPlaying = false;
    })

    const timeLengthInput = <HTMLInputElement>document.getElementById("time-length-input");
    timeLengthInput.addEventListener("input", (event) => {
        timeBar.max = timeLengthInput.value;
        onTimeLengthUpdate();
    })

    const tickmarks = document.getElementById("tickmarks");

    player.onRender = (time) => {
        timeBar.valueAsNumber = time;
        timeInput.valueAsNumber = time;
        sessionStorage.setItem("time", time.toString());
    }

    const onTimeLengthUpdate = () => {
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
    onTimeLengthUpdate();
}, false);