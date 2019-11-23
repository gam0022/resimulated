export class ShaderPlayer {
    /** 再生中かどうかのフラグです */
    isPlaying: boolean;

    /** 再生時間（秒）です */
    time: number;

    /** レンダリング時に実行されるコールバック関数です */
    onRender: (time: number) => void;

    constructor(vertexShader: string, mainImageShader: string, bufferShaders: string[]) {
        this.isPlaying = true;
        this.time = 0;

        // webgl setup
        const canvas = document.createElement("canvas");
        canvas.width = 512, canvas.height = 512;
        window.document.body.appendChild(canvas);

        // webgl2 enabled default from: firefox-51, chrome-56
        const gl = canvas.getContext("webgl2");
        if (!gl) {
            console.log("WebGL 2 is not supported...");
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

        const uniforms: { [index: string]: any } = {
            iResolution: {
                type: 'vec3',
                value: [512, 512, 0],
            },
            iTime: {
                type: 'float',
                value: 0,
            },
        };

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

        const setupUniforms = (program: WebGLProgram) => {
            Object.keys(uniforms).forEach((key, i) => {
                uniforms[key].location = gl.getUniformLocation(program, key);
            });
        };

        // shader loader
        const loadShader = (src: string, type: number) => {
            const shader = gl.createShader(type);
            gl.shaderSource(shader, src);
            gl.compileShader(shader);
            if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
                console.log(src, gl.getShaderInfoLog(shader));
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

        const createFrameBuffer = (width: number, height: number) => {
            // フレームバッファの生成
            var frameBuffer = gl.createFramebuffer();

            // フレームバッファをWebGLにバインド
            gl.bindFramebuffer(gl.FRAMEBUFFER, frameBuffer);

            // フレームバッファ用テクスチャの生成
            var fTexture = gl.createTexture();

            // フレームバッファ用のテクスチャをバインド
            gl.bindTexture(gl.TEXTURE_2D, fTexture);

            // フレームバッファ用のテクスチャにカラー用のメモリ領域を確保
            gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);

            // テクスチャパラメータ
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

            // フレームバッファにテクスチャを関連付ける
            gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, fTexture, 0);

            // 各種オブジェクトのバインドを解除
            gl.bindTexture(gl.TEXTURE_2D, null);
            gl.bindRenderbuffer(gl.RENDERBUFFER, null);
            gl.bindFramebuffer(gl.FRAMEBUFFER, null);

            // オブジェクトを返して終了
            return { f: frameBuffer, t: fTexture };
        }
        const frameBuffer = createFrameBuffer(canvas.width, canvas.height);

        // initialize data variables for the shader program
        const initVariables = (program: WebGLProgram) => {
            setupVAO(program);
            setupUniforms(program);
            return program;
        };

        const render = (program: WebGLProgram) => {
            gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
            gl.useProgram(program);

            uniforms.iTime.value = this.time;

            for (const [key, uniform] of Object.entries(uniforms)) {
                const methods: { [index: string]: any } = {
                    float: gl.uniform1f,
                    //vec2: gl.uniform2fv,
                    vec3: gl.uniform3fv,
                    //vec4: gl.uniform4fv,
                    //int: gl.uniform1i,
                }
                methods[uniform.type].call(gl, uniform.location, uniform.value);
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

        const mainProgram = initVariables(loadProgram(mainImageShader));
        //const buffersPrograms = bufferShaders.map((shader) => initVariables(loadProgram(shader)));
        let lastTimestamp = 0;
        let lastRenderTime = 0;
        const update = (timestamp: number) => {
            requestAnimationFrame(update);
            const timeDelta = (timestamp - lastTimestamp) * 0.001;

            if (this.isPlaying || lastRenderTime !== this.time) {
                if (this.onRender != null) {
                    this.onRender(this.time);
                }

                //buffersPrograms.forEach((program) => render(program));
                render(mainProgram);

                this.time += timeDelta;
                lastRenderTime = this.time;
            }

            lastTimestamp = timestamp;
        };
        update(0);
    }
}