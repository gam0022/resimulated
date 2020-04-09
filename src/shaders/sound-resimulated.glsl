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
float sidechain4;
float sidechain5;

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
    float amp = exp(-3.2 * time);
    float phase = 35.0 * time - 16.0 * exp(-60.0 * time);
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

vec2 arp(float note, float time) {
    float freq = noteToFreq(note);
    float fmamp = 0.1 * exp(-30.0 * time);
    float fm = fmamp * square(time * freq * 1.5);
    float amp = exp(-50.0 * time);
    return amp * vec2(square(freq * time), tri(freq * time));
}

vec2 arpsaw(float note, float time) {
    float freq = noteToFreq(note);
    float fmamp = 0.02 * exp(-30.0 * time);
    float fm = fmamp * sine(time * freq * 1.0);
    float amp = exp(-20.0 * time);
    return amp * vec2(sine(freq * 0.999 * time + fm), saw(freq * 1.001 * time + fm));
}

vec2 arpsine(float note, float time) {
    float freq = noteToFreq(note);
    float fmamp = 0.02 * exp(-70.0 * time);
    float fm = fmamp * sine(time * freq * 1.0);
    float amp = exp(-50.0 * time);
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

vec2 basssaw3(float note, float time) {
    float amp = exp(1.3 * time * time);
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

vec2 chordsaw1(float note, float time) {
    float amp = exp(0.0 * time * time);
    float env = exp(time * 4.0);
    float ret = 0.0;
    int num = 3;
    float step = 0.023;
    int reverbNum = 100;

    for (int i = 0; i < num; i++) {
        float freq = noteToFreq(note + 12.0 * float(i - num / 2));
        for (int j = 0; j < reverbNum; j++) {
            ret += saw(freq * (time - 0.019 * float(j)) * (1.0 + step * float(i - num / 2))) * exp(-3.0 * float(j));
        }
    }

    return vec2(0.4 * amp * ret / float(num));
}

vec2 chordsaw2(float note, float time) {
    float amp = exp(0.0 * time * time);
    float env = exp(time * 3.0);
    float ret = 0.0;
    int num = 3;
    float step = 0.0225;
    int reverbNum = 100;

    for (int i = 0; i < num; i++) {
        float freq = noteToFreq(note + 12.0 * float(i - num / 2));
        for (int j = 0; j < reverbNum; j++) {
            ret += saw(freq * (time + 0.019 * float(j)) * (1.0 + step * float(i - num / 2))) * exp(-2.0 * float(j));
        }
    }

    return vec2(0.4 * env * amp * ret / float(num));
}

vec2 chordsquare1(float note, float time) {
    float amp = exp(-15.0 * time * time);
    float ret = 0.0;
    int num = 3;
    float step = 0.023;
    int reverbNum = 100;

    for (int i = 0; i < num; i++) {
        float freq = noteToFreq(note + 12.0 * float(i - num / 2));
        for (int j = 0; j < reverbNum; j++) {
            ret += saw(freq * (time + 0.019 * float(j)) * (1.0 + step * float(i - num / 2))) * exp(-3.0 * float(j));
        }
    }

    return vec2(0.5 * amp * ret / float(num));
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

vec2 leadsub(float note, float t) {
    vec2 v = vec2(0.0);
    float dr = 0.1;
    float amp = smoothstep(0.2, 0.0, abs(t - dr - 0.1) - dr) * exp(t * 0.2);
    float f = noteToFreq(note);
    float sqr = 0.03;  // smoothstep(0.0, 0.01, abs(mod(t * 9.0, 64.0) - 20.0) - 20.0);

    float base = f;                    // 50.0 + sin(sin(t * 0.1) * t) * 20.0;
    float flt = exp(t * -3.5) * 20.0;  // + pow(cos(t * 1.0) * 0.5 + 0.5, 4.0) * 80.0 - 0.0;
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

vec2 leadsub2(float note, float t) {
    vec2 v = vec2(0.0);
    float dr = 0.1;
    float amp = smoothstep(0.2, 0.0, abs(t - dr - 0.1) - dr) * exp(t * 0.2);
    float f = noteToFreq(note);
    float sqr = 0.05;  // smoothstep(0.0, 0.01, abs(mod(t * 9.0, 64.0) - 20.0) - 20.0);

    float base = f;                    // 50.0 + sin(sin(t * 0.1) * t) * 20.0;
    float flt = exp(t * -2.5) * 20.0;  // + pow(cos(t * 1.0) * 0.5 + 0.5, 4.0) * 80.0 - 0.0;
    for (int i = 0; i < NSPC; i++) {
        float h = float(i + 1);
        float inten = 4.0 / h;
        // inten *= sin((pow(h, sin(t) * 0.5 + 0.5) + t * 0.5) * pi2) * 0.9 + 0.1;

        inten = mix(inten, inten * mod(h, 2.0), sqr);

        inten *= exp(-3.0 * max(1.9 - h, 0.0));  // + exp(abs(h - flt) * -2.0) * 8.0;

        inten *= _filter(h, flt);

        v.x += inten * sin((TAU + 0.01) * (t * base * h));
        v.y += inten * sin(TAU * (t * base * h));
    }

    float o = v.x * amp;  // exp(max(tnote - 0.3, 0.0) * -5.0);

    // o = dist(o, 2.5);

    return vec2(dist(v * amp, 2.0));
}

// https://www.shadertoy.com/view/4sSSWz
float noise2(float phi) { return fract(sin(phi * 0.055753) * 122.3762) * 4.0 - 3.0; }

vec2 snare(float note, float t) {
    float i = t * iSampleRate;
    float env = exp(-t * 17.0);
    float v = 0.3 * env * (2.3 * noise2(i) + 0.5 * sin(30.0 * i));
    return vec2(v);
}

vec2 snarefill(float note, float t) {
    float i = t * iSampleRate;
    float env = exp(-t * 30.0);
    float v = 0.2 * env * (2.3 * noise2(i) + 0.5 * sin(30.0 * i));
    return vec2(v);
}

vec2 noisefeedin(float note, float t) {
    float i = t * iSampleRate;
    float env = exp(-t * 1.0);
    float v = 0.05 * env * (3.3 * noise2(i) + 0.5 * sin(30.0 * i));
    return vec2(v);
}

vec2 sidechainnoise(float note, float t) {
    float i = t * iSampleRate;
    float env = exp(-t * 3.0);
    float v = 0.03 * env * (3.3 * noise2(i) + 0.3 * sin(20.0 * i));
    return vec2(v);
}

vec2 sidechainnoise2(float note, float t) {
    float i = t * iSampleRate;
    float env = exp(-t * 3.0);
    float v = 0.1 * env * (3.3 * noise2(i) + 0.3 * sin(20.0 * i));
    return vec2(v);
}

vec2 kickattack(float note, float t) {
    float i = t * iSampleRate;
    float env = exp(-t * 28.0);
    float v = 0.5 * env * (0.7 * noise2(i) + 0.38 * sin(45.0 * i));
    return vec2(v);
}

// 1ビートを最大何分割するか。16分音符に対応するなら4
#define NOTE_VDIV 4

// 1ビートのpackingを考慮した分割数。32bitのintに16bitずつ詰めているので 4 / (32 / 16) = 2
#define NOTE_DIV 2

// 展開用の配列のpacking数。32bitのintに4bitずつ詰めているので 32 / 4 = 8
#define DEV_PACK 8

#define MAX_BEAT_LEN 8
int[MAX_BEAT_LEN * NOTE_VDIV] tmpIndexes;

#define O(a)                                                                                                                                                                                 \
    (a | 1 << 8) | ((a | 1 << 8) << 16), (a | 1 << 8) | ((a | 1 << 8) << 16), (a | 1 << 8) | ((a | 1 << 8) << 16), (a | 1 << 8) | ((a | 1 << 8) << 16), (a | 1 << 8) | ((a | 1 << 8) << 16), \
        (a | 1 << 8) | ((a | 1 << 8) << 16), (a | 1 << 8) | ((a | 1 << 8) << 16), (a | 1 << 8) | ((a | 1 << 8) << 16)
#define F(a) (a | 4 << 8) | ((a | 4 << 8) << 16), (a | 4 << 8) | ((a | 4 << 8) << 16)
#define E(a, b) (a | 8 << 8) | ((a | 8 << 8) << 16), (b | 8 << 8) | ((b | 8 << 8) << 16)
#define S(a, b, c, d) (a | 16 << 8) | ((b | 16 << 8) << 16), (c | 16 << 8) | ((d | 16 << 8) << 16)
#define D(a, b, c, d, e, f, g, h) (a) | (b << 4) | (c << 8) | (d << 12) | (e << 16) | (f << 20) | (g << 24) | (h << 28)

#define SEQUENCER(beat, time, beatLen, devPat, devLen, notes, development, toneFunc)                     \
    int indexOffset = development[int(mod(beat / float(beatLen * DEV_PACK), float(devLen / DEV_PACK)))]; \
    indexOffset = (indexOffset >> (4 * int(mod(beat / float(beatLen), float(DEV_PACK))))) & 15;          \
    indexOffset *= beatLen * NOTE_VDIV;                                                                  \
                                                                                                         \
    for (int i = 0; i < beatLen * NOTE_VDIV;) {                                                          \
        int index = i + indexOffset;                                                                     \
        int shift = (index % 2 == 1) ? 16 : 0;                                                           \
        int div = ((notes[index >> 1] >> shift) >> 8) & 255;                                             \
        int len = NOTE_VDIV * NOTE_VDIV / div;                                                           \
        for (int j = 0; j < len; j++) {                                                                  \
            tmpIndexes[i + j] = i;                                                                       \
        }                                                                                                \
        i += len;                                                                                        \
    }                                                                                                    \
                                                                                                         \
    float indexFloat = mod(beat * float(NOTE_VDIV), float(beatLen * NOTE_VDIV));                         \
    int index = int(indexFloat);                                                                         \
    int shift = (index % 2 == 1) ? 16 : 0;                                                               \
    int note = (notes[(index + indexOffset) >> 1] >> shift) & 255;                                       \
    float localTime = beatToTime((indexFloat - float(tmpIndexes[index])) / float(NOTE_VDIV));            \
    float amp = (note == 0) ? 0.0 : 1.0;                                                                 \
    vec2 ret = vec2(toneFunc(float(note), localTime) * amp);

//  KICK  //

vec2 kick1(float beat, float time) {
// 1つの展開のビート数
#define KICK1_BEAT_LEN 8

// 展開のパターンの種類
#define KICK1_DEV_PAT 4

// 展開の長さ
#define KICK1_DEV_LEN 32

    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[KICK1_BEAT_LEN * NOTE_DIV * KICK1_DEV_PAT] notes = int[](
        // 展開0
        F(1), F(0), F(0), E(0, 1), F(1), F(0), F(0), F(1),

        // 展開1
        F(1), F(1), F(1), F(1), F(1), F(1), F(1), F(1),

        // 展開2
        F(1), F(1), F(1), F(1), F(1), F(1), F(1), F(0),

        // 展開3
        F(1), F(1), F(1), F(1), F(0), F(0), F(0), F(0));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[KICK1_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0), D(1, 1, 1, 2, 1, 1, 1, 1), D(1, 1, 1, 1, 1, 1, 1, 1), D(1, 1, 1, 1, 1, 1, 1, 3));

    SEQUENCER(beat, time, KICK1_BEAT_LEN, KICK1_DEV_PAT, KICK1_DEV_LEN, notes, development, kick)

    sidechain = smoothstep(-0.1, 0.6, localTime);
    sidechain2 = smoothstep(-0.1, 0.7, localTime);
    sidechain3 = smoothstep(-0.2, 0.7, localTime);
    sidechain4 = smoothstep(-0.3, 0.8, localTime);
    sidechain5 = smoothstep(0.0, 0.2, localTime);

    return ret;
}

vec2 kick2(float beat, float time) {
// 1つの展開のビート数
#define KICK2_BEAT_LEN 8

// 展開のパターンの種類
#define KICK2_DEV_PAT 3

// 展開の長さ
#define KICK2_DEV_LEN 32

    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[KICK2_BEAT_LEN * NOTE_DIV * KICK2_DEV_PAT] notes = int[](
        // 展開0
        F(1), F(0), F(0), E(0, 1), F(1), F(0), F(0), F(1),

        // 展開1
        F(1), F(1), F(1), F(1), F(1), F(1), F(1), F(1),

        // 展開2
        O(0), O(0));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[KICK2_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0), D(1, 1, 1, 1, 1, 1, 1, 1), D(1, 1, 1, 1, 1, 1, 1, 1), D(2, 2, 2, 2, 2, 2, 2, 2));

    SEQUENCER(beat, time, KICK2_BEAT_LEN, KICK2_DEV_PAT, KICK2_DEV_LEN, notes, development, kickattack)

    return ret;
}

vec2 crashcymbal1(float beat, float time) {
// 1つの展開のビート数
#define CRASH1_BEAT_LEN 8

// 展開のパターンの種類
#define CRASH1_DEV_PAT 3

// 展開の長さ
#define CRASH1_DEV_LEN 32

    int[CRASH1_BEAT_LEN * NOTE_DIV * CRASH1_DEV_PAT] notes = int[](
        // 展開0
        O(1), O(0),

        // 展開1
        O(0), O(0),

        // 展開2
        F(1), F(0), F(0), F(0), F(1), F(0), F(0), F(0));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[CRASH1_DEV_LEN / DEV_PACK] development = int[](D(0, 1, 1, 1, 0, 1, 2, 2), D(0, 1, 1, 1, 0, 1, 2, 2), D(0, 1, 1, 1, 0, 1, 1, 1), D(0, 1, 1, 1, 0, 1, 1, 1));

    SEQUENCER(beat, time, CRASH1_BEAT_LEN, CRASH1_DEV_PAT, CRASH1_DEV_LEN, notes, development, crash1)

    return ret;
}

vec2 crashcymbal2(float beat, float time) {
// 1つの展開のビート数
#define CRASH1_BEAT_LEN 8

// 展開のパターンの種類
#define CRASH1_DEV_PAT 3

// 展開の長さ
#define CRASH1_DEV_LEN 32

    int[CRASH1_BEAT_LEN * NOTE_DIV * CRASH1_DEV_PAT] notes = int[](
        // 展開0
        O(1), O(0),

        // 展開1
        O(0), O(0),

        // 展開2
        F(0), F(0), F(1), F(0), F(0), F(0), F(1), F(0));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[CRASH1_DEV_LEN / DEV_PACK] development = int[](D(1, 1, 0, 1, 1, 0, 2, 2), D(1, 1, 1, 1, 1, 0, 2, 2), D(1, 1, 1, 1, 1, 1, 1, 1), D(1, 1, 1, 1, 1, 1, 1, 1));

    SEQUENCER(beat, time, CRASH1_BEAT_LEN, CRASH1_DEV_PAT, CRASH1_DEV_LEN, notes, development, crash1)

    return ret;
}

//   BASS   //

vec2 bass1(float beat, float time) {
// 1つの展開のビート数
#define BASS1_BEAT_LEN 8

// 展開のパターンの種類
#define BASS1_DEV_PAT 11

// 展開の長さ
#define BASS1_DEV_LEN 32

    int[BASS1_BEAT_LEN * NOTE_DIV * BASS1_DEV_PAT] notes = int[](
        // 展開0
        F(0), F(33), E(0, 33), S(0, 33, 0, 33), F(0), F(33), E(0, 33), S(0, 33, 0, 33),

        // 展開1
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33),

        // 展開2
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(29, 29), S(0, 29, 29, 29), S(0, 31, 31, 31), S(48, 47, 43, 40),

        // 展開3
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 34, 34, 34),

        // 展開4
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 36, 36, 36),

        // 展開5
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(33, 33), S(0, 33, 33, 33), S(0, 34, 34, 34), S(0, 36, 36, 36),

        // 展開6
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(33, 33), S(0, 33, 33, 33), S(0, 43, 43, 43), S(0, 55, 57, 69),

        // 展開7
        E(29, 29), S(0, 29, 29, 29), S(0, 29, 29, 29), S(0, 31, 33, 45), E(29, 29), S(0, 29, 29, 29), S(0, 29, 29, 29), S(0, 31, 31, 31),

        // 展開8
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 43, 45, 57),

        // 展開9
        E(29, 29), S(0, 29, 29, 29), S(0, 29, 29, 29), S(0, 31, 33, 45), E(29, 29), S(0, 29, 29, 29), S(0, 31, 31, 31), S(0, 31, 31, 31),

        // 展開10
        F(0), F(33), E(0, 33), S(0, 33, 0, 33), F(0), F(33), F(0), F(0));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[BASS1_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0), D(1, 1, 1, 2, 3, 4, 5, 6), D(7, 0, 7, 8, 7, 0, 9, 0), D(0, 0, 0, 0, 0, 0, 0, 0));
    SEQUENCER(beat, time, BASS1_BEAT_LEN, BASS1_DEV_PAT, BASS1_DEV_LEN, notes, development, bass)
    return ret;
}

vec2 bass2(float beat, float time) {
// 1つの展開のビート数 ベースのアタック
#define BASS2_BEAT_LEN 8

// 展開のパターンの種類
#define BASS2_DEV_PAT 11

// 展開の長さ
#define BASS2_DEV_LEN 32

    int[BASS2_BEAT_LEN * NOTE_DIV * BASS2_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33),

        // 展開2
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(41, 41), S(0, 41, 41, 41), S(0, 43, 43, 43), F(0),

        // 展開3
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33),

        // 展開4
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 34, 34, 34),

        // 展開5
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 36, 36, 36),

        // 展開6
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(33, 33), S(0, 33, 33, 33), S(0, 34, 34, 34), S(0, 36, 36, 36),

        // 展開7
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(33, 33), S(0, 33, 33, 33), S(0, 43, 43, 43), S(0, 55, 57, 69),

        // 展開8
        E(29, 29), S(0, 29, 29, 29), S(0, 29, 29, 29), S(0, 31, 33, 45), E(29, 29), S(0, 29, 29, 29), S(0, 29, 29, 29), S(0, 31, 31, 31),

        // 展開9
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 43, 45, 57),

        // 展開10
        E(29, 29), S(0, 29, 29, 29), S(0, 29, 29, 29), S(0, 31, 33, 45), E(29, 29), S(0, 29, 29, 29), S(0, 31, 31, 31), S(0, 31, 31, 31));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[BASS2_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0), D(1, 1, 1, 2, 4, 5, 6, 7), D(8, 1, 8, 9, 8, 1, 10, 1), D(0, 0, 0, 0, 0, 0, 0, 0));
    SEQUENCER(beat, time, BASS2_BEAT_LEN, BASS2_DEV_PAT, BASS2_DEV_LEN, notes, development, attackbass)
    return ret;
}

vec2 bass3(float beat, float time) {
    if (beat < 64.0) return vec2(0.0);
    return basssaw3(33.0, beatToTime(mod(beat, 4.0)));
}

vec2 sideSupersaw1(float beat, float time) {
// 1つの展開のビート数
#define TAMESHI_BEAT_LEN 8

// 展開のパターンの種類
#define TAMESHI_DEV_PAT 7

// 展開の長さ
#define TAMESHI_DEV_LEN 32

    int[TAMESHI_BEAT_LEN * NOTE_DIV * TAMESHI_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        E(45, 45), S(0, 45, 45, 45), S(0, 45, 45, 45), S(0, 45, 45, 45), E(45, 45), S(0, 45, 45, 45), S(0, 45, 45, 45), S(0, 45, 45, 45),

        // 展開2
        E(45, 45), S(0, 45, 45, 45), S(0, 45, 45, 45), S(0, 45, 45, 45), E(41, 41), S(0, 41, 41, 41), S(0, 43, 43, 43), F(0),

        // 展開3
        E(45, 45), S(0, 45, 45, 45), S(0, 45, 45, 45), S(0, 45, 45, 45), E(45, 45), S(0, 45, 45, 45), S(0, 45, 45, 45), S(0, 46, 46, 46),

        // 展開4
        E(45, 45), S(0, 45, 45, 45), S(0, 45, 45, 45), S(0, 45, 45, 45), E(45, 45), S(0, 45, 45, 45), S(0, 45, 45, 45), S(0, 48, 48, 48),

        // 展開5
        E(45, 45), S(0, 45, 45, 45), S(0, 45, 45, 45), S(0, 45, 45, 45), E(45, 45), S(0, 45, 45, 45), S(0, 46, 46, 46), S(0, 48, 48, 48),

        // 展開6
        E(45, 45), S(0, 45, 45, 45), S(0, 45, 45, 45), S(0, 45, 45, 45), E(45, 45), S(0, 45, 45, 45), S(0, 55, 55, 55), S(0, 0, 0, 0));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[TAMESHI_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0), D(1, 1, 1, 2, 3, 4, 5, 6), D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 0, 0, 0, 0, 0));

    SEQUENCER(beat, time, TAMESHI_BEAT_LEN, TAMESHI_DEV_PAT, TAMESHI_DEV_LEN, notes, development, chordsaw1)
    return ret;
}

vec2 sideSupersaw2(float beat, float time) {
// 1つの展開のビート数
#define TAMESHI_BEAT_LEN 8

// 展開のパターンの種類
#define TAMESHI_DEV_PAT 7

// 展開の長さ
#define TAMESHI_DEV_LEN 32

    int[TAMESHI_BEAT_LEN * NOTE_DIV * TAMESHI_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33),

        // 展開2
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(29, 29), S(0, 31, 31, 31), S(0, 31, 31, 31), S(0, 31, 31, 31),

        // 展開3
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 34, 34, 34),

        // 展開4
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 36, 36, 36),

        // 展開5
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(33, 33), S(0, 33, 33, 33), S(0, 34, 34, 34), S(0, 36, 36, 36),

        // 展開6
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(33, 33), S(0, 33, 33, 33), S(0, 43, 43, 43), S(0, 55, 57, 69));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[TAMESHI_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0), D(1, 1, 1, 2, 3, 4, 5, 6), D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 0, 0, 0, 0, 0));

    SEQUENCER(beat, time, TAMESHI_BEAT_LEN, TAMESHI_DEV_PAT, TAMESHI_DEV_LEN, notes, development, chordsaw1)
    return ret;
}

vec2 tb303synth(float beat, float time) {
// 1つの展開のビート数
#define TB303SYNTH1_BEAT_LEN 8

// 展開のパターンの種類
#define TB303SYNTH1_DEV_PAT 2

// 展開の長さ
#define TB303SYNTH1_DEV_LEN 32

    int[TB303SYNTH1_BEAT_LEN * NOTE_DIV * TB303SYNTH1_DEV_PAT] notes = int[](
        // 展開0
        F(33), F(33), F(33), F(33), F(33), F(33), F(33), F(33),

        // 展開1
        E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), E(33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33), S(0, 33, 33, 33));

    // 展開
    int[TB303SYNTH1_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0), D(1, 1, 1, 1, 1, 1, 1, 1), D(1, 1, 1, 1, 1, 1, 1, 1), D(1, 1, 1, 1, 0, 0, 0, 0));

    SEQUENCER(beat, time, TB303SYNTH1_BEAT_LEN, TB303SYNTH1_DEV_PAT, TB303SYNTH1_DEV_LEN, notes, development, synth)
    return ret;
}

vec2 arp0(float beat, float time) {
    if (beat >= 64.0 && beat < 192.0) return vec2(0.0);

// 1つの展開のビート数
#define ARP0_BEAT_LEN 8

// 展開のパターンの種類
#define ARP0_DEV_PAT 2

// 展開の長さ
#define ARP0_DEV_LEN 8

    int[ARP0_BEAT_LEN * NOTE_DIV * ARP0_DEV_PAT] notes = int[](
        // 展開0
        S(57, 57, 59, 59), S(60, 60, 64, 64), S(67, 67, 69, 69), S(71, 71, 74, 74), S(57, 57, 59, 59), S(60, 60, 64, 64), S(67, 67, 69, 69), S(71, 71, 74, 74),
        // 展開1
        S(57, 57, 59, 59), S(60, 60, 64, 64), S(67, 67, 69, 69), S(71, 71, 74, 74), S(57, 57, 59, 59), S(60, 60, 64, 64), S(67, 67, 69, 69), F(0));

    // 展開
    int[ARP0_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 1));

    SEQUENCER(beat, time, ARP0_BEAT_LEN, ARP0_DEV_PAT, ARP0_DEV_LEN, notes, development, arpsaw)
    return ret;
}

vec2 arp1(float beat, float time) {
// 1つの展開のビート数
#define ARP1_BEAT_LEN 8

// 展開のパターンの種類
#define ARP1_DEV_PAT 2

// 展開の長さ
#define ARP1_DEV_LEN 32

    int[ARP1_BEAT_LEN * NOTE_DIV * ARP1_DEV_PAT] notes = int[](
        // 展開0
        S(57, 0, 59, 0), S(60, 0, 64, 0), S(67, 0, 69, 0), S(71, 0, 74, 0), S(57, 0, 59, 0), S(60, 0, 64, 0), S(67, 0, 69, 0), S(71, 0, 74, 0),

        // 展開1
        S(57, 0, 59, 0), S(60, 0, 64, 0), S(67, 0, 69, 0), S(71, 0, 74, 0), S(57, 0, 59, 0), S(60, 0, 64, 0), S(67, 0, 69, 0), F(0));

    // 展開
    int[ARP1_DEV_LEN / DEV_PACK] development = int[](D(1, 1, 1, 1, 1, 1, 1, 1), D(1, 1, 1, 1, 1, 1, 1, 1), D(1, 1, 1, 1, 1, 1, 1, 1), D(0, 0, 0, 0, 0, 0, 0, 0));

    SEQUENCER(beat, time, ARP1_BEAT_LEN, ARP1_DEV_PAT, ARP1_DEV_LEN, notes, development, arp)
    return ret;
}

vec2 arp2(float beat, float time) {
// 1つの展開のビート数
#define ARP2_BEAT_LEN 8

// 展開のパターンの種類
#define ARP2_DEV_PAT 2

// 展開の長さ
#define ARP2_DEV_LEN 32

    int[ARP2_BEAT_LEN * NOTE_DIV * ARP2_DEV_PAT] notes = int[](
        // 展開0
        S(0, 69, 0, 71), S(0, 72, 0, 76), S(0, 79, 0, 81), S(0, 83, 0, 86), S(0, 69, 0, 71), S(0, 72, 0, 76), S(0, 79, 0, 81), F(0),

        // 展開1
        S(0, 69, 0, 71), S(0, 72, 0, 76), S(0, 79, 0, 81), S(0, 83, 0, 86), S(0, 69, 0, 71), S(0, 72, 0, 76), S(0, 79, 0, 81), S(0, 83, 0, 86));

    // 展開
    int[ARP2_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 1, 1, 1, 1), D(1, 1, 1, 1, 1, 1, 1, 1), D(1, 1, 1, 1, 1, 1, 1, 1), D(1, 1, 1, 1, 1, 1, 1, 1));

    SEQUENCER(beat, time, ARP2_BEAT_LEN, ARP2_DEV_PAT, ARP2_DEV_LEN, notes, development, arp)
    return ret;
}

vec2 arp3(float beat, float time) {
// 1つの展開のビート数
#define ARP3_BEAT_LEN 8

// 展開のパターンの種類
#define ARP3_DEV_PAT 2

// 展開の長さ
#define ARP3_DEV_LEN 32

    int[ARP3_BEAT_LEN * NOTE_DIV * ARP3_DEV_PAT] notes = int[](
        // 展開0
        S(72, 60, 55, 64), S(0, 0, 0, 0), S(67, 55, 64, 55), S(0, 0, 0, 0), S(72, 60, 55, 64), S(0, 0, 0, 0), S(67, 55, 64, 55), S(0, 0, 0, 0),

        // 展開1
        S(0, 0, 0, 0), S(67, 60, 72, 55), S(0, 0, 0, 0), S(67, 60, 79, 62), S(0, 0, 0, 0), S(67, 60, 72, 55), S(0, 0, 0, 0), S(0, 0, 0, 0));

    // 展開
    int[ARP3_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0), D(1, 1, 1, 1, 1, 1, 1, 1), D(1, 1, 1, 1, 1, 1, 1, 1), D(0, 0, 0, 0, 0, 0, 0, 0));

    SEQUENCER(beat, time, ARP3_BEAT_LEN, ARP3_DEV_PAT, ARP3_DEV_LEN, notes, development, arpsine)
    return ret;
}

vec2 arp4(float beat, float time) {
// 1つの展開のビート数
#define ARP4_BEAT_LEN 8

// 展開のパターンの種類
#define ARP4_DEV_PAT 2

// 展開の長さ
#define ARP4_DEV_LEN 32

    int[ARP4_BEAT_LEN * NOTE_DIV * ARP4_DEV_PAT] notes = int[](
        // 展開0
        S(0, 0, 0, 0), S(67, 60, 72, 55), S(0, 0, 0, 0), S(67, 60, 79, 62), S(0, 0, 0, 0), S(67, 60, 72, 55), S(0, 0, 0, 0), S(67, 60, 79, 62),

        // 展開1
        S(0, 0, 0, 0), S(67, 60, 72, 55), S(0, 0, 0, 0), S(67, 60, 79, 62), S(0, 0, 0, 0), S(67, 60, 72, 55), S(0, 0, 0, 0), S(0, 0, 0, 0));

    // 展開
    int[ARP4_DEV_LEN / DEV_PACK] development = int[](D(1, 1, 1, 1, 1, 1, 1, 1), D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 0, 0, 0, 0, 0));

    SEQUENCER(beat, time, ARP4_BEAT_LEN, ARP4_DEV_PAT, ARP4_DEV_LEN, notes, development, arpsine)
    return ret;
}

vec2 arp5(float beat, float time) {
    if (beat < 64.0 || beat >= 192.0) return vec2(0.0);
// 1つの展開のビート数
#define ARP5_BEAT_LEN 8

// 展開のパターンの種類
#define ARP5_DEV_PAT 1

// 展開の長さ
#define ARP5_DEV_LEN 8

    int[ARP5_BEAT_LEN * NOTE_DIV * ARP5_DEV_PAT] notes = int[](
        // 展開0
        S(69, 0, 79, 67), S(0, 0, 76, 0), S(0, 69, 0, 0), S(67, 0, 76, 0), S(69, 0, 79, 67), S(0, 0, 76, 0), S(0, 69, 0, 0), S(67, 0, 76, 0));

    // 展開
    int[ARP5_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0));

    SEQUENCER(beat, time, ARP5_BEAT_LEN, ARP5_DEV_PAT, ARP5_DEV_LEN, notes, development, arpsine2)
    return ret;
}

vec2 thihat1(float beat, float time) {
// 1つの展開のビート数
#define HIHAT3_BEAT_LEN 8

// 展開のパターンの種類
#define HIHAT3_DEV_PAT 3

// 展開の長さ
#define HIHAT3_DEV_LEN 32

    int[HIHAT3_BEAT_LEN * NOTE_DIV * HIHAT3_DEV_PAT] notes = int[](
        // 展開0
        F(1), F(0), F(0), F(0), F(0), F(0), F(0), F(0),

        // 展開1
        E(0, 1), E(0, 1), E(0, 1), E(0, 1), E(0, 1), E(0, 1), E(0, 1), E(0, 1),

        // 展開2
        O(0), O(0));

    // 展開 #define CRASH1_DEV_LEN 8　変える
    int[HIHAT3_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0), D(1, 1, 1, 1, 1, 1, 1, 1), D(1, 1, 1, 1, 1, 1, 1, 1), D(0, 0, 0, 0, 2, 2, 2, 2));

    SEQUENCER(beat, time, HIHAT3_BEAT_LEN, HIHAT3_DEV_PAT, HIHAT3_DEV_LEN, notes, development, hihat3)

    return ret;
}

vec2 subbass1(float beat, float time) {
// 1つの展開のビート数
#define SUB1_BEAT_LEN 8

// 展開のパターンの種類
#define SUB1_DEV_PAT 2

// 展開の長さ
#define SUB1_DEV_LEN 32

    int[SUB1_BEAT_LEN * NOTE_DIV * SUB1_DEV_PAT] notes = int[](
        // 展開0
        F(33), F(33), F(33), F(33), F(33), F(33), F(33), F(33),

        // 展開1
        F(33), F(33), F(33), F(33), F(33), F(33), F(33), F(33));

    // 展開 #define SUB1_DEV_LEN 8　変える
    int[SUB1_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 1, 1, 1, 1), D(1, 1, 1, 1, 1, 1, 1, 1), D(1, 1, 1, 1, 1, 1, 1, 1), D(1, 1, 1, 1, 1, 1, 1, 1));

    SEQUENCER(beat, time, SUB1_BEAT_LEN, SUB1_DEV_PAT, SUB1_DEV_LEN, notes, development, subbass)
    return ret;
}

//  HIHAT  //

vec2 thihat2(float beat, float time) {
// 1つの展開のビート数
#define HIHAT2_BEAT_LEN 8

// 展開のパターンの種類
#define HIHAT2_DEV_PAT 3

// 展開の長さ
#define HIHAT2_DEV_LEN 32

    int[HIHAT2_BEAT_LEN * NOTE_DIV * HIHAT2_DEV_PAT] notes = int[](
        // 展開0
        S(0, 1, 1, 1), S(0, 1, 1, 1), S(0, 1, 1, 1), S(0, 1, 1, 1), S(0, 1, 1, 1), S(0, 1, 1, 1), S(0, 1, 1, 1), S(0, 1, 1, 1),

        // 展開1
        S(0, 1, 1, 1), S(0, 1, 1, 1), S(0, 1, 1, 1), S(0, 1, 1, 1), S(0, 1, 1, 1), S(0, 1, 1, 1), S(0, 1, 1, 1), S(0, 1, 1, 1),

        // 展開2
        O(0), O(0));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[HIHAT2_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 1, 1, 1, 1), D(1, 1, 1, 1, 1, 1, 1, 1), D(1, 1, 1, 1, 1, 1, 1, 1), D(1, 1, 1, 1, 2, 2, 2, 2));

    SEQUENCER(beat, time, KICK1_BEAT_LEN, KICK1_DEV_PAT, KICK1_DEV_LEN, notes, development, hihat2)
    return ret;
}

//  CHORD  //

vec2 introSupersaw1(float beat, float time) {
    if (beat >= 64.0) return vec2(0.0);

// 1つの展開のビート数
#define INTROSAW_BEAT_LEN 8

// 展開のパターンの種類
#define INTROSAW_DEV_PAT 2

// 展開の長さ
#define INTROSAW_DEV_LEN 8

    int[INTROSAW_BEAT_LEN * NOTE_DIV * INTROSAW_DEV_PAT] notes = int[](
        // 展開0
        F(0), F(45), F(0), F(0), F(0), F(45), F(0), F(45),

        // 展開1
        F(45), F(45), F(45), F(45), F(45), F(45), F(45), F(45));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[INTROSAW_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 1, 1, 1, 1));

    SEQUENCER(beat, time, INTROSAW_BEAT_LEN, INTROSAW_DEV_PAT, INTROSAW_DEV_LEN, notes, development, basssaw1)
    return ret;
}

vec2 introSupersaw2(float beat, float time) {
    if (beat >= 64.0) return vec2(0.0);

    int[INTROSAW_BEAT_LEN * NOTE_DIV * INTROSAW_DEV_PAT] notes = int[](
        // 展開0
        F(0), F(0), F(0), F(69), F(0), F(0), F(0), F(57),

        // 展開1
        F(0), F(0), F(0), F(57), F(0), F(0), F(0), F(57));

    // 展開 #define KICK1_DEV_LEN 8　変える
    int[INTROSAW_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 1, 1, 1, 1));

    SEQUENCER(beat, time, INTROSAW_BEAT_LEN, INTROSAW_DEV_PAT, INTROSAW_DEV_LEN, notes, development, basssaw2)
    return ret;
}

// SUPERSAW  //

vec2 chordSupersaw1(float beat, float time) {
// 1つの展開のビート数
#define CHORD1_BEAT_LEN 8

// 展開のパターンの種類
#define CHORD1_DEV_PAT 4

// 展開の長さ
#define CHORD1_DEV_LEN 32

    int[CHORD1_BEAT_LEN * NOTE_DIV * CHORD1_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        O(69), O(69),

        // 展開2
        F(0), F(0), E(0, 67), F(0), E(0, 67), F(0), F(0), F(0),

        // 展開3
        F(67), F(0), E(0, 67), F(0), E(0, 67), F(0), E(0, 67), F(62));

    // 展開 #define CHORD1_DEV_LEN 8　変える
    int[CHORD1_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 1, 1, 1, 1), D(2, 2, 2, 2, 3, 3, 3, 3), D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 0, 0, 0, 0, 0));

    SEQUENCER(beat, time, CHORD1_BEAT_LEN, CHORD1_DEV_PAT, CHORD1_DEV_LEN, notes, development, chordsaw1)
    return ret;
}

vec2 chordSupersaw2(float beat, float time) {
// 1つの展開のビート数
#define CHORD2_BEAT_LEN 8

// 展開のパターンの種類
#define CHORD2_DEV_PAT 4

// 展開の長さ
#define CHORD2_DEV_LEN 32

    int[CHORD2_BEAT_LEN * NOTE_DIV * CHORD2_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        O(72), O(72),

        // 展開2
        F(0), F(0), E(0, 62), F(0), E(0, 62), F(0), F(0), F(0),

        // 展開3
        F(62), F(0), E(0, 62), F(0), E(0, 62), F(0), E(0, 62), F(57));

    // 展開 #define CHORD2_DEV_LEN 8　変える
    int[CHORD2_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 1, 1, 1, 1), D(2, 2, 2, 2, 3, 3, 3, 3), D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 0, 0, 0, 0, 0));
    SEQUENCER(beat, time, CHORD2_BEAT_LEN, CHORD2_DEV_PAT, CHORD2_DEV_LEN, notes, development, chordsaw1)
    return ret;
}

vec2 chordSupersaw3(float beat, float time) {
// 1つの展開のビート数
#define CHORD3_BEAT_LEN 8

// 展開のパターンの種類
#define CHORD3_DEV_PAT 4

// 展開の長さ
#define CHORD3_DEV_LEN 32

    int[CHORD3_BEAT_LEN * NOTE_DIV * CHORD3_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        O(74), O(74),

        // 展開2
        F(0), F(0), E(0, 60), F(0), E(0, 60), F(0), F(0), F(0),

        // 展開3
        F(60), F(0), E(0, 60), F(0), E(0, 60), F(0), E(0, 60), F(54));

    // 展開 #define CHORD3_DEV_LEN 8　変える
    int[CHORD3_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 1, 1, 1, 1), D(2, 2, 2, 2, 3, 3, 3, 3), D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 0, 0, 0, 0, 0));

    SEQUENCER(beat, time, CHORD3_BEAT_LEN, CHORD3_DEV_PAT, CHORD3_DEV_LEN, notes, development, chordsaw1)
    return ret;
}

vec2 chordSupersaw4(float beat, float time) {
// 1つの展開のビート数
#define CHORD4_BEAT_LEN 8

// 展開のパターンの種類
#define CHORD4_DEV_PAT 4

// 展開の長さ
#define CHORD4_DEV_LEN 32

    int[CHORD4_BEAT_LEN * NOTE_DIV * CHORD4_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        O(79), O(79),

        // 展開2
        F(0), F(0), E(0, 57), F(0), E(0, 57), F(0), F(0), F(0),

        // 展開3
        F(57), F(0), E(0, 57), F(0), E(0, 57), F(0), E(0, 57), F(49));

    // 展開 #define CHORD4_DEV_LEN 8　変える
    int[CHORD4_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 1, 1, 1, 1), D(2, 2, 2, 2, 3, 3, 3, 3), D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 0, 0, 0, 0, 0));

    SEQUENCER(beat, time, CHORD4_BEAT_LEN, CHORD4_DEV_PAT, CHORD4_DEV_LEN, notes, development, chordsaw1)
    return ret;
}

vec2 chordSupersaw5(float beat, float time) {
// 1つの展開のビート数
#define CHORD5_BEAT_LEN 8

// 展開のパターンの種類
#define CHORD5_DEV_PAT 3

// 展開の長さ
#define CHORD5_DEV_LEN 32

    int[CHORD5_BEAT_LEN * NOTE_DIV * CHORD5_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        O(86), O(86),

        // 展開2
        O(91), O(91));

    // 展開 #define CHORD4_DEV_LEN 8　変える
    int[CHORD5_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 1, 2), D(0, 0, 0, 0, 0, 0, 0, 2), D(0, 0, 0, 0, 0, 0, 1, 2), D(0, 0, 0, 0, 0, 0, 0, 0));

    SEQUENCER(beat, time, CHORD5_BEAT_LEN, CHORD5_DEV_PAT, CHORD5_DEV_LEN, notes, development, chordsaw1)
    return ret;
}

vec2 chordSquare1(float beat, float time) {
// 1つの展開のビート数
#define SQUARE1_BEAT_LEN 8

// 展開のパターンの種類
#define SQUARE1_DEV_PAT 4

// 展開の長さ
#define SQUARE1_DEV_LEN 32

    int[SQUARE1_BEAT_LEN * NOTE_DIV * SQUARE1_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        S(67, 67, 0, 67), S(67, 0, 67, 67), S(67, 67, 0, 67), S(67, 0, 67, 67), S(67, 67, 0, 67), S(67, 0, 67, 67), S(67, 67, 0, 67), S(67, 0, 72, 72),

        // 展開2
        S(67, 67, 0, 67), S(67, 0, 67, 67), S(67, 67, 0, 67), S(67, 0, 67, 67), S(67, 67, 0, 67), S(67, 0, 67, 67), S(72, 72, 0, 72), S(0, 0, 72, 72),

        // 展開3
        S(72, 0, 0, 0), S(0, 0, 67, 0), S(0, 0, 0, 71), S(0, 0, 0, 0), S(72, 0, 0, 0), S(0, 0, 67, 0), S(0, 0, 0, 71), S(0, 0, 0, 0));

    // 展開 #define SQUARE1_DEV_LEN 8　変える
    int[SQUARE1_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 0, 1, 2, 2, 2), D(3, 3, 3, 3, 3, 3, 3, 3), D(0, 0, 0, 0, 0, 0, 0, 0));
    SEQUENCER(beat, time, SQUARE1_BEAT_LEN, SQUARE1_DEV_PAT, SQUARE1_DEV_LEN, notes, development, chordsquare1)
    return ret;
}

vec2 chordSquare2(float beat, float time) {
// 1つの展開のビート数
#define SQUARE2_BEAT_LEN 8

// 展開のパターンの種類
#define SQUARE2_DEV_PAT 4

// 展開の長さ
#define SQUARE2_DEV_LEN 32

    int[SQUARE2_BEAT_LEN * NOTE_DIV * SQUARE2_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        S(62, 62, 0, 62), S(62, 0, 62, 62), S(62, 62, 0, 62), S(62, 0, 62, 62), S(62, 62, 0, 62), S(62, 0, 62, 62), S(62, 62, 0, 62), S(62, 0, 67, 67),

        // 展開2
        S(62, 62, 0, 62), S(62, 0, 62, 62), S(62, 62, 0, 62), S(62, 0, 62, 62), S(62, 62, 0, 62), S(62, 0, 62, 62), S(67, 67, 0, 67), S(0, 0, 67, 67),

        // 展開3
        S(71, 71, 0, 71), S(71, 0, 71, 71), S(71, 71, 0, 71), S(71, 0, 71, 71), S(71, 71, 0, 71), S(71, 0, 71, 71), S(72, 72, 0, 72), S(0, 0, 72, 72));

    // 展開 #define SQUARE2_DEV_LEN 8　変える
    int[SQUARE2_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 0, 1, 2, 3, 3), D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 0, 0, 0, 0, 0));
    SEQUENCER(beat, time, SQUARE2_BEAT_LEN, SQUARE2_DEV_PAT, SQUARE2_DEV_LEN, notes, development, chordsquare1)
    return ret;
}

vec2 chordSquare3(float beat, float time) {
// 1つの展開のビート数
#define SQUARE3_BEAT_LEN 8

// 展開のパターンの種類
#define SQUARE3_DEV_PAT 4

// 展開の長さ
#define SQUARE3_DEV_LEN 32

    // ノート番号
    // F: 4分音符
    // E: 8分音符
    // S: 16分音符
    // ノート番号0は休符
    int[SQUARE3_BEAT_LEN * NOTE_DIV * SQUARE3_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        S(57, 57, 0, 57), S(57, 0, 57, 57), S(57, 57, 0, 57), S(57, 0, 57, 57), S(57, 57, 0, 57), S(57, 0, 57, 57), S(57, 57, 0, 57), S(57, 0, 59, 59),

        // 展開2
        S(57, 57, 0, 57), S(57, 0, 57, 57), S(57, 57, 0, 57), S(57, 0, 57, 57), S(57, 57, 0, 57), S(57, 0, 57, 57), S(57, 57, 0, 57), S(0, 0, 57, 57),

        // 展開3
        S(0, 0, 0, 71), S(0, 0, 0, 0), S(72, 0, 0, 0), S(0, 0, 67, 0), S(0, 0, 0, 71), S(0, 0, 0, 0), S(72, 0, 0, 0), S(0, 0, 67, 0));

    // 展開 #define SQUARE3_DEV_LEN 8　変える
    int[SQUARE3_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 0, 1, 2, 2, 2), D(3, 3, 3, 3, 3, 3, 3, 3), D(0, 0, 0, 0, 0, 0, 0, 0));
    SEQUENCER(beat, time, SQUARE3_BEAT_LEN, SQUARE3_DEV_PAT, SQUARE3_DEV_LEN, notes, development, chordsquare1)
    return ret;
}

vec2 snare1(float beat, float time) {
// 1つの展開のビート数
#define SNARE1_BEAT_LEN 8

// 展開のパターンの種類
#define SNARE1_DEV_PAT 2

// 展開の長さ
#define SNARE1_DEV_LEN 32

    int[SNARE1_BEAT_LEN * NOTE_DIV * SNARE1_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        F(0), E(1, 0), F(0), E(1, 0), F(0), E(1, 0), F(0), E(1, 0));

    // 展開 #define SNARE1_DEV_LEN 8　変える
    int[SNARE1_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 1, 1, 1, 1), D(1, 1, 1, 1, 1, 1, 1, 1), D(1, 1, 1, 1, 1, 1, 1, 1), D(0, 0, 0, 0, 0, 0, 0, 0));
    SEQUENCER(beat, time, SNARE1_BEAT_LEN, SNARE1_DEV_PAT, SNARE1_DEV_LEN, notes, development, snare)
    return ret;
}

//
// hokkSUpersaw1は79のみを再生する
//

vec2 hookSupersaw1(float beat, float time) {
// 1つの展開のビート数
#define HOOK1_BEAT_LEN 8

// 展開のパターンの種類
#define HOOK1_DEV_PAT 2

// 展開の長さ
#define HOOK1_DEV_LEN 32

    int[HOOK1_BEAT_LEN * NOTE_DIV * HOOK1_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        F(79), S(79, 79, 79, 79), S(79, 79, 79, 79), S(79, 79, 79, 79), F(79), S(79, 79, 79, 79), S(79, 79, 79, 79), S(79, 79, 79, 79));

    // 展開 #define HOOK1_DEV_LEN 8　変える
    int[HOOK1_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 0, 0, 0, 0, 0), D(1, 1, 1, 1, 1, 1, 1, 1), D(0, 0, 0, 0, 0, 0, 0, 0));
    SEQUENCER(beat, time, HOOK1_BEAT_LEN, HOOK1_DEV_PAT, HOOK1_DEV_LEN, notes, development, chordsaw2)
    return ret;
}

vec2 hookSupersaw2(float beat, float time) {
// 1つの展開のビート数
#define HOOK2_BEAT_LEN 8

// 展開のパターンの種類
#define HOOK2_DEV_PAT 4

// 展開の長さ
#define HOOK2_DEV_LEN 32

    int[HOOK2_BEAT_LEN * NOTE_DIV * HOOK2_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        F(74), S(74, 74, 74, 74), S(74, 74, 74, 74), S(74, 74, 74, 74), F(74), S(74, 74, 74, 74), S(74, 74, 74, 74), S(74, 74, 74, 74),

        // 展開2
        F(74), S(74, 74, 74, 74), S(74, 74, 74, 74), S(74, 74, 74, 74), F(86), S(86, 86, 86, 86), S(86, 86, 86, 86), S(86, 86, 86, 86),

        // 展開3 HOOK 8小節目に使用
        F(74), S(74, 74, 74, 74), S(74, 74, 74, 74), S(74, 74, 74, 74), F(76), S(76, 76, 76, 76), S(76, 76, 76, 76), S(76, 76, 76, 76));

    // 展開 #define HOOK2_DEV_LEN 8　変える
    int[HOOK2_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 0, 0, 0, 0, 0), D(1, 2, 1, 3, 1, 1, 1, 1), D(0, 0, 0, 0, 0, 0, 0, 0));
    SEQUENCER(beat, time, HOOK2_BEAT_LEN, HOOK2_DEV_PAT, HOOK2_DEV_LEN, notes, development, chordsaw2)
    return ret;
}

vec2 hookSupersaw3(float beat, float time) {
// 1つの展開のビート数
#define HOOK3_BEAT_LEN 8

// 展開のパターンの種類
#define HOOK3_DEV_PAT 8

// 展開の長さ
#define HOOK3_DEV_LEN 32

    int[HOOK3_BEAT_LEN * NOTE_DIV * HOOK3_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        F(57), S(57, 57, 57, 57), S(57, 57, 57, 57), S(57, 57, 57, 57), F(57), S(57, 57, 57, 57), S(57, 57, 57, 57), S(84, 84, 84, 84),

        // 展開2
        F(83), S(83, 83, 83, 83), S(83, 83, 83, 83), S(83, 83, 83, 83), F(83), S(83, 83, 83, 83), S(83, 83, 83, 83), S(83, 83, 83, 83),

        // 展開3 HOOK 7～8小節目に使用
        F(83), S(83, 83, 83, 83), S(83, 83, 83, 83), S(83, 83, 83, 83), F(88), S(88, 88, 88, 88), S(91, 91, 91, 91), S(91, 91, 91, 91),

        // 展開4 HOOK 9～小節目に使用
        F(79), S(79, 79, 79, 79), S(79, 79, 79, 79), S(79, 79, 79, 79), F(79), S(79, 79, 79, 79), S(79, 79, 79, 79), S(72, 72, 72, 72),

        // 展開5 HOOK 11～小節目に使用
        F(83), S(83, 83, 83, 83), S(83, 83, 83, 83), S(83, 83, 83, 83), F(79), S(79, 79, 79, 79), S(79, 79, 79, 79), S(79, 79, 79, 79),

        // 展開6 HOOK 11～小節目に使用
        F(79), S(79, 79, 79, 79), S(79, 79, 79, 79), S(79, 79, 79, 79), F(79), S(79, 79, 79, 79), S(79, 79, 79, 79), S(79, 79, 79, 79),

        // 展開7 HOOK 11～小節目に使用
        F(83), S(83, 83, 83, 83), S(83, 83, 83, 83), S(83, 83, 83, 83), F(86), S(86, 86, 86, 86), S(86, 86, 86, 86), S(86, 86, 86, 86));

    // 展開 #define HOOK3_DEV_LEN 8　変える
    int[HOOK3_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 0, 0, 0, 0, 0), D(1, 2, 1, 3, 4, 5, 6, 7), D(0, 0, 0, 0, 0, 0, 0, 0));
    SEQUENCER(beat, time, HOOK3_BEAT_LEN, HOOK3_DEV_PAT, HOOK3_DEV_LEN, notes, development, chordsaw2)
    return ret;
}

vec2 hookSupersaw4(float beat, float time) {
// 1つの展開のビート数
#define HOOK4_BEAT_LEN 8

// 展開のパターンの種類
#define HOOK4_DEV_PAT 6

// 展開の長さ
#define HOOK4_DEV_LEN 32

    int[HOOK4_BEAT_LEN * NOTE_DIV * HOOK4_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        F(71), S(71, 71, 71, 71), S(71, 71, 71, 71), S(71, 71, 71, 71), F(71), S(71, 71, 71, 71), S(71, 71, 71, 71), S(71, 71, 71, 71),

        // 展開4 HOOK 9～小節目に使用
        F(91), S(91, 91, 91, 91), S(91, 91, 91, 91), S(91, 91, 91, 91), F(91), S(91, 91, 91, 91), S(91, 91, 91, 91), S(84, 84, 84, 84),

        // 展開5 HOOK 11～小節目に使用
        F(95), S(95, 95, 95, 95), S(95, 95, 95, 95), S(95, 95, 95, 95), F(91), S(91, 91, 91, 91), S(91, 91, 91, 91), S(91, 91, 91, 91),

        // 展開6 HOOK 11～小節目に使用
        F(91), S(91, 91, 91, 91), S(91, 91, 91, 91), S(91, 91, 91, 91), F(91), S(91, 91, 91, 91), S(91, 91, 91, 91), S(91, 91, 91, 91),

        // 展開7 HOOK 11～小節目に使用
        F(95), S(95, 95, 95, 95), S(95, 95, 95, 95), S(95, 95, 95, 95), F(98), S(98, 98, 98, 98), S(98, 98, 98, 98), S(98, 98, 98, 98));

    // 展開 #define HOOK4_DEV_LEN 8　変える
    int[HOOK4_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 1, 2, 3, 4, 5), D(0, 0, 0, 0, 0, 0, 0, 0));
    SEQUENCER(beat, time, HOOK4_BEAT_LEN, HOOK4_DEV_PAT, HOOK4_DEV_LEN, notes, development, chordsaw2)
    return ret;
}

vec2 hookSupersaw5(float beat, float time) {
// 1つの展開のビート数
#define HOOK3_BEAT_LEN 8

// 展開のパターンの種類
#define HOOK3_DEV_PAT 8

// 展開の長さ
#define HOOK3_DEV_LEN 32

    int[HOOK3_BEAT_LEN * NOTE_DIV * HOOK3_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        F(69), S(69, 69, 69, 69), S(69, 69, 69, 69), S(69, 69, 69, 69), F(69), S(69, 69, 69, 69), S(69, 69, 69, 69), S(72, 72, 72, 72),

        // 展開2
        F(71), S(71, 71, 71, 71), S(71, 71, 71, 71), S(71, 71, 71, 71), F(83), S(71, 71, 71, 71), S(71, 71, 71, 71), S(71, 71, 71, 71),

        // 展開3 HOOK 7～8小節目に使用
        F(71), S(71, 71, 71, 71), S(71, 71, 71, 71), S(71, 71, 71, 71), F(76), S(76, 76, 76, 76), S(79, 79, 79, 79), S(79, 79, 79, 79),

        // 展開4 HOOK 9～小節目に使用
        F(67), S(67, 67, 67, 67), S(67, 67, 67, 67), S(67, 67, 67, 67), F(67), S(67, 67, 67, 67), S(67, 67, 67, 67), S(60, 60, 60, 60),

        // 展開5 HOOK 11～小節目に使用
        F(71), S(71, 71, 71, 71), S(71, 71, 71, 71), S(71, 71, 71, 71), F(74), S(74, 74, 74, 74), S(74, 74, 74, 74), S(74, 74, 74, 74),

        // 展開6 HOOK 11～小節目に使用
        F(67), S(67, 67, 67, 67), S(67, 67, 67, 67), S(67, 67, 67, 67), F(67), S(67, 67, 67, 67), S(67, 67, 67, 67), S(72, 72, 72, 72),

        // 展開7 HOOK 11～小節目に使用
        F(71), S(71, 71, 71, 71), S(71, 71, 71, 71), S(71, 71, 71, 71), F(74), S(74, 74, 74, 74), S(79, 79, 79, 79), S(79, 79, 79, 79));

    // 展開 #define HOOK3_DEV_LEN 8　変える
    int[HOOK3_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 0, 0, 0, 0, 0), D(1, 2, 1, 3, 4, 5, 6, 7), D(0, 0, 0, 0, 0, 0, 0, 0));
    SEQUENCER(beat, time, HOOK3_BEAT_LEN, HOOK3_DEV_PAT, HOOK3_DEV_LEN, notes, development, leadsub)
    return ret;
}

vec2 hookSupersaw6(float beat, float time) {
// 1つの展開のビート数
#define HOOK3_BEAT_LEN 8

// 展開のパターンの種類
#define HOOK3_DEV_PAT 8

// 展開の長さ
#define HOOK3_DEV_LEN 32

    int[HOOK3_BEAT_LEN * NOTE_DIV * HOOK3_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開
        F(45), S(45, 45, 45, 45), S(45, 45, 45, 45), S(45, 45, 45, 45), F(45), S(45, 45, 45, 45), S(45, 45, 45, 45), S(76, 76, 76, 76),

        // 展開2
        F(59), S(59, 59, 59, 59), S(59, 59, 59, 59), S(59, 59, 59, 59), F(71), S(59, 59, 59, 59), S(59, 59, 59, 59), S(59, 59, 59, 59),

        // 展開3 HOOK 7～8小節目に使用
        F(67), S(67, 67, 67, 67), S(67, 67, 67, 67), S(67, 67, 67, 67), F(67), S(67, 67, 67, 67), S(67, 67, 67, 67), S(67, 67, 67, 67),

        // 展開4 HOOK 9～小節目に使用
        F(79), S(79, 79, 79, 79), S(79, 79, 79, 79), S(79, 79, 79, 79), F(72), S(67, 67, 67, 67), S(67, 67, 67, 67), S(48, 48, 48, 48),

        // 展開5 HOOK 11～小節目に使用
        F(83), S(83, 83, 83, 83), S(84, 84, 84, 84), S(83, 83, 83, 83), F(67), S(67, 67, 67, 67), S(67, 67, 67, 67), S(57, 57, 57, 57),

        // 展開6 HOOK 11～小節目に使用
        F(67), S(67, 67, 67, 67), S(67, 67, 67, 67), S(67, 67, 67, 67), F(67), S(67, 67, 67, 67), S(67, 67, 67, 67), S(76, 76, 76, 76),

        // 展開7 HOOK 11～小節目に使用
        F(67), S(67, 67, 67, 67), S(67, 67, 67, 67), S(67, 67, 67, 67), F(62), S(62, 62, 62, 62), S(62, 62, 62, 62), S(62, 62, 62, 62));

    // 展開 #define HOOK3_DEV_LEN 8　変える
    int[HOOK3_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 0, 0, 0, 0, 0), D(1, 2, 1, 3, 4, 5, 6, 7), D(0, 0, 0, 0, 0, 0, 0, 0));
    SEQUENCER(beat, time, HOOK3_BEAT_LEN, HOOK3_DEV_PAT, HOOK3_DEV_LEN, notes, development, leadsub)
    return ret;
}

vec2 hookSupersaw8(float beat, float time) {
// 1つの展開のビート数
#define HOOK8_BEAT_LEN 8

// 展開のパターンの種類
#define HOOK8_DEV_PAT 3

// 展開の長さ
#define HOOK8_DEV_LEN 32

    int[HOOK8_BEAT_LEN * NOTE_DIV * HOOK8_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        F(74), S(74, 74, 74, 74), S(74, 74, 74, 74), S(74, 74, 74, 74), F(79), S(79, 79, 79, 79), S(79, 79, 79, 79), S(79, 79, 79, 79),

        // 展開2
        O(0), O(0));

    // 展開 #define HOOK3_DEV_LEN 8　変える
    int[HOOK8_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 1, 0, 0, 0, 1), D(0, 0, 0, 0, 0, 0, 0, 0));
    SEQUENCER(beat, time, HOOK8_BEAT_LEN, HOOK8_DEV_PAT, HOOK8_DEV_LEN, notes, development, leadsub)
    return ret;
}

vec2 hookSupersaw7(float beat, float time) {
// 1つの展開のビート数
#define HOOK7_BEAT_LEN 8

// 展開のパターンの種類
#define HOOK7_DEV_PAT 2

// 展開の長さ
#define HOOK7_DEV_LEN 32

    int[HOOK7_BEAT_LEN * NOTE_DIV * HOOK7_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        S(69, 72, 79, 69), S(72, 79, 69, 72), S(79, 69, 72, 79), S(69, 72, 79, 69), S(72, 79, 69, 72), S(79, 69, 72, 79), S(69, 72, 79, 69), S(72, 79, 69, 72));

    // 展開 #define HOOK3_DEV_LEN 8　変える
    int[HOOK7_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 1, 1, 1, 1), D(0, 0, 0, 0, 0, 0, 0, 0), D(1, 1, 1, 1, 1, 1, 1, 1), D(0, 0, 0, 0, 0, 0, 0, 0));
    SEQUENCER(beat, time, HOOK7_BEAT_LEN, HOOK7_DEV_PAT, HOOK7_DEV_LEN, notes, development, arpsaw)
    return ret;
}

vec2 hookSupersaw9(float beat, float time) {
// 1つの展開のビート数
#define HOOK3_BEAT_LEN 8

// 展開のパターンの種類
#define HOOK3_DEV_PAT 8

// 展開の長さ
#define HOOK3_DEV_LEN 32

    int[HOOK3_BEAT_LEN * NOTE_DIV * HOOK3_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        F(69), S(69, 69, 69, 69), S(69, 69, 69, 69), S(69, 69, 69, 69), F(69), S(69, 69, 69, 69), S(69, 69, 69, 69), S(72, 72, 72, 72),

        // 展開2
        F(71), S(71, 71, 71, 71), S(71, 71, 71, 71), S(71, 71, 71, 71), F(83), S(71, 71, 71, 71), S(71, 71, 71, 71), S(71, 71, 71, 71),

        // 展開3 HOOK 7～8小節目に使用
        F(71), S(71, 71, 71, 71), S(71, 71, 71, 71), S(71, 71, 71, 71), F(76), S(76, 76, 76, 76), S(79, 79, 79, 79), S(79, 79, 79, 79),

        // 展開4 HOOK 9～小節目に使用
        F(67), S(67, 67, 67, 67), S(67, 67, 67, 67), S(67, 67, 67, 67), F(62), S(62, 62, 62, 62), S(62, 62, 62, 62), S(60, 60, 60, 60),

        // 展開5 HOOK 11～小節目に使用
        F(71), S(71, 71, 71, 71), S(71, 71, 71, 71), S(71, 71, 71, 71), F(74), S(74, 74, 74, 74), S(74, 74, 74, 74), S(74, 74, 74, 74),

        // 展開6 HOOK 11～小節目に使用
        F(67), S(67, 67, 67, 67), S(67, 67, 67, 67), S(67, 67, 67, 67), F(67), S(67, 67, 67, 67), S(67, 67, 67, 67), S(72, 72, 72, 72),

        // 展開7 HOOK 11～小節目に使用
        F(71), S(71, 71, 71, 71), S(71, 71, 71, 71), S(71, 71, 71, 71), F(74), S(74, 74, 74, 74), S(76, 76, 76, 76), S(76, 76, 76, 76));

    // 展開 #define HOOK3_DEV_LEN 8　変える
    int[HOOK3_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 0, 0, 0, 0, 0), D(1, 2, 1, 3, 4, 5, 6, 7), D(0, 0, 0, 0, 0, 0, 0, 0));
    SEQUENCER(beat, time, HOOK3_BEAT_LEN, HOOK3_DEV_PAT, HOOK3_DEV_LEN, notes, development, leadsub2)
    return ret;
}

vec2 snare2(float beat, float time) {
// 1つの展開のビート数
#define SNARE1_BEAT_LEN 8

// 展開のパターンの種類
#define SNARE1_DEV_PAT 2

// 展開の長さ
#define SNARE1_DEV_LEN 32

    int[SNARE1_BEAT_LEN * NOTE_DIV * SNARE1_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        S(1, 1, 1, 1), S(1, 1, 1, 1), S(1, 1, 1, 1), S(1, 1, 1, 1), S(1, 1, 1, 1), S(1, 1, 1, 1), S(1, 1, 1, 1), S(1, 1, 1, 1));

    // 展開 #define SNARE1_DEV_LEN 8　変える
    int[SNARE1_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 0, 0, 0, 0, 1, 1), D(0, 0, 0, 0, 0, 0, 1, 1), D(0, 0, 0, 0, 0, 0, 0, 0));
    SEQUENCER(beat, time, SNARE1_BEAT_LEN, SNARE1_DEV_PAT, SNARE1_DEV_LEN, notes, development, snarefill)
    return ret;
}

vec2 noisefeed(float beat, float time) {
// 1つの展開のビート数
#define FEED_BEAT_LEN 8

// 展開のパターンの種類
#define FEED_DEV_PAT 3

// 展開の長さ
#define FEED_DEV_LEN 32

    int[FEED_BEAT_LEN * NOTE_DIV * FEED_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1~4
        O(0), F(1), F(1), F(1), F(1),

        // 展開3
        O(1), O(0));

    // 展開 #define SNARE1_DEV_LEN 8　変える
    int[FEED_DEV_LEN / DEV_PACK] development = int[](D(2, 0, 2, 1, 2, 0, 0, 1), D(2, 0, 0, 0, 2, 0, 0, 1), D(2, 0, 0, 0, 2, 0, 0, 1), D(2, 0, 0, 0, 2, 0, 0, 0));
    SEQUENCER(beat, time, FEED_BEAT_LEN, FEED_DEV_PAT, FEED_DEV_LEN, notes, development, noisefeedin)
    return ret;
}

vec2 noisesidechain1(float beat, float time) {
// 1つの展開のビート数
#define NOISESIDE_BEAT_LEN 8

// 展開のパターンの種類
#define NOISESIDE_DEV_PAT 2

// 展開の長さ
#define NOISESIDE_DEV_LEN 32

    int[NOISESIDE_BEAT_LEN * NOTE_DIV * NOISESIDE_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        F(1), F(1), F(1), F(1), F(1), F(1), F(1), F(1));

    // 展開 #define SNARE1_DEV_LEN 8　変える
    int[NOISESIDE_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 1, 1, 1, 1), D(0, 0, 0, 0, 1, 1, 0, 0), D(1, 1, 1, 1, 1, 1, 1, 1), D(0, 0, 0, 0, 0, 0, 0, 0));
    SEQUENCER(beat, time, NOISESIDE_BEAT_LEN, NOISESIDE_DEV_PAT, NOISESIDE_DEV_LEN, notes, development, sidechainnoise)
    return ret;
}

vec2 noisesidechain2(float beat, float time) {
// 1つの展開のビート数 L
#define NOISESIDE_BEAT_LEN 8

// 展開のパターンの種類
#define NOISESIDE_DEV_PAT 2

// 展開の長さ
#define NOISESIDE_DEV_LEN 32

    int[NOISESIDE_BEAT_LEN * NOTE_DIV * NOISESIDE_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        O(1), O(0));

    // 展開 #define SNARE1_DEV_LEN 8　変える
    int[NOISESIDE_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 1, 0, 0, 0), D(1, 0, 0, 0, 0, 0, 0, 0), D(1, 0, 0, 0, 1, 0, 0, 0), D(1, 0, 0, 0, 0, 0, 0, 0));
    SEQUENCER(beat, time, NOISESIDE_BEAT_LEN, NOISESIDE_DEV_PAT, NOISESIDE_DEV_LEN, notes, development, sidechainnoise2)
    return ret;
}

vec2 noisesidechain3(float beat, float time) {
// 1つの展開のビート数 L
#define NOISESIDE_BEAT_LEN 8

// 展開のパターンの種類
#define NOISESIDE_DEV_PAT 2

// 展開の長さ
#define NOISESIDE_DEV_LEN 32

    int[NOISESIDE_BEAT_LEN * NOTE_DIV * NOISESIDE_DEV_PAT] notes = int[](
        // 展開0
        O(0), O(0),

        // 展開1
        O(1), O(0));

    // 展開 #define SNARE1_DEV_LEN 8　変える
    int[NOISESIDE_DEV_LEN / DEV_PACK] development = int[](D(0, 0, 0, 0, 0, 0, 1, 0), D(0, 0, 0, 0, 0, 0, 0, 0), D(0, 0, 1, 0, 0, 0, 1, 0), D(0, 0, 0, 0, 0, 0, 0, 0));
    SEQUENCER(beat, time, NOISESIDE_BEAT_LEN, NOISESIDE_DEV_PAT, NOISESIDE_DEV_LEN, notes, development, sidechainnoise2)
    return ret;
}

vec2 mainSound(float time) {
    //編集用に時間を途中からすすめる
    // time += 0.0;

    float beat = timeToBeat(time);
    vec2 ret = vec2(0.0);

    // Kick
    ret += vec2(0.7) * kick1(beat, time);
    ret += vec2(0.06) * kick2(beat, time);

    // Exf
    ret += vec2(0.5, 0.15) * crashcymbal1(beat, time);
    ret += vec2(0.15, 0.5) * crashcymbal2(beat, time);

    // Arp
    ret += vec2(0.3) * sidechain * subbass1(beat, time);
    ret += vec2(0.1) * sidechain2 * arp0(beat, time);
    ret += vec2(0.35, 0.0) * sidechain2 * arp1(beat, time);
    ret += vec2(0.0, 0.35) * sidechain2 * arp2(beat, time);
    ret += vec2(0.5, 1.0) * sidechain2 * arp3(beat, time);
    ret += vec2(1.0, 0.3) * sidechain2 * arp4(beat, time);
    ret += vec2(0.4) * sidechain * arp5(beat, time);

    // Chord
    ret += vec2(0.7, 0.2) * sidechain2 * chordSupersaw1(beat, time);
    ret += vec2(0.4) * sidechain2 * chordSupersaw2(beat, time);
    ret += vec2(0.3, 0.2) * sidechain2 * chordSupersaw3(beat, time);
    ret += vec2(0.5, 0.6) * sidechain2 * chordSupersaw4(beat, time);
    ret += vec2(0.3) * sidechain2 * chordSupersaw5(beat, time);

    // Noise
    ret += vec2(0.4) * sidechain5 * noisesidechain1(beat, time);
    ret += vec2(0.2, 0.05) * sidechain5 * noisesidechain2(beat, time);
    ret += vec2(0.05, 0.2) * sidechain5 * noisesidechain3(beat, time);

    // Buildup chord
    ret += vec2(0.1, 0.3) * sidechain2 * chordSquare1(beat, time);
    ret += vec2(0.3) * sidechain2 * chordSquare2(beat, time);
    ret += vec2(0.3, 0.1) * sidechain2 * chordSquare3(beat, time);

    // Supersaw
    ret += vec2(0.02, 0.15) * sidechain * introSupersaw1(beat, time);
    ret += vec2(0.2, 0.05) * sidechain2 * introSupersaw2(beat, time);

    // Hook_Supersaw
    ret += vec2(0.3, 0.15) * sidechain * hookSupersaw1(beat, time);
    ret += vec2(0.4) * sidechain * hookSupersaw2(beat, time);
    ret += vec2(0.10, 0.2) * sidechain * hookSupersaw3(beat, time);
    ret += vec2(0.2, 0.05) * sidechain * hookSupersaw4(beat, time);

    // Hook_Voice
    ret += vec2(0.07, 0.13) * sidechain * hookSupersaw5(beat, time);
    ret += vec2(0.03, 0.1) * sidechain * hookSupersaw6(beat, time);
    ret += vec2(0.08, 0.05) * sidechain4 * hookSupersaw7(beat, time);
    ret += vec2(0.1, 0.05) * sidechain4 * hookSupersaw8(beat, time);
    ret += vec2(0.03, 0.02) * sidechain * hookSupersaw9(beat, time);

    // ret = vec2(0.0);

    // ここまでの音をMute

    // Bass
    ret += vec2(0.5) * sidechain4 * bass1(beat, time);
    ret += vec2(0.19, 0.19) * sidechain4 * bass2(beat, time);
    ret += vec2(0.01) * sidechain4 * bass3(beat, time);
    ret += vec2(0.2, 0.15) * sidechain2 * sideSupersaw1(beat, time);
    ret += vec2(0.15, 0.2) * sidechain2 * sideSupersaw2(beat, time);
    ret += vec2(0.05, 0.05) * sidechain4 * tb303synth(beat, time);

    // Hihat
    ret += vec2(0.0, 0.7) * sidechain * thihat1(beat, time);
    ret += vec2(0.3, 0.05) * sidechain * thihat2(beat, time);

    // Snare
    ret += vec2(0.2) * snare1(beat, time);
    ret += vec2(0.1) * snare2(beat, time);
    ret += vec2(0.37, 0.3) * sidechain2 * noisefeed(beat, time);

    return clamp(ret, -1.0, 1.0);
}