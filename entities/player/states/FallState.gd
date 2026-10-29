extends PlayerState
## En el aire bajando (o subiendo tras un ataque aéreo). Gestiona el coyote time
## y el jump buffer: wants_jump() se comprueba antes de aterrizar para que un
## salto memorizado salga en el mismo frame en que se toca el suelo.


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal(delta, player.get_input_direction())

	if player.wants_jump():
		transition_requested.emit(JUMP)
	elif player.wants_shoot():
		transition_requested.emit(ATTACK)
	elif player.is_on_floor():
		transition_requested.emit(_locomotion_state())
