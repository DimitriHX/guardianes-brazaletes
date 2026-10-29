extends BossState
## Rugido: se planta, ruge y empuja al jugador si está cerca (no hace daño).
## Sirve para quitárselo de encima cuando se pega demasiado.

@export var windup_time: float = 0.35
@export var recovery_time: float = 0.5
@export var push_range: float = 170.0
@export var push_force: Vector2 = Vector2(520.0, -260.0)
@export var cooldown: float = 4.0

var _windup_left: float = 0.0
var _recovery_left: float = 0.0


func enter(previous: StringName) -> void:
	super(previous)
	boss.face_target()
	_windup_left = windup_time
	_recovery_left = recovery_time


func exit() -> void:
	boss.start_cooldown(&"roar", cooldown)


func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	boss.velocity.x = 0.0
	if _windup_left > 0.0:
		_windup_left -= delta
		if _windup_left <= 0.0:
			_roar()
		return
	_recovery_left -= delta
	if _recovery_left <= 0.0:
		transition_requested.emit(&"Chase")


func _roar() -> void:
	# TODO(assets): onda expansiva/partículas del rugido.
	Events.sfx_requested.emit(&"boss_roar")
	Events.camera_shake_requested.emit(5.0, 0.25)
	if not boss.has_valid_target() or boss.distance_to_target() > push_range:
		return
	if boss.target.has_method("apply_knockback"):
		# Lado real del jugador (sin la zona muerta de giro del jefe).
		var away: float = 1.0 if boss.target.global_position.x >= boss.global_position.x else -1.0
		boss.target.call("apply_knockback", Vector2(push_force.x * away, push_force.y))
