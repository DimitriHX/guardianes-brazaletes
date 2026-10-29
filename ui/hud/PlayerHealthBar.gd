class_name PlayerHealthBar
extends Control
## Barra de vida del jugador (arte de GandalfHardcore "Hp bar"):
## - Orbe rojo: vida, se vacía de arriba abajo.
## - Barra amarilla: recarga del disparo (llena = se puede disparar).
## - Barra azul: progreso de coleccionables (se oculta si el nivel no tiene).
## Solo escucha a Events; no conoce al jugador ni al LevelManager.
## Las piezas se colocan en coordenadas del arte (116x64) y el nodo se escala.

## Segundos que tarda el orbe en animar un cambio de vida.
@export var health_tween_time: float = 0.25

var _cooldown_total: float = 0.0
var _cooldown_left: float = 0.0
var _health_tween: Tween

@onready var _orb: TextureProgressBar = $Orb
@onready var _cooldown_bar: TextureProgressBar = $CooldownBar
@onready var _collect_bar: TextureProgressBar = $CollectBar
@onready var _health_label: Label = $HealthLabel


func _ready() -> void:
	_cooldown_bar.value = _cooldown_bar.max_value
	_collect_bar.hide()
	Events.player_health_changed.connect(_on_player_health_changed)
	Events.player_shot.connect(_on_player_shot)
	Events.collectibles_changed.connect(_on_collectibles_changed)


func _process(delta: float) -> void:
	if _cooldown_left <= 0.0:
		return
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_cooldown_bar.value = _cooldown_bar.max_value * (1.0 - _cooldown_left / _cooldown_total)


func get_health_ratio() -> float:
	return _orb.value / _orb.max_value


func _on_player_health_changed(current: int, maximum: int) -> void:
	_health_label.text = "%d/%d" % [current, maximum]
	var target: float = _orb.max_value * float(current) / float(maxi(maximum, 1))
	if _health_tween != null and _health_tween.is_valid():
		_health_tween.kill()
	if not is_inside_tree() or health_tween_time <= 0.0:
		_orb.value = target
		return
	_health_tween = create_tween()
	_health_tween.tween_property(_orb, "value", target, health_tween_time)


func _on_player_shot(cooldown: float) -> void:
	if cooldown <= 0.0:
		return
	_cooldown_total = cooldown
	_cooldown_left = cooldown
	_cooldown_bar.value = 0.0


func _on_collectibles_changed(collected: int, required: int) -> void:
	_collect_bar.visible = required > 0
	if required > 0:
		_collect_bar.value = _collect_bar.max_value * clampf(float(collected) / float(required), 0.0, 1.0)
