class_name Checkpoint
extends Area2D
## Altar / farol de luz intermedio (Checkpoint).
## Permanece en reposo con un destello azulado tenue hasta que Emma lo toca;
## al activarse enciende su llama dorada, lanza destellos y registra su posición
## en `LevelManager` vía `Events.checkpoint_reached`.

const FRAMES_PER_ROW: int = 6

@export var texture: Texture2D
@export var activate_effect: PackedScene
@export var fps: float = 8.0

@export_group("Luz (PointLight2D)")
@export var inactive_color: Color = Color(0.45, 0.75, 1.0, 1.0)
@export var active_color: Color = Color(1.0, 0.82, 0.32, 1.0)
@export var inactive_energy: float = 0.45
@export var active_energy: float = 1.45
@export var inactive_scale: float = 1.25
@export var active_scale: float = 2.15

var is_activated: bool = false

var _time: float = 0.0
var _frame_time: float = 0.0

@onready var _visual: ColorRect = $Visual
@onready var _sprite: Sprite2D = $Sprite
@onready var _light: PointLight2D = $PointLight2D


func _ready() -> void:
	add_to_group("checkpoints")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	if _light != null:
		_light.add_to_group("point_lights")
		if _light.texture == null:
			_light.texture = LevelAmbience.make_radial_light_texture()
	_update_visual()


func _process(delta: float) -> void:
	_time += delta * 4.5
	if _sprite != null and _sprite.visible and _sprite.hframes > 1:
		if is_activated:
			_frame_time += delta * fps
			var col: int = int(_frame_time) % FRAMES_PER_ROW
			_sprite.frame = FRAMES_PER_ROW + col
		else:
			_sprite.frame = 0
	if _light != null:
		var base_e: float = active_energy if is_activated else inactive_energy
		var pulse: float = sin(_time) * (0.14 if is_activated else 0.05)
		_light.energy = maxf(0.1, base_e + pulse)


## Activa el altar de control y emite `Events.checkpoint_reached`.
func activate() -> void:
	if is_activated:
		return
	is_activated = true
	_update_visual()
	if activate_effect != null:
		Effect.spawn(activate_effect, self, global_position + Vector2(0.0, -8.0))
	Events.sfx_requested.emit(&"heal")
	Events.particles_requested.emit(&"sparks", global_position + Vector2(0.0, -8.0))
	Events.checkpoint_reached.emit(global_position)
	Events.hud_message.emit("Luz guardada", 1.4)


func _update_visual() -> void:
	var has_art: bool = texture != null
	if _sprite != null:
		_sprite.texture = texture
		_sprite.visible = has_art
		if has_art:
			_sprite.hframes = FRAMES_PER_ROW
			_sprite.vframes = 4
			_sprite.frame = FRAMES_PER_ROW if is_activated else 0
			_sprite.modulate = Color(1.0, 0.96, 0.82, 1.0) if is_activated else Color(0.65, 0.82, 1.0, 0.85)
	if _visual != null:
		_visual.visible = not has_art
		_visual.color = active_color if is_activated else inactive_color
	if _light != null:
		_light.color = active_color if is_activated else inactive_color
		_light.energy = active_energy if is_activated else inactive_energy
		_light.texture_scale = active_scale if is_activated else inactive_scale


func _on_body_entered(body: Node2D) -> void:
	if is_activated or body == null:
		return
	if not body.is_in_group("player"):
		return
	if body.has_method("is_dead") and bool(body.call("is_dead")):
		return
	activate()
