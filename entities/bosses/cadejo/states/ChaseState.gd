extends BossState
## Persecución agresiva. Aquí se elige la siguiente acción según la situación:
## - Muy cerca y rugido listo      -> Roar (empuja al jugador).
## - Distancia media y embestida lista, o se le acaba la paciencia -> Charge.

@export var chase_speed: float = 140.0
@export_group("Selección de ataque")
@export var roar_range: float = 90.0
@export var charge_min_range: float = 140.0
@export var charge_max_range: float = 450.0
## Segundos persiguiendo antes de forzar una embestida aunque esté lejos/cerca.
@export var patience: float = 3.0

var _chase_time: float = 0.0


func enter(previous: StringName) -> void:
	super(previous)
	_chase_time = 0.0


func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	if not boss.has_valid_target():
		boss.velocity.x = 0.0
		return
	_chase_time += delta
	boss.face_target()
	boss.velocity.x = float(boss.facing) * chase_speed * boss.speed_multiplier()

	var distance: float = boss.distance_to_target()
	if distance <= roar_range and boss.is_action_ready(&"roar"):
		transition_requested.emit(&"Roar")
	elif boss.is_action_ready(&"charge") and (
			(distance >= charge_min_range and distance <= charge_max_range) or _chase_time >= patience):
		transition_requested.emit(&"Charge")
