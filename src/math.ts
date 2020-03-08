export const mix = (x: number, y: number, a: number) => x * (1 - a) + y * a;
export const clamp = (x: number, min: number, max: number) => x < min ? min : x > max ? max : x;
export const saturate = (x: number) => clamp(x, 0, 1);

export class Vector3 {
    constructor(
        public x: number,
        public y: number,
        public z: number
    ) {
    }

    static lerp(v1: Vector3, v2: Vector3, a: number) {
        return new Vector3(mix(v1.x, v2.x, a), mix(v1.y, v2.y, a), mix(v1.z, v2.z, a));
    }
}