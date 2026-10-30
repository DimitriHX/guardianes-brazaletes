shader_type canvas_item;
// Niebla del menú: dos capas de ruido que se deslizan en horizontal a distinta
// velocidad (parallax) sobre la franja del lago, desvanecidas arriba y abajo.

uniform vec4 mist_color : source_color = vec4(0.78, 0.66, 0.95, 1.0);
uniform float strength = 0.22;
uniform float speed = 0.012;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.6 + noise(p * 2.1) * 0.3 + noise(p * 4.3) * 0.1;
}

void fragment() {
	vec2 p = UV * vec2(3.0, 6.0);
	float far = fbm(p + vec2(TIME * speed, 0.0));
	float near = fbm(p * 1.6 + vec2(TIME * speed * 2.6, 3.7));
	float band = smoothstep(0.0, 0.35, UV.y) * smoothstep(1.0, 0.6, UV.y);
	float m = (smoothstep(0.45, 0.85, far) * 0.6 + smoothstep(0.5, 0.9, near) * 0.5) * band;
	COLOR = vec4(mist_color.rgb, m * strength);
}
