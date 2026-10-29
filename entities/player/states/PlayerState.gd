class_name PlayerState
extends State
## Base de los estados del jugador. Recibe al Player mediante setup()
## (inyección desde el padre) y usa sus métodos públicos de movimiento.

const IDLE: StringName = &"Idle"
const WALK: StringName = &"Walk"
const JUMP: StringName = &"Jump"
const FALL: StringName = &"Fall"
const ATTACK: StringName = &"Attack"
const DEAD: StringName = &"Dead"

var player: Player


func setup(controlled: Player) -> void:
	player = controlled


func enter(_previous: StringName) -> void:
	player.play_animation(animation)


## Estado de locomoción que corresponde ahora mismo (tras una acción o al aterrizar).
func _locomotion_state() -> StringName:
	if not player.is_on_floor():
		return FALL
	if player.get_input_direction() != 0.0:
		return WALK
	return IDLE
