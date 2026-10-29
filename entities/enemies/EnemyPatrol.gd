class_name EnemyPatrol
extends CharacterBody2D
## Enemigo básico: patrulla de lado a lado, se gira ante paredes y bordes
## (RayCast2D hacia el suelo delante de él) y daña al jugador por contacto.
## Capa 3 (Enemies); colisiona con World (1). El Hitbox detecta al Player (2).

@export var move_speed: float = 80.0
@export var gravity: float = 1200.0
@export var max_fall_speed: float = 900.0
@export var contact_damage: int = 1
## Dirección inicial: 1 derecha, -1 izquierda.
@export_enum("Izquierda:-1", "Derecha:1") var start_direction: int = -1

var direction: int = -1

@onready var _visual: Node2D = $Visual
@onready var _ledge_ray: RayCast2D = $Visual/LedgeRay
@onready var _hitbox: Area2D = $Hitbox
@onready var _health: HealthComponent = $HealthComponent


func _ready() -> void:
	_set_direction(start_direction)
	_health.died.connect(_on_health_died)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	elif _should_turn():
		_set_direction(-direction)

	velocity.x = direction * move_speed
	move_and_slide()
	_apply_contact_damage()


func take_damage(amount: int) -> void:
	_health.take_damage(amount)
	# TODO(assets): flash/animación de "recibir daño".


func _should_turn() -> bool:
	# Pared delante o hueco sin suelo delante.
	if is_on_wall() and signf(get_wall_normal().x) == -float(direction):
		return true
	return not _ledge_ray.is_colliding()


func _apply_contact_damage() -> void:
	# Se comprueba cada frame: si el jugador sigue dentro, vuelve a recibir
	# daño en cuanto terminen sus i-frames.
	for body: Node2D in _hitbox.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.call("take_damage", contact_damage)


func _set_direction(new_direction: int) -> void:
	direction = 1 if new_direction >= 0 else -1
	# TODO(assets): con AnimatedSprite2D usar flip_h; el RayCast debe seguir delante.
	_visual.scale.x = float(direction)
	_ledge_ray.force_raycast_update()


func _on_health_died() -> void:
	Events.enemy_died.emit(self)
	# TODO(assets): animación/partículas de muerte antes de liberar.
	queue_free()
