import { ShaderPlayer } from "./shader-play"

window.addEventListener("load", ev => {
    const player = new ShaderPlayer();

    const stopButton = <HTMLInputElement>document.getElementById('stop-button');
    stopButton.addEventListener("click", (event) => {
        player.isPlaying = false;
        player.time = 0;
        playPauseButton.value = "▶";
    })

    const playPauseButton = <HTMLInputElement>document.getElementById("play-pause-button");
    playPauseButton.addEventListener("click", (event) => {
        player.isPlaying = !player.isPlaying;
        playPauseButton.value = player.isPlaying ? "⏸" : "▶";
    })

    const timeInput = <HTMLInputElement>document.getElementById("time-input");
    timeInput.addEventListener("input", (event) => {
        player.time = timeInput.valueAsNumber;
        playPauseButton.value = "▶";
        player.isPlaying = false;
    })

    const timeBar = <HTMLInputElement>document.getElementById("time-bar");
    timeBar.addEventListener("input", (event) => {
        player.time = timeBar.valueAsNumber;
        playPauseButton.value = "▶";
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