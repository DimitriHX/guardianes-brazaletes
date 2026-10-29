extends CanvasLayer
## HUD mínimo de depuración: vida, coleccionables y mensajes de fin.
## Solo escucha a Events; no conoce al jugador ni al LevelManager.
## TODO(assets): sustituir por el HUD final (corazones, iconos, fuentes).

@onready var _health_label: Label = $Margin/VBox/HealthLabel
@onready var _collect_label: Label = $Margin/VBox/CollectLabel
@onready var _message_label: Label = $MessageLabel


func _ready() -> void:
	_message_label.hide()
	Events.player_health_changed.connect(_on_player_health_changed)
	Events.collectibles_changed.connect(_on_collectibles_changed)
	Events.level_completed.connect(_on_level_completed)
	Events.player_died.connect(_on_player_died)


func _on_player_health_changed(current: int, maximum: int) -> void:
	_health_label.text = "Vida: %d / %d" % [current, maximum]


func _on_collectibles_changed(collected: int, required: int) -> void:
	_collect_label.text = "Coleccionables: %d / %d" % [collected, required]


func _on_level_completed() -> void:
	_show_message("¡Nivel completado!\nPulsa R para reiniciar")


func _on_player_died() -> void:
	_show_message("Has caído...")


func _show_message(text: String) -> void:
	_message_label.text = text
	_message_label.show()
