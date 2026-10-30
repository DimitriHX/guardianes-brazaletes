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
@export_group("Visual")
@export var collectible_texture: Texture2D
@export var health_texture: Texture2D
@export var collect_effect: PackedScene
## Balanceo vertical (px) y velocidad (ciclos por segundo).
@export var bob_amplitude: float = 2.0
@export var bob_speed: float = 1.2

var _collected: bool = false
var _time: float = 0.0

@onready var _visual: ColorRect = $Visual
@onready var _sprite: Sprite2D = $Sprite
@onready var _light: PointLight2D = get_node_or_null("PointLight2D") as PointLight2D


func _ready() -> void:
	if type == PickupType.COLLECTIBLE:
		# El LevelManager cuenta este grupo para saber cuántos hacen falta.
		add_to_group("collectibles")
	_visual.color = COLORS[type]
	var texture: Texture2D = collectible_texture if type == PickupType.COLLECTIBLE else health_texture
	var has_art: bool = OptionalAtlasTexture.has_image(texture)
	_sprite.texture = texture
	_sprite.visible = has_art
	_visual.visible = not has_art
	if _light != null:
		_light.add_to_group("point_lights")
		if _light.texture == null:
			_light.texture = LevelAmbience.make_radial_light_texture()
		_light.color = Color(1.0, 0.85, 0.3, 1.0) if type == PickupType.COLLECTIBLE else Color(0.35, 1.0, 0.55, 1.0)
	# Desfase aleatorio: que no se balanceen todos a la vez.
	_time = randf() * TAU


func _process(delta: float) -> void:
	_time += delta * bob_speed * TAU
	_sprite.position.y = sin(_time) * bob_amplitude
	if _light != null:
		_light.position.y = _sprite.position.y
		_light.energy = 0.85 + sin(_time) * 0.12


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
	Events.pickup_collected.emit(&"collectible" if type == PickupType.COLLECTIBLE else &"health")
	Effect.spawn(collect_effect, self, _sprite.global_position)
	# TODO(assets): sonido de recogida.
	queue_free()
