class_name DialogueBox
extends Control
## Caja de diálogo inferior (la voz de la pulsera y otros personajes).
## Escucha Events.dialogue_requested; encola las líneas y las muestra con efecto
## de máquina de escribir. No pausa el juego: cada línea avanza sola tras un
## tiempo de lectura proporcional a su longitud.

@export var chars_per_second: float = 45.0
## Tiempo de lectura tras escribir la línea: base + por carácter.
@export var read_time_base: float = 1.4
@export var read_time_per_char: float = 0.035

var _queue: Array[Dictionary] = []
var _line_time: float = 0.0
var _line_duration: float = 0.0
var _active: bool = false

@onready var _speaker: Label = %Speaker
@onready var _text: Label = %Text


func _ready() -> void:
	hide()
	Events.dialogue_requested.connect(say)


func _process(delta: float) -> void:
	if not _active:
		return
	_line_time += delta
	var total: int = _text.get_total_character_count()
	_text.visible_characters = mini(int(_line_time * chars_per_second), total)
	if _line_time >= _line_duration:
		_next_line()


func say(speaker: String, lines: PackedStringArray) -> void:
	for line: String in lines:
		_queue.append({"speaker": speaker, "text": line})
	if not _active:
		_next_line()


func is_talking() -> bool:
	return _active


func get_current_text() -> String:
	return _text.text if _active else ""


## Salta todas las líneas pendientes.
func clear() -> void:
	_queue.clear()
	_finish()


func _next_line() -> void:
	if _queue.is_empty():
		_finish()
		return
	var line: Dictionary = _queue.pop_front()
	_speaker.text = String(line["speaker"])
	_text.text = String(line["text"])
	_text.visible_characters = 0
	_line_time = 0.0
	var length: int = _text.text.length()
	_line_duration = float(length) / chars_per_second + read_time_base + float(length) * read_time_per_char
	_active = true
	show()


func _finish() -> void:
	var was_active: bool = _active
	_active = false
	hide()
	if was_active:
		Events.dialogue_finished.emit()
