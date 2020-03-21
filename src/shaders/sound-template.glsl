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

float sidechain;

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

// primitive oscillators
float sine(float phase) { return sin(TAU * phase); }
float saw(float phase) { return 2.0 * fract(phase) - 1.0; }
float square(float phase) { return fract(phase) < 0.5 ? -1.0 : 1.0; }

// drums
float kick(float note, float time) {
    float amp = exp(-5.0 * time);
    float phase = 50.0 * time - 10.0 * exp(-70.0 * time);
    return amp * sine(phase);
}

vec2 hihat(float note, float time) {
    float amp = exp(-50.0 * time);
    return amp * noise(time * 100.0).xy;
}

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
    float fmamp = 0.02 * exp(-70.0 * time);
    float fm = fmamp * sine(time * freq * 1.0);
    float amp = exp(-70.0 * time);
    return amp * vec2(sine(freq * 0.999 * time + fm), sine(freq * 1.001 * time + fm));
}

// 1ビートを最大何分割するか。16分音符に対応するなら4
#define NOTE_DIV 4

#define F(a) a | 4 << 8, a | 4 << 8, a | 4 << 8, a | 4 << 8
#define E(a) a | 8 << 8, a | 8 << 8
#define E2(a, b) a | 8 << 8, a | 8 << 8, b | 8 << 8, b | 8 << 8
#define S(a) a | 16 << 8
#define S4(a, b, c, d) a | 16 << 8, b | 16 << 8, c | 16 << 8, d | 16 << 8

#define SEQUENCER(beat, time, beatLen, devPat, devLen, notes, development, toneFunc)                                               \
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
    vec2 ret = vec2(toneFunc(float(note), localTime) * amp);

vec2 arp1(float beat, float time) {
// 1つの展開のビート数
#define ARP1_BEAT_LEN 8

// 展開のパターンの種類
#define ARP1_DEV_PAT 2

// 展開の長さ
#define ARP1_DEV_LEN 4

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[ARP1_BEAT_LEN * NOTE_DIV * ARP1_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        S4(69, 0, 71, 0),

        // 2
        S4(72, 0, 76, 0),

        // 3
        S4(79, 0, 81, 0),

        // 4
        S4(83, 0, 86, 0),

        // 5
        S4(69, 0, 71, 0),

        // 6
        S4(72, 0, 76, 0),

        // 7
        S4(79, 0, 81, 0),

        // 8
        S4(83, 0, 86, 0),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        S4(69, 0, 71, 0),

        // 2
        S4(72, 0, 76, 0),

        // 3
        S4(79, 0, 81, 0),

        // 4
        S4(83, 0, 86, 0),

        // 5
        S4(69, 0, 71, 0),

        // 6
        S4(72, 0, 76, 0),

        // 7
        S4(79, 0, 81, 0),

        // 8
        S4(83, 0, 86, 0));

    // 展開
    int[ARP1_DEV_LEN] development = int[](0, 0, 1, 1);

    SEQUENCER(beat, time, ARP1_BEAT_LEN, ARP1_DEV_PAT, ARP1_DEV_LEN, notes, development, arp)
    return ret;
}

vec2 arp2(float beat, float time) {
// 1つの展開のビート数
#define ARP2_BEAT_LEN 8

// 展開のパターンの種類
#define ARP2_DEV_PAT 2

// 展開の長さ
#define ARP2_DEV_LEN 4

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[ARP2_BEAT_LEN * NOTE_DIV * ARP2_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        S4(0, 69, 0, 71),

        // 2
        S4(0, 72, 0, 76),

        // 3
        S4(0, 79, 0, 81),

        // 4
        S4(0, 83, 0, 86),

        // 5
        S4(0, 69, 0, 71),

        // 6
        S4(0, 72, 0, 76),

        // 7
        S4(0, 79, 0, 81),

        // 8
        S4(0, 83, 0, 86),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        S4(0, 69, 0, 71),

        // 2
        S4(0, 72, 0, 76),

        // 3
        S4(0, 79, 0, 81),

        // 4
        S4(0, 83, 0, 86),

        // 5
        S4(0, 69, 0, 71),

        // 6
        S4(0, 72, 0, 76),

        // 7
        S4(0, 79, 0, 81),

        // 8
        S4(0, 83, 0, 86));

    // 展開
    int[ARP2_DEV_LEN] development = int[](0, 0, 1, 1);

    SEQUENCER(beat, time, ARP2_BEAT_LEN, ARP2_DEV_PAT, ARP2_DEV_LEN, notes, development, arp)
    return ret;
}

vec2 kick1(float beat, float time) {
// 1つの展開のビート数
#define KICK1_BEAT_LEN 8

// 展開のパターンの種類
#define KICK1_DEV_PAT 2

// 展開の長さ
#define KICK1_DEV_LEN 4

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[KICK1_BEAT_LEN * NOTE_DIV * KICK1_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        F(1),

        // 2
        F(0),

        // 3
        F(1),

        // 4
        F(1),

        // 5
        F(1),

        // 6
        F(0),

        // 7
        F(1),

        // 8
        F(1),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        F(1),

        // 2
        F(0),

        // 3
        F(1),

        // 4
        F(1),

        // 5
        F(1),

        // 6
        F(0),

        // 7
        F(1),

        // 8
        F(1));

    // 展開
    int[KICK1_DEV_LEN] development = int[](0, 0, 1, 1);

    SEQUENCER(beat, time, KICK1_BEAT_LEN, KICK1_DEV_PAT, KICK1_DEV_LEN, notes, development, kick)

    sidechain = smoothstep(0.0, 0.4, localTime);
    return ret;
}

vec2 mainSound(float time) {
    float beat = timeToBeat(time);
    vec2 ret = vec2(0.0);

    // kick
    ret += kick1(beat, time);

    // hihat
    float hihatTime = beatToTime(mod(beat + 0.5, 1.0));
    ret += 0.5 * hihat(1.0, hihatTime);

    // bass
    float bassNote = chord(0.0) - 24.0;
    ret += sidechain * 0.6 * bass(bassNote, time);

    // chord
    ret += sidechain * 0.6 * vec2(pad(chord(0.0), time) + pad(chord(1.0), time) + pad(chord(2.0), time) + pad(chord(3.0), time)) / 4.0;

    // arp
    ret += vec2(0.7, 0.3) * arp1(beat, time);  // L70
    ret += vec2(0.3, 0.7) * arp2(beat, time);  // R70

    return clamp(ret, -1.0, 1.0);
}