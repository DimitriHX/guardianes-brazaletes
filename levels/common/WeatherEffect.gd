class_name WeatherEffect
extends Node2D
## Clima del nivel: hojas que caen (LEAVES) o nieve (SNOW).
## Dos capas de partículas que siguen la vista de la cámara: una lejana (más
## pequeña, lenta y tenue) y otra cercana. Las dos se dibujan detrás del
## terreno, del jugador y de los enemigos (z_index negativo), así que nunca
## tapan la acción: solo dan vida y profundidad al fondo.
## Las partículas viven en coordenadas del mundo (local_coords = false): al
## moverse la cámara se quedan donde estaban, como el resto del escenario.
## Las texturas (hoja y copo de pocos píxeles) se generan por código.

enum Kind { NONE, LEAVES, SNOW }

@export var kind: Kind = Kind.NONE

## Capas: [z_index, cantidad, escala, opacidad, velocidad relativa].
const LAYERS: Array[Array] = [
	[-60, 0.6, 1.1, 0.6, 0.7],
	[-10, 0.4, 1.8, 0.9, 1.0],
]
## Margen (px de mundo) alrededor de la vista donde también nacen partículas.
const VIEW_MARGIN: float = 120.0

var _emitters: Array[CPUParticles2D] = []


func _ready() -> void:
	# Después de que la cámara se mueva este frame (como ParallaxBackdrop).
	process_priority = 100
	if kind == Kind.NONE:
		return
	for layer: Array in LAYERS:
		var emitter: CPUParticles2D = _make_leaves(layer) if kind == Kind.LEAVES else _make_snow(layer)
		emitter.z_index = int(layer[0])
		emitter.local_coords = false
		emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		emitter.emitting = false
		add_child(emitter)
		_emitters.append(emitter)
	# Diferido: en _ready la cámara del nivel aún no está colocada. Así el
	# precalentado (preprocess) llena la vista desde el primer frame.
	_start.call_deferred()


func _start() -> void:
	_follow_view()
	for emitter: CPUParticles2D in _emitters:
		emitter.emitting = true


func _process(_delta: float) -> void:
	_follow_view()


static func kind_from_string(value: String) -> Kind:
	match value.strip_edges().to_upper():
		"LEAVES", "HOJAS":
			return Kind.LEAVES
		"SNOW", "NIEVE":
			return Kind.SNOW
	return Kind.NONE


func get_emitters() -> Array[CPUParticles2D]:
	return _emitters


## Coloca cada emisor sobre la vista de la cámara: nacen en toda la vista y un
## poco por encima; el color de la partícula aparece y se apaga suavemente.
func _follow_view() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return
	var view: Vector2 = get_viewport_rect().size / camera.zoom
	var center: Vector2 = camera.get_screen_center_position()
	for emitter: CPUParticles2D in _emitters:
		emitter.global_position = center - Vector2(0.0, VIEW_MARGIN)
		emitter.emission_rect_extents = view / 2.0 + Vector2(VIEW_MARGIN, VIEW_MARGIN)


func _make_leaves(layer: Array) -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	var speed: float = float(layer[4])
	p.amount = roundi(50.0 * float(layer[1]))
	p.lifetime = 9.0
	p.preprocess = p.lifetime
	p.texture = _leaf_texture()
	# Viento suave hacia la izquierda; la hoja cae despacio y se balancea.
	p.direction = Vector2(-1.0, 0.3)
	p.spread = 25.0
	p.initial_velocity_min = 12.0 * speed
	p.initial_velocity_max = 30.0 * speed
	p.gravity = Vector2(-4.0, 22.0) * speed
	p.damping_min = 2.0
	p.damping_max = 5.0
	p.tangential_accel_min = -14.0
	p.tangential_accel_max = 14.0
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.scale_amount_min = float(layer[2]) * 0.9
	p.scale_amount_max = float(layer[2]) * 1.2
	# Aleteo: la hoja se "voltea" estrechándose y abriéndose en X.
	var flutter: Curve = Curve.new()
	for i: int in 9:
		var t: float = float(i) / 8.0
		flutter.add_point(Vector2(t, 0.35 + 0.65 * absf(cos(t * TAU * 2.0))))
	p.split_scale = true
	p.scale_curve_x = flutter
	p.scale_curve_y = _constant_curve(1.0)
	p.color_initial_ramp = _gradient([
		Color(0.55, 0.78, 0.30), Color(0.85, 0.80, 0.30),
		Color(0.92, 0.55, 0.20), Color(0.70, 0.35, 0.18),
	])
	p.color_ramp = _fade_ramp(float(layer[3]))
	return p


func _make_snow(layer: Array) -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	var speed: float = float(layer[4])
	p.amount = roundi(170.0 * float(layer[1]))
	p.lifetime = 8.0
	p.preprocess = p.lifetime
	p.texture = _snow_texture()
	p.direction = Vector2(-0.3, 1.0)
	p.spread = 20.0
	p.initial_velocity_min = 14.0 * speed
	p.initial_velocity_max = 26.0 * speed
	p.gravity = Vector2(-2.0, 6.0) * speed
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.tangential_accel_min = -6.0
	p.tangential_accel_max = 6.0
	p.scale_amount_min = float(layer[2]) * 0.8
	p.scale_amount_max = float(layer[2]) * 1.2
	# Más de 1: compensa el tinte frío del CanvasModulate (si no, el copo se
	# confunde con el cielo) y hace que el glow del nivel lo ilumine un poco.
	p.color_initial_ramp = _gradient([Color(1.15, 1.2, 1.3), Color(1.35, 1.4, 1.5)])
	p.color_ramp = _fade_ramp(float(layer[3]))
	return p


## Hoja de 7x5 px: contorno más oscuro, nervio central claro. Blanca y gris
## para que `color_initial_ramp` le dé el color.
static func _leaf_texture() -> ImageTexture:
	var rows: PackedStringArray = [
		"..oo...",
		".oxxo..",
		"oxlllxo",
		".oxxxo.",
		"..ooo.o",
	]
	return _texture_from_rows(rows, {
		"o": Color(0.62, 0.62, 0.62, 1.0),
		"x": Color(0.88, 0.88, 0.88, 1.0),
		"l": Color(1.0, 1.0, 1.0, 1.0),
	})


## Copo de 4x4 px: centro sólido y borde tenue.
static func _snow_texture() -> ImageTexture:
	var rows: PackedStringArray = [".aa.", "aooa", "aooa", ".aa."]
	return _texture_from_rows(rows, {
		"o": Color(1.0, 1.0, 1.0, 1.0),
		"a": Color(1.0, 1.0, 1.0, 0.45),
	})


static func _texture_from_rows(rows: PackedStringArray, colors: Dictionary) -> ImageTexture:
	var img: Image = Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y: int in rows.size():
		for x: int in rows[y].length():
			var key: String = rows[y][x]
			if colors.has(key):
				img.set_pixel(x, y, colors[key] as Color)
	return ImageTexture.create_from_image(img)


## Aparece al nacer y se desvanece al final de la vida, con opacidad máxima `alpha`.
static func _fade_ramp(alpha: float) -> Gradient:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.12, 0.8, 1.0])
	g.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, alpha),
		Color(1, 1, 1, alpha), Color(1, 1, 1, 0.0),
	])
	return g


static func _gradient(colors: Array[Color]) -> Gradient:
	var g: Gradient = Gradient.new()
	var offsets: PackedFloat32Array = PackedFloat32Array()
	for i: int in colors.size():
		offsets.append(float(i) / float(maxi(colors.size() - 1, 1)))
	g.offsets = offsets
	g.colors = PackedColorArray(colors)
	return g


static func _constant_curve(value: float) -> Curve:
	var c: Curve = Curve.new()
	c.add_point(Vector2(0.0, value))
	c.add_point(Vector2(1.0, value))
	return c
