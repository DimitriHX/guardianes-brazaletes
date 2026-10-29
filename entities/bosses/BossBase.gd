class_name BossBase
extends CharacterBody2D
## Base para jefes. Igual que el Player, es el "cuerpo": expone operaciones
## (gravedad, orientación, distancia al objetivo, cooldowns de acciones) y la
## StateMachine hija es el "cerebro" con los patrones de ataque.
## - Dormido hasta activate(): no hace daño ni recibe daño.
## - Fases: al cruzar cada umbral de vida (phase_thresholds) sube `phase`,
##   cambia el multiplicador de velocidad y se avisa por señal y por Events.
## - Combate por componentes: Stats + Hurtbox (recibe) + Hitbox (contacto).

signal phase_changed(phase: int)

@export var display_name: String = "Jefe"
@export var gravity: float = 1200.0
@export var max_fall_speed: float = 900.0
## Estado al que pasa al activarse.
@export var first_state: StringName = &"Chase"
## Hacia dónde mira el dibujo original. Desmarcar si el sprite sale al revés.
@export var art_faces_right: bool = true
@export_group("Fases")
## Fracciones de vida que inician cada fase: [0.5] = fase 2 al 50 %.
@export var phase_thresholds: Array[float] = [0.5]
## Multiplicador de velocidad por fase (índice 0 = fase 1).
@export var phase_speed_multipliers: Array[float] = [1.0, 1.4]
## Mensaje del HUD al empezar cada fase (índice 0 = fase 2). Vacío = ninguno.
@export var phase_messages: Array[String] = []

var target: Node2D
var phase: int = 1
var facing: int = -1
var is_active: bool = false

var _cooldowns: Dictionary[StringName, float] = {}
var _dormant_taken_multiplier: float = 1.0

@onready var stats: StatsComponent = $Stats
@onready var hitbox: HitboxComponent = $Hitbox
@onready var animator: CharacterAnimator = $Visual/Animator
@onready var _visual: Node2D = $Visual
@onready var _state_machine: StateMachine = $StateMachine


func _ready() -> void:
	for child: Node in _state_machine.get_children():
		var state: BossState = child as BossState
		if state != null:
			state.setup(self)
	stats.health_changed.connect(_on_health_changed)
	stats.damaged.connect(_on_damaged)
	stats.died.connect(_on_died)
	animator.one_shot_finished.connect(_on_animation_one_shot_finished)
	# Dormido: inofensivo e invulnerable hasta que empiece el combate.
	hitbox.active = false
	_dormant_taken_multiplier = stats.damage_taken_multiplier
	stats.damage_taken_multiplier = 0.0
	_set_facing(facing)
	_state_machine.start()


func _physics_process(delta: float) -> void:
	for action: StringName in _cooldowns.keys():
		_cooldowns[action] = maxf(_cooldowns[action] - delta, 0.0)
	_state_machine.physics_update(delta)
	move_and_slide()


func activate(new_target: Node2D) -> void:
	if is_active or stats.is_dead():
		return
	target = new_target
	is_active = true
	hitbox.active = true
	stats.damage_taken_multiplier = _dormant_taken_multiplier
	Events.boss_fight_started.emit(self, display_name, stats.current_health, stats.max_health)
	_state_machine.transition_to(first_state)


## Daño directo (sin Hurtbox).
func take_damage(amount: int) -> void:
	stats.take_damage(amount)


func get_state_name() -> StringName:
	return _state_machine.get_current_state_name()


# --- Operaciones para los estados ---

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)


## Multiplicador de la fase actual (velocidad y ritmo de los ataques).
func speed_multiplier() -> float:
	if phase_speed_multipliers.is_empty():
		return 1.0
	return phase_speed_multipliers[mini(phase - 1, phase_speed_multipliers.size() - 1)]


func has_valid_target() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return not (target.has_method("is_dead") and bool(target.call("is_dead")))


func distance_to_target() -> float:
	return absf(target.global_position.x - global_position.x) if has_valid_target() else INF


## 1 si el objetivo está a la derecha, -1 si está a la izquierda.
func direction_to_target() -> int:
	if not has_valid_target():
		return facing
	return 1 if target.global_position.x >= global_position.x else -1


func face_target() -> void:
	_set_facing(direction_to_target())


func set_facing(new_facing: int) -> void:
	_set_facing(new_facing)


func is_action_ready(action: StringName) -> bool:
	return _cooldowns.get(action, 0.0) <= 0.0


## Los cooldowns se acortan en fases más rápidas.
func start_cooldown(action: StringName, seconds: float) -> void:
	_cooldowns[action] = seconds / speed_multiplier()


func play_animation(anim: StringName) -> void:
	animator.play_state(anim)


# --- Privados ---

func _set_facing(new_facing: int) -> void:
	facing = 1 if new_facing >= 0 else -1
	# Escalar el contenedor gira sprite, placeholder y Hitbox a la vez.
	_visual.scale.x = float(facing) * (1.0 if art_faces_right else -1.0)


func _on_health_changed(current: int, maximum: int) -> void:
	Events.boss_health_changed.emit(current, maximum)
	while current > 0 and phase - 1 < phase_thresholds.size() \
			and float(current) <= float(maximum) * phase_thresholds[phase - 1]:
		phase += 1
		phase_changed.emit(phase)
		Events.boss_phase_changed.emit(self, phase)
		var message_index: int = phase - 2
		if message_index < phase_messages.size() and not phase_messages[message_index].is_empty():
			Events.hud_message.emit(phase_messages[message_index], 2.0)


func _on_damaged(_amount: int) -> void:
	if not stats.is_dead():
		animator.play_state(&"hurt")


func _on_died() -> void:
	hitbox.active = false
	_state_machine.transition_to(&"Dead")


func _on_animation_one_shot_finished(anim: StringName) -> void:
	if anim == &"death":
		Events.boss_defeated.emit(self)
