class_name TerrainRenderer
extends Node2D
## Dibuja el suelo grueso (`#`) de un nivel de texto celda a celda (autotile).
## Cada celda elige su pieza del bloque 3x3 de la hoja de tiles según sus
## vecinas: hierba arriba solo donde no hay tierra encima, bordes laterales solo
## donde el terreno termina. Así colinas, escalones y fosos se ven como un único
## terreno continuo, sin las costuras que dejaría dibujar cada rectángulo de
## colisión por separado. La colisión no cambia (la siguen dando los StaticBody2D).
## Los bordes del mapa y los muros (`|`) cuentan como terreno: no se dibuja borde
## contra ellos ni en el fondo del mapa.
## Profundidad: cada celda pasa al shader `terrain_depth` cuántas celdas de
## terreno tiene encima; la tierra toma el color de la estación junto a la
## superficie y se oscurece hacia abajo.
## Hijos: GroundDecor (pasto, piedras... sobre la superficie) y PitShade
## (oscuridad dentro de los fosos).

## Tamaño de un tile en la hoja (px) y separación vertical entre estaciones
## (mismos valores que PlatformSkinner).
const TILE: int = 32
const SEASON_STRIDE: int = 192
const DEPTH_SHADER: Shader = preload("res://shaders/terrain_depth.gdshader")
## Debe coincidir con `max_depth` del shader.
const MAX_DEPTH_CELLS: float = 16.0
## Color de la tierra junto a la superficie y en lo hondo, por estación.
const SOIL_COLORS: Dictionary[int, Array] = {
	PlatformSkinner.Season.GREEN: [Color(0.29, 0.20, 0.13), Color(0.07, 0.05, 0.06)],
	PlatformSkinner.Season.AUTUMN: [Color(0.30, 0.14, 0.09), Color(0.08, 0.03, 0.05)],
	PlatformSkinner.Season.WINTER: [Color(0.20, 0.24, 0.34), Color(0.04, 0.05, 0.10)],
}

@export var tileset: Texture2D
@export var season: PlatformSkinner.Season = PlatformSkinner.Season.GREEN
## Tamaño de una celda en el mundo (PlatformGenerator.CELL_SIZE).
@export var cell_size: float = 20.0

## Celdas sólidas que dibuja este nodo y celdas que cuentan como sólidas
## para elegir piezas pero no se dibujan (muros).
var _cells: Dictionary[Vector2i, bool] = {}
var _solid_neighbors: Dictionary[Vector2i, bool] = {}
var _size_cells: Vector2i = Vector2i.ZERO


## Define el terreno: `cells` = celdas `#`; `extra_solid` = otras celdas que
## tapan bordes (muros); `size_cells` = tamaño del mapa en celdas.
func _ready() -> void:
	material = make_depth_material(season)
	var pit_shade: PitShade = PitShade.new()
	pit_shade.name = "PitShade"
	add_child(pit_shade)
	pit_shade.setup(self)
	var decor: GroundDecor = GroundDecor.new()
	decor.name = "GroundDecor"
	add_child(decor)
	decor.setup(self, int(season))


## Material del shader de profundidad con los colores de `season_value`.
## `from_vertex_y` = profundidad según la altura local (NinePatch de PlatformSkinner).
static func make_depth_material(season_value: int, from_vertex_y: bool = false) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = DEPTH_SHADER
	var colors: Array = SOIL_COLORS.get(season_value, SOIL_COLORS[PlatformSkinner.Season.GREEN])
	mat.set_shader_parameter(&"soil_top", colors[0])
	mat.set_shader_parameter(&"soil_deep", colors[1])
	mat.set_shader_parameter(&"max_depth", MAX_DEPTH_CELLS)
	mat.set_shader_parameter(&"tile_px", float(TILE))
	mat.set_shader_parameter(&"depth_from_vertex_y", from_vertex_y)
	return mat


func set_cells(cells: Array[Vector2i], extra_solid: Array[Vector2i], size_cells: Vector2i) -> void:
	_cells.clear()
	_solid_neighbors.clear()
	for c: Vector2i in cells:
		_cells[c] = true
	for c: Vector2i in extra_solid:
		_solid_neighbors[c] = true
	_size_cells = size_cells
	queue_redraw()


func get_cell_count() -> int:
	return _cells.size()


func get_size_cells() -> Vector2i:
	return _size_cells


func has_cell(cell: Vector2i) -> bool:
	return _cells.has(cell)


## Celdas de terreno con aire justo encima (donde se pisa).
func get_surface_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in _cells:
		if not _is_solid(cell + Vector2i.UP):
			result.append(cell)
	return result


## Fosos: tramos de columnas sin terreno en la fila del fondo del mapa.
## Devuelve [x0, x1, y del borde] en el mundo; el borde es el más bajo de los
## dos lados, donde empieza el hueco a la vista.
func find_pits() -> Array[Vector3]:
	var pits: Array[Vector3] = []
	var bottom: int = _size_cells.y - 1
	var c: int = 0
	while c < _size_cells.x:
		if _is_solid(Vector2i(c, bottom)):
			c += 1
			continue
		var start: int = c
		while c < _size_cells.x and not _is_solid(Vector2i(c, bottom)):
			c += 1
		var lip: int = maxi(_column_top(start - 1), _column_top(c))
		pits.append(Vector3(float(start) * cell_size, float(c) * cell_size, float(lip) * cell_size))
	return pits


## Primera fila del terreno que sube sin cortes desde el fondo en la columna `col`.
func _column_top(col: int) -> int:
	var r: int = _size_cells.y - 1
	while r > 0 and _is_solid(Vector2i(col, r - 1)):
		r -= 1
	return r


## Celdas de terreno seguidas que hay justo encima de `cell` (0 = superficie).
func get_cell_depth(cell: Vector2i) -> int:
	var depth: int = 0
	var above: Vector2i = cell + Vector2i.UP
	while depth < int(MAX_DEPTH_CELLS) and _is_solid(above):
		depth += 1
		above += Vector2i.UP
	return depth


## Región de la hoja (px) que usa la celda `cell`.
func get_cell_region(cell: Vector2i) -> Rect2:
	var col: int = 1
	if not _is_solid(cell + Vector2i.LEFT):
		col = 0
	elif not _is_solid(cell + Vector2i.RIGHT):
		col = 2
	var row: int = 1
	if not _is_solid(cell + Vector2i.UP):
		row = 0
	elif not _is_solid(cell + Vector2i.DOWN):
		row = 2
	return Rect2(
		float(col * TILE),
		float(row * TILE + int(season) * SEASON_STRIDE),
		float(TILE),
		float(TILE)
	)


func _draw() -> void:
	if tileset == null:
		return
	for cell: Vector2i in _cells:
		var dest: Rect2 = Rect2(Vector2(cell) * cell_size, Vector2(cell_size, cell_size))
		# El rojo del modulate lleva la profundidad al shader.
		var depth: Color = Color(float(get_cell_depth(cell)) / MAX_DEPTH_CELLS, 1.0, 1.0, 1.0)
		draw_texture_rect_region(tileset, dest, get_cell_region(cell), depth)


func _is_solid(cell: Vector2i) -> bool:
	# Fuera del mapa por los lados o por abajo: roca (sin borde). Por arriba: aire.
	if cell.y < 0:
		return false
	if cell.x < 0 or cell.x >= _size_cells.x or cell.y >= _size_cells.y:
		return true
	return _cells.has(cell) or _solid_neighbors.has(cell)
