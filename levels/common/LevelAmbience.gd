class_name LevelAmbience
extends Node2D
## Escena de ambientación reutilizable por nivel (Sprint B):
## - CanvasModulate con tono ambiental configurable o automático según la estación.
## - WorldEnvironment en modo Canvas con glow/bloom suave para realzar las luces
##   (PointLight2D de antorchas, monedas de luz, portales y brazalete).
## - Generador compartido de textura radial para PointLight2D sin depender de PNGs externos.

const DEFAULT_AMBIENT_BY_SEASON: Dictionary[int, Color] = {
	0: Color(0.82, 0.88, 0.95, 1.0), # GREEN: crepúsculo en el Bosque de los Pinos
	1: Color(0.72, 0.64, 0.76, 1.0), # AUTUMN: penumbra en la Guarida del Cadejo
	2: Color(0.70, 0.78, 0.94, 1.0), # WINTER: noche fría en el Sendero de las Sombras
}

@export_range(0, 2, 1) var season: int = 0
## Si es true y no se pasa un color explícito, usa el tono ambiental de `season`.
@export var use_season_ambient: bool = true
@export var ambient_color: Color = Color(0.82, 0.88, 0.95, 1.0)

@export_group("Glow (WorldEnvironment)")
@export var glow_enabled: bool = true
@export var glow_intensity: float = 0.65
@export var glow_strength: float = 0.95
@export var glow_bloom: float = 0.15
@export var glow_hdr_threshold: float = 0.85

static var _shared_light_texture: GradientTexture2D

@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var world_environment: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	add_to_group("level_ambience")
	apply_ambience()


func set_season(new_season: int, custom_ambient: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	season = clampi(new_season, 0, 2)
	if custom_ambient.a > 0.0:
		use_season_ambient = false
		ambient_color = custom_ambient
	else:
		use_season_ambient = true
		ambient_color = DEFAULT_AMBIENT_BY_SEASON.get(season, Color(0.82, 0.88, 0.95, 1.0))
	if is_node_ready():
		apply_ambience()


func apply_ambience() -> void:
	if use_season_ambient:
		ambient_color = DEFAULT_AMBIENT_BY_SEASON.get(season, ambient_color)
	if canvas_modulate != null:
		canvas_modulate.color = ambient_color
	if world_environment != null:
		var env: Environment = world_environment.environment
		if env == null:
			env = Environment.new()
			world_environment.environment = env
		env.background_mode = Environment.BG_CANVAS
		env.glow_enabled = glow_enabled
		env.glow_intensity = glow_intensity
		env.glow_strength = glow_strength
		env.glow_bloom = glow_bloom
		env.glow_hdr_threshold = glow_hdr_threshold
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN


func get_ambient_color() -> Color:
	return canvas_modulate.color if canvas_modulate != null else ambient_color


func is_glow_enabled() -> bool:
	if world_environment != null and world_environment.environment != null:
		return world_environment.environment.glow_enabled
	return glow_enabled


## Devuelve una textura radial suave (blanco en el centro -> negro transparente en el borde)
## lista para usarse en cualquier PointLight2D.
## TODO(assets): sustituir por textura de halo/luz personalizada si el diseñador lo requiere.
static func make_radial_light_texture(size: int = 128) -> GradientTexture2D:
	if _shared_light_texture != null and _shared_light_texture.width == size:
		return _shared_light_texture
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(0.55, 0.55, 0.55, 0.55),
		Color(0.0, 0.0, 0.0, 0.0),
	])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = size
	tex.height = size
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	if size == 128:
		_shared_light_texture = tex
	return tex
