class_name SplashScreen
extends Control
## Pantalla de inicio comercial del estudio ("PLAYER FIRE"):
## - Fondo negro puro con el nombre del equipo en rojo fuego centrado y brasas suaves.
## - Aparece poco a poco (fade-in), se mantiene unos instantes con un pulso cálido
##   y se desvanece a negro (fade-out) antes de abrir el Menú Principal.
## - Se puede saltar pulsando Espacio/Enter/Esc/Clic (`skip_splash()`).

@export_file("*.tscn") var next_scene: String = "res://ui/menus/MainMenu.tscn"
@export var initial_delay: float = 0.25
@export var fade_in_time: float = 1.3
@export var hold_time: float = 1.1
@export var fade_out_time: float = 1.0

var _finished: bool = false
var _tween: Tween

@onready var _brand_box: Control = %BrandBox
@onready var _team_label: Label = %TeamLabel
@onready var _embers: CPUParticles2D = %EmberParticles


func _ready() -> void:
	get_tree().paused = false
	_brand_box.modulate.a = 0.0
	_brand_box.scale = Vector2(0.92, 0.92)
	_update_pivot.call_deferred()
	_play_sequence()


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("jump"):
		get_viewport().set_input_as_handled()
		skip_splash()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		get_viewport().set_input_as_handled()
		skip_splash()


func get_brand_opacity() -> float:
	return _brand_box.modulate.a if _brand_box != null else 0.0


func skip_splash() -> void:
	if _finished:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_go_to_next_scene()


func _update_pivot() -> void:
	if _brand_box != null:
		_brand_box.pivot_offset = _brand_box.size * 0.5


func _play_sequence() -> void:
	if _embers != null:
		_embers.emitting = true
	_tween = create_tween()
	_tween.tween_interval(initial_delay)
	# 1. Aparece poco a poco (fade-in + ligero zoom suave)
	_tween.tween_property(_brand_box, "modulate:a", 1.0, fade_in_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_brand_box, "scale", Vector2.ONE, fade_in_time + hold_time * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 2. Pulso de fuego mientras se mantiene en pantalla
	_tween.tween_property(_team_label, "self_modulate", Color(1.25, 1.12, 1.0, 1.0), hold_time * 0.5).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_team_label, "self_modulate", Color.WHITE, hold_time * 0.5).set_trans(Tween.TRANS_SINE)
	# 3. Se desvanece a negro como en los juegos comerciales
	_tween.tween_property(_brand_box, "modulate:a", 0.0, fade_out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_go_to_next_scene)


func _go_to_next_scene() -> void:
	if _finished or next_scene.is_empty():
		return
	_finished = true
	get_tree().change_scene_to_file(next_scene)
