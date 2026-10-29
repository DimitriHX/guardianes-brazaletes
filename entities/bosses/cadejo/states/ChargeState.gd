extends BossState
## Embestida: se para y se prepara (windup, telegrafía el ataque), luego carga
## en línea recta haciendo más daño por contacto. Termina por tiempo o al
## chocar con una pared y pasa a Retreat.
## Fase 2 (ataque nuevo): encadena una segunda embestida girándose.

@export var windup_time: float = 0.45
@export var charge_speed: float = 420.0
@export var charge_duration: float = 0.75
## Multiplicador del daño de contacto durante la carga.
@export var charge_damage_multiplier: float = 2.0
@export var cooldown: float = 2.5
## Embestidas extra encadenadas a partir de la fase 2.
@export var phase2_extra_charges: int = 1

var _windup_left: float = 0.0
var _dash_left: float = 0.0
var _charges_left: int = 0
var _base_damage_multiplier: float = 1.0


func enter(previous: StringName) -> void:
	super(previous)
	_base_damage_multiplier = boss.stats.damage_multiplier
	_charges_left = phase2_extra_charges if boss.phase >= 2 else 0
	_begin_windup()


func exit() -> void:
	boss.stats.damage_multiplier = _base_damage_multiplier
	boss.start_cooldown(&"charge", cooldown)


func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	if _windup_left > 0.0:
		boss.velocity.x = 0.0
		_windup_left -= delta
		if _windup_left <= 0.0:
			_begin_dash()
		return

	boss.velocity.x = float(boss.facing) * charge_speed * boss.speed_multiplier()
	_dash_left -= delta
	var hit_wall: bool = boss.is_on_wall() and signf(boss.get_wall_normal().x) == -float(boss.facing)
	if _dash_left <= 0.0 or hit_wall:
		if hit_wall:
			Events.camera_shake_requested.emit(4.5, 0.18)
		boss.stats.damage_multiplier = _base_damage_multiplier
		if _charges_left > 0 and boss.has_valid_target():
			_charges_left -= 1
			_begin_windup()
		else:
			transition_requested.emit(&"Retreat")


func is_dashing() -> bool:
	return _windup_left <= 0.0 and _dash_left > 0.0


func _begin_windup() -> void:
	_windup_left = windup_time / boss.speed_multiplier()
	_dash_left = 0.0
	boss.face_target()
	# TODO(assets): telegrafiar con un destello o sonido además de la animación.
	boss.play_animation(&"attack")


func _begin_dash() -> void:
	_dash_left = charge_duration
	Events.sfx_requested.emit(&"boss_charge")
	boss.stats.damage_multiplier = _base_damage_multiplier * charge_damage_multiplier
	boss.play_animation(&"run")
