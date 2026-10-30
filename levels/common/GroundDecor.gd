class_name GroundDecor
extends Node2D
## Relieve del suelo: matas de pasto, flores, piedras y setas sobre la superficie
## del terreno, y piedrecitas o raíces incrustadas justo debajo, según la
## estación (hoja `ground_decor.png`, generada por tools/make_ground_decor.py).
## La colocación es pseudoaleatoria pero fija por celda: el nivel se ve igual en
## cada partida. El pasto y las flores se mecen con el shader `grass_sway`.
## Solo es dibujo: no cambia la colisión.

const SHEET: Texture2D = preload("res://assets/tiles/ground_decor.png")
const SWAY_SHADER: Shader = preload("res://shaders/grass_sway.gdshader")
## Lado de una pieza y alto de la fila de cada estación en la hoja (px).
const PIECE_PX: int = 32
const SLOT_PX: int = 64
## Tamaño en el mundo de un píxel de la hoja (como los tiles: 20 / 32).
const TEXEL: float = 0.625

## Piezas de superficie [índice, peso, se mece] por estación.
const SURFACE_PIECES: Dictionary[int, Array] = {
	PlatformSkinner.Season.GREEN: [[0, 6, true], [1, 4, true], [2, 5, true], [3, 2, true], [4, 2, true], [5, 2, false], [6, 1, false], [7, 1, false]],
	PlatformSkinner.Season.AUTUMN: [[0, 6, true], [1, 4, true], [2, 5, true], [3, 3, false], [4, 2, true], [5, 2, false], [6, 1, false], [7, 1, false]],
	PlatformSkinner.Season.WINTER: [[0, 5, true], [1, 3, true], [2, 4, true], [3, 3, true], [4, 2, false], [5, 2, false], [6, 1, false], [7, 3, false]],
}
const BURIED_PIECES: Array[int] = [8, 9]

## Probabilidad de que una celda de superficie lleve decoración.
@export_range(0.0, 1.0, 0.05) var surface_density: float = 0.85
## Probabilidad de piedrecitas o raíces en la celda de justo debajo.
@export_range(0.0, 1.0, 0.05) var buried_density: float = 0.18

var _terrain: TerrainRenderer
var _season: int = 0
## [Rect2 destino, Rect2 región, se mece]
var _pieces: Array[Array] = []


func setup(terrain: TerrainRenderer, season: int) -> void:
	_terrain = terrain
	_season = season
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SWAY_SHADER
	mat.set_shader_parameter(&"sheet_height_px", float(SHEET.get_height()))
	mat.set_shader_parameter(&"slot_px", float(SLOT_PX))
	material = mat
	_build()


func get_piece_count() -> int:
	return _pieces.size()


func _build() -> void:
	_pieces.clear()
	if _terrain == null:
		return
	var cell_size: float = _terrain.cell_size
	var piece_world: float = float(PIECE_PX) * TEXEL
	var options: Array = SURFACE_PIECES.get(_season, SURFACE_PIECES[PlatformSkinner.Season.GREEN])
	var total_weight: int = 0
	for o: Array in options:
		total_weight += int(o[1])
	for cell: Vector2i in _terrain.get_surface_cells():
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = hash(cell) ^ (_season * 7919)
		var cell_pos: Vector2 = Vector2(cell) * cell_size
		# Superficie: una o dos piezas apoyadas en el borde de arriba de la celda.
		# La hierba del tile ocupa ~5 px de arriba: se hunden 4 px para asentarse.
		var count: int = 0
		if rng.randf() < surface_density:
			count = 2 if rng.randf() < 0.45 else 1
		for i: int in count:
			var pick: int = rng.randi_range(0, total_weight - 1)
			var chosen: Array = options[0]
			for o: Array in options:
				pick -= int(o[1])
				if pick < 0:
					chosen = o
					break
			var x: float = cell_pos.x + rng.randf_range(-0.6, 0.6) * cell_size
			var dest: Rect2 = Rect2(Vector2(x, cell_pos.y - piece_world + 4.0 * TEXEL), Vector2(piece_world, piece_world))
			_pieces.append([dest, _region(int(chosen[0])), bool(chosen[2])])
		# Incrustadas: en la celda de debajo si es tierra.
		var below: Vector2i = cell + Vector2i.DOWN
		if _terrain.has_cell(below) and rng.randf() < buried_density:
			var idx: int = BURIED_PIECES[rng.randi_range(0, BURIED_PIECES.size() - 1)]
			var bdest: Rect2 = Rect2(Vector2(below) * cell_size + Vector2(rng.randf_range(0.0, 0.4) * cell_size, 0.0), Vector2(piece_world, piece_world))
			_pieces.append([bdest, _region(idx), false])
	queue_redraw()


func _region(index: int) -> Rect2:
	return Rect2(float(index * PIECE_PX), float(_season * SLOT_PX), float(PIECE_PX), float(PIECE_PX))


func _draw() -> void:
	for piece: Array in _pieces:
		# El rojo del modulate le dice al shader si la pieza se mece.
		var sway: Color = Color(1.0 if bool(piece[2]) else 0.0, 1.0, 1.0, 1.0)
		draw_texture_rect_region(SHEET, piece[0] as Rect2, piece[1] as Rect2, sway)
