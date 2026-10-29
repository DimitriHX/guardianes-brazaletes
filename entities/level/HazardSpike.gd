class_name HazardSpike
extends HitboxComponent
## Peligro ambiental de pinchos (Capa 6: Hazards = 32; máscara 2: Player).
## Extiende HitboxComponent en modo continuo (continuous = true): al tocar el
## Hurtbox del jugador inflige daño respetando sus i-frames.
## Puede dimensionarse dinámicamente con `set_size_px` al generarse desde texto plano.

@export var spike_color: Color = Color(0.88, 0.22, 0.28, 1.0)
## Tile de pinchos que se repite a lo ancho. Vacío = ColorRect provisional.
@export var spike_texture: Texture2D
## Escala del tile en el mundo (0.625 = 32 px del arte en 20 px, como los tiles).
@export var tile_scale: float = 0.625

var _size_px: Vector2 = Vector2(40.0, 16.0)

@onready var _visual: ColorRect = $Visual
@onready var _sprite: TextureRect = $Sprite
@onready var _shape_node: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	super()
	collision_layer = 32
	collision_mask = 2
	continuous = true
	if _visual != null:
		_visual.color = spike_color
	_layout_sprite()


## Ajusta el ancho y alto del bloque de pinchos (en píxeles, múltiplos de 20).
func set_size_px(new_size: Vector2) -> void:
	if _shape_node == null:
		_shape_node = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _visual == null:
		_visual = get_node_or_null("Visual") as ColorRect
	if _shape_node != null:
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = new_size
		_shape_node.shape = rect
	if _visual != null:
		_visual.offset_left = -new_size.x * 0.5
		_visual.offset_top = -new_size.y * 0.5
		_visual.offset_right = new_size.x * 0.5
		_visual.offset_bottom = new_size.y * 0.5
	_size_px = new_size
	_layout_sprite()


## Repite el tile a lo ancho del bloque, apoyado en su borde inferior.
func _layout_sprite() -> void:
	if _sprite == null:
		_sprite = get_node_or_null("Sprite") as TextureRect
	if _sprite == null:
		return
	var has_art: bool = spike_texture != null
	_sprite.visible = has_art
	if _visual != null:
		_visual.visible = not has_art
	if not has_art:
		return
	_sprite.texture = spike_texture
	var art_size: Vector2 = Vector2(_size_px.x / tile_scale, spike_texture.get_size().y)
	_sprite.scale = Vector2(tile_scale, tile_scale)
	_sprite.size = art_size
	_sprite.position = Vector2(-_size_px.x * 0.5, _size_px.y * 0.5 - art_size.y * tile_scale)
