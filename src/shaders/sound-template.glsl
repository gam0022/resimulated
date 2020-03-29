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
float sidechain2;
float sidechain3;

// general functions
float timeToBeat(float t) { return t / 60.0 * BPM; }
float beatToTime(float b) { return b / BPM * 60.0; }
float noteToFreq(float n) { return 440.0 * pow(2.0, (n - 69.0) / 12.0); }

// https://www.shadertoy.com/view/4djSRW
vec4 noise(float p) {
    vec4 p4 = fract(vec4(p) * vec4(.1050, .1030, .0973, .1099));
    p4 += dot(p4, p4.wzxy + 55.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

// quantize https://www.shadertoy.com/view/ldfSW2
float quan(float s, float c) { return floor(s / c) * c; }

// hash
float nse(float x) {
    return fract(sin(x * 110.082) * 19871.8972);
    // return fract(sin(x * 110.082) * 13485.8372);
}

float dist(float s, float d) { return clamp(s * d, -1.0, 1.0); }

// primitive oscillators
float sine(float phase) { return sin(TAU * phase); }
float saw(float phase) { return 2.0 * fract(phase) - 1.0; }
float square(float phase) { return fract(phase) < 0.5 ? -1.0 : 1.0; }
float tri(float phase) { return abs(2. * fract(phase * .5 - .25) - 1.) * 2. - 1.; }

// drums
float kick(float note, float time) {
    float amp = exp(-2.0 * time);
    float phase = 30.0 * time - 15.0 * exp(-55.0 * time);
    return amp * sine(phase);
}

vec2 hihat(float note, float time) {
    float amp = exp(-50.0 * time);
    return amp * noise(time * 100.0).xy;
}

vec2 hihat2(float note, float time) {
    float amp = exp(-70.0 * time);
    return amp * noise(time * 300.0).xy;
}

vec2 hihat3(float note, float time) {
    float amp = exp(-50.0 * time);
    float phase = 200.0 * time - 300.0 * exp(-40.0 * time);
    return amp * noise(time * 300.0).xy;
}

// https://www.shadertoy.com/view/ldfSW2
vec2 crash1(float note, float time) {
    {
        // tb = fract(tb / 4.0) * 0.5;
        float aa = 15.0;
        time = sqrt(time * aa) / aa;
        float amp = exp(max(time - 0.15, 0.0) * -5.0);
        float v = nse(quan(mod(time, 0.6), 0.0001));
        v = dist(v, 0.1) * amp;
        return vec2(dist(v * amp, 2.0));
    }
}

// synths
vec2 bass(float note, float time) {
    float freq = noteToFreq(note);
    return vec2(saw(freq * time) + sine(freq * time)) / 1.5;
}

vec2 subbass(float note, float time) {
    float freq = noteToFreq(note);
    return vec2(sine(freq * time)) / 2.0;
}

vec2 pad(float note, float time) {
    float freq = noteToFreq(note);
    float vib = 0.2 * sine(3.0 * time);
    return vec2(saw(freq * 0.99 * time + vib), saw(freq * 1.01 * time + vib));
}

vec2 arp(float note, float time) {
    float freq = noteToFreq(note);
    float fmamp = 0.1 * exp(-30.0 * time);
    float fm = fmamp * square(time * freq * 1.2);
    float amp = exp(-50.0 * time);
    return amp * vec2(square(freq * time), tri(freq * time));
}

vec2 arpsaw(float note, float time) {
    float freq = noteToFreq(note);
    float fmamp = 0.02 * exp(-30.0 * time);
    float fm = fmamp * sine(time * freq * 1.0);
    float amp = exp(-30.0 * time);
    return amp * vec2(sine(freq * 0.999 * time + fm), saw(freq * 1.001 * time + fm));
}

vec2 arpsine(float note, float time) {
    float freq = noteToFreq(note);
    float fmamp = 0.02 * exp(-70.0 * time);
    float fm = fmamp * sine(time * freq * 1.0);
    float amp = exp(-70.0 * time);
    return amp * vec2(sine(freq * 0.999 * time + fm), sine(freq * 1.001 * time + fm));
}

vec2 arpsine2(float note, float time) {
    float freq = noteToFreq(note);
    float fmamp = 0.02 * exp(-30.0 * time);
    float fm = fmamp * sine(time * freq * 1.0);
    float amp = exp(-30.0 * time);
    return amp * vec2(sine(freq * 0.999 * time + fm), sine(freq * 1.001 * time + fm));
}

vec2 supersaw(float note, float time) {
    float amp = exp(0.0 * time * time);
    float vib = 0.2 * sine(3.0 * time);
    float ret = 0.0;
    int num = 3;
    float step = 0.014;
    int reverbNum = 100;

    for (int i = 0; i < num; i++) {
        float freq = noteToFreq(note + 12.0 * float(i - num / 2));
        for (int j = 0; j < reverbNum; j++) {
            ret += saw(freq * (time - 0.008 * float(j)) * (1.0 + step * float(i - num / 2))) * exp(-3.0 * float(j));
        }
    }

    return vec2(0.5 * amp * ret / float(num));
}

vec2 basssaw1(float note, float time) {
    float amp = exp(15.0 * time * time);
    float ret = 0.0;
    int num = 2;
    float step = 0.014;
    int reverbNum = 100;

    for (int i = 0; i < num; i++) {
        float freq = noteToFreq(note + 12.0 * float(i - num / 2));
        for (int j = 0; j < reverbNum; j++) {
            ret += saw(freq * (time - 0.008 * float(j)) * (1.0 + step * float(i - num / 2))) * exp(-3.0 * float(j));
        }
    }

    return vec2(0.5 * amp * ret / float(num));
}

vec2 basssaw2(float note, float time) {
    float amp = exp(15.0 * time * time);
    float ret = 0.0;
    int num = 2;
    float step = 0.014;
    int reverbNum = 100;

    for (int i = 0; i < num; i++) {
        float freq = noteToFreq(note + 12.0 * float(i - num / 2));
        for (int j = 0; j < reverbNum; j++) {
            ret += saw(freq * (time - 0.008 * float(j)) * (1.0 + step * float(i - num / 2))) * exp(-3.0 * float(j));
        }
    }

    return vec2(0.5 * amp * ret / float(num));
}

vec2 chordsaw1(float note, float time) {
    float amp = exp(0.0 * time * time);
    float ret = 0.0;
    int num = 3;
    float step = 0.023;
    int reverbNum = 100;

    for (int i = 0; i < num; i++) {
        float freq = noteToFreq(note + 12.0 * float(i - num / 2));
        for (int j = 0; j < reverbNum; j++) {
            ret += saw(freq * (time - 0.018 * float(j)) * (1.0 + step * float(i - num / 2))) * exp(-3.0 * float(j));
        }
    }

    return vec2(0.5 * amp * ret / float(num));
}

vec2 chordsquare1(float note, float time) {
    float freq = noteToFreq(note);
    return vec2(square(freq * time) + sine(freq * time)) / 1.5;
}

#define NSPC 256

// hard clipping distortion
// float dist(float s, float d) { return clamp(s * d, -1.0, 1.0); }
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
    float dr = 0.15;
    float amp = smoothstep(0.1, 0.0, abs(t - dr - 0.1) - dr) * exp(t * 0.2);
    float f = noteToFreq(note);
    float sqr = 0.1;  // smoothstep(0.0, 0.01, abs(mod(t * 9.0, 64.0) - 20.0) - 20.0);

    float base = f;                    // 50.0 + sin(sin(t * 0.1) * t) * 20.0;
    float flt = exp(t * -1.5) * 30.0;  // + pow(cos(t * 1.0) * 0.5 + 0.5, 4.0) * 80.0 - 0.0;
    for (int i = 0; i < NSPC; i++) {
        float h = float(i + 1);
        float inten = 2.0 / h;
        // inten *= sin((pow(h, sin(t) * 0.5 + 0.5) + t * 0.5) * pi2) * 0.9 + 0.1;

        inten = mix(inten, inten * mod(h, 2.0), sqr);

        inten *= exp(-2.0 * max(2.0 - h, 0.0));  // + exp(abs(h - flt) * -2.0) * 8.0;

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
    float ec = 0.4, fb = 0.3, et = 2.0 / 9.0, tm = 2.0 / 9.0;
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

vec2 attackbass(float note, float t) {
    vec2 v = vec2(0.0);
    float dr = 0.15;
    float amp = smoothstep(0.1, 0.0, abs(t - dr - 0.1) - dr) * exp(t * 0.2);
    float f = noteToFreq(note);
    float sqr = 0.1;  // smoothstep(0.0, 0.01, abs(mod(t * 9.0, 64.0) - 20.0) - 20.0);

    float base = f;                    // 50.0 + sin(sin(t * 0.1) * t) * 20.0;
    float flt = exp(t * -1.5) * 30.0;  // + pow(cos(t * 1.0) * 0.5 + 0.5, 4.0) * 80.0 - 0.0;
    for (int i = 0; i < NSPC; i++) {
        float h = float(i + 1);
        float inten = 2.0 / h;
        // inten *= sin((pow(h, sin(t) * 0.5 + 0.5) + t * 0.5) * pi2) * 0.9 + 0.1;

        inten = mix(inten, inten * mod(h, 2.0), sqr);

        inten *= exp(-2.0 * max(2.0 - h, 0.0));  // + exp(abs(h - flt) * -2.0) * 8.0;

        inten *= _filter(h, flt);

        v.x += inten * sin((TAU + 0.01) * (t * base * h));
        v.y += inten * sin(TAU * (t * base * h));
    }

    float o = v.x * amp;  // exp(max(tnote - 0.3, 0.0) * -5.0);

    // o = dist(o, 2.5);

    return vec2(dist(v * amp, 2.0));
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

//  KICK  //

vec2 kick1(float beat, float time) {
// 1つの展開のビート数
#define KICK1_BEAT_LEN 8

// 展開のパターンの種類
#define KICK1_DEV_PAT 3

// 展開の長さ
#define KICK1_DEV_LEN 16

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
        F(1),

        //
        // 展開2
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
        F(0));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[KICK1_DEV_LEN] development = int[](0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 2, 1, 1, 1, 1);

    SEQUENCER(beat, time, KICK1_BEAT_LEN, KICK1_DEV_PAT, KICK1_DEV_LEN, notes, development, kick)

    if (beat < 64.0) {
        sidechain = smoothstep(-0.2, 0.6, localTime);
    } else {
        sidechain = smoothstep(-0.2, 0.7, localTime);
    }

    if (beat < 64.0) {
        sidechain2 = smoothstep(-0.1, 0.6, localTime);
    } else {
        sidechain2 = smoothstep(-0.2, 0.7, localTime);
    }

    if (beat < 64.0) {
        sidechain3 = smoothstep(-0.0, 0.9, localTime);
    } else {
        sidechain3 = smoothstep(-0.2, 0.7, localTime);
    }

    return ret;
}

vec2 crashcymbal1(float beat, float time) {
// 1つの展開のビート数
#define CRASH1_BEAT_LEN 8

// 展開のパターンの種類
#define CRASH1_DEV_PAT 3

// 展開の長さ
#define CRASH1_DEV_LEN 16

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[CRASH1_BEAT_LEN * NOTE_DIV * CRASH1_DEV_PAT] notes = int[](
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
        F(0),

        // 5
        F(0),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        F(0),

        // 4
        F(0),

        // 5
        F(0),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0),

        //
        // 展開2（とりあえず今は展開0と同じ）
        //

        // 1
        F(1),

        // 2
        F(0),

        // 3
        F(0),

        // 4
        F(0),

        // 5
        F(1),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[CRASH1_DEV_LEN] development = int[](0, 1, 1, 1, 0, 1, 2, 2, 0, 1, 1, 1, 0, 1, 1, 1);

    SEQUENCER(beat, time, CRASH1_BEAT_LEN, CRASH1_DEV_PAT, CRASH1_DEV_LEN, notes, development, crash1)

    return ret;
}

vec2 crashcymbal2(float beat, float time) {
// 1つの展開のビート数
#define CRASH1_BEAT_LEN 8

// 展開のパターンの種類
#define CRASH1_DEV_PAT 3

// 展開の長さ
#define CRASH1_DEV_LEN 16

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[CRASH1_BEAT_LEN * NOTE_DIV * CRASH1_DEV_PAT] notes = int[](
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
        F(0),

        // 5
        F(0),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        F(0),

        // 4
        F(0),

        // 5
        F(0),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0),

        //
        // 展開2（とりあえず今は展開0と同じ）
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        F(1),

        // 4
        F(0),

        // 5
        F(0),

        // 6
        F(0),

        // 7
        F(1),

        // 8
        F(0));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[CRASH1_DEV_LEN] development = int[](1, 1, 0, 1, 1, 0, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1);

    SEQUENCER(beat, time, CRASH1_BEAT_LEN, CRASH1_DEV_PAT, CRASH1_DEV_LEN, notes, development, crash1)

    return ret;
}

//   BASS   //

vec2 bass1(float beat, float time) {
// 1つの展開のビート数
#define BASS1_BEAT_LEN 8

// 展開のパターンの種類
#define BASS1_DEV_PAT 8

// 展開の長さ
#define BASS1_DEV_LEN 16

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[BASS1_BEAT_LEN * NOTE_DIV * BASS1_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        F(0),

        // 2
        F(33),

        // 3
        E2(0, 33),

        // 4
        S4(0, 33, 0, 33),

        // 5
        F(0),

        // 6
        F(33),

        // 7
        E2(0, 33),

        // 8
        S4(0, 33, 0, 33),

        //
        // 展開1
        //

        // 1
        F(0),

        // 2
        F(33),

        // 3
        E2(0, 33),

        // 4
        S4(0, 33, 0, 33),

        // 5
        F(0),

        // 6
        F(33),

        // 7
        E2(0, 33),

        // 8
        S4(0, 33, 0, 33),

        //
        // 展開2
        //

        // 1
        E2(33, 33),

        // 2
        S4(0, 33, 33, 33),

        // 3
        S4(0, 33, 33, 33),

        // 4
        S4(0, 33, 33, 33),

        // 5
        E2(33, 33),

        // 6
        S4(0, 33, 33, 33),

        // 7
        S4(0, 33, 33, 33),

        // 8
        S4(0, 33, 33, 33),

        //
        // 展開3
        //

        // 1
        E2(33, 33),

        // 2
        S4(0, 33, 33, 33),

        // 3
        S4(0, 33, 33, 33),

        // 4
        S4(0, 33, 33, 33),

        // 5
        E2(29, 29),

        // 6
        S4(0, 29, 29, 29),

        // 7
        S4(0, 31, 31, 31),

        // 8
        S4(48, 47, 43, 40),

        //
        // 展開4
        //

        // 1
        E2(33, 33),

        // 2
        S4(0, 33, 33, 33),

        // 3
        S4(0, 33, 33, 33),

        // 4
        S4(0, 33, 33, 33),

        // 5
        E2(33, 33),

        // 6
        S4(0, 33, 33, 33),

        // 7
        S4(0, 33, 33, 33),

        // 8
        S4(0, 34, 34, 34),

        //
        // 展開5
        //

        // 1
        E2(33, 33),

        // 2
        S4(0, 33, 33, 33),

        // 3
        S4(0, 33, 33, 33),

        // 4
        S4(0, 33, 33, 33),

        // 5
        E2(33, 33),

        // 6
        S4(0, 33, 33, 33),

        // 7
        S4(0, 33, 33, 33),

        // 8
        S4(0, 36, 36, 36),

        //
        // 展開6
        //

        // 1
        E2(33, 33),

        // 2
        S4(0, 33, 33, 33),

        // 3
        S4(0, 33, 33, 33),

        // 4
        S4(0, 33, 33, 33),

        // 5
        E2(33, 33),

        // 6
        S4(0, 33, 33, 33),

        // 7
        S4(0, 34, 34, 34),

        // 8
        S4(0, 36, 36, 36),

        //
        // 展開7
        //

        // 1
        E2(33, 33),

        // 2
        S4(0, 33, 33, 33),

        // 3
        S4(0, 33, 33, 33),

        // 4
        S4(0, 33, 33, 33),

        // 5
        E2(33, 33),

        // 6
        S4(0, 33, 33, 33),

        // 7
        S4(0, 43, 43, 43),

        // 8
        S4(0, 55, 57, 69));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[BASS1_DEV_LEN] development = int[](0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 3, 4, 5, 6, 7);
    SEQUENCER(beat, time, BASS1_BEAT_LEN, BASS1_DEV_PAT, BASS1_DEV_LEN, notes, development, bass)
    return ret;
}

vec2 bass2(float beat, float time) {
// 1つの展開のビート数 ベースのアタック
#define BASS2_BEAT_LEN 8

// 展開のパターンの種類
#define BASS2_DEV_PAT 8

// 展開の長さ
#define BASS2_DEV_LEN 16

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[BASS2_BEAT_LEN * NOTE_DIV * BASS2_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        F(0),

        // 4
        F(0),

        // 5
        F(0),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0),

        //
        // 展開1
        //

        // 1
        E2(33, 33),

        // 2
        S4(0, 33, 33, 33),

        // 3
        S4(0, 33, 33, 33),

        // 4
        S4(0, 33, 33, 33),

        // 5
        E2(33, 33),

        // 6
        S4(0, 33, 33, 33),

        // 7
        S4(0, 33, 33, 33),

        // 8
        S4(0, 33, 33, 33),

        //
        // 展開2
        //

        // 1
        E2(33, 33),

        // 2
        S4(0, 33, 33, 33),

        // 3
        S4(0, 33, 33, 33),

        // 4
        S4(0, 33, 33, 33),

        // 5
        E2(41, 41),

        // 6
        S4(0, 41, 41, 41),

        // 7
        S4(0, 43, 43, 43),

        // 8
        F(0),

        //
        // 展開3
        //

        // 1
        E2(33, 33),

        // 2
        S4(0, 33, 33, 33),

        // 3
        S4(0, 33, 33, 33),

        // 4
        S4(0, 33, 33, 33),

        // 5
        E2(33, 33),

        // 6
        S4(0, 33, 33, 33),

        // 7
        S4(0, 33, 33, 33),

        // 8
        S4(0, 33, 33, 33),

        //
        // 展開4
        //

        // 1
        E2(33, 33),

        // 2
        S4(0, 33, 33, 33),

        // 3
        S4(0, 33, 33, 33),

        // 4
        S4(0, 33, 33, 33),

        // 5
        E2(33, 33),

        // 6
        S4(0, 33, 33, 33),

        // 7
        S4(0, 33, 33, 33),

        // 8
        S4(0, 34, 34, 34),

        //
        // 展開5
        //

        // 1
        E2(33, 33),

        // 2
        S4(0, 33, 33, 33),

        // 3
        S4(0, 33, 33, 33),

        // 4
        S4(0, 33, 33, 33),

        // 5
        E2(33, 33),

        // 6
        S4(0, 33, 33, 33),

        // 7
        S4(0, 33, 33, 33),

        // 8
        S4(0, 36, 36, 36),

        //
        // 展開6
        //

        // 1
        E2(33, 33),

        // 2
        S4(0, 33, 33, 33),

        // 3
        S4(0, 33, 33, 33),

        // 4
        S4(0, 33, 33, 33),

        // 5
        E2(33, 33),

        // 6
        S4(0, 33, 33, 33),

        // 7
        S4(0, 34, 34, 34),

        // 8
        S4(0, 36, 36, 36),

        //
        // 展開7
        //

        // 1
        E2(33, 33),

        // 2
        S4(0, 33, 33, 33),

        // 3
        S4(0, 33, 33, 33),

        // 4
        S4(0, 33, 33, 33),

        // 5
        E2(33, 33),

        // 6
        S4(0, 33, 33, 33),

        // 7
        S4(0, 43, 43, 43),

        // 8
        S4(0, 55, 57, 69));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[BASS2_DEV_LEN] development = int[](0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 2, 4, 5, 6, 7);
    SEQUENCER(beat, time, BASS2_BEAT_LEN, BASS2_DEV_PAT, BASS2_DEV_LEN, notes, development, attackbass)
    return ret;
}

vec2 sideSupersaw1(float beat, float time) {
// 1つの展開のビート数
#define TAMESHI_BEAT_LEN 8

// 展開のパターンの種類
#define TAMESHI_DEV_PAT 8

// 展開の長さ
#define TAMESHI_DEV_LEN 16

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[TAMESHI_BEAT_LEN * NOTE_DIV * TAMESHI_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        F(0),

        // 4
        F(0),

        // 5
        F(0),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        E2(45, 45),

        // 2
        S4(0, 45, 45, 45),

        // 3
        S4(0, 45, 45, 45),

        // 4
        S4(0, 45, 45, 45),

        // 5
        E2(45, 45),

        // 6
        S4(0, 45, 45, 45),

        // 7
        S4(0, 45, 45, 45),

        // 8
        S4(0, 45, 45, 45),

        //
        // 展開2（とりあえず今は展開0と同じ）
        //

        // 1
        E2(45, 45),

        // 2
        S4(0, 45, 45, 45),

        // 3
        S4(0, 45, 45, 45),

        // 4
        S4(0, 45, 45, 45),

        // 5
        E2(41, 41),

        // 6
        S4(0, 41, 41, 41),

        // 7
        S4(0, 43, 43, 43),

        // 8
        F(0),

        //
        // 展開3
        //

        // 1
        E2(45, 45),

        // 2
        S4(0, 45, 45, 45),

        // 3
        S4(0, 45, 45, 45),

        // 4
        S4(0, 45, 45, 45),

        // 5
        E2(45, 45),

        // 6
        S4(0, 45, 45, 45),

        // 7
        S4(0, 45, 45, 45),

        // 8
        S4(0, 45, 45, 45),

        //
        // 展開4
        //

        // 1
        E2(45, 45),

        // 2
        S4(0, 45, 45, 45),

        // 3
        S4(0, 45, 45, 45),

        // 4
        S4(0, 45, 45, 45),

        // 5
        E2(45, 45),

        // 6
        S4(0, 45, 45, 45),

        // 7
        S4(0, 45, 45, 45),

        // 8
        S4(0, 46, 46, 46),

        //
        // 展開5
        //

        // 1
        E2(45, 45),

        // 2
        S4(0, 45, 45, 45),

        // 3
        S4(0, 45, 45, 45),

        // 4
        S4(0, 45, 45, 45),

        // 5
        E2(45, 45),

        // 6
        S4(0, 45, 45, 45),

        // 7
        S4(0, 45, 45, 45),

        // 8
        S4(0, 48, 48, 48),

        //
        // 展開6
        //

        // 1
        E2(45, 45),

        // 2
        S4(0, 45, 45, 45),

        // 3
        S4(0, 45, 45, 45),

        // 4
        S4(0, 45, 45, 45),

        // 5
        E2(45, 45),

        // 6
        S4(0, 45, 45, 45),

        // 7
        S4(0, 46, 46, 46),

        // 8
        S4(0, 48, 48, 48),

        //
        // 展開7
        //

        // 1
        E2(45, 45),

        // 2
        S4(0, 45, 45, 45),

        // 3
        S4(0, 45, 45, 45),

        // 4
        S4(0, 45, 45, 45),

        // 5
        E2(45, 45),

        // 6
        S4(0, 45, 45, 45),

        // 7
        S4(0, 55, 55, 55),

        // 8
        S4(0, 0, 0, 0));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[TAMESHI_DEV_LEN] development = int[](0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 2, 4, 5, 6, 7);

    SEQUENCER(beat, time, TAMESHI_BEAT_LEN, TAMESHI_DEV_PAT, TAMESHI_DEV_LEN, notes, development, chordsaw1)
    return ret;
}

vec2 sideSupersaw2(float beat, float time) {
// 1つの展開のビート数
#define TAMESHI_BEAT_LEN 8

// 展開のパターンの種類
#define TAMESHI_DEV_PAT 8

// 展開の長さ
#define TAMESHI_DEV_LEN 16

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[TAMESHI_BEAT_LEN * NOTE_DIV * TAMESHI_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        F(0),

        // 4
        F(0),

        // 5
        F(0),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        E2(33, 33),

        // 2
        S4(0, 33, 33, 33),

        // 3
        S4(0, 33, 33, 33),

        // 4
        S4(0, 33, 33, 33),

        // 5
        E2(33, 33),

        // 6
        S4(0, 33, 33, 33),

        // 7
        S4(0, 33, 33, 33),

        // 8
        S4(0, 33, 33, 33),

        //
        // 展開2（とりあえず今は展開0と同じ）
        //

        // 1
        E2(33, 33),

        // 2
        S4(0, 33, 33, 33),

        // 3
        S4(0, 33, 33, 33),

        // 4
        S4(0, 33, 33, 33),

        // 5
        E2(29, 29),

        // 6
        S4(0, 31, 31, 31),

        // 7
        S4(0, 31, 31, 31),

        // 8
        S4(0, 31, 31, 31),

        //
        // 展開3
        //

        // 1
        E2(33, 33),

        // 2
        S4(0, 33, 33, 33),

        // 3
        S4(0, 33, 33, 33),

        // 4
        S4(0, 33, 33, 33),

        // 5
        E2(33, 33),

        // 6
        S4(0, 33, 33, 33),

        // 7
        S4(0, 33, 33, 33),

        // 8
        S4(0, 33, 33, 33),

        //
        // 展開4
        //

        // 1
        E2(33, 33),

        // 2
        S4(0, 33, 33, 33),

        // 3
        S4(0, 33, 33, 33),

        // 4
        S4(0, 33, 33, 33),

        // 5
        E2(33, 33),

        // 6
        S4(0, 33, 33, 33),

        // 7
        S4(0, 33, 33, 33),

        // 8
        S4(0, 34, 34, 34),

        //
        // 展開5
        //

        // 1
        E2(33, 33),

        // 2
        S4(0, 33, 33, 33),

        // 3
        S4(0, 33, 33, 33),

        // 4
        S4(0, 33, 33, 33),

        // 5
        E2(33, 33),

        // 6
        S4(0, 33, 33, 33),

        // 7
        S4(0, 33, 33, 33),

        // 8
        S4(0, 36, 36, 36),

        //
        // 展開6
        //

        // 1
        E2(33, 33),

        // 2
        S4(0, 33, 33, 33),

        // 3
        S4(0, 33, 33, 33),

        // 4
        S4(0, 33, 33, 33),

        // 5
        E2(33, 33),

        // 6
        S4(0, 33, 33, 33),

        // 7
        S4(0, 34, 34, 34),

        // 8
        S4(0, 36, 36, 36),

        //
        // 展開7
        //

        // 1
        E2(33, 33),

        // 2
        S4(0, 33, 33, 33),

        // 3
        S4(0, 33, 33, 33),

        // 4
        S4(0, 33, 33, 33),

        // 5
        E2(33, 33),

        // 6
        S4(0, 33, 33, 33),

        // 7
        S4(0, 43, 43, 43),

        // 8
        S4(0, 55, 57, 69));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[TAMESHI_DEV_LEN] development = int[](0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 2, 4, 5, 6, 7);

    SEQUENCER(beat, time, TAMESHI_BEAT_LEN, TAMESHI_DEV_PAT, TAMESHI_DEV_LEN, notes, development, chordsaw1)
    return ret;
}

vec2 tb303synth(float beat, float time) {
// 1つの展開のビート数
#define TB303SYNTH1_BEAT_LEN 8

// 展開のパターンの種類
#define TB303SYNTH1_DEV_PAT 2

// 展開の長さ
#define TB303SYNTH1_DEV_LEN 16

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[TB303SYNTH1_BEAT_LEN * NOTE_DIV * TB303SYNTH1_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        F(33),

        // 2
        F(33),

        // 3
        F(33),

        // 4
        F(33),

        // 5
        F(33),

        // 6
        F(33),

        // 7
        F(33),

        // 8
        F(33),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        E2(33, 33),

        // 2
        S4(0, 33, 33, 33),

        // 3
        S4(0, 33, 33, 33),

        // 4
        S4(0, 33, 33, 33),

        // 5
        E2(33, 33),

        // 6
        S4(0, 33, 33, 33),

        // 7
        S4(0, 33, 33, 33),

        // 8
        S4(0, 33, 33, 33));

    // 展開
    int[TB303SYNTH1_DEV_LEN] development = int[](0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1);

    SEQUENCER(beat, time, TB303SYNTH1_BEAT_LEN, TB303SYNTH1_DEV_PAT, TB303SYNTH1_DEV_LEN, notes, development, synth)
    return ret;
}

vec2 arp0(float beat, float time) {
// 1つの展開のビート数
#define ARP0_BEAT_LEN 8

// 展開のパターンの種類
#define ARP0_DEV_PAT 2

// 展開の長さ
#define ARP0_DEV_LEN 16

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[ARP0_BEAT_LEN * NOTE_DIV * ARP0_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        S4(57, 57, 59, 59),

        // 2
        S4(60, 60, 64, 64),

        // 3
        S4(67, 67, 69, 69),

        // 4
        S4(71, 71, 74, 74),

        // 5
        S4(57, 57, 59, 59),

        // 6
        S4(60, 60, 64, 64),

        // 7
        S4(67, 67, 69, 69),

        // 8
        S4(71, 71, 74, 74),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        F(0),

        // 4
        F(0),

        // 5
        F(0),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0));

    // 展開
    int[ARP0_DEV_LEN] development = int[](0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1);

    SEQUENCER(beat, time, ARP0_BEAT_LEN, ARP0_DEV_PAT, ARP0_DEV_LEN, notes, development, arpsaw)
    return ret;
}

vec2 arp1(float beat, float time) {
// 1つの展開のビート数
#define ARP1_BEAT_LEN 8

// 展開のパターンの種類
#define ARP1_DEV_PAT 2

// 展開の長さ
#define ARP1_DEV_LEN 16

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
    int[ARP1_DEV_LEN] development = int[](0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1);

    SEQUENCER(beat, time, ARP1_BEAT_LEN, ARP1_DEV_PAT, ARP1_DEV_LEN, notes, development, arp)
    return ret;
}

vec2 arp2(float beat, float time) {
// 1つの展開のビート数
#define ARP2_BEAT_LEN 8

// 展開のパターンの種類
#define ARP2_DEV_PAT 2

// 展開の長さ
#define ARP2_DEV_LEN 16

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
        S4(0, 57, 0, 59),

        // 2
        S4(0, 60, 0, 64),

        // 3
        S4(0, 67, 0, 69),

        // 4
        S4(0, 71, 0, 74),

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
    int[ARP2_DEV_LEN] development = int[](0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1);

    SEQUENCER(beat, time, ARP2_BEAT_LEN, ARP2_DEV_PAT, ARP2_DEV_LEN, notes, development, arp)
    return ret;
}

vec2 arp3(float beat, float time) {
// 1つの展開のビート数
#define ARP3_BEAT_LEN 8

// 展開のパターンの種類
#define ARP3_DEV_PAT 2

// 展開の長さ
#define ARP3_DEV_LEN 16

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
    int[ARP3_DEV_LEN] development = int[](0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1);

    SEQUENCER(beat, time, ARP3_BEAT_LEN, ARP3_DEV_PAT, ARP3_DEV_LEN, notes, development, arpsine)
    return ret;
}

vec2 arp4(float beat, float time) {
// 1つの展開のビート数
#define ARP4_BEAT_LEN 8

// 展開のパターンの種類
#define ARP4_DEV_PAT 2

// 展開の長さ
#define ARP4_DEV_LEN 16

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
    int[ARP4_DEV_LEN] development = int[](0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1);

    SEQUENCER(beat, time, ARP4_BEAT_LEN, ARP4_DEV_PAT, ARP4_DEV_LEN, notes, development, arpsine)
    return ret;
}

vec2 arp5(float beat, float time) {
// 1つの展開のビート数
#define ARP5_BEAT_LEN 8

// 展開のパターンの種類
#define ARP5_DEV_PAT 2

// 展開の長さ
#define ARP5_DEV_LEN 16

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
        F(0),

        // 2
        F(0),

        // 3
        F(0),

        // 4
        F(0),

        // 5
        F(0),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        S4(69, 0, 79, 67),

        // 2
        S4(0, 0, 76, 0),

        // 3
        S4(0, 69, 0, 0),

        // 4
        S4(67, 0, 76, 0),

        // 5
        S4(69, 0, 79, 67),

        // 6
        S4(0, 0, 76, 0),

        // 7
        S4(0, 69, 0, 0),

        // 8
        S4(67, 0, 76, 0));

    // 展開
    int[ARP5_DEV_LEN] development = int[](0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1);

    SEQUENCER(beat, time, ARP5_BEAT_LEN, ARP5_DEV_PAT, ARP5_DEV_LEN, notes, development, arpsine2)
    return ret;
}

vec2 hihat33(float beat, float time) {
// 1つの展開のビート数
#define HIHAT3_BEAT_LEN 8

// 展開のパターンの種類
#define HIHAT3_DEV_PAT 2

// 展開の長さ
#define HIHAT3_DEV_LEN 16

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[HIHAT3_BEAT_LEN * NOTE_DIV * HIHAT3_DEV_PAT] notes = int[](
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
        F(0),

        // 5
        F(0),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        E2(0, 1),

        // 2
        E2(0, 1),

        // 3
        E2(0, 1),

        // 4
        E2(0, 1),

        // 5
        E2(0, 1),

        // 6
        E2(0, 1),

        // 7
        E2(0, 1),

        // 8
        E2(0, 1));

    // 展開 #define CRASH1_DEV_LEN 8　変える
    int[HIHAT3_DEV_LEN] development = int[](0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1);

    SEQUENCER(beat, time, HIHAT3_BEAT_LEN, HIHAT3_DEV_PAT, HIHAT3_DEV_LEN, notes, development, hihat3)

    return ret;
}

vec2 subbass1(float beat, float time) {
// 1つの展開のビート数
#define SUB1_BEAT_LEN 8

// 展開のパターンの種類
#define SUB1_DEV_PAT 2

// 展開の長さ
#define SUB1_DEV_LEN 16

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[SUB1_BEAT_LEN * NOTE_DIV * SUB1_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        F(33),

        // 2
        F(33),

        // 3
        F(33),

        // 4
        F(33),

        // 5
        F(33),

        // 6
        F(33),

        // 7
        F(33),

        // 8
        F(33),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        F(33),

        // 2
        F(33),

        // 3
        F(33),

        // 4
        F(33),

        // 5
        F(33),

        // 6
        F(33),

        // 7
        F(33),

        // 8
        F(33));

    // 展開 #define SUB1_DEV_LEN 8　変える
    int[SUB1_DEV_LEN] development = int[](0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1);

    SEQUENCER(beat, time, SUB1_BEAT_LEN, SUB1_DEV_PAT, SUB1_DEV_LEN, notes, development, subbass)
    return ret;
}

//  HIHAT  //
//  HIHAT  //
//  HIHAT  //

vec2 testhihat2(float beat, float time) {
// 1つの展開のビート数
#define HIHAT2_BEAT_LEN 8

// 展開のパターンの種類
#define HIHAT2_DEV_PAT 2

// 展開の長さ
#define HIHAT2_DEV_LEN 16

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[HIHAT2_BEAT_LEN * NOTE_DIV * HIHAT2_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        S4(0, 1, 1, 1),

        // 2
        S4(0, 1, 1, 1),

        // 3
        S4(0, 1, 1, 1),

        // 4
        S4(0, 1, 1, 1),

        // 5
        S4(0, 1, 1, 1),

        // 6
        S4(0, 1, 1, 1),

        // 7
        S4(0, 1, 1, 1),

        // 8
        S4(0, 1, 1, 1),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        S4(0, 1, 1, 1),

        // 2
        S4(0, 1, 1, 1),

        // 3
        S4(0, 1, 1, 1),

        // 4
        S4(0, 1, 1, 1),

        // 5
        S4(0, 1, 1, 1),

        // 6
        S4(0, 1, 1, 1),

        // 7
        S4(0, 1, 1, 1),

        // 8
        S4(0, 1, 1, 1));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[HIHAT2_DEV_LEN] development = int[](0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1);

    SEQUENCER(beat, time, KICK1_BEAT_LEN, KICK1_DEV_PAT, KICK1_DEV_LEN, notes, development, hihat2)
    return ret;
}

//  CHORD  //
//  CHORD  //
//  CHORD  //

vec2 introSupersaw1(float beat, float time) {
// 1つの展開のビート数
#define INTROSAW_BEAT_LEN 8

// 展開のパターンの種類
#define INTROSAW_DEV_PAT 3

// 展開の長さ
#define INTROSAW_DEV_LEN 16

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[INTROSAW_BEAT_LEN * NOTE_DIV * INTROSAW_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        F(0),

        // 2
        F(45),

        // 3
        F(0),

        // 4
        F(45),

        // 5
        F(0),

        // 6
        F(45),

        // 7
        F(0),

        // 8
        F(45),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        F(45),

        // 2
        F(45),

        // 3
        F(45),

        // 4
        F(45),

        // 5
        F(45),

        // 6
        F(45),

        // 7
        F(45),

        // 8
        F(45),

        //
        // 展開2
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        E2(0, 0),

        // 4
        F(0),

        // 5
        E2(0, 0),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[INTROSAW_DEV_LEN] development = int[](0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2);

    SEQUENCER(beat, time, INTROSAW_BEAT_LEN, INTROSAW_DEV_PAT, INTROSAW_DEV_LEN, notes, development, basssaw1)
    return ret;
}

vec2 introSupersaw2(float beat, float time) {
// 1つの展開のビート数
#define INTROSAW_BEAT_LEN 8

// 展開のパターンの種類
#define INTROSAW_DEV_PAT 3

// 展開の長さ
#define INTROSAW_DEV_LEN 16

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[INTROSAW_BEAT_LEN * NOTE_DIV * INTROSAW_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        F(0),

        // 4
        F(69),

        // 5
        F(0),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(57),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        F(0),

        // 4
        F(57),

        // 5
        F(0),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(57),

        //
        // 展開2
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        E2(0, 0),

        // 4
        F(0),

        // 5
        E2(0, 0),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[INTROSAW_DEV_LEN] development = int[](0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2);

    SEQUENCER(beat, time, INTROSAW_BEAT_LEN, INTROSAW_DEV_PAT, INTROSAW_DEV_LEN, notes, development, basssaw2)
    return ret;
}

//  鬼のSUPERSAW  //
//  鬼のSUPERSAW  //
//  鬼のSUPERSAW  //

vec2 chordSupersaw1(float beat, float time) {
// 1つの展開のビート数
#define CHORD1_BEAT_LEN 8

// 展開のパターンの種類
#define CHORD1_DEV_PAT 4

// 展開の長さ
#define CHORD1_DEV_LEN 16

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[CHORD1_BEAT_LEN * NOTE_DIV * CHORD1_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        F(0),

        // 4
        F(0),

        // 5
        F(0),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0),

        //
        // 展開1（とりあえず今は展開0と同じ）
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
        F(69),

        //
        // 展開2
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        E2(0, 67),

        // 4
        F(0),

        // 5
        E2(0, 67),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0),

        //
        // 展開3
        //

        // 1
        F(67),

        // 2
        F(0),

        // 3
        E2(0, 67),

        // 4
        F(0),

        // 5
        E2(0, 67),

        // 6
        F(0),

        // 7
        E2(0, 67),

        // 8
        F(62));

    // 展開 #define CHORD1_DEV_LEN 8　変える
    int[CHORD1_DEV_LEN] development = int[](0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3);

    SEQUENCER(beat, time, CHORD1_BEAT_LEN, CHORD1_DEV_PAT, CHORD1_DEV_LEN, notes, development, chordsaw1)
    return ret;
}

vec2 chordSupersaw2(float beat, float time) {
// 1つの展開のビート数
#define CHORD2_BEAT_LEN 8

// 展開のパターンの種類
#define CHORD2_DEV_PAT 4

// 展開の長さ
#define CHORD2_DEV_LEN 16

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[CHORD2_BEAT_LEN * NOTE_DIV * CHORD2_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        F(0),

        // 4
        F(0),

        // 5
        F(0),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        F(72),

        // 2
        F(72),

        // 3
        F(72),

        // 4
        F(72),

        // 5
        F(72),

        // 6
        F(72),

        // 7
        F(72),

        // 8
        F(72),

        //
        // 展開2
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        E2(0, 62),

        // 4
        F(0),

        // 5
        E2(0, 62),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0),

        //
        // 展開3
        //

        // 1
        F(62),

        // 2
        F(0),

        // 3
        E2(0, 62),

        // 4
        F(0),

        // 5
        E2(0, 62),

        // 6
        F(0),

        // 7
        E2(0, 62),

        // 8
        F(57));

    // 展開 #define CHORD2_DEV_LEN 8　変える
    int[CHORD2_DEV_LEN] development = int[](0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3);
    SEQUENCER(beat, time, CHORD2_BEAT_LEN, CHORD2_DEV_PAT, CHORD2_DEV_LEN, notes, development, chordsaw1)
    return ret;
}

vec2 chordSupersaw3(float beat, float time) {
// 1つの展開のビート数
#define CHORD3_BEAT_LEN 8

// 展開のパターンの種類
#define CHORD3_DEV_PAT 4

// 展開の長さ
#define CHORD3_DEV_LEN 16

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[CHORD3_BEAT_LEN * NOTE_DIV * CHORD3_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        F(0),

        // 4
        F(0),

        // 5
        F(0),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        F(74),

        // 2
        F(74),

        // 3
        F(74),

        // 4
        F(74),

        // 5
        F(74),

        // 6
        F(74),

        // 7
        F(74),

        // 8
        F(74),

        //
        // 展開2
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        E2(0, 60),

        // 4
        F(0),

        // 5
        E2(0, 60),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0),

        //
        // 展開3
        //

        // 1
        F(60),

        // 2
        F(0),

        // 3
        E2(0, 60),

        // 4
        F(0),

        // 5
        E2(0, 60),

        // 6
        F(0),

        // 7
        E2(0, 60),

        // 8
        F(54));

    // 展開 #define CHORD3_DEV_LEN 8　変える
    int[CHORD3_DEV_LEN] development = int[](0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3);

    SEQUENCER(beat, time, CHORD3_BEAT_LEN, CHORD3_DEV_PAT, CHORD3_DEV_LEN, notes, development, chordsaw1)
    return ret;
}

vec2 chordSupersaw4(float beat, float time) {
// 1つの展開のビート数
#define CHORD4_BEAT_LEN 8

// 展開のパターンの種類
#define CHORD4_DEV_PAT 4

// 展開の長さ
#define CHORD4_DEV_LEN 16

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[CHORD4_BEAT_LEN * NOTE_DIV * CHORD4_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        F(0),

        // 4
        F(0),

        // 5
        F(0),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        F(79),

        // 2
        F(79),

        // 3
        F(79),

        // 4
        F(79),

        // 5
        F(79),

        // 6
        F(79),

        // 7
        F(79),

        // 8
        F(79),

        //
        // 展開2
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        E2(0, 57),

        // 4
        F(0),

        // 5
        E2(0, 57),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0),

        //
        // 展開3
        //

        // 1
        F(57),

        // 2
        F(0),

        // 3
        E2(0, 57),

        // 4
        F(0),

        // 5
        E2(0, 57),

        // 6
        F(0),

        // 7
        E2(0, 57),

        // 8
        F(49));

    // 展開 #define CHORD4_DEV_LEN 8　変える
    int[CHORD4_DEV_LEN] development = int[](0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3);

    SEQUENCER(beat, time, CHORD4_BEAT_LEN, CHORD4_DEV_PAT, CHORD4_DEV_LEN, notes, development, chordsaw1)
    return ret;
}

vec2 chordSquare1(float beat, float time) {
// 1つの展開のビート数
#define SQUARE1_BEAT_LEN 8

// 展開のパターンの種類
#define SQUARE1_DEV_PAT 4

// 展開の長さ
#define SQUARE1_DEV_LEN 16

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[SQUARE1_BEAT_LEN * NOTE_DIV * SQUARE1_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        F(0),

        // 4
        F(0),

        // 5
        F(0),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        S4(67, 67, 0, 67),

        // 2
        S4(67, 0, 67, 67),

        // 3
        S4(67, 67, 0, 67),

        // 4
        S4(67, 0, 67, 67),

        // 5
        S4(67, 67, 0, 67),

        // 6
        S4(67, 0, 67, 67),

        // 7
        S4(67, 67, 0, 67),

        // 8
        S4(67, 0, 72, 72),

        //
        // 展開2
        //

        // 1
        S4(67, 67, 0, 67),

        // 2
        S4(67, 0, 67, 67),

        // 3
        S4(67, 67, 0, 67),

        // 4
        S4(67, 0, 67, 67),

        // 5
        S4(67, 67, 0, 67),

        // 6
        S4(67, 0, 67, 67),

        // 7
        S4(72, 72, 0, 72),

        // 8
        S4(0, 0, 72, 72),

        //
        // 展開3
        //

        // 1
        S4(71, 71, 0, 71),

        // 2
        S4(71, 0, 71, 71),

        // 3
        S4(71, 71, 0, 71),

        // 4
        S4(71, 0, 71, 71),

        // 5
        S4(71, 71, 0, 71),

        // 6
        S4(71, 0, 71, 71),

        // 7
        S4(72, 72, 0, 72),

        // 8
        S4(0, 0, 72, 72));

    // 展開 #define SQUARE1_DEV_LEN 8　変える
    int[SQUARE1_DEV_LEN] development = int[](0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 3);
    SEQUENCER(beat, time, SQUARE1_BEAT_LEN, SQUARE1_DEV_PAT, SQUARE1_DEV_LEN, notes, development, chordsquare1)
    return ret;
}

vec2 chordSquare2(float beat, float time) {
// 1つの展開のビート数
#define SQUARE2_BEAT_LEN 8

// 展開のパターンの種類
#define SQUARE2_DEV_PAT 4

// 展開の長さ
#define SQUARE2_DEV_LEN 16

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[SQUARE2_BEAT_LEN * NOTE_DIV * SQUARE2_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        F(0),

        // 4
        F(0),

        // 5
        F(0),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        S4(62, 62, 0, 62),

        // 2
        S4(62, 0, 62, 62),

        // 3
        S4(62, 62, 0, 62),

        // 4
        S4(62, 0, 62, 62),

        // 5
        S4(62, 62, 0, 62),

        // 6
        S4(62, 0, 62, 62),

        // 7
        S4(62, 62, 0, 62),

        // 8
        S4(62, 0, 67, 67),

        //
        // 展開2
        //

        // 1
        S4(62, 62, 0, 62),

        // 2
        S4(62, 0, 62, 62),

        // 3
        S4(62, 62, 0, 62),

        // 4
        S4(62, 0, 62, 62),

        // 5
        S4(62, 62, 0, 62),

        // 6
        S4(62, 0, 62, 62),

        // 7
        S4(67, 67, 0, 67),

        // 8
        S4(0, 0, 67, 67),

        //
        // 展開3
        //

        // 1
        S4(67, 67, 0, 67),

        // 2
        S4(67, 0, 67, 67),

        // 3
        S4(67, 67, 0, 67),

        // 4
        S4(67, 0, 67, 67),

        // 5
        S4(67, 67, 0, 67),

        // 6
        S4(67, 0, 67, 67),

        // 7
        S4(67, 67, 0, 67),

        // 8
        S4(0, 0, 67, 67));

    // 展開 #define SQUARE2_DEV_LEN 8　変える
    int[SQUARE2_DEV_LEN] development = int[](0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 3);
    SEQUENCER(beat, time, SQUARE2_BEAT_LEN, SQUARE2_DEV_PAT, SQUARE2_DEV_LEN, notes, development, chordsquare1)
    return ret;
}

vec2 chordSquare3(float beat, float time) {
// 1つの展開のビート数
#define SQUARE3_BEAT_LEN 8

// 展開のパターンの種類
#define SQUARE3_DEV_PAT 4

// 展開の長さ
#define SQUARE3_DEV_LEN 16

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[SQUARE3_BEAT_LEN * NOTE_DIV * SQUARE3_DEV_PAT] notes = int[](
        //
        // 展開0
        //

        // 1
        F(0),

        // 2
        F(0),

        // 3
        F(0),

        // 4
        F(0),

        // 5
        F(0),

        // 6
        F(0),

        // 7
        F(0),

        // 8
        F(0),

        //
        // 展開1（とりあえず今は展開0と同じ）
        //

        // 1
        S4(57, 57, 0, 57),

        // 2
        S4(57, 0, 57, 57),

        // 3
        S4(57, 57, 0, 57),

        // 4
        S4(57, 0, 57, 57),

        // 5
        S4(57, 57, 0, 57),

        // 6
        S4(57, 0, 57, 57),

        // 7
        S4(57, 57, 0, 57),

        // 8
        S4(57, 0, 59, 59),

        //
        // 展開2
        //

        // 1
        S4(57, 57, 0, 57),

        // 2
        S4(57, 0, 57, 57),

        // 3
        S4(57, 57, 0, 57),

        // 4
        S4(57, 0, 57, 57),

        // 5
        S4(57, 57, 0, 57),

        // 6
        S4(57, 0, 57, 57),

        // 7
        S4(57, 57, 0, 57),

        // 8
        S4(0, 0, 57, 57),

        //
        // 展開3
        //

        // 1
        S4(57, 57, 0, 57),

        // 2
        S4(57, 0, 57, 57),

        // 3
        S4(57, 57, 0, 57),

        // 4
        S4(57, 0, 57, 57),

        // 5
        S4(57, 57, 0, 57),

        // 6
        S4(57, 0, 57, 57),

        // 7
        S4(57, 57, 0, 57),

        // 8
        S4(0, 0, 57, 57));

    // 展開 #define SQUARE3_DEV_LEN 8　変える
    int[SQUARE3_DEV_LEN] development = int[](0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 3);
    SEQUENCER(beat, time, SQUARE3_BEAT_LEN, SQUARE3_DEV_PAT, SQUARE3_DEV_LEN, notes, development, chordsquare1)
    return ret;
}

vec2 mainSound(float time) {
    float beat = timeToBeat(time);
    vec2 ret = vec2(0.0);

    // kick
    ret += vec2(0.7) * kick1(beat, time);
    ret += vec2(0.2, 0.05) * crashcymbal1(beat, time);  // L70 R0
    ret += vec2(0.05, 0.2) * crashcymbal2(beat, time);  // L70 R0

    // hihat
    ret += vec2(0.0, 0.4) * sidechain * hihat33(beat, time);
    ret += vec2(0.3, 0.1) * sidechain * testhihat2(beat, time);

    ret += vec2(0.3, 0.3) * bass1(beat, time);                        // L70 R0
    ret += vec2(0.09, 0.09) * bass2(beat, time);                      // L70 R0
    ret += vec2(0.1, 0.05) * sidechain2 * sideSupersaw1(beat, time);  // ベースの補強
    // ret += vec2(0.05, 0.1) * sidechain2 * sideSupersaw2(beat, time);  // ベースの補強
    ret += vec2(0.05, 0.05) * sidechain * tb303synth(beat, time);  // ベースの補強

    // arp
    ret += vec2(0.1, 0.1) * sidechain * subbass1(beat, time);          // L70 R0
    ret += vec2(0.1) * sidechain * arp0(beat, time);                   // L50 R0
    ret += vec2(0.3, 0.0) * sidechain * arp1(beat, time);              //
    ret += vec2(0.0, 0.3) * sidechain * arp2(beat, time);              //
    ret += vec2(0.3, 0.6) * sidechain * arp3(beat, time);              // サイン波のアルペジオ
    ret += vec2(0.6, 0.3) * sidechain * arp4(beat, time);              //  サイン波のアルペジオ
    ret += vec2(0.3, 0.1) * sidechain2 * chordSupersaw1(beat, time);   // コード
    ret += vec2(0.2, 0.2) * sidechain2 * chordSupersaw2(beat, time);   // コード
    ret += vec2(0.2, 0.02) * sidechain2 * chordSupersaw3(beat, time);  // コード
    ret += vec2(0.3, 0.1) * sidechain2 * chordSupersaw4(beat, time);   // コード
    ret += vec2(0.3, 0.3) * sidechain * arp5(beat, time);              // アルペジオ中央
    ret += vec2(0.1, 0.2) * sidechain2 * chordSquare1(beat, time);     //
    ret += vec2(0.15, 0.15) * sidechain2 * chordSquare2(beat, time);   //
    ret += vec2(0.2, 0.1) * sidechain2 * chordSquare3(beat, time);     //

    // supersaw以外の音をMute
    // ret = vec2(0.0);

    // supersawのテスト
    ret += vec2(0.02, 0.08) * sidechain * introSupersaw1(beat, time);
    ret += vec2(0.08, 0.02) * sidechain2 * introSupersaw2(beat, time);

    return clamp(ret, -1.0, 1.0);
}