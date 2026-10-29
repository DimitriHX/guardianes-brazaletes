extends Node
## Ajustes del jugador (Autoload "GameSettings"): volumen de música y efectos,
## silencio y pantalla completa. Se guardan en user://settings.cfg y se aplican
## a los buses de audio "Music" y "SFX" al arrancar y en cada cambio.

signal changed

const PATH: String = "user://settings.cfg"

var music_volume: float = 0.8
var sfx_volume: float = 0.9
var muted: bool = false
var fullscreen: bool = false


func _ready() -> void:
	load_settings()
	apply()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_commit()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_commit()


func set_muted(value: bool) -> void:
	muted = value
	_commit()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_commit()


func apply() -> void:
	_apply_bus(&"Music", music_volume)
	_apply_bus(&"SFX", sfx_volume)
	var master: int = AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(master, muted)
	# En headless/editor embebido no hay ventana que cambiar.
	if DisplayServer.get_name() != "headless":
		var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)


func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(PATH) != OK:
		return
	music_volume = float(config.get_value("audio", "music_volume", music_volume))
	sfx_volume = float(config.get_value("audio", "sfx_volume", sfx_volume))
	muted = bool(config.get_value("audio", "muted", muted))
	fullscreen = bool(config.get_value("video", "fullscreen", fullscreen))


func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "muted", muted)
	config.set_value("video", "fullscreen", fullscreen)
	config.save(PATH)


func _commit() -> void:
	apply()
	save_settings()
	changed.emit()


func _apply_bus(bus_name: StringName, volume: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, volume <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.001)))
