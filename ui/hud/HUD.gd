extends CanvasLayer
## HUD de los niveles. Solo escucha a Events; no conoce al jugador, al jefe ni
## al LevelManager.
## - PlayerHealthBar: orbe de vida, recarga del disparo y progreso.
## - CoinCounter: monedas recogidas / necesarias (oculto si el nivel no tiene).
## - BossPanel: nombre y barra del jefe, solo durante el combate.
## - MessagePanel: mensajes sobre un tablón (aparece con un pequeño "pop").
## - LevelBanner: nombre del nivel al empezar, se desvanece solo.
## - PauseMenu: Esc / P / Start.

## Segundos que el rótulo del nivel permanece visible.
@export var banner_time: float = 2.5

var _message_token: int = 0

@onready var _message_panel: Control = $MessagePanel
@onready var _message_label: Label = $MessagePanel/MessageLabel
@onready var _banner: Control = $LevelBanner
@onready var _banner_label: Label = $LevelBanner/BannerLabel
@onready var _coin_counter: Control = $CoinCounter
@onready var _coin_label: Label = $CoinCounter/HBox/CoinLabel
@onready var _boss_panel: Control = $BossPanel
@onready var _boss_name: Label = $BossPanel/VBox/BossName
@onready var _boss_bar: PixelBar = $BossPanel/VBox/BossBar


func _ready() -> void:
	_message_panel.hide()
	_banner.hide()
	_boss_panel.hide()
	_coin_counter.hide()
	Events.player_died.connect(_on_player_died)
	Events.hud_message.connect(show_message)
	Events.level_started.connect(_on_level_started)
	Events.collectibles_changed.connect(_on_collectibles_changed)
	Events.boss_fight_started.connect(_on_boss_fight_started)
	Events.boss_health_changed.connect(_on_boss_health_changed)
	Events.boss_defeated.connect(_on_boss_defeated)


## duration <= 0: el mensaje se queda hasta que llegue otro.
func show_message(text: String, duration: float) -> void:
	_message_token += 1
	_message_label.text = text
	_pop_in(_message_panel)
	if duration > 0.0:
		var token: int = _message_token
		get_tree().create_timer(duration, true).timeout.connect(_hide_message.bind(token))


func is_message_visible() -> bool:
	return _message_panel.visible


func _hide_message(token: int) -> void:
	if token == _message_token:
		_fade_out(_message_panel)


func _pop_in(panel: Control) -> void:
	panel.show()
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	# El pivote se fija cuando el contenedor ya tiene su tamaño final.
	panel.pivot_offset = panel.size / 2.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _fade_out(panel: Control) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(panel.hide)


func _on_level_started(level_name: String) -> void:
	_banner_label.text = level_name
	_pop_in(_banner)
	get_tree().create_timer(banner_time).timeout.connect(_fade_out.bind(_banner))


func _on_collectibles_changed(collected: int, required: int) -> void:
	_coin_counter.visible = required > 0
	_coin_label.text = "%d/%d" % [collected, required]


func _on_player_died() -> void:
	show_message("Emma se desvanece...", 0.0)


func _on_boss_fight_started(_boss: Node, display_name: String, current: int, maximum: int) -> void:
	_boss_name.text = display_name
	_boss_bar.max_value = maximum
	_boss_bar.value = current
	_pop_in(_boss_panel)


func _on_boss_health_changed(current: int, maximum: int) -> void:
	_boss_bar.max_value = maximum
	_boss_bar.set_value_animated(current)


func _on_boss_defeated(_boss: Node) -> void:
	_fade_out(_boss_panel)
