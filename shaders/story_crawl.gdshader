shader_type canvas_item;
// Deforma la textura (el texto de la historia dibujado en un SubViewport) como
// un plano inclinado que se aleja: estrecho arriba, ancho abajo, con mapeo
// vertical en perspectiva correcta y fundido al fondo.

// Ancho relativo del borde superior (1.0 = sin perspectiva).
uniform float top_width : hint_range(0.05, 1.0) = 0.28;
// Fracción superior de la pantalla en la que el texto se desvanece.
uniform float fade_height : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	float y = UV.y;
	float row_scale = mix(top_width, 1.0, y);
	float u = 0.5 + (UV.x - 0.5) / row_scale;
	// Interpolación con corrección de perspectiva entre arriba (lejos) y abajo (cerca).
	float v = y / ((1.0 - y) * top_width + y);
	if (u < 0.0 || u > 1.0) {
		COLOR = vec4(0.0);
	} else {
		vec4 c = texture(TEXTURE, vec2(u, v));
		c.a *= smoothstep(0.0, fade_height, y);
		COLOR = c;
	}
}
