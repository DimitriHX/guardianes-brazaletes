class_name EnemyPatrol
extends CharacterBody2D
## Enemigo básico: patrulla de lado a lado y se gira ante paredes y bordes
## (RayCast2D hacia el suelo delante de él).
## Combate por componentes: Hurtbox (capa Enemies) recibe los golpes y los pasa
## a Stats; Hitbox (continuo, máscara Player) hace el daño por contacto.
## Animación con CharacterAnimator: walk, attack (al golpear), hurt y death.
## Al morir deja de colisionar y de hacer daño, reproduce "death" y se libera.
## Capa 3 (Enemies); colisiona con World (1).

@export var move_speed: float = 80.0
@export var gravity: float = 1200.0
@export var max_fall_speed: float = 900.0
## Dirección inicial: 1 derecha, -1 izquierda.
@export_enum("Izquierda:-1", "Derecha:1") var start_direction: int = -1
@export var death_effect: PackedScene
## Seguridad: se libera aunque la animación de muerte no termine.
@export var max_death_time: float = 2.0

var direction: int = -1
var is_dying: bool = false

@onready var _visual: Node2D = $Visual
@onready var _ledge_ray: RayCast2D = $Visual/LedgeRay
@onready var _animator: CharacterAnimator = $Visual/Animator
@onready var _stats: StatsComponent = $Stats
@onready var _hitbox: HitboxComponent = $Hitbox
@onready var _hurtbox: HurtboxComponent = $Hurtbox


func _ready() -> void:
	_set_direction(start_direction)
	_stats.died.connect(_on_stats_died)
	_stats.damaged.connect(_on_stats_damaged)
	_hitbox.hit_landed.connect(_on_hit_landed)
	_animator.one_shot_finished.connect(_on_animation_one_shot_finished)
	_animator.play_state(&"walk")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	elif not is_dying and _should_turn():
		_set_direction(-direction)

	velocity.x = 0.0 if is_dying else direction * move_speed
	move_and_slide()


## Daño directo (sin Hurtbox): trampas, scripts de nivel, etc.
func take_damage(amount: int) -> void:
	_stats.take_damage(amount)


func _should_turn() -> bool:
	# Pared delante o hueco sin suelo delante.
	if is_on_wall() and signf(get_wall_normal().x) == -float(direction):
		return true
	return not _ledge_ray.is_colliding()


func _set_direction(new_direction: int) -> void:
	direction = 1 if new_direction >= 0 else -1
	# Escalar el contenedor gira sprite y LedgeRay a la vez (el ray sigue delante).
	_visual.scale.x = float(direction)
	_ledge_ray.force_raycast_update()


func _on_stats_damaged(_amount: int) -> void:
	if not is_dying:
		_animator.play_state(&"hurt")


func _on_hit_landed(_hurtbox: HurtboxComponent) -> void:
	_animator.play_state(&"attack")


func _on_stats_died() -> void:
	is_dying = true
	Events.enemy_died.emit(self)
	_hitbox.active = false
	_hitbox.set_deferred("monitoring", false)
	_hurtbox.set_deferred("monitorable", false)
	# Sigue sobre el suelo (World) pero ya no es "enemigo" para nadie.
	set_deferred("collision_layer", 0)
	Effect.spawn(death_effect, self, global_position)
	_animator.play_state(&"death")
	get_tree().create_timer(max_death_time).timeout.connect(queue_free)


func _on_animation_one_shot_finished(anim: StringName) -> void:
	if anim == &"death":
		queue_free()
