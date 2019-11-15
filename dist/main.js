/******/ (function(modules) { // webpackBootstrap
/******/ 	// The module cache
/******/ 	var installedModules = {};
/******/
/******/ 	// The require function
/******/ 	function __webpack_require__(moduleId) {
/******/
/******/ 		// Check if module is in cache
/******/ 		if(installedModules[moduleId]) {
/******/ 			return installedModules[moduleId].exports;
/******/ 		}
/******/ 		// Create a new module (and put it into the cache)
/******/ 		var module = installedModules[moduleId] = {
/******/ 			i: moduleId,
/******/ 			l: false,
/******/ 			exports: {}
/******/ 		};
/******/
/******/ 		// Execute the module function
/******/ 		modules[moduleId].call(module.exports, module, module.exports, __webpack_require__);
/******/
/******/ 		// Flag the module as loaded
/******/ 		module.l = true;
/******/
/******/ 		// Return the exports of the module
/******/ 		return module.exports;
/******/ 	}
/******/
/******/
/******/ 	// expose the modules object (__webpack_modules__)
/******/ 	__webpack_require__.m = modules;
/******/
/******/ 	// expose the module cache
/******/ 	__webpack_require__.c = installedModules;
/******/
/******/ 	// define getter function for harmony exports
/******/ 	__webpack_require__.d = function(exports, name, getter) {
/******/ 		if(!__webpack_require__.o(exports, name)) {
/******/ 			Object.defineProperty(exports, name, { enumerable: true, get: getter });
/******/ 		}
/******/ 	};
/******/
/******/ 	// define __esModule on exports
/******/ 	__webpack_require__.r = function(exports) {
/******/ 		if(typeof Symbol !== 'undefined' && Symbol.toStringTag) {
/******/ 			Object.defineProperty(exports, Symbol.toStringTag, { value: 'Module' });
/******/ 		}
/******/ 		Object.defineProperty(exports, '__esModule', { value: true });
/******/ 	};
/******/
/******/ 	// create a fake namespace object
/******/ 	// mode & 1: value is a module id, require it
/******/ 	// mode & 2: merge all properties of value into the ns
/******/ 	// mode & 4: return value when already ns object
/******/ 	// mode & 8|1: behave like require
/******/ 	__webpack_require__.t = function(value, mode) {
/******/ 		if(mode & 1) value = __webpack_require__(value);
/******/ 		if(mode & 8) return value;
/******/ 		if((mode & 4) && typeof value === 'object' && value && value.__esModule) return value;
/******/ 		var ns = Object.create(null);
/******/ 		__webpack_require__.r(ns);
/******/ 		Object.defineProperty(ns, 'default', { enumerable: true, value: value });
/******/ 		if(mode & 2 && typeof value != 'string') for(var key in value) __webpack_require__.d(ns, key, function(key) { return value[key]; }.bind(null, key));
/******/ 		return ns;
/******/ 	};
/******/
/******/ 	// getDefaultExport function for compatibility with non-harmony modules
/******/ 	__webpack_require__.n = function(module) {
/******/ 		var getter = module && module.__esModule ?
/******/ 			function getDefault() { return module['default']; } :
/******/ 			function getModuleExports() { return module; };
/******/ 		__webpack_require__.d(getter, 'a', getter);
/******/ 		return getter;
/******/ 	};
/******/
/******/ 	// Object.prototype.hasOwnProperty.call
/******/ 	__webpack_require__.o = function(object, property) { return Object.prototype.hasOwnProperty.call(object, property); };
/******/
/******/ 	// __webpack_public_path__
/******/ 	__webpack_require__.p = "";
/******/
/******/
/******/ 	// Load entry module and return exports
/******/ 	return __webpack_require__(__webpack_require__.s = "./src/index.js");
/******/ })
/************************************************************************/
/******/ ({

/***/ "./src/index.js":
/*!**********************!*\
  !*** ./src/index.js ***!
  \**********************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

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
        fetch("vertex.glsl").then(res => res.text()).then(
            src => loadShader(src, gl.VERTEX_SHADER)),
        fetch("fragment.glsl").then(res => res.text()).then(
            src => loadShader(src, gl.FRAGMENT_SHADER))
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


/***/ })

/******/ });
//# sourceMappingURL=data:application/json;charset=utf-8;base64,eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbIndlYnBhY2s6Ly8vd2VicGFjay9ib290c3RyYXAiLCJ3ZWJwYWNrOi8vLy4vc3JjL2luZGV4LmpzIl0sIm5hbWVzIjpbXSwibWFwcGluZ3MiOiI7UUFBQTtRQUNBOztRQUVBO1FBQ0E7O1FBRUE7UUFDQTtRQUNBO1FBQ0E7UUFDQTtRQUNBO1FBQ0E7UUFDQTtRQUNBO1FBQ0E7O1FBRUE7UUFDQTs7UUFFQTtRQUNBOztRQUVBO1FBQ0E7UUFDQTs7O1FBR0E7UUFDQTs7UUFFQTtRQUNBOztRQUVBO1FBQ0E7UUFDQTtRQUNBLDBDQUEwQyxnQ0FBZ0M7UUFDMUU7UUFDQTs7UUFFQTtRQUNBO1FBQ0E7UUFDQSx3REFBd0Qsa0JBQWtCO1FBQzFFO1FBQ0EsaURBQWlELGNBQWM7UUFDL0Q7O1FBRUE7UUFDQTtRQUNBO1FBQ0E7UUFDQTtRQUNBO1FBQ0E7UUFDQTtRQUNBO1FBQ0E7UUFDQTtRQUNBLHlDQUF5QyxpQ0FBaUM7UUFDMUUsZ0hBQWdILG1CQUFtQixFQUFFO1FBQ3JJO1FBQ0E7O1FBRUE7UUFDQTtRQUNBO1FBQ0EsMkJBQTJCLDBCQUEwQixFQUFFO1FBQ3ZELGlDQUFpQyxlQUFlO1FBQ2hEO1FBQ0E7UUFDQTs7UUFFQTtRQUNBLHNEQUFzRCwrREFBK0Q7O1FBRXJIO1FBQ0E7OztRQUdBO1FBQ0E7Ozs7Ozs7Ozs7Ozs7QUNsRmE7O0FBRWI7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTs7QUFFQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBLHNEQUFzRDtBQUN0RDtBQUNBO0FBQ0E7OztBQUdBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQSxLQUFLOztBQUVMO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0EsOERBQThEO0FBQzlEO0FBQ0E7O0FBRUE7QUFDQTtBQUNBLDZEQUE2RDtBQUM3RDtBQUNBOztBQUVBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBLGFBQWE7QUFDYixTQUFTO0FBQ1Q7O0FBRUE7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBOztBQUVBO0FBQ0EsQ0FBQyIsImZpbGUiOiJtYWluLmpzIiwic291cmNlc0NvbnRlbnQiOlsiIFx0Ly8gVGhlIG1vZHVsZSBjYWNoZVxuIFx0dmFyIGluc3RhbGxlZE1vZHVsZXMgPSB7fTtcblxuIFx0Ly8gVGhlIHJlcXVpcmUgZnVuY3Rpb25cbiBcdGZ1bmN0aW9uIF9fd2VicGFja19yZXF1aXJlX18obW9kdWxlSWQpIHtcblxuIFx0XHQvLyBDaGVjayBpZiBtb2R1bGUgaXMgaW4gY2FjaGVcbiBcdFx0aWYoaW5zdGFsbGVkTW9kdWxlc1ttb2R1bGVJZF0pIHtcbiBcdFx0XHRyZXR1cm4gaW5zdGFsbGVkTW9kdWxlc1ttb2R1bGVJZF0uZXhwb3J0cztcbiBcdFx0fVxuIFx0XHQvLyBDcmVhdGUgYSBuZXcgbW9kdWxlIChhbmQgcHV0IGl0IGludG8gdGhlIGNhY2hlKVxuIFx0XHR2YXIgbW9kdWxlID0gaW5zdGFsbGVkTW9kdWxlc1ttb2R1bGVJZF0gPSB7XG4gXHRcdFx0aTogbW9kdWxlSWQsXG4gXHRcdFx0bDogZmFsc2UsXG4gXHRcdFx0ZXhwb3J0czoge31cbiBcdFx0fTtcblxuIFx0XHQvLyBFeGVjdXRlIHRoZSBtb2R1bGUgZnVuY3Rpb25cbiBcdFx0bW9kdWxlc1ttb2R1bGVJZF0uY2FsbChtb2R1bGUuZXhwb3J0cywgbW9kdWxlLCBtb2R1bGUuZXhwb3J0cywgX193ZWJwYWNrX3JlcXVpcmVfXyk7XG5cbiBcdFx0Ly8gRmxhZyB0aGUgbW9kdWxlIGFzIGxvYWRlZFxuIFx0XHRtb2R1bGUubCA9IHRydWU7XG5cbiBcdFx0Ly8gUmV0dXJuIHRoZSBleHBvcnRzIG9mIHRoZSBtb2R1bGVcbiBcdFx0cmV0dXJuIG1vZHVsZS5leHBvcnRzO1xuIFx0fVxuXG5cbiBcdC8vIGV4cG9zZSB0aGUgbW9kdWxlcyBvYmplY3QgKF9fd2VicGFja19tb2R1bGVzX18pXG4gXHRfX3dlYnBhY2tfcmVxdWlyZV9fLm0gPSBtb2R1bGVzO1xuXG4gXHQvLyBleHBvc2UgdGhlIG1vZHVsZSBjYWNoZVxuIFx0X193ZWJwYWNrX3JlcXVpcmVfXy5jID0gaW5zdGFsbGVkTW9kdWxlcztcblxuIFx0Ly8gZGVmaW5lIGdldHRlciBmdW5jdGlvbiBmb3IgaGFybW9ueSBleHBvcnRzXG4gXHRfX3dlYnBhY2tfcmVxdWlyZV9fLmQgPSBmdW5jdGlvbihleHBvcnRzLCBuYW1lLCBnZXR0ZXIpIHtcbiBcdFx0aWYoIV9fd2VicGFja19yZXF1aXJlX18ubyhleHBvcnRzLCBuYW1lKSkge1xuIFx0XHRcdE9iamVjdC5kZWZpbmVQcm9wZXJ0eShleHBvcnRzLCBuYW1lLCB7IGVudW1lcmFibGU6IHRydWUsIGdldDogZ2V0dGVyIH0pO1xuIFx0XHR9XG4gXHR9O1xuXG4gXHQvLyBkZWZpbmUgX19lc01vZHVsZSBvbiBleHBvcnRzXG4gXHRfX3dlYnBhY2tfcmVxdWlyZV9fLnIgPSBmdW5jdGlvbihleHBvcnRzKSB7XG4gXHRcdGlmKHR5cGVvZiBTeW1ib2wgIT09ICd1bmRlZmluZWQnICYmIFN5bWJvbC50b1N0cmluZ1RhZykge1xuIFx0XHRcdE9iamVjdC5kZWZpbmVQcm9wZXJ0eShleHBvcnRzLCBTeW1ib2wudG9TdHJpbmdUYWcsIHsgdmFsdWU6ICdNb2R1bGUnIH0pO1xuIFx0XHR9XG4gXHRcdE9iamVjdC5kZWZpbmVQcm9wZXJ0eShleHBvcnRzLCAnX19lc01vZHVsZScsIHsgdmFsdWU6IHRydWUgfSk7XG4gXHR9O1xuXG4gXHQvLyBjcmVhdGUgYSBmYWtlIG5hbWVzcGFjZSBvYmplY3RcbiBcdC8vIG1vZGUgJiAxOiB2YWx1ZSBpcyBhIG1vZHVsZSBpZCwgcmVxdWlyZSBpdFxuIFx0Ly8gbW9kZSAmIDI6IG1lcmdlIGFsbCBwcm9wZXJ0aWVzIG9mIHZhbHVlIGludG8gdGhlIG5zXG4gXHQvLyBtb2RlICYgNDogcmV0dXJuIHZhbHVlIHdoZW4gYWxyZWFkeSBucyBvYmplY3RcbiBcdC8vIG1vZGUgJiA4fDE6IGJlaGF2ZSBsaWtlIHJlcXVpcmVcbiBcdF9fd2VicGFja19yZXF1aXJlX18udCA9IGZ1bmN0aW9uKHZhbHVlLCBtb2RlKSB7XG4gXHRcdGlmKG1vZGUgJiAxKSB2YWx1ZSA9IF9fd2VicGFja19yZXF1aXJlX18odmFsdWUpO1xuIFx0XHRpZihtb2RlICYgOCkgcmV0dXJuIHZhbHVlO1xuIFx0XHRpZigobW9kZSAmIDQpICYmIHR5cGVvZiB2YWx1ZSA9PT0gJ29iamVjdCcgJiYgdmFsdWUgJiYgdmFsdWUuX19lc01vZHVsZSkgcmV0dXJuIHZhbHVlO1xuIFx0XHR2YXIgbnMgPSBPYmplY3QuY3JlYXRlKG51bGwpO1xuIFx0XHRfX3dlYnBhY2tfcmVxdWlyZV9fLnIobnMpO1xuIFx0XHRPYmplY3QuZGVmaW5lUHJvcGVydHkobnMsICdkZWZhdWx0JywgeyBlbnVtZXJhYmxlOiB0cnVlLCB2YWx1ZTogdmFsdWUgfSk7XG4gXHRcdGlmKG1vZGUgJiAyICYmIHR5cGVvZiB2YWx1ZSAhPSAnc3RyaW5nJykgZm9yKHZhciBrZXkgaW4gdmFsdWUpIF9fd2VicGFja19yZXF1aXJlX18uZChucywga2V5LCBmdW5jdGlvbihrZXkpIHsgcmV0dXJuIHZhbHVlW2tleV07IH0uYmluZChudWxsLCBrZXkpKTtcbiBcdFx0cmV0dXJuIG5zO1xuIFx0fTtcblxuIFx0Ly8gZ2V0RGVmYXVsdEV4cG9ydCBmdW5jdGlvbiBmb3IgY29tcGF0aWJpbGl0eSB3aXRoIG5vbi1oYXJtb255IG1vZHVsZXNcbiBcdF9fd2VicGFja19yZXF1aXJlX18ubiA9IGZ1bmN0aW9uKG1vZHVsZSkge1xuIFx0XHR2YXIgZ2V0dGVyID0gbW9kdWxlICYmIG1vZHVsZS5fX2VzTW9kdWxlID9cbiBcdFx0XHRmdW5jdGlvbiBnZXREZWZhdWx0KCkgeyByZXR1cm4gbW9kdWxlWydkZWZhdWx0J107IH0gOlxuIFx0XHRcdGZ1bmN0aW9uIGdldE1vZHVsZUV4cG9ydHMoKSB7IHJldHVybiBtb2R1bGU7IH07XG4gXHRcdF9fd2VicGFja19yZXF1aXJlX18uZChnZXR0ZXIsICdhJywgZ2V0dGVyKTtcbiBcdFx0cmV0dXJuIGdldHRlcjtcbiBcdH07XG5cbiBcdC8vIE9iamVjdC5wcm90b3R5cGUuaGFzT3duUHJvcGVydHkuY2FsbFxuIFx0X193ZWJwYWNrX3JlcXVpcmVfXy5vID0gZnVuY3Rpb24ob2JqZWN0LCBwcm9wZXJ0eSkgeyByZXR1cm4gT2JqZWN0LnByb3RvdHlwZS5oYXNPd25Qcm9wZXJ0eS5jYWxsKG9iamVjdCwgcHJvcGVydHkpOyB9O1xuXG4gXHQvLyBfX3dlYnBhY2tfcHVibGljX3BhdGhfX1xuIFx0X193ZWJwYWNrX3JlcXVpcmVfXy5wID0gXCJcIjtcblxuXG4gXHQvLyBMb2FkIGVudHJ5IG1vZHVsZSBhbmQgcmV0dXJuIGV4cG9ydHNcbiBcdHJldHVybiBfX3dlYnBhY2tfcmVxdWlyZV9fKF9fd2VicGFja19yZXF1aXJlX18ucyA9IFwiLi9zcmMvaW5kZXguanNcIik7XG4iLCJcInVzZSBzdHJpY3RcIjtcblxud2luZG93LmFkZEV2ZW50TGlzdGVuZXIoXCJsb2FkXCIsIGV2ID0+IHtcbiAgICAvLyB3ZWJnbCBzZXR1cFxuICAgIGNvbnN0IGNhbnZhcyA9IGRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoXCJjYW52YXNcIik7XG4gICAgY2FudmFzLndpZHRoID0gNTEyLCBjYW52YXMuaGVpZ2h0ID0gNTEyO1xuICAgIGNhbnZhcy5zdHlsZS5ib3JkZXIgPSBcInNvbGlkXCI7XG4gICAgZG9jdW1lbnQuYm9keS5hcHBlbmRDaGlsZChjYW52YXMpO1xuICAgIC8vIHdlYmdsMiBlbmFibGVkIGRlZmF1bHQgZnJvbTogZmlyZWZveC01MSwgY2hyb21lLTU2XG4gICAgY29uc3QgZ2wgPSBjYW52YXMuZ2V0Q29udGV4dChcIndlYmdsMlwiKTtcbiAgICBnbC5lbmFibGUoZ2wuQ1VMTF9GQUNFKTtcblxuICAgIC8vIGRyYXdpbmcgZGF0YSAoYXMgdmlld3BvcnQgc3F1YXJlKVxuICAgIGNvbnN0IHZlcnQyZCA9IFtbMSwgMV0sIFstMSwgMV0sIFsxLCAtMV0sIFstMSwgLTFdXTtcbiAgICBjb25zdCB2ZXJ0MmREYXRhID0gbmV3IEZsb2F0MzJBcnJheShbXS5jb25jYXQoLi4udmVydDJkKSk7XG4gICAgY29uc3QgdmVydEJ1ZiA9IGdsLmNyZWF0ZUJ1ZmZlcigpO1xuICAgIGdsLmJpbmRCdWZmZXIoZ2wuQVJSQVlfQlVGRkVSLCB2ZXJ0QnVmKTtcbiAgICBnbC5idWZmZXJEYXRhKGdsLkFSUkFZX0JVRkZFUiwgdmVydDJkRGF0YSwgZ2wuU1RBVElDX0RSQVcpO1xuICAgIGdsLmJpbmRCdWZmZXIoZ2wuQVJSQVlfQlVGRkVSLCBudWxsKTtcblxuICAgIGNvbnN0IGluZGV4ID0gW1swLCAxLCAyXSwgWzMsIDIsIDFdXTtcbiAgICBjb25zdCBpbmRleERhdGEgPSBuZXcgVWludDE2QXJyYXkoW10uY29uY2F0KC4uLmluZGV4KSk7XG4gICAgY29uc3QgaW5kZXhCdWYgPSBnbC5jcmVhdGVCdWZmZXIoKTtcbiAgICBnbC5iaW5kQnVmZmVyKGdsLkVMRU1FTlRfQVJSQVlfQlVGRkVSLCBpbmRleEJ1Zik7XG4gICAgZ2wuYnVmZmVyRGF0YShnbC5FTEVNRU5UX0FSUkFZX0JVRkZFUiwgaW5kZXhEYXRhLCBnbC5TVEFUSUNfRFJBVyk7XG4gICAgZ2wuYmluZEJ1ZmZlcihnbC5FTEVNRU5UX0FSUkFZX0JVRkZFUiwgbnVsbCk7XG5cbiAgICAvLyBvcGVuZ2wzIHVuaWZvcm0gYnVmZmVyXG4gICAgLy8gTk9URTogZWFjaCBkYXRhIGF0dHJpYnV0ZSByZXF1aXJlZCAxNiBieXRlXG4gICAgY29uc3Qgc2NyZWVuRGF0YSA9IG5ldyBGbG9hdDMyQXJyYXkoW2NhbnZhcy53aWR0aCwgY2FudmFzLmhlaWdodCwgMCwgMF0pO1xuICAgIGNvbnN0IHNjcmVlbkJ1ZiA9IGdsLmNyZWF0ZUJ1ZmZlcigpO1xuICAgIGdsLmJpbmRCdWZmZXIoZ2wuVU5JRk9STV9CVUZGRVIsIHNjcmVlbkJ1Zik7XG4gICAgZ2wuYnVmZmVyRGF0YShnbC5VTklGT1JNX0JVRkZFUiwgc2NyZWVuRGF0YSwgZ2wuRFlOQU1JQ19EUkFXKTtcbiAgICBnbC5iaW5kQnVmZmVyKGdsLlVOSUZPUk1fQlVGRkVSLCBudWxsKTtcblxuICAgIGNvbnN0IHRpbWVyRGF0YSA9IG5ldyBVaW50MzJBcnJheShbMCwgMCwgMCwgMF0pO1xuICAgIGNvbnN0IHRpbWVyQnVmID0gZ2wuY3JlYXRlQnVmZmVyKCk7XG4gICAgZ2wuYmluZEJ1ZmZlcihnbC5VTklGT1JNX0JVRkZFUiwgdGltZXJCdWYpO1xuICAgIGdsLmJ1ZmZlckRhdGEoZ2wuVU5JRk9STV9CVUZGRVIsIHRpbWVyRGF0YSwgZ2wuRFlOQU1JQ19EUkFXKTtcbiAgICBnbC5iaW5kQnVmZmVyKGdsLlVOSUZPUk1fQlVGRkVSLCBudWxsKTtcbiAgICBcbiAgICAvLyBvcGVuZ2wzIFZBT1xuICAgIGNvbnN0IHZlcnRleEFycmF5ID0gZ2wuY3JlYXRlVmVydGV4QXJyYXkoKTtcbiAgICBjb25zdCBzZXR1cFZBTyA9IChwcm9ncmFtKSA9PiB7XG4gICAgICAgIC8vIHNldHVwIGJ1ZmZlcnMgYW5kIGF0dHJpYnV0ZXMgdG8gdGhlIFZBT1xuICAgICAgICBnbC5iaW5kVmVydGV4QXJyYXkodmVydGV4QXJyYXkpO1xuICAgICAgICAvLyBiaW5kIGJ1ZmZlciBkYXRhXG4gICAgICAgIGdsLmJpbmRCdWZmZXIoZ2wuQVJSQVlfQlVGRkVSLCB2ZXJ0QnVmKTtcbiAgICAgICAgZ2wuYmluZEJ1ZmZlcihnbC5FTEVNRU5UX0FSUkFZX0JVRkZFUiwgaW5kZXhCdWYpO1xuXG4gICAgICAgIC8vIHNldCBhdHRyaWJ1dGUgdHlwZXNcbiAgICAgICAgY29uc3QgdmVydDJkSWQgPSBnbC5nZXRBdHRyaWJMb2NhdGlvbihwcm9ncmFtLCBcInZlcnQyZFwiKTtcbiAgICAgICAgY29uc3QgZWxlbSA9IGdsLkZMT0FULCBjb3VudCA9IHZlcnQyZFswXS5sZW5ndGgsIG5vcm1hbGl6ZSA9IGZhbHNlO1xuICAgICAgICBjb25zdCBvZmZzZXQgPSAwLCBzdHJpZGUgPSBjb3VudCAqIEZsb2F0MzJBcnJheS5CWVRFU19QRVJfRUxFTUVOVDtcbiAgICAgICAgZ2wuZW5hYmxlVmVydGV4QXR0cmliQXJyYXkodmVydDJkSWQpO1xuICAgICAgICBnbC52ZXJ0ZXhBdHRyaWJQb2ludGVyKFxuICAgICAgICAgICAgdmVydDJkSWQsIGNvdW50LCBlbGVtLCBub3JtYWxpemUsIHN0cmlkZSwgb2Zmc2V0KTtcbiAgICAgICAgZ2wuYmluZFZlcnRleEFycmF5KG51bGwpO1xuICAgICAgICAvL05PVEU6IHRoZXNlIHVuYm91bmQgYnVmZmVycyBpcyBub3QgcmVxdWlyZWQ7IHdvcmtzIGZpbmUgaWYgdW5ib3VuZFxuICAgICAgICAvL2dsLmJpbmRCdWZmZXIoZ2wuQVJSQVlfQlVGRkVSLCBudWxsKTtcbiAgICAgICAgLy9nbC5iaW5kQnVmZmVyKGdsLkVMRU1FTlRfQVJSQVlfQlVGRkVSLCBudWxsKTtcbiAgICB9O1xuICAgIFxuICAgIFxuICAgIC8vIHNoYWRlciBsb2FkZXJcbiAgICBjb25zdCBsb2FkU2hhZGVyID0gKHNyYywgdHlwZSkgPT4ge1xuICAgICAgICBjb25zdCBzaGFkZXIgPSBnbC5jcmVhdGVTaGFkZXIodHlwZSk7XG4gICAgICAgIGdsLnNoYWRlclNvdXJjZShzaGFkZXIsIHNyYyk7XG4gICAgICAgIGdsLmNvbXBpbGVTaGFkZXIoc2hhZGVyKTtcbiAgICAgICAgaWYgKCFnbC5nZXRTaGFkZXJQYXJhbWV0ZXIoc2hhZGVyLCBnbC5DT01QSUxFX1NUQVRVUykpIHtcbiAgICAgICAgICAgIGNvbnNvbGUubG9nKHNyYywgZ2wuZ2V0U2hhZGVySW5mb0xvZyhzaGFkZXIpKTtcbiAgICAgICAgfVxuICAgICAgICByZXR1cm4gc2hhZGVyO1xuICAgIH07XG4gICAgY29uc3QgbG9hZFByb2dyYW0gPSAoKSA9PiBQcm9taXNlLmFsbChbXG4gICAgICAgIGZldGNoKFwidmVydGV4Lmdsc2xcIikudGhlbihyZXMgPT4gcmVzLnRleHQoKSkudGhlbihcbiAgICAgICAgICAgIHNyYyA9PiBsb2FkU2hhZGVyKHNyYywgZ2wuVkVSVEVYX1NIQURFUikpLFxuICAgICAgICBmZXRjaChcImZyYWdtZW50Lmdsc2xcIikudGhlbihyZXMgPT4gcmVzLnRleHQoKSkudGhlbihcbiAgICAgICAgICAgIHNyYyA9PiBsb2FkU2hhZGVyKHNyYywgZ2wuRlJBR01FTlRfU0hBREVSKSlcbiAgICBdKS50aGVuKHNoYWRlcnMgPT4ge1xuICAgICAgICBjb25zdCBwcm9ncmFtID0gZ2wuY3JlYXRlUHJvZ3JhbSgpO1xuICAgICAgICBzaGFkZXJzLmZvckVhY2goc2hhZGVyID0+IGdsLmF0dGFjaFNoYWRlcihwcm9ncmFtLCBzaGFkZXIpKTtcbiAgICAgICAgZ2wubGlua1Byb2dyYW0ocHJvZ3JhbSk7XG4gICAgICAgIGlmICghZ2wuZ2V0UHJvZ3JhbVBhcmFtZXRlcihwcm9ncmFtLCBnbC5MSU5LX1NUQVRVUykpIHtcbiAgICAgICAgICAgIGNvbnNvbGUubG9nKGdsLmdldFByb2dyYW1JbmZvTG9nKHByb2dyYW0pKTtcbiAgICAgICAgfTtcbiAgICAgICAgcmV0dXJuIHByb2dyYW07XG4gICAgfSk7XG5cbiAgICAvLyBpbml0aWFsaXplIGRhdGEgdmFyaWFibGVzIGZvciB0aGUgc2hhZGVyIHByb2dyYW1cbiAgICBjb25zdCBpbml0VmFyaWFibGVzID0gKHByb2dyYW0pID0+IHtcbiAgICAgICAgc2V0dXBWQU8ocHJvZ3JhbSk7XG4gICAgICAgIHJldHVybiBwcm9ncmFtO1xuICAgIH07XG5cbiAgICBjb25zdCByZW5kZXIgPSAocHJvZ3JhbSwgY291bnQpID0+IHtcbiAgICAgICAgLy8gc2V0IHRpbWVyIHZhcmlhYmxlIHRvIHVwZGF0ZSB0aGUgdW5pZm9ybSBidWZmZXJcbiAgICAgICAgdGltZXJEYXRhWzBdID0gY291bnQ7XG4gICAgICAgIGdsLmJpbmRCdWZmZXIoZ2wuVU5JRk9STV9CVUZGRVIsIHRpbWVyQnVmKTtcbiAgICAgICAgZ2wuYnVmZmVyRGF0YShnbC5VTklGT1JNX0JVRkZFUiwgdGltZXJEYXRhLCBnbC5EWU5BTUlDX0RSQVcpO1xuICAgICAgICBnbC5iaW5kQnVmZmVyKGdsLlVOSUZPUk1fQlVGRkVSLCBudWxsKTtcblxuICAgICAgICAvLyB1bmlmb3JtIGJ1ZmZlciBiaW5kaW5nXG4gICAgICAgIGxldCB1bmlmb3JtSW5kZXggPSAwO1xuICAgICAgICBjb25zdCBzY3JlZW5JZCA9IGdsLmdldFVuaWZvcm1CbG9ja0luZGV4KHByb2dyYW0sIFwiU2NyZWVuXCIpO1xuICAgICAgICAvL2NvbnNvbGUubG9nKFwic2NyZWVuIHVuaWZvcm0gc2l6ZVwiLCBnbC5nZXRBY3RpdmVVbmlmb3JtQmxvY2tQYXJhbWV0ZXIoXG4gICAgICAgIC8vICAgIHByb2dyYW0sIHNjcmVlbklkLCBnbC5VTklGT1JNX0JMT0NLX0RBVEFfU0laRSkpOyAvLz0+IDR4ND0xNlxuICAgICAgICBnbC51bmlmb3JtQmxvY2tCaW5kaW5nKHByb2dyYW0sIHNjcmVlbklkLCArK3VuaWZvcm1JbmRleCk7XG4gICAgICAgIGdsLmJpbmRCdWZmZXJCYXNlKGdsLlVOSUZPUk1fQlVGRkVSLCB1bmlmb3JtSW5kZXgsIHNjcmVlbkJ1Zik7XG5cbiAgICAgICAgY29uc3QgdGltZXJJZCA9IGdsLmdldFVuaWZvcm1CbG9ja0luZGV4KHByb2dyYW0sIFwiVGltZXJcIik7XG4gICAgICAgIC8vY29uc29sZS5sb2coXCJ0aW1lciB1bmlmb3JtIHNpemVcIiwgZ2wuZ2V0QWN0aXZlVW5pZm9ybUJsb2NrUGFyYW1ldGVyKFxuICAgICAgICAvLyAgICBwcm9ncmFtLCB0aW1lcklkLCBnbC5VTklGT1JNX0JMT0NLX0RBVEFfU0laRSkpOyAvLz0+IDR4ND0xNlxuICAgICAgICBnbC51bmlmb3JtQmxvY2tCaW5kaW5nKHByb2dyYW0sIHRpbWVySWQsICsrdW5pZm9ybUluZGV4KTtcbiAgICAgICAgZ2wuYmluZEJ1ZmZlckJhc2UoZ2wuVU5JRk9STV9CVUZGRVIsIHVuaWZvcm1JbmRleCwgdGltZXJCdWYpO1xuICAgICAgICBcbiAgICAgICAgZ2wuY2xlYXIoZ2wuQ09MT1JfQlVGRkVSX0JJVCB8IGdsLkRFUFRIX0JVRkZFUl9CSVQpO1xuICAgICAgICBnbC51c2VQcm9ncmFtKHByb2dyYW0pO1xuICAgICAgICAvLyBkcmF3IHRoZSBidWZmZXIgd2l0aCBWQU9cbiAgICAgICAgLy8gTk9URTogYmluZGluZyB2ZXJ0IGFuZCBpbmRleCBidWZmZXIgaXMgbm90IHJlcXVpcmVkXG4gICAgICAgIGdsLmJpbmRWZXJ0ZXhBcnJheSh2ZXJ0ZXhBcnJheSk7XG4gICAgICAgIGNvbnN0IGluZGV4T2Zmc2V0ID0gMCAqIGluZGV4WzBdLmxlbmd0aDtcbiAgICAgICAgZ2wuZHJhd0VsZW1lbnRzKGdsLlRSSUFOR0xFUywgaW5kZXhEYXRhLmxlbmd0aCxcbiAgICAgICAgICAgICAgICAgICAgICAgIGdsLlVOU0lHTkVEX1NIT1JULCBpbmRleE9mZnNldCk7XG4gICAgICAgIGNvbnN0IGVycm9yID0gZ2wuZ2V0RXJyb3IoKTtcbiAgICAgICAgaWYgKGVycm9yICE9PSBnbC5OT19FUlJPUikgY29uc29sZS5sb2coZXJyb3IpO1xuICAgICAgICBnbC5iaW5kVmVydGV4QXJyYXkobnVsbCk7XG4gICAgICAgIGdsLnVzZVByb2dyYW0obnVsbCk7XG4gICAgfTtcbiAgICBjb25zdCBzdGFydFJlbmRlcmluZyA9IChwcm9ncmFtKSA9PiB7XG4gICAgICAgIChmdW5jdGlvbiBsb29wKGNvdW50KSB7XG4gICAgICAgICAgICByZXF1ZXN0QW5pbWF0aW9uRnJhbWUoKCkgPT4ge1xuICAgICAgICAgICAgICAgIHJlbmRlcihwcm9ncmFtLCBjb3VudCk7XG4gICAgICAgICAgICAgICAgc2V0VGltZW91dChsb29wLCAzMCwgKGNvdW50ICsgMSkgJiAweDdmZmZmZmZmKTtcbiAgICAgICAgICAgIH0pO1xuICAgICAgICB9KSgwKTtcbiAgICB9O1xuXG4gICAgLy8gKG5vdCB1c2VkIGJlY2F1c2Ugb2YgaXQgcnVucyBmb3JldmVyKVxuICAgIGNvbnN0IGNsZWFudXBSZXNvdXJjZXMgPSAocHJvZ3JhbSkgPT4ge1xuICAgICAgICBnbC5kZWxldGVCdWZmZXIodmVydEJ1Zik7XG4gICAgICAgIGdsLmRlbGV0ZUJ1ZmZlcihpbmRleEJ1Zik7XG4gICAgICAgIGdsLmRlbGV0ZUJ1ZmZlcihzY3JlZW5CdWYpO1xuICAgICAgICBnbC5kZWxldGVCdWZmZXIodGltZXJCdWYpO1xuICAgICAgICBnbC5kZWxldGVWZXJ0ZXhBcnJheSh2ZXJ0ZXhBcnJheSk7XG4gICAgICAgIGdsLmRlbGV0ZVByb2dyYW0ocHJvZ3JhbSk7XG4gICAgfTtcbiAgICBcbiAgICBsb2FkUHJvZ3JhbSgpLnRoZW4oaW5pdFZhcmlhYmxlcykudGhlbihzdGFydFJlbmRlcmluZyk7XG59LCBmYWxzZSk7XG4iXSwic291cmNlUm9vdCI6IiJ9