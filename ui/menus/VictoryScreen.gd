class_name VictoryScreen
extends Control
## Pantalla "¡Victoria!" (Sprint E):
## - Puede usarse como overlay dentro del HUD (se abre al emitir
##   `Events.victory_screen_requested` o cuando un nivel termina con `pause_on_complete = true`)
##   o como escena independiente (`SceneTransition.change_scene("res://ui/menus/VictoryScreen.tscn")`).
## - Ofrece botones navegables por teclado/mando para Reiniciar o Volver al Menú Principal.

signal opened
signal closed

@export_file("*.tscn") var restart_scene: String = "res://levels/sueno_1/Bosque.tscn"
@export_file("*.tscn") var menu_scene: String = "res://ui/menus/MainMenu.tscn"
@export var default_subtitle: String = "El Cadejo blanco vuelve a velar tus sueños."
## Duración (s) del fundido lento con porcentaje ("Despertando... X%") al volver al menú.
@export var menu_fade_time: float = 3.5

var is_open: bool = false

@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _restart_button: Button = %RestartButton
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_restart_button.pressed.connect(_on_restart_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	Events.victory_screen_requested.connect(open)
	if get_tree().current_scene == self:
		open(default_subtitle)
	else:
		hide()


func open(subtitle_text: String = "") -> void:
	if is_open:
		return
	is_open = true
	_subtitle_label.text = default_subtitle if subtitle_text.is_empty() else subtitle_text
	show()
	if get_tree().current_scene != self:
		get_tree().paused = true
	AudioManager.play_music(&"victory")
	_restart_button.grab_focus.call_deferred()
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	if get_tree().current_scene != self:
		get_tree().paused = false
	closed.emit()


func _on_restart_pressed() -> void:
	AudioManager.play_sfx(&"ui_select")
	var standalone: bool = get_tree().current_scene == self
	close()
	if standalone:
		SceneTransition.change_scene(restart_scene)
	else:
		Events.level_restart_requested.emit()


func _on_menu_pressed() -> void:
	AudioManager.play_sfx(&"ui_select")
	var standalone: bool = get_tree().current_scene == self
	var fade_duration: float = _resolve_fade_duration()
	close()
	if standalone:
		SceneTransition.fade_to_scene(menu_scene, fade_duration)
	else:
		Events.level_fade_requested.emit(menu_scene, fade_duration)


func _resolve_fade_duration() -> float:
	var scene: Node = get_tree().current_scene
	if scene != null:
		var exit_door: Node = scene.get_node_or_null("ExitDoor")
		if exit_door != null:
			var door_fade: float = float(exit_door.get("fade_out_time"))
			if door_fade > 0.0:
				return door_fade
	return menu_fade_time
