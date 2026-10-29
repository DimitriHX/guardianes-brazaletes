extends BossState
## Retrocede alejándose del jugador un momento (ventana para atacarle) y
## vuelve a perseguir.

@export var retreat_speed: float = 110.0
@export var retreat_time: float = 0.8

var _time_left: float = 0.0


func enter(previous: StringName) -> void:
	super(previous)
	_time_left = retreat_time


func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	_time_left -= delta
	# Se aleja sin girarse (mira al jugador mientras retrocede).
	boss.face_target()
	boss.velocity.x = -float(boss.facing) * retreat_speed
	var blocked: bool = boss.is_on_wall() and signf(boss.get_wall_normal().x) == float(boss.facing)
	if _time_left <= 0.0 or blocked:
		transition_requested.emit(&"Chase")
