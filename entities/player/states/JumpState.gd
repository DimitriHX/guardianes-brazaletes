extends PlayerState
## Fase ascendente del salto. Al entrar aplica el impulso; pasa a Fall al
## empezar a bajar (o al chocar con un techo).


func enter(previous: StringName) -> void:
	super(previous)
	player.start_jump()


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal(delta, player.get_input_direction())

	if player.wants_shoot():
		transition_requested.emit(ATTACK)
	elif player.velocity.y >= 0.0:
		transition_requested.emit(FALL)
