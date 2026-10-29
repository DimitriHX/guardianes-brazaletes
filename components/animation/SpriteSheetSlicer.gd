class_name SpriteSheetSlicer
extends RefCounted
## Utilidades para sacar frames de una hoja de sprites (PNG o JPEG):
## - slice(): recorta regiones de la hoja.
## - remove_background(): quita un fondo OPACO (p. ej. un JPEG) con un relleno
##   desde los bordes del frame. Un píxel es "fondo" si es oscuro y tiene el
##   mismo TINTE que `key` (no el mismo brillo): así un personaje negro sobre un
##   fondo negro-azulado se conserva. Después limpia motas sueltas del JPEG y
##   los trozos de frames vecinos que asoman por los laterales.
## - align_bottom_center(): recorta cada frame a su contenido y lo coloca en un
##   lienzo común anclado por los pies, para que la animación no "baile" aunque
##   las regiones de la hoja no estén alineadas.

## Margen de luminancia sobre la del color clave para considerar un píxel fondo.
const LUMINANCE_MARGIN: float = 0.1
## Píxeles casi negros: fondo solo si están rodeados de fondo (ver despeckle).
const NEAR_BLACK: float = 0.025
## Fragmentos que tocan un lateral y miden menos que esta fracción de la figura
## principal se consideran restos de frames vecinos.
const MAX_EDGE_FRAGMENT_RATIO: float = 0.25

static var _sheet_cache: Dictionary = {}


static func slice(sheet: Texture2D, regions: Array[Rect2i]) -> Array[Image]:
	var source: Image = _sheet_image(sheet)
	var frames: Array[Image] = []
	if source == null:
		return frames
	var bounds: Rect2i = Rect2i(Vector2i.ZERO, source.get_size())
	for region: Rect2i in regions:
		var clipped: Rect2i = region.intersection(bounds)
		if clipped.has_area():
			frames.append(source.get_region(clipped))
	return frames


## Divide `area` en `columns` frames del mismo ancho.
static func grid_regions(area: Rect2i, columns: int) -> Array[Rect2i]:
	var regions: Array[Rect2i] = []
	if columns <= 0:
		return regions
	var width: int = area.size.x / columns
	for i: int in columns:
		regions.append(Rect2i(area.position.x + i * width, area.position.y, width, area.size.y))
	return regions


## `key`: color típico del fondo. `tolerance`: diferencia de tinte admitida
## (0.02-0.04 para JPEG).
static func remove_background(image: Image, key: Color, tolerance: float) -> void:
	var w: int = image.get_width()
	var h: int = image.get_height()
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(w * h)
	var queue: Array[Vector2i] = []
	for x: int in w:
		for y: int in [0, h - 1]:
			_try_seed(image, Vector2i(x, y), key, tolerance, visited, queue)
	for y: int in h:
		for x: int in [0, w - 1]:
			_try_seed(image, Vector2i(x, y), key, tolerance, visited, queue)

	var head: int = 0
	var offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		var c: Color = image.get_pixelv(p)
		image.set_pixelv(p, Color(c.r, c.g, c.b, 0.0))
		for o: Vector2i in offsets:
			var n: Vector2i = p + o
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or visited[n.y * w + n.x] == 1:
				continue
			if _is_background(image.get_pixelv(n), key, tolerance):
				visited[n.y * w + n.x] = 1
				queue.append(n)
	_despeckle(image, 2)
	_remove_edge_fragments(image)


## Recorta cada frame a sus píxeles visibles y los centra abajo en un lienzo
## del tamaño del mayor. `padding` deja margen alrededor.
static func align_bottom_center(frames: Array[Image], padding: int = 1) -> Array[Image]:
	var trimmed: Array[Image] = []
	var canvas: Vector2i = Vector2i.ONE
	for frame: Image in frames:
		var used: Rect2i = frame.get_used_rect()
		var piece: Image = frame.get_region(used) if used.has_area() else frame
		trimmed.append(piece)
		canvas = Vector2i(maxi(canvas.x, piece.get_width()), maxi(canvas.y, piece.get_height()))
	canvas += Vector2i(padding * 2, padding * 2)
	var aligned: Array[Image] = []
	for piece: Image in trimmed:
		var out: Image = Image.create_empty(canvas.x, canvas.y, false, Image.FORMAT_RGBA8)
		var at: Vector2i = Vector2i((canvas.x - piece.get_width()) / 2, canvas.y - padding - piece.get_height())
		out.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), at)
		aligned.append(out)
	return aligned


static func clear_cache() -> void:
	_sheet_cache.clear()


static func _sheet_image(sheet: Texture2D) -> Image:
	if sheet == null:
		return null
	var key: String = sheet.resource_path if not sheet.resource_path.is_empty() else str(sheet.get_instance_id())
	if _sheet_cache.has(key):
		return _sheet_cache[key]
	var image: Image = sheet.get_image()
	if image == null:
		push_error("SpriteSheetSlicer: no se pudo leer la imagen de '%s'." % key)
		return null
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	_sheet_cache[key] = image
	return image


static func _try_seed(image: Image, p: Vector2i, key: Color, tolerance: float, visited: PackedByteArray, queue: Array[Vector2i]) -> void:
	var i: int = p.y * image.get_width() + p.x
	if visited[i] == 0 and _is_background(image.get_pixelv(p), key, tolerance):
		visited[i] = 1
		queue.append(p)


static func _is_background(c: Color, key: Color, tolerance: float) -> bool:
	if c.a < 0.05:
		return true
	if _luminance(c) > _luminance(key) + LUMINANCE_MARGIN:
		return false
	# Mismo tinte que el fondo: compara (G-R) y (B-R), independiente del brillo.
	return absf((c.g - c.r) - (key.g - key.r)) <= tolerance and absf((c.b - c.r) - (key.b - key.r)) <= tolerance


## Borra píxeles opacos casi aislados (ruido del JPEG que quedó en el fondo).
static func _despeckle(image: Image, passes: int) -> void:
	var w: int = image.get_width()
	var h: int = image.get_height()
	for pass_index: int in passes:
		var to_clear: Array[Vector2i] = []
		for y: int in h:
			for x: int in w:
				var c: Color = image.get_pixel(x, y)
				if c.a < 0.05:
					continue
				var empty: int = 0
				for dy: int in range(-1, 2):
					for dx: int in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var nx: int = x + dx
						var ny: int = y + dy
						if nx < 0 or ny < 0 or nx >= w or ny >= h or image.get_pixel(nx, ny).a < 0.05:
							empty += 1
				var dark: bool = maxf(c.r, maxf(c.g, c.b)) <= NEAR_BLACK
				if empty >= 6 or (dark and empty >= 4):
					to_clear.append(Vector2i(x, y))
		for p: Vector2i in to_clear:
			var c: Color = image.get_pixelv(p)
			image.set_pixelv(p, Color(c.r, c.g, c.b, 0.0))


## Etiqueta las manchas opacas (8-vecinos) y borra las que tocan el borde
## izquierdo/derecho y son pequeñas frente a la mayor.
static func _remove_edge_fragments(image: Image) -> void:
	var w: int = image.get_width()
	var h: int = image.get_height()
	var labels: PackedInt32Array = PackedInt32Array()
	labels.resize(w * h)
	var sizes: Array[int] = [0]
	var touches_side: Array[bool] = [false]
	var pixels: Array = [[]]
	for y: int in h:
		for x: int in w:
			if labels[y * w + x] != 0 or image.get_pixel(x, y).a < 0.05:
				continue
			var label: int = sizes.size()
			var members: Array[Vector2i] = [Vector2i(x, y)]
			labels[y * w + x] = label
			var head: int = 0
			var side: bool = false
			while head < members.size():
				var p: Vector2i = members[head]
				head += 1
				if p.x == 0 or p.x == w - 1:
					side = true
				for dy: int in range(-1, 2):
					for dx: int in range(-1, 2):
						var n: Vector2i = p + Vector2i(dx, dy)
						if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or labels[n.y * w + n.x] != 0:
							continue
						if image.get_pixelv(n).a >= 0.05:
							labels[n.y * w + n.x] = label
							members.append(n)
			sizes.append(members.size())
			touches_side.append(side)
			pixels.append(members)
	var largest: int = 0
	for size: int in sizes:
		largest = maxi(largest, size)
	for label: int in range(1, sizes.size()):
		if touches_side[label] and float(sizes[label]) < float(largest) * MAX_EDGE_FRAGMENT_RATIO:
			for p: Vector2i in pixels[label]:
				var c: Color = image.get_pixelv(p)
				image.set_pixelv(p, Color(c.r, c.g, c.b, 0.0))


static func _luminance(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114
