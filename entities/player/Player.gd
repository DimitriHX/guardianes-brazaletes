class_name Player
extends CharacterBody2D
## Jugador de plataformas. Este script es el "cuerpo": expone parámetros y
## operaciones de movimiento (gravedad, horizontal, salto, disparo).
## El "cerebro" es la StateMachine hija: cada estado (Idle, Walk, Jump, Fall,
## Attack, Dead) decide qué operaciones usar, a qué estado pasar y qué
## animación reproducir. Reenvía vida y muerte al bus global Events.

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

@export_group("Retroceso")
## Fricción horizontal mientras dura un empujón (knockback).
@export var knockback_friction: float = 900.0

## Dirección a la que mira el jugador: 1 derecha, -1 izquierda.
var facing: int = 1
## Última animación pedida por un estado (útil para depurar sin sprite).
var current_animation: StringName = &""

var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _shoot_cooldown_left: float = 0.0
var _knockback_left: float = 0.0
var _is_dead: bool = false

@onready var _visual: Node2D = $Visual
@onready var _muzzle: Marker2D = $Visual/Muzzle
@onready var _animator: CharacterAnimator = $Visual/Animator
@onready var _stats: StatsComponent = $Stats
@onready var _state_machine: StateMachine = $StateMachine


func _ready() -> void:
	_stats.health_changed.connect(_on_health_changed)
	_stats.died.connect(_on_health_died)
	_stats.damaged.connect(_on_damaged)
	_animator.one_shot_finished.connect(_on_animation_one_shot_finished)
	for child: Node in _state_machine.get_children():
		var state: PlayerState = child as PlayerState
		if state != null:
			state.setup(self)
	_state_machine.start()
	Events.player_health_changed.emit(_stats.current_health, _stats.max_health)


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_state_machine.physics_update(delta)
	move_and_slide()


func _process(delta: float) -> void:
	_state_machine.update(delta)
	# Parpadeo durante la invulnerabilidad (i-frames), con o sin sprite.
	_visual.modulate.a = 0.4 if _stats.is_invulnerable() else 1.0


func _unhandled_input(event: InputEvent) -> void:
	_state_machine.handle_input(event)


# --- Vida ---

func take_damage(amount: int) -> void:
	_stats.take_damage(amount)


func heal(amount: int) -> void:
	_stats.heal(amount)


func kill() -> void:
	_stats.kill()


func is_dead() -> bool:
	return _is_dead


## true si una curación tendría efecto (no está muerto ni con la vida al máximo).
func can_heal() -> bool:
	return not _is_dead and not _stats.is_full()


## Empujón externo (rugido de jefe, explosiones...). Durante `control_lock`
## segundos el input horizontal no frena ni anula el empujón.
func apply_knockback(impulse: Vector2, control_lock: float = 0.3) -> void:
	if _is_dead:
		return
	velocity = impulse
	_knockback_left = control_lock


func is_knocked_back() -> bool:
	return _knockback_left > 0.0


# --- Operaciones para los estados ---

func get_state_name() -> StringName:
	return _state_machine.get_current_state_name()


func get_input_direction() -> float:
	return Input.get_axis("move_left", "move_right")


func apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var g: float = gravity * (fall_gravity_multiplier if velocity.y > 0.0 else 1.0)
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)

	# Salto variable: soltar el botón corta la subida.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier


func apply_horizontal(delta: float, direction: float) -> void:
	if _knockback_left > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
		return
	var control: float = 1.0 if is_on_floor() else air_control
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * move_speed, acceleration * control * delta)
		_set_facing(1 if direction > 0.0 else -1)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * control * delta)


## Hay un salto memorizado (buffer) y aún se puede saltar (suelo o coyote).
func wants_jump() -> bool:
	return _jump_buffer_left > 0.0 and _coyote_left > 0.0


func start_jump() -> void:
	velocity.y = jump_velocity
	_jump_buffer_left = 0.0
	_coyote_left = 0.0
	Events.player_jumped.emit()


func wants_shoot() -> bool:
	return projectile_scene != null and _shoot_cooldown_left <= 0.0 and Input.is_action_pressed("shoot")


func shoot() -> void:
	if projectile_scene == null:
		return
	_shoot_cooldown_left = shoot_cooldown
	var projectile: Projectile = projectile_scene.instantiate() as Projectile
	projectile.setup(Vector2(float(facing), 0.0), _stats.get_damage())
	# Se añade al nivel (no al jugador) para que no se mueva con él.
	var container: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	container.add_child(projectile)
	projectile.global_position = _muzzle.global_position
	Events.player_shot.emit(shoot_cooldown)
	# TODO(assets): sonido de disparo.


## Lo llaman los estados al entrar. El CharacterAnimator decide si puede
## mostrarse ya (prioridades) o tras terminar un ataque/daño en curso.
## TODO(assets): rellenar entities/player/player_animations.tres con los .piskel.
func play_animation(anim: StringName) -> void:
	current_animation = anim
	_animator.play_state(anim)


func get_displayed_animation() -> StringName:
	return _animator.current_animation


# --- Privados ---

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
	_knockback_left = maxf(_knockback_left - delta, 0.0)


func _set_facing(new_facing: int) -> void:
	if new_facing == facing:
		return
	facing = new_facing
	# Escalar el contenedor gira a la vez sprite, placeholders y Muzzle.
	_visual.scale.x = float(facing)


func _on_health_changed(current: int, maximum: int) -> void:
	Events.player_health_changed.emit(current, maximum)


func _on_damaged(_amount: int) -> void:
	if not _is_dead:
		_animator.play_state(&"hurt")


func _on_health_died() -> void:
	_is_dead = true
	_state_machine.transition_to(PlayerState.DEAD)
	# Events.player_died se emite al terminar la animación "death".


func _on_animation_one_shot_finished(anim: StringName) -> void:
	if anim == &"death":
		Events.player_died.emit()
