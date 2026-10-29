class_name MainMenu
extends Control
## Menú principal:
## Iniciar juego -> secuencia de historia (StoryCrawl) -> Nivel 1.
## Opciones -> panel con volumen de música/efectos y pantalla completa
## (persistido por GameSettings; la pantalla se elige con dos botones
## excluyentes VENTANA / COMPLETA). Salida -> cierra el juego.
## Navegable con teclado y mando (foco en los botones).

@export_file("*.tscn") var start_scene: String = "res://ui/story/StoryCrawl.tscn"

@onready var _main_buttons: VBoxContainer = %MainButtons
@onready var _start_button: Button = %StartButton
@onready var _options_button: Button = %OptionsButton
@onready var _quit_button: Button = %QuitButton
@onready var _options_panel: PanelContainer = %OptionsPanel
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _music_value: Label = %MusicValue
@onready var _sfx_value: Label = %SfxValue
@onready var _windowed_button: Button = %WindowedButton
@onready var _fullscreen_button: Button = %FullscreenButton
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	get_tree().paused = false
	AudioManager.play_music(&"menu")
	_start_button.pressed.connect(_on_start_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_music_slider.value = GameSettings.music_volume
	_sfx_slider.value = GameSettings.sfx_volume
	_update_volume_labels()
	_fullscreen_button.set_pressed_no_signal(GameSettings.fullscreen)
	_windowed_button.set_pressed_no_signal(not GameSettings.fullscreen)
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_windowed_button.pressed.connect(_on_screen_mode_pressed.bind(false))
	_fullscreen_button.pressed.connect(_on_screen_mode_pressed.bind(true))
	_options_panel.hide()
	_start_button.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _options_panel.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func is_options_open() -> bool:
	return _options_panel.visible


func _on_start_pressed() -> void:
	AudioManager.play_sfx(&"ui_select")
	_set_buttons_disabled(true)
	SceneTransition.change_scene(start_scene)


func _on_options_pressed() -> void:
	AudioManager.play_sfx(&"ui_select")
	_main_buttons.hide()
	_options_panel.show()
	_music_slider.grab_focus()


func _on_back_pressed() -> void:
	AudioManager.play_sfx(&"ui_select")
	_options_panel.hide()
	_main_buttons.show()
	_options_button.grab_focus()


func _on_music_changed(value: float) -> void:
	GameSettings.set_music_volume(value)
	_update_volume_labels()


func _on_sfx_changed(value: float) -> void:
	GameSettings.set_sfx_volume(value)
	_update_volume_labels()
	AudioManager.play_sfx(&"ui_select")


func _on_screen_mode_pressed(fullscreen: bool) -> void:
	AudioManager.play_sfx(&"ui_select")
	GameSettings.set_fullscreen(fullscreen)


func _update_volume_labels() -> void:
	_music_value.text = "%d%%" % roundi(_music_slider.value * 100.0)
	_sfx_value.text = "%d%%" % roundi(_sfx_slider.value * 100.0)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _set_buttons_disabled(value: bool) -> void:
	for button: Button in [_start_button, _options_button, _quit_button]:
		button.disabled = value
