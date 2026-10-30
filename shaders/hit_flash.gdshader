shader_type canvas_item;
// Destello de impacto: mezcla el color del sprite con `flash_color` según
// `flash_amount` (0 = sprite normal, 1 = silueta del color). Respeta la alfa.

uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR = vec4(mix(COLOR.rgb, flash_color.rgb, flash_amount), COLOR.a);
}
