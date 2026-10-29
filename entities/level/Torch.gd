class_name Torch
extends Node2D
## Antorcha animada con PointLight2D y parpadeo suave (Sprint B).
## Usa la hoja `Torch.png` (6 columnas x 4 filas de 32x32 px):
## - Fila 1: antorcha de pie encendida (6 frames)
## - Fila 2: antorcha de pared recta encendida (6 frames)
## - Fila 3: antorcha de pared inclinada encendida (6 frames)
## Si no hay textura asignada, muestra el ColorRect placeholder `$Visual`.

enum Style { STANDING = 1, WALL = 2, ANGLED = 3 }

const FRAMES_PER_ROW: int = 6

@export var style: Style = Style.STANDING
@export var texture: Texture2D
@export var fps: float = 8.0

@export_group("Luz (PointLight2D)")
@export var light_color: Color = Color(1.0, 0.72, 0.32, 1.0)
@export var base_energy: float = 1.15
@export var base_scale: float = 1.85
@export var flicker_energy: float = 0.14
@export var flicker_scale: float = 0.08
@export var flicker_speed: float = 5.5

var _time: float = 0.0
var _frame_time: float = 0.0

@onready var _visual: ColorRect = $Visual
@onready var _sprite: Sprite2D = $Sprite
@onready var _light: PointLight2D = $PointLight2D


func _ready() -> void:
	add_to_group("torches")
	add_to_group("point_lights")
	_time = randf() * TAU
	_frame_time = randf() * float(FRAMES_PER_ROW)
	_setup_visual()
	_setup_light()


func _process(delta: float) -> void:
	_time += delta * flicker_speed
	if _sprite != null and _sprite.visible and _sprite.hframes > 1:
		_frame_time += delta * fps
		var row: int = clampi(int(style), 1, 3)
		var col: int = int(_frame_time) % FRAMES_PER_ROW
		_sprite.frame = row * FRAMES_PER_ROW + col
	if _light != null:
		var wave: float = sin(_time) * 0.65 + cos(_time * 2.3) * 0.35
		_light.energy = maxf(0.1, base_energy + wave * flicker_energy)
		_light.texture_scale = maxf(0.2, base_scale + wave * flicker_scale)


func get_light() -> PointLight2D:
	return _light


func _setup_visual() -> void:
	var has_art: bool = texture != null
	if _sprite != null:
		_sprite.texture = texture
		_sprite.visible = has_art
		if has_art:
			_sprite.hframes = FRAMES_PER_ROW
			_sprite.vframes = 4
			_sprite.frame = clampi(int(style), 1, 3) * FRAMES_PER_ROW
	if _visual != null:
		_visual.visible = not has_art


func _setup_light() -> void:
	if _light == null:
		return
	if _light.texture == null:
		_light.texture = LevelAmbience.make_radial_light_texture()
	_light.color = light_color
	_light.energy = base_energy
	_light.texture_scale = base_scale
