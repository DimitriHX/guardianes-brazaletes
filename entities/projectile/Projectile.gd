class_name Projectile
extends Area2D
## Proyectil del jugador: avanza en línea recta, daña lo primero que toque
## (si expone take_damage) y se destruye al chocar con el mundo o al caducar.
## Capa 4 (PlayerProjectiles); detecta World (1) y Enemies (3).

@export var speed: float = 650.0
@export var damage: int = 1
## Segundos de vida antes de autodestruirse.
@export var lifetime: float = 1.2

var direction: Vector2 = Vector2.RIGHT

var _life_left: float = 0.0
var _has_hit: bool = false


func _ready() -> void:
	_life_left = lifetime
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()


## Llamar antes de añadir al árbol (o justo después) para fijar la dirección.
func setup(new_direction: Vector2) -> void:
	direction = new_direction.normalized()
	# Orienta el proyectil (y su futuro sprite) hacia la dirección de vuelo.
	rotation = direction.angle()


func _on_body_entered(body: Node2D) -> void:
	if _has_hit:
		return
	_has_hit = true
	if body.has_method("take_damage"):
		body.call("take_damage", damage)
	# TODO(assets): instanciar efecto de impacto aquí.
	queue_free()
