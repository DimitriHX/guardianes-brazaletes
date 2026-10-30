class_name PitShade
extends Node2D
## Oscuridad dentro de los fosos: en cada tramo de columnas sin suelo hasta el
## fondo del mapa dibuja un degradado que empieza transparente a la altura del
## borde y se vuelve negro unas celdas más abajo. Así el hueco se lee como un
## agujero profundo y no como un corte que deja ver el fondo.
## Va detrás del terreno (z_index negativo): las paredes del foso lo tapan.

## Celdas que tarda el degradado en llegar al negro.
@export var fade_cells: float = 3.5
@export var pit_color: Color = Color(0.02, 0.01, 0.04, 1.0)
## Píxeles extra por debajo del mapa (por si la cámara asoma al caer).
@export var bottom_margin: float = 400.0

var _terrain: TerrainRenderer
## [x0, x1, y_top] en coordenadas del mundo.
var _pits: Array[Vector3] = []


func setup(terrain: TerrainRenderer) -> void:
	_terrain = terrain
	z_index = -5
	_pits.clear()
	for pit: Vector3 in terrain.find_pits():
		_pits.append(pit)
	queue_redraw()


func get_pits() -> Array[Vector3]:
	return _pits


func _draw() -> void:
	if _terrain == null:
		return
	var bottom: float = float(_terrain.get_size_cells().y) * _terrain.cell_size + bottom_margin
	var clear: Color = Color(pit_color, 0.0)
	for pit: Vector3 in _pits:
		var top: float = pit.z
		var solid_from: float = top + fade_cells * _terrain.cell_size
		draw_polygon(
			PackedVector2Array([Vector2(pit.x, top), Vector2(pit.y, top), Vector2(pit.y, solid_from), Vector2(pit.x, solid_from)]),
			PackedColorArray([clear, clear, pit_color, pit_color])
		)
		draw_rect(Rect2(pit.x, solid_from, pit.y - pit.x, bottom - solid_from), pit_color)
