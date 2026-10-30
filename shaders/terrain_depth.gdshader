shader_type canvas_item;
// Profundidad del terreno: la tierra de la hoja de tiles (casi negra) se tiñe
// con el color de la estación cerca de la superficie y se oscurece al bajar,
// con manchas sutiles para que no se vea plana. La hierba/hielo de arriba
// apenas cambia.
// Profundidad en celdas desde la superficie:
// - TerrainRenderer la pasa en el canal rojo del modulate (celdas / max_depth)
//   y el shader suma la posición dentro del tile para que el degradado sea continuo.
// - Con depth_from_vertex_y (plataformas sueltas de PlatformSkinner) sale de la
//   altura local del vértice, en píxeles de la hoja.

uniform vec3 soil_top : source_color = vec3(0.30, 0.20, 0.12);
uniform vec3 soil_deep : source_color = vec3(0.06, 0.04, 0.05);
// Cuánto se amplifica el detalle (piedras, grietas) de la hoja sobre el tinte.
uniform float detail_gain = 3.0;
// Celdas hasta llegar al color profundo.
uniform float fade_cells = 7.0;
// Oscurecimiento máximo en lo más hondo (1 = nada).
uniform float deep_shade = 0.55;
uniform float max_depth = 16.0;
uniform float tile_px = 32.0;
uniform bool depth_from_vertex_y = false;

varying float v_depth;
varying vec2 v_world;
varying float v_local_y;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	v_depth = COLOR.r * max_depth;
	v_local_y = VERTEX.y / tile_px;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float d;
	if (depth_from_vertex_y) {
		d = v_local_y;
	} else {
		float py = UV.y / TEXTURE_PIXEL_SIZE.y;
		d = v_depth + mod(py, tile_px) / tile_px;
	}
	float k = smoothstep(0.3, fade_cells, d);

	float hi = max(tex.r, max(tex.g, tex.b));
	float sat = hi - min(tex.r, min(tex.g, tex.b));
	// Tierra y piedras: poco saturadas y oscuras (la hierba y el hielo no).
	float soil = (1.0 - smoothstep(0.10, 0.22, sat)) * (1.0 - smoothstep(0.45, 0.62, hi));

	// Grano fino (2x2 texels) para que la tierra no se vea lisa.
	float grain = 1.0 + (hash(floor(v_world / 1.25)) - 0.5) * 0.12;

	// Tinte de estación + detalle de la hoja (su brillo medio es ~0.12) amplificado.
	vec3 tint = mix(soil_top, soil_deep, k) * grain;
	vec3 soil_col = max(tint + (tex.rgb - vec3(0.12)) * detail_gain, vec3(0.0));
	vec3 col = mix(tex.rgb, soil_col, soil);
	col *= mix(1.0, deep_shade, k);
	COLOR = vec4(col, tex.a);
}
