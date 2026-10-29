class_name Pickup
extends Area2D
## Objeto recogible configurable desde el inspector.
## - HEALTH: cura `amount` al jugador. No se consume si tiene la vida al máximo.
## - COLLECTIBLE: suma `amount` al contador del nivel vía Events.collectible_picked.
## Capa 5 (Pickups); detecta solo al Player (2).

enum PickupType { HEALTH, COLLECTIBLE }

const COLORS: Dictionary[PickupType, Color] = {
	PickupType.HEALTH: Color(0.3, 0.9, 0.4),
	PickupType.COLLECTIBLE: Color(1.0, 0.8, 0.15),
}

@export var type: PickupType = PickupType.COLLECTIBLE
@export var amount: int = 1

var _collected: bool = false

@onready var _visual: ColorRect = $Visual


func _ready() -> void:
	if type == PickupType.COLLECTIBLE:
		# El LevelManager cuenta este grupo para saber cuántos hacen falta.
		add_to_group("collectibles")
	# TODO(assets): un sprite/animación distinto por tipo en lugar del color.
	_visual.color = COLORS[type]


func _physics_process(_delta: float) -> void:
	# Sondeo en lugar de body_entered: si el jugador está encima con la vida
	# llena y luego recibe daño, el pickup de vida se recoge sin tener que salir.
	if _collected:
		return
	for body: Node2D in get_overlapping_bodies():
		if body.is_in_group("player") and _try_apply(body):
			_collect()
			return


func _try_apply(player: Node2D) -> bool:
	match type:
		PickupType.HEALTH:
			if not player.has_method("can_heal") or not bool(player.call("can_heal")):
				return false
			player.call("heal", amount)
			return true
		PickupType.COLLECTIBLE:
			if player.has_method("is_dead") and bool(player.call("is_dead")):
				return false
			Events.collectible_picked.emit(amount)
			return true
	return false


func _collect() -> void:
	_collected = true
	remove_from_group("collectibles")
	# TODO(assets): efecto y sonido de recogida.
	queue_free()
