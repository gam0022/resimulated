"use strict";

window.addEventListener("load", ev => {
    // webgl setup
    const canvas = document.createElement("canvas");
    canvas.width = 512, canvas.height = 512;
    canvas.style.border = "solid";
    document.body.appendChild(canvas);
    // webgl2 enabled default from: firefox-51, chrome-56
    const gl = canvas.getContext("webgl2");
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

    // opengl3 uniform buffer
    // NOTE: each data attribute required 16 byte
    const screenData = new Float32Array([canvas.width, canvas.height, 0, 0]);
    const screenBuf = gl.createBuffer();
    gl.bindBuffer(gl.UNIFORM_BUFFER, screenBuf);
    gl.bufferData(gl.UNIFORM_BUFFER, screenData, gl.DYNAMIC_DRAW);
    gl.bindBuffer(gl.UNIFORM_BUFFER, null);

    const timerData = new Uint32Array([0, 0, 0, 0]);
    const timerBuf = gl.createBuffer();
    gl.bindBuffer(gl.UNIFORM_BUFFER, timerBuf);
    gl.bufferData(gl.UNIFORM_BUFFER, timerData, gl.DYNAMIC_DRAW);
    gl.bindBuffer(gl.UNIFORM_BUFFER, null);
    
    // opengl3 VAO
    const vertexArray = gl.createVertexArray();
    const setupVAO = (program) => {
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
        gl.vertexAttribPointer(
            vert2dId, count, elem, normalize, stride, offset);
        gl.bindVertexArray(null);
        //NOTE: these unbound buffers is not required; works fine if unbound
        //gl.bindBuffer(gl.ARRAY_BUFFER, null);
        //gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, null);
    };
    
    
    // shader loader
    const loadShader = (src, type) => {
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
    const initVariables = (program) => {
        setupVAO(program);
        return program;
    };

    const render = (program, count) => {
        // set timer variable to update the uniform buffer
        timerData[0] = count;
        gl.bindBuffer(gl.UNIFORM_BUFFER, timerBuf);
        gl.bufferData(gl.UNIFORM_BUFFER, timerData, gl.DYNAMIC_DRAW);
        gl.bindBuffer(gl.UNIFORM_BUFFER, null);

        // uniform buffer binding
        let uniformIndex = 0;
        const screenId = gl.getUniformBlockIndex(program, "Screen");
        //console.log("screen uniform size", gl.getActiveUniformBlockParameter(
        //    program, screenId, gl.UNIFORM_BLOCK_DATA_SIZE)); //=> 4x4=16
        gl.uniformBlockBinding(program, screenId, ++uniformIndex);
        gl.bindBufferBase(gl.UNIFORM_BUFFER, uniformIndex, screenBuf);

        const timerId = gl.getUniformBlockIndex(program, "Timer");
        //console.log("timer uniform size", gl.getActiveUniformBlockParameter(
        //    program, timerId, gl.UNIFORM_BLOCK_DATA_SIZE)); //=> 4x4=16
        gl.uniformBlockBinding(program, timerId, ++uniformIndex);
        gl.bindBufferBase(gl.UNIFORM_BUFFER, uniformIndex, timerBuf);
        
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        gl.useProgram(program);
        // draw the buffer with VAO
        // NOTE: binding vert and index buffer is not required
        gl.bindVertexArray(vertexArray);
        const indexOffset = 0 * index[0].length;
        gl.drawElements(gl.TRIANGLES, indexData.length,
                        gl.UNSIGNED_SHORT, indexOffset);
        const error = gl.getError();
        if (error !== gl.NO_ERROR) console.log(error);
        gl.bindVertexArray(null);
        gl.useProgram(null);
    };
    const startRendering = (program) => {
        (function loop(count) {
            requestAnimationFrame(() => {
                render(program, count);
                setTimeout(loop, 30, (count + 1) & 0x7fffffff);
            });
        })(0);
    };

    // (not used because of it runs forever)
    const cleanupResources = (program) => {
        gl.deleteBuffer(vertBuf);
        gl.deleteBuffer(indexBuf);
        gl.deleteBuffer(screenBuf);
        gl.deleteBuffer(timerBuf);
        gl.deleteVertexArray(vertexArray);
        gl.deleteProgram(program);
    };
    
    loadProgram().then(initVariables).then(startRendering);
}, false);
