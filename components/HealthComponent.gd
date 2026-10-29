class_name HealthComponent
extends Node
## Componente reutilizable de vida y daño.
## Se añade como hijo de cualquier entidad (Player, enemigos, jefes).
## Avisa a su padre con señales locales y, además, publica en Events los
## eventos de combate globales (daño, vida crítica, muerte) para sistemas
## transversales como HUD, hitstop o cámara.

signal health_changed(current: int, maximum: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died

@export var max_health: int = 3
## Segundos de invulnerabilidad tras recibir daño (0 = sin i-frames).
@export var invulnerability_time: float = 0.0
## Fracción de la vida máxima por debajo de la cual se considera "crítica".
@export_range(0.0, 1.0, 0.05) var critical_health_ratio: float = 0.25

var current_health: int = 0

var _invulnerable_left: float = 0.0
var _is_dead: bool = false


func _ready() -> void:
	current_health = max_health


func _process(delta: float) -> void:
	if _invulnerable_left > 0.0:
		_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)


func take_damage(amount: int) -> void:
	if amount <= 0 or _is_dead or is_invulnerable():
		return
	var was_critical: bool = is_critical()
	current_health = maxi(current_health - amount, 0)
	_invulnerable_left = invulnerability_time
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)
	Events.entity_damaged.emit(get_parent(), amount)
	if current_health == 0:
		_die()
	elif not was_critical and is_critical():
		Events.entity_health_critical.emit(get_parent())


func heal(amount: int) -> void:
	if amount <= 0 or _is_dead or current_health == max_health:
		return
	var previous: int = current_health
	current_health = mini(current_health + amount, max_health)
	healed.emit(current_health - previous)
	health_changed.emit(current_health, max_health)


## Muerte inmediata, ignorando la invulnerabilidad (caídas al vacío, trampas letales).
func kill() -> void:
	if _is_dead:
		return
	current_health = 0
	health_changed.emit(current_health, max_health)
	_die()


func reset() -> void:
	current_health = max_health
	_invulnerable_left = 0.0
	_is_dead = false
	health_changed.emit(current_health, max_health)


func is_dead() -> bool:
	return _is_dead


func is_full() -> bool:
	return current_health >= max_health


func is_critical() -> bool:
	return current_health > 0 and float(current_health) <= float(max_health) * critical_health_ratio


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


func _die() -> void:
	_is_dead = true
	died.emit()
	Events.entity_died.emit(get_parent())
