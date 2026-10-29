class_name FallingPlatform
extends StaticBody2D
## Plataforma frágil one-way que tiembla al ser pisada por el jugador,
## cae desvaneciéndose tras `shake_time` y reaparece en su lugar tras `respawn_time`.
## Compatible con `PlatformSkinner` (usa `CollisionShape2D` + `Visual`).

enum Phase { IDLE, SHAKING, FALLING, RESPAWNING }

@export var shake_time: float = 0.45
@export var fall_duration: float = 0.35
@export var fall_distance: float = 60.0
@export var respawn_time: float = 2.0
@export var shake_amplitude: float = 2.5
@export var idle_tint: Color = Color(0.94, 0.82, 0.70, 1.0)
@export var shake_tint: Color = Color(1.0, 0.68, 0.52, 1.0)

var _phase: Phase = Phase.IDLE
var _timer: float = 0.0
var _home_position: Vector2 = Vector2.ZERO
var _size_px: Vector2 = Vector2(80.0, 10.0)

@onready var _visual: ColorRect = $Visual
@onready var _shape_node: CollisionShape2D = $CollisionShape2D
@onready var _detector: Area2D = $Detector
@onready var _detector_shape: CollisionShape2D = $Detector/CollisionShape2D


func _ready() -> void:
	add_to_group("falling_platforms")
	collision_layer = 1
	collision_mask = 0
	_home_position = position
	modulate = idle_tint
	if _detector != null:
		_detector.collision_layer = 0
		_detector.collision_mask = 2


func _physics_process(delta: float) -> void:
	match _phase:
		Phase.IDLE:
			if _is_player_standing_on_top():
				trigger_fall()
		Phase.SHAKING:
			_timer -= delta
			var offset_x: float = sin(_timer * 65.0) * shake_amplitude
			position = _home_position + Vector2(offset_x, 0.0)
			if _timer <= 0.0:
				_begin_fall()
		Phase.FALLING:
			_timer -= delta
			var t: float = clampf(1.0 - (_timer / maxf(0.01, fall_duration)), 0.0, 1.0)
			position = _home_position + Vector2(0.0, fall_distance * t * t)
			modulate.a = 1.0 - t
			if _timer <= 0.0:
				_begin_respawn()
		Phase.RESPAWNING:
			_timer -= delta
			if _timer <= 0.0:
				reset_platform()


## Ajusta el tamaño en píxeles de la plataforma y de su detector superior.
func set_size_px(new_size: Vector2) -> void:
	_size_px = new_size
	if _shape_node == null:
		_shape_node = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _visual == null:
		_visual = get_node_or_null("Visual") as ColorRect
	if _detector_shape == null:
		_detector_shape = get_node_or_null("Detector/CollisionShape2D") as CollisionShape2D

	if _shape_node != null:
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = new_size
		_shape_node.shape = rect
		_shape_node.one_way_collision = true

	if _visual != null:
		_visual.offset_left = -new_size.x * 0.5
		_visual.offset_top = -new_size.y * 0.5
		_visual.offset_right = new_size.x * 0.5
		_visual.offset_bottom = new_size.y * 0.5

	if _detector_shape != null:
		var det_rect: RectangleShape2D = RectangleShape2D.new()
		det_rect.size = Vector2(maxf(8.0, new_size.x - 4.0), 10.0)
		_detector_shape.shape = det_rect
		_detector_shape.position = Vector2(0.0, -new_size.y * 0.5 - 3.0)


## Inicia la secuencia de temblor y caída si está en reposo.
func trigger_fall() -> void:
	if _phase != Phase.IDLE:
		return
	_home_position = position
	_phase = Phase.SHAKING
	_timer = shake_time
	modulate = shake_tint
	Events.particles_requested.emit(&"dust", global_position)


## Restaura inmediatamente la plataforma a su estado inicial.
func reset_platform() -> void:
	_phase = Phase.IDLE
	_timer = 0.0
	position = _home_position
	modulate = idle_tint
	visible = true
	if _shape_node != null:
		_shape_node.disabled = false


func get_phase() -> Phase:
	return _phase


func is_solid() -> bool:
	return _shape_node != null and not _shape_node.disabled


func _is_player_standing_on_top() -> bool:
	if _detector == null:
		return false
	for body: Node2D in _detector.get_overlapping_bodies():
		var player: Player = body as Player
		if player != null and not player.is_dead():
			if player.velocity.y >= -10.0 and player.global_position.y <= global_position.y + 4.0:
				return true
	return false


func _begin_fall() -> void:
	_phase = Phase.FALLING
	_timer = fall_duration
	position = _home_position
	if _shape_node != null:
		_shape_node.disabled = true
	Events.particles_requested.emit(&"dust", global_position)


func _begin_respawn() -> void:
	_phase = Phase.RESPAWNING
	_timer = respawn_time
	visible = false
