class_name ParallaxBackdrop
extends Node2D
## Fondo por capas con parallax horizontal, siempre llenando la vista:
## cada capa es un Sprite2D que se coloca en la esquina de la vista de la cámara
## activa, se escala para cubrir su alto y desplaza su textura (region + repeat)
## según `scroll_factors`. Calculado a mano (no Parallax2D) para que sea
## exacto con el zoom dinámico de GameCamera.
## Capas ordenadas de la más lejana a la más cercana.

@export var layers: Array[Texture2D] = []
## 0 = quieta (infinitamente lejos), 1 = se mueve con el mundo. Una por capa;
## si faltan valores se usa el último.
@export var scroll_factors: Array[float] = [0.0, 0.1, 0.2, 0.35, 0.5, 0.65]
## Oscurece/tiñe el fondo para que el primer plano destaque.
@export var tint: Color = Color(1, 1, 1, 1)

var _sprites: Array[Sprite2D] = []


func _ready() -> void:
	z_index = -100
	# Después de que la cámara se mueva este frame, para no ir un frame por detrás.
	process_priority = 100
	for i: int in layers.size():
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "Layer%d" % i
		sprite.texture = layers[i]
		sprite.centered = false
		sprite.region_enabled = true
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		sprite.self_modulate = tint
		add_child(sprite)
		_sprites.append(sprite)
	# Diferido: en _ready la cámara del nivel aún no ha aplicado su zoom.
	_update.call_deferred()


func _process(_delta: float) -> void:
	_update()


func get_layer_sprites() -> Array[Sprite2D]:
	return _sprites


func _update() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null or _sprites.is_empty():
		return
	var view: Vector2 = get_viewport_rect().size / camera.zoom
	var top_left: Vector2 = camera.get_screen_center_position() - view / 2.0
	for i: int in _sprites.size():
		var sprite: Sprite2D = _sprites[i]
		var tex_size: Vector2 = sprite.texture.get_size()
		var s: float = view.y / tex_size.y
		var factor: float = scroll_factors[mini(i, scroll_factors.size() - 1)] if not scroll_factors.is_empty() else 0.0
		sprite.global_position = top_left
		sprite.scale = Vector2(s, s)
		sprite.region_rect = Rect2(top_left.x * factor / s, 0.0, view.x / s + 1.0, tex_size.y)
