class ShaderPlayer {
    constructor() {
        // webgl setup
        const canvas = document.createElement("canvas");
        canvas.width = 512, canvas.height = 512;
        canvas.style.border = "solid";
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

        const uniforms: {[index: string]:any} = {
            iResolution: {
                type: 'vec3',
                value: [512, 512, 0],
            },
            iTime: {
                type: 'float',
                value: 0,
            },
            iTimeDelta: {
                type: 'float',
                value: 0,
            },
            iFrame: {
                type: 'int',
                value: 0,
            },
            iMouse: {
                type: 'vec4',
                value: [0, 0, 0, 0],
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

        const loadProgram = () => Promise.all([
            /*fetch("vertex.glsl").then(res => res.text()).then(
                src => loadShader(src, gl.VERTEX_SHADER)),
            fetch("fragment.glsl").then(res => res.text()).then(
                src => loadShader(src, gl.FRAGMENT_SHADER))*/
            loadShader(require("./vertex.glsl").default, gl.VERTEX_SHADER),
            loadShader(require("./fragment.glsl").default, gl.FRAGMENT_SHADER)
        ]).then(shaders => {
            const program = gl.createProgram();
            shaders.forEach(shader => gl.attachShader(program, shader));
            gl.linkProgram(program);
            if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
                console.log(gl.getProgramInfoLog(program));
            };
            return program;
        });

        // initialize data variables for the shader program
        const initVariables = (program: WebGLProgram) => {
            setupVAO(program);
            setupUniforms(program);
            return program;
        };

        const render = (program: WebGLProgram, timestamp: number, lastTimestamp: number) => {
            gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
            gl.useProgram(program);

            uniforms.iTime.value = timestamp * 0.001;
            uniforms.iTimeDelta.value = (timestamp - lastTimestamp) * 0.001;
            uniforms.iFrame.value++;

            Object.keys(uniforms).forEach((key) => {
                //const t = uniforms[key].type;
                //const method = t.match(/vec/) ? `${t[t.length - 1]}fv` : `1${t[0]}`;
                //gl[`uniform${method}`](uniforms[key].location, uniforms[key].value);
                switch(uniforms[key].type) {
                    case "float":
                        gl.uniform1f(uniforms[key].location, uniforms[key].value);
                        break;

                    case "vec2":
                        gl.uniform2fv(uniforms[key].location, uniforms[key].value);
                        break;

                    case "vec3":
                        gl.uniform3fv(uniforms[key].location, uniforms[key].value);
                        break;
                    
                    case "vec4":
                        gl.uniform4fv(uniforms[key].location, uniforms[key].value);
                        break;

                    case "int":
                        gl.uniform1i(uniforms[key].location, uniforms[key].value);
                        break;
                }
            });

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

        const startRendering = (program: WebGLProgram) => {
            let lastTimestamp = 0;
            const update = (timestamp: number) => {
                render(program, timestamp, lastTimestamp);
                requestAnimationFrame(update);
                lastTimestamp = timestamp;
            };
            update(0);
        };

        // (not used because of it runs forever)
        const cleanupResources = (program: WebGLProgram) => {
            gl.deleteBuffer(vertBuf);
            gl.deleteBuffer(indexBuf);
            gl.deleteVertexArray(vertexArray);
            gl.deleteProgram(program);
        };

        loadProgram().then(initVariables).then(startRendering);
    }
}

window.addEventListener("load", ev => {
    const player = new ShaderPlayer();
}, false);