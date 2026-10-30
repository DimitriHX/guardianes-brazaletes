class_name SquashStretch
extends Node
## Estirar y aplastar (squash & stretch) un sprite y volver a su escala con un
## rebote suave (TRANS_BACK). Solo toca la escala del nodo visual, nunca la
## colisión. El sprite debe estar anclado por los pies (CharacterAnimator con
## `anchor_bottom`) para que se deforme desde el suelo.
## Uso: `pop(Vector2(0.8, 1.2))` = más estrecho y alto (salto).

## Nodo a deformar. Vacío = el hermano "Visual/Animator".
@export var target: Node2D
## Segundos en volver a la escala original.
@export var return_time: float = 0.2
## Vida cuya señal `damaged` aplasta el sprite. Vacío = el hermano "Stats".
@export var health: HealthComponent
## Deformación al recibir daño (Vector2.ONE = ninguna).
@export var hurt_factor: Vector2 = Vector2(1.2, 0.82)

var _base_scale: Vector2 = Vector2.ONE
var _tween: Tween


func _ready() -> void:
	if target == null:
		target = get_parent().get_node_or_null("Visual/Animator") as Node2D
	if target != null:
		_base_scale = target.scale
	if health == null:
		health = get_parent().get_node_or_null("Stats") as HealthComponent
	if health != null and hurt_factor != Vector2.ONE:
		health.damaged.connect(_on_damaged)


## Deforma al instante por `factor` (x, y) y vuelve a la escala base con rebote.
## `time` < 0 usa `return_time`.
func pop(factor: Vector2, time: float = -1.0) -> void:
	if target == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	target.scale = _base_scale * factor
	_tween = create_tween()
	_tween.tween_property(target, "scale", _base_scale, return_time if time < 0.0 else time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Escala actual relativa a la base (Vector2.ONE = en reposo).
func get_factor() -> Vector2:
	if target == null:
		return Vector2.ONE
	return target.scale / _base_scale


func _on_damaged(_amount: int) -> void:
	pop(hurt_factor)
