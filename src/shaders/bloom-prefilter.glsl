float brightness(vec3 c) {
    return max(max(c.r, c.g), c.b);
}

uniform float gBloomThreshold;// 1.0 0 100
uniform float gBloomSoftKnee;// 0.5 0 4

// https://github.com/Unity-Technologies/PostProcessing/blob/v1/PostProcessing/Runtime/Components/BloomComponent.cs#L78-L109
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float softKnee = 0.5;
    float lthresh = gBloomThreshold;

	vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 color = texture(iPrevPass, uv);
    vec3 m = color.rgb;
    float br = brightness(m);

    float knee = lthresh * softKnee + 1e-5f;
    vec3 curve = vec3(lthresh - knee, knee * 2.0, 0.25 / knee);
    float rq = clamp(br - curve.x, 0.0, curve.y);
    rq = curve.z * rq * rq;

    m *= max(rq, br - lthresh) / max(br, 1e-5);
    fragColor = vec4(m, color.a);
}