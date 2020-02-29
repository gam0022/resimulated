export const mix = (x: number, y: number, a: number) => x * (1 - a) + y * a;
export const clamp = (x: number, min: number, max: number) => x < min ? min : x > max ? max : x;
export const saturate = (x: number) => clamp(x, 0, 1);