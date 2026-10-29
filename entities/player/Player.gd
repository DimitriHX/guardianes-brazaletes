class_name Player
extends CharacterBody2D
## Jugador de plataformas: movimiento horizontal con aceleración,
## salto con coyote time, jump buffer y altura variable.
## Reenvía su vida y muerte al bus global Events.

@export_group("Movimiento")
@export var move_speed: float = 220.0
@export var acceleration: float = 1800.0
@export var friction: float = 2200.0
@export var air_control: float = 0.8

@export_group("Salto")
@export var jump_velocity: float = -430.0
@export var gravity: float = 1200.0
## Multiplicador de gravedad al caer (caída más "pesada" que la subida).
@export var fall_gravity_multiplier: float = 1.6
@export var max_fall_speed: float = 900.0
## Segundos tras salir de una plataforma en los que aún se puede saltar.
@export var coyote_time: float = 0.1
## Segundos que se recuerda una pulsación de salto antes de tocar suelo.
@export var jump_buffer_time: float = 0.12
## Al soltar el botón durante la subida, la velocidad vertical se multiplica por esto.
@export var jump_cut_multiplier: float = 0.45

@export_group("Disparo")
@export var projectile_scene: PackedScene
## Segundos mínimos entre disparos (mantener pulsado dispara a este ritmo).
@export var shoot_cooldown: float = 0.25

## Dirección a la que mira el jugador: 1 derecha, -1 izquierda.
var facing: int = 1

var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _shoot_cooldown_left: float = 0.0
var _is_dead: bool = false

@onready var _visual: Node2D = $Visual
@onready var _muzzle: Marker2D = $Visual/Muzzle
@onready var _health: HealthComponent = $HealthComponent


func _ready() -> void:
	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_on_health_died)
	Events.player_health_changed.emit(_health.current_health, _health.max_health)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_update_timers(delta)
	_apply_gravity(delta)
	_apply_horizontal(delta)
	_try_jump()
	move_and_slide()
	_try_shoot()


func _process(_delta: float) -> void:
	# Parpadeo durante la invulnerabilidad.
	# TODO(assets): sustituir por animación/shader de daño del sprite.
	_visual.modulate.a = 0.4 if _health.is_invulnerable() else 1.0


func take_damage(amount: int) -> void:
	_health.take_damage(amount)


func heal(amount: int) -> void:
	_health.heal(amount)


func kill() -> void:
	_health.kill()


func is_dead() -> bool:
	return _is_dead


## true si una curación tendría efecto (no está muerto ni con la vida al máximo).
func can_heal() -> bool:
	return not _is_dead and not _health.is_full()


func _update_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_left = coyote_time
	else:
		_coyote_left = maxf(_coyote_left - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_left = jump_buffer_time
	else:
		_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)

	_shoot_cooldown_left = maxf(_shoot_cooldown_left - delta, 0.0)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var g: float = gravity * (fall_gravity_multiplier if velocity.y > 0.0 else 1.0)
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)

	# Salto variable: soltar el botón corta la subida.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier


func _apply_horizontal(delta: float) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	var control: float = 1.0 if is_on_floor() else air_control
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * move_speed, acceleration * control * delta)
		_set_facing(1 if direction > 0.0 else -1)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * control * delta)


func _try_jump() -> void:
	if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_left = 0.0
		_coyote_left = 0.0


func _try_shoot() -> void:
	if projectile_scene == null or _shoot_cooldown_left > 0.0:
		return
	if not Input.is_action_pressed("shoot"):
		return
	_shoot_cooldown_left = shoot_cooldown
	var projectile: Projectile = projectile_scene.instantiate() as Projectile
	projectile.setup(Vector2(float(facing), 0.0))
	# Se añade al nivel (no al jugador) para que no se mueva con él.
	var container: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	container.add_child(projectile)
	projectile.global_position = _muzzle.global_position
	# TODO(assets): animación de disparo y sonido.


func _set_facing(new_facing: int) -> void:
	if new_facing == facing:
		return
	facing = new_facing
	# TODO(assets): con AnimatedSprite2D usar flip_h en lugar de escalar el contenedor.
	_visual.scale.x = float(facing)


func _on_health_changed(current: int, maximum: int) -> void:
	Events.player_health_changed.emit(current, maximum)


func _on_health_died() -> void:
	_is_dead = true
	velocity = Vector2.ZERO
	# TODO(assets): reproducir animación de muerte antes de notificar.
	Events.player_died.emit()
