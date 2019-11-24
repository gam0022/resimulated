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


    // status
    let resolutionScale = 0.5;


    // SessionStorage
    const saveToSessionStorage = () => {
        sessionStorage.setItem("time", player.time.toString());
        sessionStorage.setItem("isPlaying", player.isPlaying ? "true" : "false");
        sessionStorage.setItem("resolutionScale", resolutionScale.toString());
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
            resolutionScale = parseFloat(resolutionScaleStr);
            resolutionScaleSelect.value = resolutionScaleStr;
        }
    }
    loadFromSessionStorage();


    // UI
    const onResolutionCange = () => {
        player.setSize(window.innerWidth * resolutionScale, window.innerHeight * resolutionScale);
    }
    onResolutionCange();
    window.addEventListener("resize", onResolutionCange);

    resolutionScaleSelect.addEventListener("input", ev => {
        resolutionScale = parseFloat(resolutionScaleSelect.value);
        onResolutionCange();
        saveToSessionStorage();
    })

    stopButton.addEventListener("click", (event) => {
        player.isPlaying = false;
        player.time = 0;
        playPauseButton.value = playChar;
        saveToSessionStorage();
    })

    playPauseButton.addEventListener("click", (event) => {
        player.isPlaying = !player.isPlaying;
        playPauseButton.value = player.isPlaying ? pauseChar : playChar;
        saveToSessionStorage();
    })

    timeInput.addEventListener("input", (event) => {
        player.time = timeInput.valueAsNumber;
        playPauseButton.value = playChar;
        player.isPlaying = false;
        saveToSessionStorage();
    })

    timeBar.addEventListener("input", (event) => {
        player.time = timeBar.valueAsNumber;
        playPauseButton.value = playChar;
        player.isPlaying = false;
        saveToSessionStorage();
    })

    timeLengthInput.addEventListener("input", (event) => {
        timeBar.max = timeLengthInput.value;
        onTimeLengthUpdate();
        saveToSessionStorage();
    })

    player.onRender = (time) => {
        timeBar.valueAsNumber = time;
        timeInput.valueAsNumber = time;
        saveToSessionStorage();
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