extends PlayerState
## Disparo. Dispara al entrar y mantiene el control (se puede andar, caer y
## saltar disparando). Dura `duration` segundos para dar tiempo a la animación;
## mantener el botón vuelve a entrar en cuanto el cooldown lo permite.

## Segundos que dura el estado (debe ser <= shoot_cooldown del Player).
@export var duration: float = 0.15

var _time_left: float = 0.0


func enter(previous: StringName) -> void:
	super(previous)
	_time_left = duration
	player.shoot()


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal(delta, player.get_input_direction())
	_time_left -= delta

	if player.wants_jump():
		transition_requested.emit(JUMP)
	elif _time_left <= 0.0:
		transition_requested.emit(_locomotion_state())
