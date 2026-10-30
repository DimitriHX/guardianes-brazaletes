class_name PlayerHealthBar
extends Control
## Indicador de vida del jugador: un orbe de vidrio con anillo dorado y la gema
## del brazalete (arte generado por tools/make_health_orb.py). El líquido rojo
## baja de arriba abajo al perder vida y en el centro se lee vida actual / máxima.
## Con poca vida el orbe late para avisar.
## Solo escucha a Events; no conoce al jugador ni al LevelManager.
## Las piezas se colocan en coordenadas del arte (56x56) y el nodo se escala.

## Segundos que tarda el orbe en animar un cambio de vida.
@export var health_tween_time: float = 0.25
## Por debajo de esta fracción de vida el orbe late.
@export_range(0.0, 1.0, 0.05) var low_health_ratio: float = 0.34

var _health_tween: Tween
var _pulse_tween: Tween
var _base_scale: Vector2

@onready var _orb: TextureProgressBar = $Orb
@onready var _health_label: Label = $HealthLabel


func _ready() -> void:
	_base_scale = scale
	Events.player_health_changed.connect(_on_player_health_changed)


func get_health_ratio() -> float:
	return _orb.value / _orb.max_value


func is_pulsing() -> bool:
	return _pulse_tween != null and _pulse_tween.is_valid()


func _on_player_health_changed(current: int, maximum: int) -> void:
	_health_label.text = "%d/%d" % [current, maximum]
	var ratio: float = float(current) / float(maxi(maximum, 1))
	_set_low_health_pulse(current > 0 and ratio <= low_health_ratio)
	var target: float = _orb.max_value * ratio
	if _health_tween != null and _health_tween.is_valid():
		_health_tween.kill()
	if not is_inside_tree() or health_tween_time <= 0.0:
		_orb.value = target
		return
	_health_tween = create_tween()
	_health_tween.tween_property(_orb, "value", target, health_tween_time)


## Latido: dos golpes rápidos y una pausa, como un corazón.
func _set_low_health_pulse(enabled: bool) -> void:
	if enabled == is_pulsing():
		return
	if not enabled:
		_pulse_tween.kill()
		_pulse_tween = null
		scale = _base_scale
		return
	if not is_inside_tree():
		return
	_pulse_tween = create_tween().set_loops()
	for i: int in 2:
		_pulse_tween.tween_property(self, "scale", _base_scale * 1.08, 0.08)
		_pulse_tween.tween_property(self, "scale", _base_scale, 0.12)
	_pulse_tween.tween_interval(0.5)
