extends CanvasLayer
## Transiciones entre escenas (Autoload "SceneTransition") con el shader
## res://shader/transition.gdshader: cubre la pantalla con un patrón que avanza,
## cambia o recarga la escena y la vuelve a descubrir.
## Uso: SceneTransition.change_scene("res://levels/BossLevel.tscn")
##      SceneTransition.reload_scene()
## Funciona con el árbol en pausa y bloquea el input mientras cubre.

signal covered
signal finished

const SHADER: Shader = preload("res://shader/transition.gdshader")

@export var cover_time: float = 0.45
@export var reveal_time: float = 0.45
@export var color: Color = Color(0.04, 0.03, 0.06)
## Patrón: nº de círculos por ancho de pantalla.
@export var shape_tiling: float = 18.0

var is_transitioning: bool = false

var _rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("base_color", color)
	_material.set_shader_parameter("factor", 0.0)
	_material.set_shader_parameter("width", 0.4)
	_material.set_shader_parameter("gradient_texture", _make_sweep_gradient())
	_material.set_shader_parameter("gradient_fixed", false)
	_material.set_shader_parameter("shape_texture", _make_dot_shape())
	_material.set_shader_parameter("shape_tiling", shape_tiling)
	_material.set_shader_parameter("shape_feathering", 0.1)
	_material.set_shader_parameter("shape_treshold", 1.0)

	_rect = ColorRect.new()
	_rect.name = "Cover"
	_rect.material = _material
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	get_viewport().size_changed.connect(_update_resolution)
	_update_resolution()
	_rect.hide()


func change_scene(scene_path: String) -> void:
	_run(func() -> void: get_tree().change_scene_to_file(scene_path))


func reload_scene() -> void:
	_run(func() -> void: get_tree().reload_current_scene())


## 0 = despejado, 1 = cubierto (útil para menús o efectos propios).
func set_factor(value: float) -> void:
	_material.set_shader_parameter("factor", clampf(value, 0.0, 1.0))
	_rect.visible = value > 0.0


func get_factor() -> float:
	return float(_material.get_shader_parameter("factor"))


func _run(swap: Callable) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	await _tween_factor(1.0, cover_time)
	covered.emit()
	get_tree().paused = false
	swap.call()
	# Dos frames: la escena nueva entra en el árbol y la cámara se coloca.
	await get_tree().process_frame
	await get_tree().process_frame
	await _tween_factor(0.0, reveal_time)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false
	finished.emit()


func _tween_factor(target: float, duration: float) -> void:
	_rect.show()
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(set_factor, get_factor(), target, maxf(duration, 0.01))
	await tween.finished


func _update_resolution() -> void:
	_material.set_shader_parameter("node_resolution", get_viewport().get_visible_rect().size)


## Degradado horizontal: la transición barre de izquierda a derecha.
func _make_sweep_gradient() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color.BLACK)
	gradient.set_color(1, Color.WHITE)
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 256
	tex.height = 4
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	return tex


## Patrón: un círculo suave por celda (blanco en el centro), generado por código.
## TODO(assets): sustituir por una textura de patrón propia (rombos, estrellas...).
func _make_dot_shape() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color.BLACK)
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex
