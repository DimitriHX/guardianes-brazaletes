extends PlayerState
## Muerto: inmóvil e ignora el input. Estado terminal (el LevelManager reinicia).


func enter(previous: StringName) -> void:
	super(previous)
	player.velocity = Vector2.ZERO
