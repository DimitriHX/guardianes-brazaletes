shader_type canvas_item;
// Mece con el viento la decoración del suelo (GroundDecor). Solo se mueven los
// vértices de arriba de cada pieza: en la hoja cada fila mide `slot_px` y la
// pieza ocupa la mitad de arriba, así que un vértice superior cae al inicio de
// la fila. El canal rojo del modulate dice si la pieza se mece (1) o no (0).

uniform float sheet_height_px = 96.0;
uniform float slot_px = 32.0;
// Desplazamiento máximo de la punta, en unidades del mundo.
uniform float amplitude = 1.6;
uniform float speed = 1.7;

void vertex() {
	float local_y = mod(UV.y * sheet_height_px + 0.01, slot_px);
	float is_top = 1.0 - step(slot_px * 0.25, local_y);
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float wave = sin(TIME * speed + world.x * 0.07) + 0.4 * sin(TIME * speed * 2.3 + world.x * 0.19);
	VERTEX.x += wave * amplitude * is_top * COLOR.r;
}

void fragment() {
	COLOR = texture(TEXTURE, UV);
}
