class_name PlayerHealthBar
extends Control
## Indicador de vida del jugador (arte de GandalfHardcore "Hp bar", recortado
## al orbe y la estatua): el orbe rojo se vacía de arriba abajo y en el centro
## se lee la vida actual / máxima.
## Solo escucha a Events; no conoce al jugador ni al LevelManager.
## Las piezas se colocan en coordenadas del arte (69x64) y el nodo se escala.

## Segundos que tarda el orbe en animar un cambio de vida.
@export var health_tween_time: float = 0.25

var _health_tween: Tween

@onready var _orb: TextureProgressBar = $Orb
@onready var _health_label: Label = $HealthLabel


func _ready() -> void:
	Events.player_health_changed.connect(_on_player_health_changed)


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
