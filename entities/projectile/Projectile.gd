class_name Projectile
extends Area2D
## Proyectil del jugador: avanza en línea recta y se destruye al chocar con el
## mundo (este Area2D, máscara World), al golpear un Hurtbox enemigo (Hitbox
## hijo, máscara Enemies) o al caducar. Capa 4 (PlayerProjectiles).

@export var speed: float = 650.0
## Segundos de vida antes de autodestruirse.
@export var lifetime: float = 1.2

var direction: Vector2 = Vector2.RIGHT

var _life_left: float = 0.0
var _spent: bool = false

@onready var _hitbox: HitboxComponent = $Hitbox


func _ready() -> void:
	_life_left = lifetime
	body_entered.connect(_on_body_entered)
	_hitbox.hit_landed.connect(_on_hit_landed)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()


## Llamar antes de añadir al árbol. `damage` < 0 conserva el daño de la escena.
func setup(new_direction: Vector2, damage: int = -1) -> void:
	direction = new_direction.normalized()
	# Orienta el proyectil (y su futuro sprite) hacia la dirección de vuelo.
	rotation = direction.angle()
	if damage >= 0:
		($Hitbox as HitboxComponent).damage = damage


func _spend() -> void:
	if _spent:
		return
	_spent = true
	_hitbox.active = false
	# TODO(assets): instanciar efecto de impacto aquí.
	queue_free()


func _on_body_entered(_body: Node2D) -> void:
	_spend()


func _on_hit_landed(_hurtbox: HurtboxComponent) -> void:
	_spend()
