extends CanvasLayer
## HUD mínimo de depuración: vida, coleccionables, barra del jefe y mensajes.
## Solo escucha a Events; no conoce al jugador, al jefe ni al LevelManager.
## TODO(assets): sustituir por el HUD final (corazones, iconos, fuentes, marco de la barra).

var _message_token: int = 0

@onready var _health_label: Label = $Margin/VBox/HealthLabel
@onready var _collect_label: Label = $Margin/VBox/CollectLabel
@onready var _message_label: Label = $MessageLabel
@onready var _boss_panel: Control = $BossPanel
@onready var _boss_name: Label = $BossPanel/VBox/BossName
@onready var _boss_bar: ProgressBar = $BossPanel/VBox/BossBar


func _ready() -> void:
	_message_label.hide()
	_boss_panel.hide()
	Events.player_health_changed.connect(_on_player_health_changed)
	Events.collectibles_changed.connect(_on_collectibles_changed)
	Events.player_died.connect(_on_player_died)
	Events.hud_message.connect(show_message)
	Events.boss_fight_started.connect(_on_boss_fight_started)
	Events.boss_health_changed.connect(_on_boss_health_changed)
	Events.boss_defeated.connect(_on_boss_defeated)


## duration <= 0: el mensaje se queda hasta que llegue otro.
func show_message(text: String, duration: float) -> void:
	_message_token += 1
	_message_label.text = text
	_message_label.show()
	if duration > 0.0:
		var token: int = _message_token
		get_tree().create_timer(duration, true).timeout.connect(_hide_message.bind(token))


func _hide_message(token: int) -> void:
	if token == _message_token:
		_message_label.hide()


func _on_player_health_changed(current: int, maximum: int) -> void:
	_health_label.text = "Vida: %d / %d" % [current, maximum]


func _on_collectibles_changed(collected: int, required: int) -> void:
	_collect_label.visible = required > 0
	_collect_label.text = "Coleccionables: %d / %d" % [collected, required]


func _on_player_died() -> void:
	show_message("Has caído...", 0.0)


func _on_boss_fight_started(_boss: Node, display_name: String, current: int, maximum: int) -> void:
	_boss_name.text = display_name
	_boss_bar.max_value = maximum
	_boss_bar.value = current
	_boss_panel.show()


func _on_boss_health_changed(current: int, maximum: int) -> void:
	_boss_bar.max_value = maximum
	_boss_bar.value = current


func _on_boss_defeated(_boss: Node) -> void:
	_boss_panel.hide()
