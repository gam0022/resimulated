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
    float amp = exp(-1.0 * time);
    float phase = 15.0 * time - 13.0 * exp(-40.0 * time);
    return amp * sine(phase);
}

vec2 hihat(float note, float time) {
    float amp = exp(-50.0 * time);
    return amp * noise(time * 100.0).xy;
}

// synths
vec2 bass(float note, float time) {
    float freq = noteToFreq(note);
    return vec2(saw(freq * time) + sine(freq * time)) / 2.0;
}

vec2 pad(float note, float time) {
    float freq = noteToFreq(note);
    float vib = 0.2 * sine(3.0 * time);
    return vec2(saw(freq * 0.99 * time + vib), saw(freq * 1.01 * time + vib));
}

vec2 arp(float note, float time) {
    float freq = noteToFreq(note);
    float fmamp = 0.1 * exp(-30.0 * time);
    float fm = fmamp * square(time * freq * 1.0);
    float amp = exp(-50.0 * time);
    return amp * vec2(sine(freq * 0.999 * time + fm), sine(freq * 1.001 * time + fm));
}

vec2 arpsine(float note, float time) {
    float freq = noteToFreq(note);
    float fmamp = 0.02 * exp(-70.0 * time);
    float fm = fmamp * sine(time * freq * 1.0);
    float amp = exp(-70.0 * time);
    return amp * vec2(sine(freq * 0.999 * time + fm), sine(freq * 1.001 * time + fm));
}

vec2 supersaw(float note, float time) {
    float amp = exp(-3.0 * time);
    float ret = 0.0;

    int num = 3;
    float step = 0.014;
    for (int i = 0; i < num; i++) {
        float freq = noteToFreq(note + 12.0 * float(i - num / 2));
        ret += saw(freq * time * (1.0 + step * float(i - num / 2)));
    }

    return vec2(amp * ret / float(num));
}

#define NSPC 256

// hard clipping distortion
float dist(float s, float d) { return clamp(s * d, -1.0, 1.0); }
vec2 dist(vec2 s, float d) { return clamp(s * d, -1.0, 1.0); }

// my resonant lowpass filter's frequency response
float _filter(float h, float cut) {
    cut -= 20.0;
    float df = max(h - cut, 0.0), df2 = abs(h - cut);
    return exp(-0.005 * df * df) * 0.5 + exp(df2 * df2 * -0.1) * 2.2;
}

// tb303 core
vec2 synth(float note, float t) {
    vec2 v = vec2(0.0);
    float dr = 0.26;
    float amp = smoothstep(0.05, 0.0, abs(t - dr - 0.05) - dr) * exp(t * -1.0);
    float f = noteToFreq(note);
    float sqr = 1.0;  // smoothstep(0.0, 0.01, abs(mod(t * 9.0, 64.0) - 20.0) - 20.0);

    float base = f;                    // 50.0 + sin(sin(t * 0.1) * t) * 20.0;
    float flt = exp(t * -1.5) * 50.0;  // + pow(cos(t * 1.0) * 0.5 + 0.5, 4.0) * 80.0 - 0.0;
    for (int i = 0; i < NSPC; i++) {
        float h = float(i + 1);
        float inten = 1.0 / h;
        // inten *= sin((pow(h, sin(t) * 0.5 + 0.5) + t * 0.5) * pi2) * 0.9 + 0.1;

        inten = mix(inten, inten * mod(h, 2.0), sqr);

        inten *= exp(-1.0 * max(2.0 - h, 0.0));  // + exp(abs(h - flt) * -2.0) * 8.0;

        inten *= _filter(h, flt);

        v.x += inten * sin((TAU + 0.01) * (t * base * h));
        v.y += inten * sin(TAU * (t * base * h));
    }

    float o = v.x * amp;  // exp(max(tnote - 0.3, 0.0) * -5.0);

    // o = dist(o, 2.5);

    return vec2(dist(v * amp, 2.0));
}

vec2 synth1_echo(float note, float time) {
    vec2 v;
    v = synth(note, time) * 0.5;  // + synth2(time) * 0.5;
    float ec = 0.4, fb = 0.6, et = 2.0 / 9.0, tm = 2.0 / 9.0;
    v += synth(note, time - et) * ec * vec2(1.0, 0.5);
    ec *= fb;
    et += tm;
    v += synth(note, time - et).yx * ec * vec2(0.5, 1.0);
    ec *= fb;
    et += tm;
    v += synth(note, time - et) * ec * vec2(1.0, 0.5);
    ec *= fb;
    et += tm;
    v += synth(note, time - et).yx * ec * vec2(0.5, 1.0);
    ec *= fb;
    et += tm;

    return v;
}

// 1ビートを最大何分割するか。16分音符に対応するなら4
#define NOTE_DIV 4

#define F(a) a | 4 << 8, a | 4 << 8, a | 4 << 8, a | 4 << 8
#define E(a) a | 8 << 8, a | 8 << 8
#define E2(a, b) a | 8 << 8, a | 8 << 8, b | 8 << 8, b | 8 << 8
#define S(a) a | 16 << 8
#define S4(a, b, c, d) a | 16 << 8, b | 16 << 8, c | 16 << 8, d | 16 << 8

#define SEQUENCER(beat, time, beatLen, devPat, devLen, notes, development, toneFunc)                    \
    int indexOffset = development[int(mod(beat / float(beatLen), float(devLen)))] * beatLen * NOTE_DIV; \
                                                                                                        \
    int[beatLen * NOTE_DIV] indexes;                                                                    \
    for (int i = 0; i < beatLen * NOTE_DIV;) {                                                          \
        int div = notes[i + indexOffset] >> 8;                                                          \
        if (div == 4) {                                                                                 \
            indexes[i + 0] = i;                                                                         \
            indexes[i + 1] = i;                                                                         \
            indexes[i + 2] = i;                                                                         \
            indexes[i + 3] = i;                                                                         \
            i += 4;                                                                                     \
        } else if (div == 8) {                                                                          \
            indexes[i + 0] = i;                                                                         \
            indexes[i + 1] = i;                                                                         \
            i += 2;                                                                                     \
        } else if (div == 16) {                                                                         \
            indexes[i + 0] = i;                                                                         \
            i += 1;                                                                                     \
        }                                                                                               \
    }                                                                                                   \
                                                                                                        \
    float indexFloat = mod(beat * float(NOTE_DIV), float(beatLen * NOTE_DIV));                          \
    int index = int(indexFloat);                                                                        \
    int note = notes[index + indexOffset] & 255;                                                        \
    float localTime = beatToTime((indexFloat - float(indexes[index])) / float(NOTE_DIV));               \
    float amp = (note == 0) ? 0.0 : 1.0;                                                                \
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
        S4(57, 0, 59, 0),

        // 2
        S4(60, 0, 64, 0),

        // 3
        S4(67, 0, 69, 0),

        // 4
        S4(71, 0, 74, 0),

        // 5
        S4(57, 0, 59, 0),

        // 6
        S4(60, 0, 64, 0),

        // 7
        S4(67, 0, 69, 0),

        // 8
        S4(71, 0, 74, 0),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        S4(57, 0, 59, 0),

        // 2
        S4(60, 0, 64, 0),

        // 3
        S4(67, 0, 69, 0),

        // 4
        S4(71, 0, 74, 0),

        // 5
        S4(57, 0, 59, 0),

        // 6
        S4(60, 0, 64, 0),

        // 7
        S4(67, 0, 69, 0),

        // 8
        S4(71, 0, 74, 0));

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
#define ARP2_DEV_LEN 8

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
    int[ARP2_DEV_LEN] development = int[](0, 0, 0, 0, 1, 1, 1, 1);

    SEQUENCER(beat, time, ARP2_BEAT_LEN, ARP2_DEV_PAT, ARP2_DEV_LEN, notes, development, arp)
    return ret;
}

vec2 arp3(float beat, float time) {
// 1つの展開のビート数
#define ARP3_BEAT_LEN 8

// 展開のパターンの種類
#define ARP3_DEV_PAT 2

// 展開の長さ
#define ARP3_DEV_LEN 8

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[ARP3_BEAT_LEN * NOTE_DIV * ARP3_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        S4(72, 60, 55, 64),

        // 2
        S4(0, 0, 0, 0),

        // 3
        S4(67, 55, 64, 55),

        // 4
        S4(0, 0, 0, 0),

        // 5
        S4(72, 60, 55, 64),

        // 6
        S4(0, 0, 0, 0),

        // 7
        S4(67, 55, 64, 55),

        // 8
        S4(0, 0, 0, 0),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        S4(72, 60, 55, 64),

        // 2
        S4(0, 0, 0, 0),

        // 3
        S4(67, 55, 64, 55),

        // 4
        S4(0, 0, 0, 0),

        // 5
        S4(72, 60, 55, 64),

        // 6
        S4(0, 0, 0, 0),

        // 7
        S4(67, 55, 64, 55),

        // 8
        S4(0, 0, 0, 0));

    // 展開
    int[ARP3_DEV_LEN] development = int[](0, 0, 0, 0, 1, 1, 1, 1);

    SEQUENCER(beat, time, ARP3_BEAT_LEN, ARP3_DEV_PAT, ARP3_DEV_LEN, notes, development, arpsine)
    return ret;
}

vec2 arp4(float beat, float time) {
// 1つの展開のビート数
#define ARP4_BEAT_LEN 8

// 展開のパターンの種類
#define ARP4_DEV_PAT 2

// 展開の長さ
#define ARP4_DEV_LEN 8

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[ARP4_BEAT_LEN * NOTE_DIV * ARP4_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        S4(0, 0, 0, 0),

        // 2
        S4(67, 60, 72, 55),

        // 3
        S4(0, 0, 0, 0),

        // 4
        S4(67, 60, 79, 62),

        // 5
        S4(0, 0, 0, 0),

        // 6
        S4(67, 60, 72, 55),

        // 7
        S4(0, 0, 0, 0),

        // 8
        S4(67, 60, 79, 62),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        S4(0, 0, 0, 0),

        // 2
        S4(67, 60, 72, 55),

        // 3
        S4(0, 0, 0, 0),

        // 4
        S4(67, 60, 79, 62),

        // 5
        S4(0, 0, 0, 0),

        // 6
        S4(67, 60, 72, 55),

        // 7
        S4(0, 0, 0, 0),

        // 8
        S4(67, 60, 79, 62));

    // 展開
    int[ARP4_DEV_LEN] development = int[](0, 0, 0, 0, 1, 1, 1, 1);

    SEQUENCER(beat, time, ARP4_BEAT_LEN, ARP4_DEV_PAT, ARP4_DEV_LEN, notes, development, arpsine)
    return ret;
}

vec2 kick1(float beat, float time) {
// 1つの展開のビート数
#define KICK1_BEAT_LEN 8

// 展開のパターンの種類
#define KICK1_DEV_PAT 2

// 展開の長さ
#define KICK1_DEV_LEN 8

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
        F(0),

        // 4
        E2(0, 1),

        // 5
        F(1),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(1),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        F(1),

        // 2
        F(1),

        // 3
        F(1),

        // 4
        F(1),

        // 5
        F(1),

        // 6
        F(1),

        // 7
        F(1),

        // 8
        F(1));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[KICK1_DEV_LEN] development = int[](0, 0, 0, 0, 1, 1, 1, 1);

    SEQUENCER(beat, time, KICK1_BEAT_LEN, KICK1_DEV_PAT, KICK1_DEV_LEN, notes, development, kick)

    sidechain = smoothstep(0.0, 0.4, localTime);
    return ret;
}

vec2 testSupersaw(float beat, float time) {
// 1つの展開のビート数
#define KICK1_BEAT_LEN 8

// 展開のパターンの種類
#define KICK1_DEV_PAT 2

// 展開の長さ
#define KICK1_DEV_LEN 8

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
        F(64),

        // 2
        F(64),

        // 3
        F(64),

        // 4
        F(64),

        // 5
        F(64),

        // 6
        F(64),

        // 7
        F(64),

        // 8
        F(64),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        F(67),

        // 2
        F(67),

        // 3
        F(67),

        // 4
        F(67),

        // 5
        F(67),

        // 6
        F(67),

        // 7
        F(67),

        // 8
        F(67));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[KICK1_DEV_LEN] development = int[](0, 0, 0, 0, 1, 1, 1, 1);

    SEQUENCER(beat, time, KICK1_BEAT_LEN, KICK1_DEV_PAT, KICK1_DEV_LEN, notes, development, supersaw)
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
    float bassNote = chord(0.0) - 22.0;
    ret += sidechain * 0.3 * bass(bassNote, time);

    // chord
    ret += sidechain * 0.0 * vec2(pad(chord(0.0), time) + pad(chord(1.0), time) + pad(chord(2.0), time) + pad(chord(3.0), time)) / 4.0;

    // arp
    ret += vec2(0.2, 0.0) * arp1(beat, time);  // L70 R0
    ret += vec2(0.0, 0.2) * arp2(beat, time);  // R70 R0
    ret += vec2(0.1, 0.6) * arp3(beat, time);  // R70 R0 サイン波のアルペジオ
    ret += vec2(0.6, 0.1) * arp4(beat, time);  // R70 R0 サイン波のアルペジオ

    // supersaw以外の音をMute
    ret = vec2(0.0);

    // supersawのテスト
    ret += testSupersaw(beat, time);

    return clamp(ret, -1.0, 1.0);
}