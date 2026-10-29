@tool
class_name PixelBar
extends Control
## Barra de valor con el marco de pixel art del kit medieval (MediavelFree):
## el marco se dibuja como nine-patch a `pixel_scale` y el relleno se pinta por
## filas con los colores del arte, así la barra puede tener cualquier ancho.
## Anima los cambios de valor.

@export var frame_texture: Texture2D:
	set(value):
		frame_texture = value
		_rebuild()
## Región del marco en la textura y su borde (en píxeles del arte).
@export var frame_region: Rect2 = Rect2(2, 98, 61, 12):
	set(value):
		frame_region = value
		_rebuild()
@export var frame_margin: int = 3:
	set(value):
		frame_margin = value
		_rebuild()
@export var pixel_scale: float = 3.0:
	set(value):
		pixel_scale = maxf(value, 0.1)
		queue_redraw()
## Colores del relleno por fila (de arriba abajo), tomados del arte.
@export var fill_rows: PackedColorArray = PackedColorArray([
	Color("ff7168"), Color("fe6056"), Color("cf1e34"), Color("c41a2f"), Color("c41a2f"), Color("c41a2f"),
])
@export var empty_color: Color = Color("361c20")
@export var max_value: float = 100.0:
	set(value):
		max_value = maxf(value, 0.001)
		queue_redraw()
@export var value: float = 100.0:
	set(new_value):
		value = clampf(new_value, 0.0, max_value)
		queue_redraw()
@export var tween_time: float = 0.25

var _style: StyleBoxTexture
var _tween: Tween


func _ready() -> void:
	_rebuild()


## Cambia el valor animado (sin animación si tween_time <= 0 o fuera del árbol).
func set_value_animated(new_value: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if tween_time <= 0.0 or not is_inside_tree():
		value = new_value
		return
	_tween = create_tween()
	_tween.tween_property(self, "value", clampf(new_value, 0.0, max_value), tween_time)


func get_ratio() -> float:
	return value / max_value


func _draw() -> void:
	var texel_size: Vector2 = size / pixel_scale
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(pixel_scale, pixel_scale))
	if _style != null:
		draw_style_box(_style, Rect2(Vector2.ZERO, texel_size))
	var inner: Rect2 = Rect2(Vector2(frame_margin, frame_margin), texel_size - Vector2(frame_margin, frame_margin) * 2.0)
	if inner.size.x > 0.0 and inner.size.y > 0.0:
		draw_rect(inner, empty_color)
		var fill_width: float = floorf(inner.size.x * get_ratio())
		var rows: int = mini(fill_rows.size(), int(inner.size.y))
		for i: int in rows:
			draw_rect(Rect2(inner.position.x, inner.position.y + i, fill_width, 1.0), fill_rows[i])
		if inner.size.y > rows and rows > 0:
			draw_rect(Rect2(inner.position.x, inner.position.y + rows, fill_width, inner.size.y - rows), fill_rows[rows - 1])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _rebuild() -> void:
	if frame_texture == null:
		_style = null
	else:
		_style = StyleBoxTexture.new()
		_style.texture = frame_texture
		_style.region_rect = frame_region
		_style.set_texture_margin_all(frame_margin)
		_style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	queue_redraw()
