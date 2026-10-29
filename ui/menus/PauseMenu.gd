class_name PauseMenu
extends Control
## Menú de pausa (acción "pause": Esc / P / Start). Pausa el árbol y muestra
## Continuar / Reiniciar con foco para teclado y mando.
## No se abre si el juego ya está pausado por otro sistema (p. ej. la pantalla
## de victoria del LevelManager) ni durante una transición de escena.

signal opened
signal closed

@export_file("*.tscn") var menu_scene: String = "res://ui/menus/MainMenu.tscn"

var is_open: bool = false

@onready var _continue_button: Button = %ContinueButton
@onready var _restart_button: Button = %RestartButton
@onready var _menu_button: Button = get_node_or_null("%MenuButton") as Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_continue_button.pressed.connect(close)
	_restart_button.pressed.connect(_on_restart_pressed)
	if _menu_button != null:
		_menu_button.pressed.connect(_on_menu_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if is_open:
		close()
	elif can_open():
		open()
	else:
		return
	get_viewport().set_input_as_handled()


func can_open() -> bool:
	return not get_tree().paused and not SceneTransition.is_transitioning


func open() -> void:
	if is_open:
		return
	is_open = true
	show()
	get_tree().paused = true
	_continue_button.grab_focus()
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	get_tree().paused = false
	closed.emit()


func _on_restart_pressed() -> void:
	close()
	Events.level_restart_requested.emit()


func _on_menu_pressed() -> void:
	close()
	SceneTransition.change_scene(menu_scene)
