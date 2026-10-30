class_name MainMenu
extends Control
## Menú principal:
## Iniciar juego -> secuencia de historia (StoryCrawl) -> Nivel 1.
## Opciones -> panel con volumen de música/efectos, vibración de cámara y pantalla completa
## (persistido por GameSettings; la pantalla se elige con dos botones
## excluyentes VENTANA / COMPLETA). Salida -> cierra el juego.
## Navegable con teclado y mando (foco en los botones).
## El título late suavemente (escala) mientras su shader hace fluir los colores;
## al abrir, el título aparece y los botones entran desde la derecha.

## Escala máxima del latido del título y segundos por latido.
const TITLE_PULSE_SCALE: float = 1.04
const TITLE_PULSE_TIME: float = 1.4

@export_file("*.tscn") var start_scene: String = "res://ui/story/StoryCrawl.tscn"

@onready var _title: Label = %Title
@onready var _main_buttons: VBoxContainer = %MainButtons
@onready var _start_button: Button = %StartButton
@onready var _options_button: Button = %OptionsButton
@onready var _quit_button: Button = %QuitButton
@onready var _options_panel: PanelContainer = %OptionsPanel
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _music_value: Label = %MusicValue
@onready var _sfx_value: Label = %SfxValue
@onready var _shake_slider: HSlider = %ShakeSlider
@onready var _shake_value: Label = %ShakeValue
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
	_shake_slider.value = GameSettings.screen_shake
	_update_volume_labels()
	_fullscreen_button.set_pressed_no_signal(GameSettings.fullscreen)
	_windowed_button.set_pressed_no_signal(not GameSettings.fullscreen)
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_shake_slider.value_changed.connect(_on_shake_changed)
	_windowed_button.pressed.connect(_on_screen_mode_pressed.bind(false))
	_fullscreen_button.pressed.connect(_on_screen_mode_pressed.bind(true))
	_options_panel.hide()
	_start_button.grab_focus.call_deferred()
	_title.resized.connect(_center_title_pivot)
	_center_title_pivot()
	_play_intro()


func _center_title_pivot() -> void:
	_title.pivot_offset = _title.size / 2.0


func _play_intro() -> void:
	_title.modulate.a = 0.0
	_title.scale = Vector2(0.9, 0.9)
	var intro: Tween = create_tween().set_parallel()
	intro.tween_property(_title, "modulate:a", 1.0, 0.8)
	intro.tween_property(_title, "scale", Vector2.ONE, 0.8) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Los botones entran desde la derecha, uno tras otro (en el VBox están en x = 0).
	var buttons: Array[Button] = [_start_button, _options_button, _quit_button]
	for i: int in buttons.size():
		var button: Button = buttons[i]
		button.modulate.a = 0.0
		var slide: Tween = create_tween()
		slide.tween_interval(0.25 + 0.1 * i)
		slide.tween_property(button, "position:x", 0.0, 0.45).from(300.0) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		slide.parallel().tween_property(button, "modulate:a", 1.0, 0.35)
	intro.chain().tween_callback(_start_title_pulse)


func _start_title_pulse() -> void:
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(_title, "scale", Vector2.ONE * TITLE_PULSE_SCALE, TITLE_PULSE_TIME / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(_title, "scale", Vector2.ONE, TITLE_PULSE_TIME / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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


func _on_shake_changed(value: float) -> void:
	GameSettings.set_screen_shake(value)
	_update_volume_labels()


func _on_screen_mode_pressed(fullscreen: bool) -> void:
	AudioManager.play_sfx(&"ui_select")
	GameSettings.set_fullscreen(fullscreen)


func _update_volume_labels() -> void:
	_music_value.text = "%d%%" % roundi(_music_slider.value * 100.0)
	_sfx_value.text = "%d%%" % roundi(_sfx_slider.value * 100.0)
	_shake_value.text = "%d%%" % roundi(_shake_slider.value * 100.0)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _set_buttons_disabled(value: bool) -> void:
	for button: Button in [_start_button, _options_button, _quit_button]:
		button.disabled = value
