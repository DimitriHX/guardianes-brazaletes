class_name GameCamera
extends Camera2D
## Cámara de juego reutilizable:
## - Zoom cerrado sobre el objetivo (sprites más grandes). Si la ventana es
##   muy alta o ancha, el zoom sube lo justo para que la vista quepa en los
##   límites y nunca se vea el vacío.
## - Seguimiento suave (position_smoothing) y márgenes de arrastre verticales
##   para que los saltos pequeños no muevan la cámara.
## - Look-ahead: se adelanta hacia donde mira el objetivo (propiedad `facing`).
##   Se aplica sobre `position` (no `offset`), porque en Godot 4 los límites no
##   recortan `offset`. `offset` queda libre para efectos como el shake.
## - Límites automáticos y FIRMES (no usar limit_smoothed: deja asomar el vacío
##   mientras suaviza). Toma el rectángulo del primer nodo Control del grupo
##   `bounds_group` (un ReferenceRect "CameraBounds" en el nivel).

## Nodo a seguir. Vacío = el padre (lo normal: la cámara cuelga del Player).
@export var target: Node2D
## Zoom deseado para una resolución base de `reference_height` px de alto.
## El real se escala con la resolución del proyecto (1080p -> x1.5) y puede ser
## mayor si la vista no cabe en los límites.
## 1.6 a 720p = pixel-perfect con tiles a 0.625 (PlatformSkinner) y jugador a 1.25.
@export_range(0.5, 4.0, 0.1) var zoom_level: float = 1.6
## Alto de la resolución para la que está pensado `zoom_level`. Así el encuadre
## es el mismo a 1280x720 que a 1920x1080 (antes, a 1080p se veía todo alejado).
@export var reference_height: float = 720.0
@export_group("Look-ahead")
@export var look_ahead_distance: float = 48.0
## Rapidez con la que el look-ahead alcanza su posición (mayor = más brusco).
@export var look_ahead_speed: float = 3.0
@export_group("Límites")
@export var bounds_group: StringName = &"camera_bounds"
@export_group("Shake (Sprint 10)")
@export var player_hurt_shake: float = 6.0
@export var player_hurt_shake_time: float = 0.22
@export var enemy_hit_shake: float = 2.5
@export var enemy_hit_shake_time: float = 0.10
@export var boss_defeat_shake: float = 8.0
@export var boss_defeat_shake_time: float = 0.40
@export var shake_frequency: float = 38.0

var _follows_parent: bool = true
var _look_ahead: float = 0.0
var _bounds: Rect2 = Rect2()
var _has_bounds: bool = false
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_left: float = 0.0
var _shake_time: float = 0.0


func _ready() -> void:
	if target == null:
		target = get_parent() as Node2D
	_follows_parent = target == get_parent()
	_apply_bounds_from_group()
	get_viewport().size_changed.connect(_update_zoom)
	Events.camera_shake_requested.connect(shake)
	Events.entity_damaged.connect(_on_entity_damaged)
	Events.boss_defeated.connect(_on_boss_defeated)
	_update_zoom()
	if target != null:
		_snap_to_target()


func _process(delta: float) -> void:
	_update_shake(delta)
	if target == null or not is_instance_valid(target):
		return
	var facing_value: Variant = target.get("facing")
	var facing: float = float(facing_value) if facing_value != null else 0.0
	var weight: float = 1.0 - exp(-look_ahead_speed * delta)
	_look_ahead = lerpf(_look_ahead, facing * look_ahead_distance, weight)
	if _follows_parent:
		position.x = _look_ahead
	else:
		global_position = target.global_position + Vector2(_look_ahead, 0.0)


## Sacude la cámara usando `offset` (sin alterar `position` ni salirse de límites).
func shake(intensity: float, duration: float = 0.2) -> void:
	if intensity <= 0.0 or duration <= 0.0:
		return
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_duration = maxf(_shake_left, duration)
	_shake_left = maxf(_shake_left, duration)


func stop_shake() -> void:
	_shake_left = 0.0
	_shake_intensity = 0.0
	offset = Vector2.ZERO


func is_shaking() -> bool:
	return _shake_left > 0.0


func get_shake_intensity() -> float:
	return _shake_intensity if _shake_left > 0.0 else 0.0


## Fija los límites a un rectángulo en coordenadas globales.
func set_bounds(rect: Rect2) -> void:
	_bounds = rect
	_has_bounds = true
	limit_left = floori(rect.position.x)
	limit_top = floori(rect.position.y)
	limit_right = ceili(rect.end.x)
	limit_bottom = ceili(rect.end.y)
	_update_zoom()


func _apply_bounds_from_group() -> void:
	var bounds: Control = get_tree().get_first_node_in_group(bounds_group) as Control
	if bounds == null:
		push_warning("GameCamera: no hay nodo en el grupo '%s'; se usan los límites del inspector." % bounds_group)
		return
	set_bounds(bounds.get_global_rect())


## Zoom objetivo ya escalado a la resolución base del proyecto.
func get_effective_zoom_level() -> float:
	var base_height: float = float(ProjectSettings.get_setting("display/window/size/viewport_height", reference_height))
	return zoom_level * base_height / maxf(reference_height, 1.0)


func _update_zoom() -> void:
	if not is_inside_tree():
		return
	var z: float = get_effective_zoom_level()
	if _has_bounds and _bounds.size.x > 0.0 and _bounds.size.y > 0.0:
		var view: Vector2 = get_viewport_rect().size
		z = maxf(z, maxf(view.x / _bounds.size.x, view.y / _bounds.size.y))
	if is_equal_approx(zoom.x, z):
		return
	zoom = Vector2(z, z)
	# Recolocar al instante: si no, el suavizado enseña el vacío unos frames.
	# Diferido: durante size_changed la cámara aún no conoce el viewport nuevo.
	force_update_scroll()
	reset_smoothing.call_deferred()


func _snap_to_target() -> void:
	# Evita que la cámara "viaje" desde el origen al cargar el nivel.
	_look_ahead = 0.0
	if _follows_parent:
		position.x = 0.0
	else:
		global_position = target.global_position
	reset_smoothing()


func _update_shake(delta: float) -> void:
	if _shake_left <= 0.0:
		if offset != Vector2.ZERO:
			offset = Vector2.ZERO
		return
	_shake_left = maxf(_shake_left - delta, 0.0)
	if _shake_left <= 0.0:
		_shake_intensity = 0.0
		offset = Vector2.ZERO
		return
	_shake_time += delta * shake_frequency
	var decay: float = _shake_left / maxf(_shake_duration, 0.001)
	var amp: float = _shake_intensity * decay
	var wave_x: float = sin(_shake_time * 1.7) * 0.7 + cos(_shake_time * 3.1) * 0.3
	var wave_y: float = cos(_shake_time * 2.3) * 0.7 + sin(_shake_time * 3.7) * 0.3
	offset = Vector2(wave_x, wave_y) * amp


func _on_entity_damaged(entity: Node, amount: int) -> void:
	if entity != null and entity.is_in_group("player"):
		shake(player_hurt_shake, player_hurt_shake_time)
	else:
		shake(enemy_hit_shake + float(maxi(amount - 1, 0)) * 0.8, enemy_hit_shake_time)


func _on_boss_defeated(_boss: Node) -> void:
	shake(boss_defeat_shake, boss_defeat_shake_time)
