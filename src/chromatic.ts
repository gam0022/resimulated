// for Webpack DefinePlugin
declare var PRODUCTION: boolean;

enum PassType {
    Image,
    FinalImage,
    Bloom,
    BloomUpsample,
    Sound,
}

class Pass {
    type: PassType;
    index: number;
    program: WebGLProgram;
    uniforms: { [index: string]: { type: string, value: any } };
    locations: { [index: string]: WebGLUniformLocation };
    frameBuffer: WebGLFramebuffer;
    texture: WebGLTexture;
    scale: number;
}

const SOUND_WIDTH = 512;
const SOUND_HEIGHT = 512;

export class Chromatic {
    /** 再生時間の長さです */
    timeLength: number;

    /** 再生中かどうかのフラグです */
    isPlaying: boolean;

    /** 再生時間（秒）です */
    time: number;

    /** レンダリング時に実行されるコールバック関数です */
    onRender: (time: number, timeDelta: number) => void;

    gl: WebGL2RenderingContext;
    audioContext: AudioContext;
    audioSource: AudioBufferSourceNode;

    imagePasses: Pass[];

    constructor(
        timeLength: number,
        vertexShader: string,
        imageCommonHeaderShader: string,
        imageShaders: string[],

        bloomPassBeginIndex: number,
        bloomDonwsampleIterations: number,
        bloomPrefilterShader: string,
        bloomDownsampleShader: string,
        bloomUpsampleShader: string,
        bloomFinalShader: string,

        soundShader: string
    ) {
        this.timeLength = timeLength;
        this.isPlaying = true;
        this.time = 0;

        // setup WebAudio
        const audio = this.audioContext = new window.AudioContext();

        // setup WebGL
        const canvas = document.createElement("canvas");
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
        window.document.body.appendChild(canvas);

        // webgl2 enabled default from: firefox-51, chrome-56
        const gl = this.gl = canvas.getContext("webgl2");
        if (!gl) {
            console.log("WebGL 2 is not supported...");
            return;
        }

        const ext = gl.getExtension("EXT_color_buffer_float");
        if (!ext) {
            alert("need EXT_color_buffer_float");
            return;
        }

        const ext2 = gl.getExtension("OES_texture_float_linear");
        if (!ext2) {
            alert("need OES_texture_float_linear");
            return;
        }

        gl.enable(gl.CULL_FACE);

        // drawing data (as viewport square)
        const vert2d = [[1, 1], [-1, 1], [1, -1], [-1, -1]];
        const vert2dData = new Float32Array([].concat(...vert2d));
        const vertBuf = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, vertBuf);
        gl.bufferData(gl.ARRAY_BUFFER, vert2dData, gl.STATIC_DRAW);
        gl.bindBuffer(gl.ARRAY_BUFFER, null);

        const index = [[0, 1, 2], [3, 2, 1]];
        const indexData = new Uint16Array([].concat(...index));
        const indexBuf = gl.createBuffer();
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, indexBuf);
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indexData, gl.STATIC_DRAW);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, null);

        // opengl3 VAO
        const vertexArray = gl.createVertexArray();
        const setupVAO = (program: WebGLProgram) => {
            // setup buffers and attributes to the VAO
            gl.bindVertexArray(vertexArray);
            // bind buffer data
            gl.bindBuffer(gl.ARRAY_BUFFER, vertBuf);
            gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, indexBuf);

            // set attribute types
            const vert2dId = gl.getAttribLocation(program, "vert2d");
            const elem = gl.FLOAT, count = vert2d[0].length, normalize = false;
            const offset = 0, stride = count * Float32Array.BYTES_PER_ELEMENT;
            gl.enableVertexAttribArray(vert2dId);
            gl.vertexAttribPointer(vert2dId, count, elem, normalize, stride, offset);
            gl.bindVertexArray(null);
            //NOTE: these unbound buffers is not required; works fine if unbound
            //gl.bindBuffer(gl.ARRAY_BUFFER, null);
            //gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, null);
        };

        const imageCommonHeaderShaderLineCount = imageCommonHeaderShader.split("\n").length;

        // shader loader
        const loadShader = (src: string, type: number) => {
            const shader = gl.createShader(type);
            gl.shaderSource(shader, src);
            gl.compileShader(shader);
            if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
                const log = gl.getShaderInfoLog(shader).replace(/(\d+):(\d+)/g, (match: string, p1: string, p2: string) => {
                    const line = parseInt(p2);
                    if (line <= imageCommonHeaderShaderLineCount) {
                        return `${p1}:${line} (common header)`;
                    } else {
                        return `${p1}:${line - imageCommonHeaderShaderLineCount}`;
                    }
                });
                console.log(src, log);
            }
            return shader;
        };

        const loadProgram = (fragmentShader: string) => {
            const shaders = [
                loadShader(vertexShader, gl.VERTEX_SHADER),
                loadShader(fragmentShader, gl.FRAGMENT_SHADER)
            ];
            const program = gl.createProgram();
            shaders.forEach(shader => gl.attachShader(program, shader));
            gl.linkProgram(program);
            if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
                console.log(gl.getProgramInfoLog(program));
            };
            return program;
        };

        const createLocations = (pass: Pass) => {
            const locations: { [index: string]: WebGLUniformLocation } = {};
            Object.keys(pass.uniforms).forEach(key => {
                locations[key] = gl.getUniformLocation(pass.program, key);
            });
            return locations;
        };

        const initPass = (program: WebGLProgram, index: number, type: PassType, scale: number) => {
            setupVAO(program);
            const pass = new Pass();
            pass.type = type;
            pass.index = index;
            pass.scale = scale;
            pass.program = program;

            pass.uniforms = {
                iResolution: { type: "v3", value: [canvas.width * pass.scale, canvas.height * pass.scale, 0] },
                iTime: { type: "f", value: 0.0 },
                iPrevPass: { type: "t", value: Math.max(pass.index - 1, 0) },
                iBeforeBloom: { type: "t", value: Math.max(bloomPassBeginIndex - 1, 0) },
                iBlockOffset: { type: "f", value: 0.0 },
                iSampleRate: { type: "f", value: audio.sampleRate },
            };

            this.imagePasses.forEach((_, i) => {
                pass.uniforms[`iPass${i}`] = { type: "t", value: i };
            });

            if (type === PassType.BloomUpsample) {
                const bloomDonwsampleEndIndex = bloomPassBeginIndex + bloomDonwsampleIterations;
                const upCount = index - bloomDonwsampleEndIndex;
                pass.uniforms.iPairBloomDown = { type: "t", value: index - upCount * 2 };
            }

            pass.locations = createLocations(pass);

            this.setupFrameBuffer(pass);
            return pass;
        };

        const render = (pass: Pass) => {
            gl.useProgram(pass.program);
            gl.bindFramebuffer(gl.FRAMEBUFFER, pass.frameBuffer);
            gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

            for (const [key, uniform] of Object.entries(pass.uniforms)) {
                if (uniform.type === "t" && key.indexOf("iPass") === 0) {
                    gl.activeTexture(gl.TEXTURE0 + uniform.value);
                    gl.bindTexture(gl.TEXTURE_2D, this.imagePasses[uniform.value].texture);
                }

                const methods: { [index: string]: any } = {
                    f: gl.uniform1f,
                    // v2: gl.uniform2fv,
                    v3: gl.uniform3fv,
                    // v4: gl.uniform4fv,
                    t: gl.uniform1i,
                }

                methods[uniform.type].call(gl, pass.locations[key], uniform.value);
            }

            // draw the buffer with VAO
            // NOTE: binding vert and index buffer is not required
            gl.bindVertexArray(vertexArray);
            const indexOffset = 0 * index[0].length;
            gl.drawElements(gl.TRIANGLES, indexData.length, gl.UNSIGNED_SHORT, indexOffset);
            const error = gl.getError();
            if (error !== gl.NO_ERROR) console.log(error);
            gl.bindVertexArray(null);
            gl.useProgram(null);
        };

        this.imagePasses = [];
        let passIndex = 0;
        imageShaders.forEach((shader, i, ary) => {
            if (i === bloomPassBeginIndex) {
                this.imagePasses.push(initPass(
                    loadProgram(imageCommonHeaderShader + bloomPrefilterShader),
                    passIndex,
                    PassType.Bloom,
                    1
                ));
                passIndex++;

                let scale = 1;
                for (let j = 0; j < bloomDonwsampleIterations; j++) {
                    scale *= 0.5;
                    this.imagePasses.push(initPass(
                        loadProgram(imageCommonHeaderShader + bloomDownsampleShader),
                        passIndex,
                        PassType.Bloom,
                        scale,
                    ));
                    passIndex++;
                }

                for (let j = 0; j < bloomDonwsampleIterations - 1; j++) {
                    scale *= 2;
                    this.imagePasses.push(initPass(
                        loadProgram(imageCommonHeaderShader + bloomUpsampleShader),
                        passIndex,
                        PassType.BloomUpsample,
                        scale,
                    ));
                    passIndex++;
                }

                this.imagePasses.push(initPass(
                    loadProgram(imageCommonHeaderShader + bloomFinalShader),
                    passIndex,
                    PassType.BloomUpsample,
                    1,
                ));
                passIndex++;
            }

            this.imagePasses.push(initPass(
                loadProgram(imageCommonHeaderShader + shader),
                passIndex,
                i < ary.length - 1 ? PassType.Image : PassType.FinalImage,
                1
            ));

            passIndex++;
        })

        // Sound
        const audioBuffer = audio.createBuffer(2, audio.sampleRate * timeLength, audio.sampleRate);
        const samples = SOUND_WIDTH * SOUND_HEIGHT;
        const numBlocks = (audio.sampleRate * timeLength) / samples;
        const soundProgram = loadProgram(soundShader);
        const soundPass = initPass(soundProgram, 0, PassType.Sound, 1);
        for (let i = 0; i < numBlocks; i++) {
            // Update uniform & Render
            soundPass.uniforms.iBlockOffset.value = i * samples / audio.sampleRate;
            render(soundPass);

            // Read pixels
            const pixels = new Uint8Array(SOUND_WIDTH * SOUND_HEIGHT * 4);
            gl.readPixels(0, 0, SOUND_WIDTH, SOUND_HEIGHT, gl.RGBA, gl.UNSIGNED_BYTE, pixels);

            // Convert pixels to samples
            const outputDataL = audioBuffer.getChannelData(0);
            const outputDataR = audioBuffer.getChannelData(1);
            for (let j = 0; j < samples; j++) {
                outputDataL[i * samples + j] = (pixels[j * 4 + 0] + 256 * pixels[j * 4 + 1]) / 65535 * 2 - 1;
                outputDataR[i * samples + j] = (pixels[j * 4 + 2] + 256 * pixels[j * 4 + 3]) / 65535 * 2 - 1;
            }
        }

        this.audioSource = audio.createBufferSource();
        this.audioSource.buffer = audioBuffer;
        this.audioSource.loop = true;
        this.audioSource.connect(audio.destination);

        // Start Rendering
        let lastTimestamp = 0;
        let lastRenderTime = 0;
        const update = (timestamp: number) => {
            requestAnimationFrame(update);
            const timeDelta = (timestamp - lastTimestamp) * 0.001;

            if (this.isPlaying || lastRenderTime !== this.time) {
                if (!PRODUCTION) {
                    if (this.onRender != null) {
                        this.onRender(this.time, timeDelta);
                    }
                }

                this.imagePasses.forEach((pass) => {
                    pass.uniforms.iTime.value = this.time;
                    render(pass);
                });

                this.time += timeDelta;
                lastRenderTime = this.time;
            }

            lastTimestamp = timestamp;
        };
        update(0);
    }

    setupFrameBuffer(pass: Pass) {
        // FIXME: setupFrameBuffer の呼び出し側でやるべき
        if (pass.type === PassType.FinalImage) {
            return;
        }

        const gl = this.gl;

        let width = pass.uniforms.iResolution.value[0];
        let height = pass.uniforms.iResolution.value[1];
        let type = gl.FLOAT;
        let format = gl.RGBA32F;
        let filter = gl.LINEAR;

        if (pass.type === PassType.Sound) {
            width = SOUND_WIDTH;
            height = SOUND_HEIGHT;
            type = gl.UNSIGNED_BYTE;
            format = gl.RGBA;
            filter = gl.NEAREST;
        }

        // フレームバッファの生成
        pass.frameBuffer = gl.createFramebuffer();

        // フレームバッファをWebGLにバインド
        gl.bindFramebuffer(gl.FRAMEBUFFER, pass.frameBuffer);

        // フレームバッファ用テクスチャの生成
        pass.texture = gl.createTexture();

        // フレームバッファ用のテクスチャをバインド
        gl.bindTexture(gl.TEXTURE_2D, pass.texture);

        // フレームバッファ用のテクスチャにカラー用のメモリ領域を確保
        gl.texImage2D(gl.TEXTURE_2D, 0, format, width, height, 0, gl.RGBA, type, null);

        // テクスチャパラメータ
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, filter);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, filter);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

        // フレームバッファにテクスチャを関連付ける
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, pass.texture, 0);

        // 各種オブジェクトのバインドを解除
        gl.bindTexture(gl.TEXTURE_2D, null);
        gl.bindRenderbuffer(gl.RENDERBUFFER, null);
        gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    }

    setSize(width: number, height: number) {
        if (!PRODUCTION) {
            const canvas = this.gl.canvas;
            canvas.width = width;
            canvas.height = height;

            this.gl.viewport(0, 0, width, height);

            this.imagePasses.forEach(pass => {
                this.gl.deleteFramebuffer(pass.frameBuffer);
                this.gl.deleteTexture(pass.texture);
                pass.uniforms.iResolution.value = [width * pass.scale, height * pass.scale, 0];
                this.setupFrameBuffer(pass);
            });
        }
    }

    stopSound() {
        this.audioSource.stop();
    }

    playSound() {
        const newAudioSource = this.audioContext.createBufferSource();
        newAudioSource.buffer = this.audioSource.buffer;
        newAudioSource.loop = this.audioSource.loop;
        newAudioSource.connect(this.audioContext.destination);
        this.audioSource = newAudioSource;

        this.audioSource.start(this.audioContext.currentTime, this.time % this.timeLength);
    }
}