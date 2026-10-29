@tool
class_name PixelPanel
extends MarginContainer
## Panel de pixel art (nine-patch) que se adapta al tamaño de su contenido.
## Dibuja una región de una textura como nine-patch a `pixel_scale` (para que
## el arte de 16 px se vea nítido en una UI de 1280x720), y los hijos se colocan
## encima con el margen interior `padding`. Los textos NO se escalan.

@export var texture: Texture2D:
	set(value):
		texture = value
		_rebuild()
@export var region: Rect2 = Rect2():
	set(value):
		region = value
		_rebuild()
## Margen del nine-patch en píxeles del arte (las esquinas no se estiran).
@export var patch_margin: int = 8:
	set(value):
		patch_margin = value
		_rebuild()
@export var pixel_scale: float = 3.0:
	set(value):
		pixel_scale = maxf(value, 0.1)
		queue_redraw()
## Espacio entre el borde del panel y el contenido (px de pantalla).
@export var padding: Vector4i = Vector4i(24, 18, 24, 18):
	set(value):
		padding = value
		_apply_padding()

var _style: StyleBoxTexture


func _ready() -> void:
	_rebuild()
	_apply_padding()


func _draw() -> void:
	if _style == null:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(pixel_scale, pixel_scale))
	draw_style_box(_style, Rect2(Vector2.ZERO, size / pixel_scale))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _rebuild() -> void:
	if texture == null:
		_style = null
		queue_redraw()
		return
	_style = StyleBoxTexture.new()
	_style.texture = texture
	_style.region_rect = region
	_style.set_texture_margin_all(patch_margin)
	_style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	_style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	queue_redraw()


func _apply_padding() -> void:
	add_theme_constant_override("margin_left", padding.x)
	add_theme_constant_override("margin_top", padding.y)
	add_theme_constant_override("margin_right", padding.z)
	add_theme_constant_override("margin_bottom", padding.w)
