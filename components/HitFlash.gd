class_name HitFlash
extends Node
## Destello blanco breve sobre el sprite al recibir daño (game feel).
## Se añade como hijo de la entidad; escucha la señal `damaged` de su
## HealthComponent/StatsComponent y anima `flash_amount` del shader
## `hit_flash.gdshader` de 1 a 0. El material es propio de cada instancia.

const FLASH_SHADER: Shader = preload("res://shaders/hit_flash.gdshader")

## Nodo que destella. Vacío = el hermano "Visual/Animator".
@export var target: CanvasItem
## Vida que dispara el destello. Vacío = el hermano "Stats".
@export var health: HealthComponent
@export var flash_color: Color = Color.WHITE
## Duración del destello (vuelve a la normalidad con ease-out).
@export var flash_time: float = 0.14

var _material: ShaderMaterial
var _tween: Tween


func _ready() -> void:
	if target == null:
		target = get_parent().get_node_or_null("Visual/Animator") as CanvasItem
	if health == null:
		health = get_parent().get_node_or_null("Stats") as HealthComponent
	if target == null:
		return
	_material = ShaderMaterial.new()
	_material.shader = FLASH_SHADER
	_material.set_shader_parameter(&"flash_color", flash_color)
	_material.set_shader_parameter(&"flash_amount", 0.0)
	target.material = _material
	if health != null:
		health.damaged.connect(_on_damaged)


## Hace destellar el sprite (también se puede llamar a mano).
func flash() -> void:
	if _material == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_material.set_shader_parameter(&"flash_amount", 1.0)
	_tween = create_tween()
	_tween.tween_method(_set_amount, 1.0, 0.0, flash_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func get_flash_amount() -> float:
	return float(_material.get_shader_parameter(&"flash_amount")) if _material != null else 0.0


func _set_amount(value: float) -> void:
	_material.set_shader_parameter(&"flash_amount", value)


func _on_damaged(_amount: int) -> void:
	flash()
