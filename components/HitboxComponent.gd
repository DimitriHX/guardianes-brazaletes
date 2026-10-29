class_name HitboxComponent
extends Area2D
## Zona que INFLIGE golpes a los HurtboxComponent que toca.
## Poner collision_layer = 0 y collision_mask en la capa del objetivo
## (Player=2 para daño enemigo, Enemies=4 para ataques del jugador).
## - continuous = false: golpea una vez al entrar (proyectiles, golpes).
## - continuous = true: vuelve a golpear cada frame mientras se solapen; las
##   i-frames del objetivo limitan la frecuencia (daño por contacto).

## Solo se emite cuando el golpe se aplicó de verdad (el objetivo no era invulnerable).
signal hit_landed(hurtbox: HurtboxComponent)

@export var damage: int = 1
## Si se asigna, el daño sale de stats.get_damage() en lugar de `damage`.
@export var stats: StatsComponent
@export var continuous: bool = false
## Desactiva el golpeo sin quitar el nodo (p. ej. durante un ataque que aún no impacta).
@export var active: bool = true


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _physics_process(_delta: float) -> void:
	if not continuous or not active:
		return
	for area: Area2D in get_overlapping_areas():
		var hurtbox: HurtboxComponent = area as HurtboxComponent
		if hurtbox != null:
			_hit(hurtbox)


func get_damage() -> int:
	return stats.get_damage() if stats != null else damage


func _hit(hurtbox: HurtboxComponent) -> void:
	var source: Node = owner if owner != null else get_parent()
	if hurtbox.receive_hit(get_damage(), source):
		hit_landed.emit(hurtbox)


func _on_area_entered(area: Area2D) -> void:
	if continuous or not active:
		return
	var hurtbox: HurtboxComponent = area as HurtboxComponent
	if hurtbox != null:
		_hit(hurtbox)
