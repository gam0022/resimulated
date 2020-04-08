// for Webpack DefinePlugin
declare var PRODUCTION: boolean;
declare var GLOBAL_UNIFORMS: boolean;
declare var PLAY_SOUND_FILE: string;

const PassType = {
    Image: 0 as const,
    FinalImage: 1 as const,
    Bloom: 2 as const,
    BloomUpsample: 3 as const,
    Sound: 4 as const,
}

type PassType = typeof PassType[keyof typeof PassType]

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

    /** 強制描画 */
    needsUpdate: boolean;

    /** 再生時間（秒）です */
    time: number;

    /** レンダリング時に実行されるコールバック関数です */
    onRender: (time: number, timeDelta: number) => void;

    /** 毎フレーム実行されるコールバック関数です */
    onUpdate: () => void;

    canvas: HTMLCanvasElement;
    audioContext: AudioContext;
    audioSource: AudioBufferSourceNode;

    // global uniforms
    uniformArray: { key: string, initValue: any, min?: number, max?: number, group?: string }[];
    uniforms: { [key: string]: any };

    init: () => void;
    render: () => void;
    setSize: (width: number, height: number) => void;
    play: () => void;
    playSound: () => void;
    stopSound: () => void;

    debugFrameNumber: number;

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

        soundShader: string,
        createTextTexture: (gl: WebGL2RenderingContext) => WebGLTexture,
    ) {
        const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

        this.init = async () => {
            this.timeLength = timeLength;
            this.isPlaying = true;
            this.needsUpdate = false;
            this.time = 0;
            this.debugFrameNumber = -1;

            if (GLOBAL_UNIFORMS) {
                this.uniformArray = [];
                this.uniforms = {};
            }

            // setup WebAudio
            const audio = this.audioContext = new window.AudioContext();

            // setup WebGL
            const canvas = this.canvas = document.createElement("canvas");
            canvas.width = window.innerWidth;
            canvas.height = window.innerHeight;
            window.document.body.appendChild(canvas);

            // webgl2 enabled default from: firefox-51, chrome-56
            const gl = canvas.getContext("webgl2", { preserveDrawingBuffer: true });
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

            const textTexture = createTextTexture(gl);

            const imageCommonHeaderShaderLineCount = imageCommonHeaderShader.split("\n").length;

            const loadShader = (src: string, type: number) => {
                const shader = gl.createShader(type);
                gl.shaderSource(shader, src);
                gl.compileShader(shader);
                if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
                    if (PRODUCTION) {
                        const log = gl.getShaderInfoLog(shader);
                        console.log(src, log);
                    } else {
                        if (src.includes("mainSound")) {
                            const log = gl.getShaderInfoLog(shader);
                            console.log(src, log);
                        } else {
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
                    }
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

            const setupFrameBuffer = (pass: Pass) => {
                // FIXME: setupFrameBuffer の呼び出し側でやるべき
                if (pass.type === PassType.FinalImage) {
                    return;
                }

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

            const initPass = (program: WebGLProgram, index: number, type: PassType, scale: number) => {
                setupVAO(program);
                const pass = new Pass();
                pass.program = program;
                pass.index = index;
                pass.type = type;
                pass.scale = scale;

                pass.uniforms = {
                    iResolution: { type: "v3", value: [canvas.width * pass.scale, canvas.height * pass.scale, 0] },
                    iTime: { type: "f", value: 0.0 },
                    iPrevPass: { type: "t", value: Math.max(pass.index - 1, 0) },
                    iBeforeBloom: { type: "t", value: Math.max(bloomPassBeginIndex - 1, 0) },
                    iBlockOffset: { type: "f", value: 0.0 },
                    iSampleRate: { type: "f", value: audio.sampleRate },
                    iTextTexture: { type: "t", value: 0 },
                };

                if (type === PassType.BloomUpsample) {
                    const bloomDonwsampleEndIndex = bloomPassBeginIndex + bloomDonwsampleIterations;
                    const upCount = index - bloomDonwsampleEndIndex;
                    pass.uniforms.iPairBloomDown = { type: "t", value: index - upCount * 2 };
                }

                if (GLOBAL_UNIFORMS) {
                    this.uniformArray.forEach(unifrom => {
                        pass.uniforms[unifrom.key] = { type: typeof unifrom.initValue === "number" ? "f" : "v3", value: unifrom.initValue };
                    })
                }

                pass.locations = createLocations(pass);

                setupFrameBuffer(pass);
                return pass;
            };

            const renderPass = (pass: Pass) => {
                gl.useProgram(pass.program);
                gl.bindFramebuffer(gl.FRAMEBUFFER, pass.frameBuffer);
                gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

                for (const [key, uniform] of Object.entries(pass.uniforms)) {
                    const methods: { [index: string]: any } = {
                        f: gl.uniform1f,
                        // v2: gl.uniform2fv,
                        v3: gl.uniform3fv,
                        // v4: gl.uniform4fv,
                        // t: gl.uniform1i,
                    }

                    const textureUnitIds: { [index: string]: number } = {
                        iPrevPass: 0,
                        iBeforeBloom: 1,
                        iPairBloomDown: 2,
                        iTextTexture: 3,
                    }

                    if (uniform.type === "t") {
                        gl.activeTexture(gl.TEXTURE0 + textureUnitIds[key]);

                        if (key === "iTextTexture") {
                            gl.bindTexture(gl.TEXTURE_2D, textTexture);
                        } else if (!PRODUCTION && this.debugFrameNumber >= 0 && key === "iPrevPass" && pass.type === PassType.FinalImage) {
                            if (this.debugFrameNumber == 30) {
                                gl.bindTexture(gl.TEXTURE_2D, textTexture);
                            } else {
                                const i = Math.min(Math.floor(this.debugFrameNumber), imagePasses.length - 1);
                                gl.bindTexture(gl.TEXTURE_2D, imagePasses[i].texture);
                            }
                        } else {
                            gl.bindTexture(gl.TEXTURE_2D, imagePasses[uniform.value].texture);
                        }

                        // methods[uniform.type].call(gl, pass.locations[key], textureUnitIds[key]);
                        gl.uniform1i(pass.locations[key], textureUnitIds[key]);
                    } else {
                        methods[uniform.type].call(gl, pass.locations[key], uniform.value);
                    }
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

            this.setSize = (width: number, height: number) => {
                const canvas = gl.canvas;
                canvas.width = width;
                canvas.height = height;

                gl.viewport(0, 0, width, height);

                imagePasses.forEach(pass => {
                    gl.deleteFramebuffer(pass.frameBuffer);
                    gl.deleteTexture(pass.texture);
                    pass.uniforms.iResolution.value = [width * pass.scale, height * pass.scale, 0];
                    setupFrameBuffer(pass);
                });
            }

            this.playSound = () => {
                if (!PRODUCTION) {
                    const newAudioSource = this.audioContext.createBufferSource();
                    newAudioSource.buffer = this.audioSource.buffer;
                    newAudioSource.loop = this.audioSource.loop;
                    newAudioSource.connect(this.audioContext.destination);
                    this.audioSource = newAudioSource;
                }

                this.audioSource.start(this.audioContext.currentTime, this.time % this.timeLength);
            }

            if (!PRODUCTION) {
                this.stopSound = () => {
                    this.audioSource.stop();
                }
            }

            const initSound = async () => {
                // Sound
                const sampleLength = Math.ceil(audio.sampleRate * timeLength);
                const audioBuffer = audio.createBuffer(2, sampleLength, audio.sampleRate);
                const samples = SOUND_WIDTH * SOUND_HEIGHT;
                const numBlocks = sampleLength / samples;

                let startTime, endTime;

                if (!PRODUCTION) {
                    startTime = performance.now();
                }

                const soundProgram = loadProgram(soundShader);

                await sleep(100);

                if (!PRODUCTION) {
                    endTime = performance.now();
                    console.log(`compile soundShader: ${endTime - startTime} ms`);
                }

                const soundPass = initPass(soundProgram, 0, PassType.Sound, 1);
                for (let i = 0; i < numBlocks; i++) {
                    // Update uniform & Render
                    soundPass.uniforms.iBlockOffset.value = i * samples / audio.sampleRate;
                    renderPass(soundPass);

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

                if (PLAY_SOUND_FILE) {
                    (async () => {
                        const response = await fetch(PLAY_SOUND_FILE);
                        const arrayBuffer = await response.arrayBuffer();
                        this.audioSource.buffer = await audio.decodeAudioData(arrayBuffer);
                    })();
                } else {
                    this.audioSource.buffer = audioBuffer;
                }

                // this.audioSource.loop = false;
                this.audioSource.connect(audio.destination);
            }

            this.render = () => {
                imagePasses.forEach((pass) => {
                    pass.uniforms.iTime.value = this.time;
                    if (GLOBAL_UNIFORMS) {
                        for (const [key, value] of Object.entries(this.uniforms)) {
                            if (pass.uniforms[key] !== undefined) {
                                if (typeof value === "number") {
                                    pass.uniforms[key].value = value;
                                } else {
                                    // NOTE: for dat.GUI addColor
                                    pass.uniforms[key].value = [value[0] / 255, value[1] / 255, value[2] / 255];
                                }
                            }
                        }
                    }
                    renderPass(pass);
                });
            }

            // Get global uniforms
            if (GLOBAL_UNIFORMS) {
                let currentGroup = "default";
                const getGlobalUniforms = (fragmentShader: string) => {
                    // for Debug dat.GUI
                    let reg = /uniform (float|vec3) (g.+);\s*(\/\/ ([\-\d\.-]+))?( ([\-\d\.]+) ([\-\d\.]+))?( [\w\d]+)?/g;
                    let result: RegExpExecArray;
                    while ((result = reg.exec(fragmentShader)) !== null) {
                        let uniform: { key: string, initValue: any, min?: number, max?: number, group?: string };

                        if (result[1] === "float") {
                            uniform = {
                                key: result[2],
                                initValue: result[4] !== undefined ? parseFloat(result[4]) : 0,
                            };

                            if (!PRODUCTION) {
                                uniform.min = result[6] !== undefined ? parseFloat(result[6]) : 0;
                                uniform.max = result[7] !== undefined ? parseFloat(result[7]) : 1;
                            }
                        } else {
                            uniform = {
                                key: result[2],
                                initValue: [parseFloat(result[4]), parseFloat(result[6]), parseFloat(result[7])],
                            };
                        }

                        if (!PRODUCTION) {
                            if (result[8] !== undefined) {
                                currentGroup = result[8];
                            }

                            uniform.group = currentGroup;
                        }

                        this.uniformArray.push(uniform);
                        this.uniforms[uniform.key] = uniform.initValue;
                    }
                };

                getGlobalUniforms(imageCommonHeaderShader);

                imageShaders.forEach(shader => {
                    getGlobalUniforms(shader);
                });

                getGlobalUniforms(bloomPrefilterShader);
                getGlobalUniforms(bloomDownsampleShader);
                getGlobalUniforms(bloomUpsampleShader);
                getGlobalUniforms(bloomFinalShader);
            }

            // Create Rendering Pipeline
            const imagePasses: Pass[] = [];
            let passIndex = 0;

            const initRenderingPipeline = async () => {
                for (let i = 0; i < imageShaders.length; i++) {
                    const shader = imageShaders[i];
                    if (i === bloomPassBeginIndex) {
                        imagePasses.push(initPass(
                            loadProgram(imageCommonHeaderShader + bloomPrefilterShader),
                            passIndex,
                            PassType.Bloom,
                            1
                        ));
                        passIndex++;

                        let scale = 1;
                        for (let j = 0; j < bloomDonwsampleIterations; j++) {
                            scale *= 0.5;
                            imagePasses.push(initPass(
                                loadProgram(imageCommonHeaderShader + bloomDownsampleShader),
                                passIndex,
                                PassType.Bloom,
                                scale,
                            ));
                            passIndex++;
                        }

                        for (let j = 0; j < bloomDonwsampleIterations - 1; j++) {
                            scale *= 2;
                            imagePasses.push(initPass(
                                loadProgram(imageCommonHeaderShader + bloomUpsampleShader),
                                passIndex,
                                PassType.BloomUpsample,
                                scale,
                            ));
                            passIndex++;
                        }

                        imagePasses.push(initPass(
                            loadProgram(imageCommonHeaderShader + bloomFinalShader),
                            passIndex,
                            PassType.BloomUpsample,
                            1,
                        ));
                        passIndex++;
                    }

                    let startTime, endTime;

                    if (!PRODUCTION) {
                        startTime = performance.now();
                    }

                    imagePasses.push(initPass(
                        loadProgram(imageCommonHeaderShader + shader),
                        passIndex,
                        i < imageShaders.length - 1 ? PassType.Image : PassType.FinalImage,
                        1
                    ));

                    await sleep(100);

                    if (!PRODUCTION) {
                        endTime = performance.now();
                        console.log(`compile imageShader[${i}]: ${endTime - startTime} ms`);
                    }

                    passIndex++;
                }

                // Init Sound
                await initSound();

                // Rendering Loop
                let lastTimestamp = 0;
                let startTimestamp: number | null = null;
                const update = (timestamp: number) => {
                    requestAnimationFrame(update);
                    if (!startTimestamp) {
                        startTimestamp = timestamp;
                    }

                    const timeDelta = (timestamp - lastTimestamp) * 0.001;

                    if (!PRODUCTION) {
                        if (this.onUpdate != null) {
                            this.onUpdate();
                        }
                    }

                    if (this.isPlaying || this.needsUpdate) {
                        if (this.onRender != null) {
                            this.onRender(this.time, timeDelta);
                        }

                        this.render();

                        if (PRODUCTION) {
                            this.time = (timestamp - startTimestamp) * 0.001;
                        } else {
                            if (this.isPlaying) {
                                this.time += timeDelta;
                            }
                        }
                    }

                    this.needsUpdate = false;
                    lastTimestamp = timestamp;
                };

                this.play = () => {
                    requestAnimationFrame(update);
                }
            }
            await initRenderingPipeline();
        }
    }
}