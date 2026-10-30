shader_type canvas_item;
// Título del menú: el relleno de las letras recorre un degradado de colores que
// fluye en diagonal, con un destello que barre el texto cada pocos segundos, y
// todo el texto flota arriba y abajo. El contorno (cualquier color que no sea
// blanco) se dibuja tal cual: el Label debe tener font_color blanco.

uniform sampler2D palette : source_color, repeat_enable;
// Vueltas del degradado por segundo y px por vuelta.
uniform float flow_speed = 0.12;
uniform float flow_scale = 1100.0;
uniform float float_amplitude = 8.0;
uniform float float_speed = 1.6;
uniform float shine_period = 4.5;
uniform float shine_width = 90.0;

varying vec4 v_color;
varying vec2 v_pos;

void vertex() {
	v_color = COLOR;
	v_pos = VERTEX;
	VERTEX.y += sin(TIME * float_speed) * float_amplitude;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 base = tex * v_color;
	bool is_fill = min(v_color.r, min(v_color.g, v_color.b)) > 0.95;
	if (is_fill) {
		float t = (v_pos.x + v_pos.y * 0.6) / flow_scale - TIME * flow_speed;
		vec3 col = texture(palette, vec2(fract(t), 0.5)).rgb;
		// Destello: banda diagonal que cruza el título y luego descansa.
		float sweep = mod(TIME, shine_period) / shine_period * 3.0 - 0.5;
		float band = v_pos.x - v_pos.y * 0.5 - sweep * 1400.0;
		float shine = 1.0 - smoothstep(0.0, shine_width, abs(band));
		col = mix(col, vec3(1.0), shine * 0.75);
		base.rgb = col * tex.rgb;
	}
	COLOR = base;
}
