#version 300 es
precision mediump float;
uniform float iSampleRate;
uniform float iBlockOffset;

vec2 mainSound(float time);

out vec4 outColor;
void main() {
    float t = iBlockOffset + ((gl_FragCoord.x - 0.5) + (gl_FragCoord.y - 0.5) * 512.0) / iSampleRate;
    vec2 y = mainSound(t);
    vec2 v = floor((0.5 + 0.5 * y) * 65536.0);
    vec2 vl = mod(v, 256.0) / 255.0;
    vec2 vh = floor(v / 256.0) / 255.0;
    outColor = vec4(vl.x, vh.x, vl.y, vh.y);
}

//--------------------
// ここから下を書き換える
//--------------------

#define BPM 140.0

#define PI 3.141592654
#define TAU 6.283185307

// ------
// general functions

float timeToBeat(float t) { return t / 60.0 * BPM; }
float beatToTime(float b) { return b / BPM * 60.0; }

float noteToFreq(float n) { return 440.0 * pow(2.0, (n - 69.0) / 12.0); }

float chord(float n) { return (n < 1.0 ? 55.0 : n < 2.0 ? 58.0 : n < 3.0 ? 62.0 : 65.0); }

// https://www.shadertoy.com/view/4djSRW
vec4 noise(float p) {
    vec4 p4 = fract(vec4(p) * vec4(.1031, .1030, .0973, .1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

// ------
// primitive oscillators

float sine(float phase) { return sin(TAU * phase); }

float saw(float phase) { return 2.0 * fract(phase) - 1.0; }

float square(float phase) { return fract(phase) < 0.5 ? -1.0 : 1.0; }

// ------
// drums

float kick(float time) {
    float amp = exp(-5.0 * time);
    float phase = 50.0 * time - 10.0 * exp(-70.0 * time);
    return amp * sine(phase);
}

vec2 hihat(float time) {
    float amp = exp(-50.0 * time);
    return amp * noise(time * 100.0).xy;
}

// ------
// synths

vec2 bass(float note, float time) {
    float freq = noteToFreq(note);
    return vec2(square(freq * time) + sine(freq * time)) / 2.0;
}

vec2 pad(float note, float time) {
    float freq = noteToFreq(note);
    float vib = 0.2 * sine(3.0 * time);
    return vec2(saw(freq * 0.99 * time + vib), saw(freq * 1.01 * time + vib));
}

vec2 arp(float note, float time) {
    float freq = noteToFreq(note);
    float fmamp = 0.1 * exp(-50.0 * time);
    float fm = fmamp * sine(time * freq * 7.0);
    float amp = exp(-20.0 * time);
    return amp * vec2(sine(freq * 0.99 * time + fm), sine(freq * 1.01 * time + fm));
}

// 1ビートを最大何分割するか。16分音符に対応するなら4
#define NOTE_DIV 4

#define F(a) a | 4 << 8, a | 4 << 8, a | 4 << 8, a | 4 << 8
#define E(a, b) a | 8 << 8, a | 8 << 8, b | 8 << 8, b | 8 << 8
#define S(a, b, c, d) a | 16 << 8, b | 16 << 8, c | 16 << 8, d | 16 << 8

#define SEQUENCER(beat, time, beatLen, devNum, devLen, notes, development, toneFunc)                                               \
    int indexOffset = development[int(mod(beat / float(beatLen), float(devLen)))] * beatLen * NOTE_DIV;                            \
                                                                                                                                   \
    int[beatLen * NOTE_DIV] indexes;                                                                                               \
    int currentIndex = 0;                                                                                                          \
    for (int i = 0; i < beatLen * NOTE_DIV;) {                                                                                     \
        int div = notes[i + indexOffset] >> 8;                                                                                     \
        if (div == 4) {                                                                                                            \
            indexes[i + 0] = currentIndex;                                                                                         \
            indexes[i + 1] = currentIndex;                                                                                         \
            indexes[i + 2] = currentIndex;                                                                                         \
            indexes[i + 3] = currentIndex;                                                                                         \
            i += 4;                                                                                                                \
        } else if (div == 8) {                                                                                                     \
            indexes[i + 0] = currentIndex;                                                                                         \
            indexes[i + 1] = currentIndex;                                                                                         \
            i += 2;                                                                                                                \
        } else if (div == 16) {                                                                                                    \
            indexes[i + 0] = currentIndex;                                                                                         \
            i += 1;                                                                                                                \
        }                                                                                                                          \
                                                                                                                                   \
        currentIndex += 16 / div;                                                                                                  \
    }                                                                                                                              \
                                                                                                                                   \
    float indexFloat = mod(beat * float(NOTE_DIV), float(beatLen * NOTE_DIV));                                                     \
    int index = int(indexFloat);                                                                                                   \
    int note = notes[index + indexOffset] & 255;                                                                                   \
    float localTime = beatToTime((indexFloat - float(indexes[index])) / float(notes[index + indexOffset] >> 8) * float(NOTE_DIV)); \
    float amp = (note == 0) ? 0.0 : 1.0;                                                                                           \
    return vec2(toneFunc(float(note), localTime) * amp);

vec2 arp1(float beat, float time) {
// 1つの展開のビート数
#define ARP1_BEAT_LEN 8

// 展開のパターンの種類
#define ARP1_DEV_NUM 2

// 展開の長さ
#define ARP1_DEV_LEN 4

    // ノート番号
    // F: 4分音符
    // R: 8分音符
    // S: 16分音符
    int[ARP1_BEAT_LEN * NOTE_DIV * ARP1_DEV_NUM] notes = int[](
        //
        // 展開1
        //

        // 1
        F(69),

        // 2
        E(69, 70),

        // 3
        S(69, 70, 69, 72),

        // 4
        F(69),

        // 5
        E(69, 70),

        // 6
        E(69, 0),

        // 7
        S(69, 0, 69, 0),

        // 8
        E(69, 70),

        //
        // 展開2
        //

        // 1
        F(69),

        // 2
        F(69),

        // 3
        F(69),

        // 4
        F(69),

        // 5
        F(69),

        // 6
        F(69),

        // 7
        F(69),

        // 8
        F(69));

    // 展開
    int[ARP1_DEV_LEN] development = int[](0, 1, 0, 0);

    SEQUENCER(beat, time, ARP1_BEAT_LEN, ARP1_DEV_NUM, ARP1_DEV_LEN, notes, development, arp)
}

// ------
// main

vec2 mainSound(float time) {
    float beat = timeToBeat(time);
    vec2 ret = vec2(0.0);

    // ---
    // kick

    float kickTime = beatToTime(mod(beat, 1.0));
    ret += 0.8 * kick(kickTime);

    float sidechain = smoothstep(0.0, 0.4, kickTime);

    // ---
    // hihat

    float hihatTime = beatToTime(mod(beat + 0.5, 1.0));
    ret += 0.5 * hihat(hihatTime);

    // ---
    // bass

    float bassNote = chord(0.0) - 24.0;
    ret += sidechain * 0.6 * bass(bassNote, time);

    // ---
    // chord

    ret += sidechain * 0.6 * vec2(pad(chord(0.0), time) + pad(chord(1.0), time) + pad(chord(2.0), time) + pad(chord(3.0), time)) / 4.0;

    // ---
    // arp

    /*float arpTime = beatToTime(mod(beat, 0.25));

    // ノート番号を指定していします
    float[8 * 2] arpNotes = float[](
        // 展開1
        69.0, 70.0, 71.0, 72.0, 69.0, 70.0, 69.0, 72.0,

        // 展開2
        50.0, 51.0, 52.0, 53.0, 50.0, 51.0, 52.0, 53.0);

    // 展開 0 -> 1 -> 0
    int[3] offsets = int[](0, 1, 0);

    // ノート番号を決定します
    float arpNote = arpNotes[offsets[int(mod(beat / 8.0, 3.0))] * 8 + int(mod(beat, 8.0))];

    ret += sidechain * 0.5 * vec2(arp(arpNote, arpTime));*/

    // ---

    ret += arp1(beat, time);

    return clamp(ret, -1.0, 1.0);
}