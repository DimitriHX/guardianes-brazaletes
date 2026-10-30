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

## Tamaño de un tile en la hoja (px) y separación vertical entre estaciones
## (mismos valores que PlatformSkinner).
const TILE: int = 32
const SEASON_STRIDE: int = 192

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
		draw_texture_rect_region(tileset, dest, get_cell_region(cell))


func _is_solid(cell: Vector2i) -> bool:
	# Fuera del mapa por los lados o por abajo: roca (sin borde). Por arriba: aire.
	if cell.y < 0:
		return false
	if cell.x < 0 or cell.x >= _size_cells.x or cell.y >= _size_cells.y:
		return true
	return _cells.has(cell) or _solid_neighbors.has(cell)
