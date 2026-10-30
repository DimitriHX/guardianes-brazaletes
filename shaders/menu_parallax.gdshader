shader_type canvas_item;
// Fondo del menú con parallax en una sola imagen: la imagen se amplía un poco y
// se desplaza despacio en un vaivén; cada píxel se mueve más cuanto más "cerca"
// está. La cercanía se estima por posición: el cielo del centro está lejos, y
// el suelo de abajo y los árboles de los lados, cerca. Los cambios de
// profundidad son suaves, así que la imagen no se deforma de forma visible.
// `pointer` (-1..1) lo envía MainMenu para que el fondo siga un poco al ratón.

uniform float zoom = 1.07;
uniform vec2 drift_amount = vec2(0.016, 0.006);
uniform float drift_speed = 0.12;
uniform vec2 pointer = vec2(0.0);
uniform float pointer_amount = 0.012;

float nearness(vec2 uv) {
	float ground = smoothstep(0.55, 1.0, uv.y);
	float sides = smoothstep(0.32, 0.0, uv.x) + smoothstep(0.68, 1.0, uv.x);
	return clamp(max(ground, sides * 0.9), 0.0, 1.0);
}

void fragment() {
	vec2 uv = (UV - 0.5) / zoom + 0.5;
	float depth = 0.25 + 0.75 * nearness(uv);
	vec2 drift = vec2(sin(TIME * drift_speed), sin(TIME * drift_speed * 0.7 + 1.3)) * drift_amount;
	uv += (drift + pointer * pointer_amount) * depth;
	COLOR = texture(TEXTURE, clamp(uv, vec2(0.001), vec2(0.999)));
}
