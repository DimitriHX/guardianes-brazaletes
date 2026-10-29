extends PlayerState
## Caminando por el suelo.


func physics_update(delta: float) -> void:
	var direction: float = player.get_input_direction()
	player.apply_horizontal(delta, direction)

	if not player.is_on_floor():
		transition_requested.emit(FALL)
	elif player.wants_jump():
		transition_requested.emit(JUMP)
	elif player.wants_shoot():
		transition_requested.emit(ATTACK)
	elif direction == 0.0:
		transition_requested.emit(IDLE)
