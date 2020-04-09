export const mix = (x: number, y: number, a: number) => x * (1 - a) + y * a;
export const clamp = (x: number, min: number, max: number) => x < min ? min : x > max ? max : x;
export const clamp2 = (x: number, min: number, max: number) => min < max ? clamp(x, min, max) : clamp(x, max, min);
export const saturate = (x: number) => clamp(x, 0, 1);

// Hologram Boxes by kaneta: https://www.shadertoy.com/view/3tX3R4
export const remap = (x: number, im: number, ix: number, om: number, ox: number) => clamp2(om + (x - im) * (ox - om) / (ix - im), om, ox);
export const remapFrom = (x: number, min: number, max: number) => remap(x, min, max, 0, 1);
export const remapTo = (x: number, min: number, max: number) => remap(x, 0, 1, min, max);

// Noise
export const fbm = (x: number, t: number) => Math.sin(x + t) + 0.5 * Math.sin(2.0 * x + t) + 0.25 * Math.sin(4.0 * x + t);

// https://gist.github.com/gre/1650294
export const easeInOutCubic = (t: number) => t < .5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1;
export const easeInOutCubicVelocity = (t: number) => t < .5 ? 12 * t * t : 12 * (t - 1) * (t - 1);
export const easeInOutCos = (t: number) => 0.5 - 0.5 * Math.cos(Math.PI * t);

export class Vector3 {
    constructor(
        public x: number,
        public y: number,
        public z: number
    ) {
    }

    add(other: Vector3) {
        return new Vector3(this.x + other.x, this.y + other.y, this.z + other.z);
    }

    mul(other: Vector3) {
        return new Vector3(this.x * other.x, this.y * other.y, this.z * other.z);
    }

    scale(scale: number) {
        return new Vector3(this.x * scale, this.y * scale, this.z * scale);
    }

    static mix(v1: Vector3, v2: Vector3, a: number) {
        return new Vector3(mix(v1.x, v2.x, a), mix(v1.y, v2.y, a), mix(v1.z, v2.z, a));
    }

    static fbm(t: number) {
        return new Vector3(fbm(11431, t), fbm(23123, t), fbm(87034, t));
    }
}