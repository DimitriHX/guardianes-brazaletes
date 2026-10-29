class_name StatsComponent
extends HealthComponent
## HealthComponent ampliado con estadísticas de combate:
## - Daño que inflige: base_damage * damage_multiplier (get_damage()).
## - Daño que recibe: amount * damage_taken_multiplier (0.5 = resiste la mitad,
##   0 = inmune, 2 = débil).
## Los multiplicadores pueden cambiarse en runtime (power-ups, fases de jefe).

@export_group("Combate")
@export var base_damage: int = 1
@export var damage_multiplier: float = 1.0
@export var damage_taken_multiplier: float = 1.0


func take_damage(amount: int) -> void:
	super(roundi(float(amount) * damage_taken_multiplier))


func get_damage() -> int:
	return maxi(roundi(float(base_damage) * damage_multiplier), 0)
