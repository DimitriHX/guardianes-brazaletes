class_name HurtboxComponent
extends Area2D
## Zona que RECIBE golpes. Un HitboxComponent que la toque llama a receive_hit().
## Reenvía el daño al HealthComponent/StatsComponent asignado y avisa al padre.
## Poner su collision_layer en la capa de su dueño (Player=2, Enemies=3) y
## collision_mask = 0 (no necesita detectar nada). Debe quedar monitorable.

signal hurt(amount: int, source: Node)

@export var health: HealthComponent


func _ready() -> void:
	if health == null:
		push_warning("HurtboxComponent '%s' sin HealthComponent asignado." % get_path())


## Devuelve true si el golpe se aplicó (false si muerto o invulnerable).
func receive_hit(amount: int, source: Node) -> bool:
	if health == null or health.is_dead() or health.is_invulnerable():
		return false
	health.take_damage(amount)
	hurt.emit(amount, source)
	return true
