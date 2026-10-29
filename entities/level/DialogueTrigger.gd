class_name DialogueTrigger
extends Area2D
## Zona que lanza un diálogo cuando el jugador entra (una vez por defecto).
## Area2D sin capa; detecta al Player (2). El texto se edita en el inspector.

@export var speaker: String = "Pulsera"
@export_multiline var lines: PackedStringArray = PackedStringArray()
@export var once: bool = true

var _fired: bool = false
var _player_inside: bool = false


func _physics_process(_delta: float) -> void:
	var inside: bool = false
	for body: Node2D in get_overlapping_bodies():
		if body.is_in_group("player"):
			inside = true
			break
	# Solo al ENTRAR (no en cada frame mientras siga dentro).
	if inside and not _player_inside and not (_fired and once):
		_fire()
	_player_inside = inside


func _fire() -> void:
	if lines.is_empty():
		return
	_fired = true
	Events.dialogue_requested.emit(speaker, lines)
	if once:
		set_physics_process(false)
