class_name PiskelLoader
extends RefCounted
## Lee archivos .piskel (el formato JSON que guarda Piskel) y devuelve sus
## frames como texturas, sin necesidad de exportarlos antes a PNG.
## Formato: {"piskel": {width, height, fps, layers: [<json de capa>...]}};
## cada capa tiene frameCount, opacity y chunks [{layout, base64PNG}], donde
## layout[columna][fila] = índice del frame dentro de la imagen del chunk.
## Los resultados se cachean por ruta.
## NOTA de exportación: Godot no importa .piskel; para builds exportadas hay que
## añadir "*.piskel" en Exportar > Recursos > Filtros de archivos no recurso.


class Result:
	extends RefCounted
	var frames: Array[Texture2D] = []
	var fps: float = 12.0
	var size: Vector2i = Vector2i.ZERO


static var _cache: Dictionary = {}


## Devuelve null (y escribe el error) si el archivo no existe o no es válido.
static func load_piskel(path: String) -> Result:
	if _cache.has(path):
		return _cache[path]
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("PiskelLoader: no se pudo leer '%s' (%s)." % [path, error_string(FileAccess.get_open_error())])
		return null
	var root: Variant = JSON.parse_string(text)
	if typeof(root) != TYPE_DICTIONARY or not (root as Dictionary).has("piskel"):
		push_error("PiskelLoader: '%s' no es un .piskel válido." % path)
		return null

	var piskel: Dictionary = root["piskel"]
	var width: int = int(piskel.get("width", 0))
	var height: int = int(piskel.get("height", 0))
	if width <= 0 or height <= 0:
		push_error("PiskelLoader: '%s' tiene un tamaño inválido." % path)
		return null

	var images: Array[Image] = []
	for layer_variant: Variant in piskel.get("layers", []):
		var layer: Dictionary = _parse_layer(layer_variant)
		if layer.is_empty():
			continue
		var frame_count: int = int(layer.get("frameCount", 0))
		while images.size() < frame_count:
			images.append(Image.create_empty(width, height, false, Image.FORMAT_RGBA8))
		var opacity: float = float(layer.get("opacity", 1.0))
		for chunk: Dictionary in layer.get("chunks", []):
			_blend_chunk(chunk, width, height, opacity, images)

	var result: Result = Result.new()
	result.fps = float(piskel.get("fps", 12))
	result.size = Vector2i(width, height)
	for image: Image in images:
		result.frames.append(ImageTexture.create_from_image(image))
	_cache[path] = result
	return result


static func clear_cache() -> void:
	_cache.clear()


static func _parse_layer(layer_variant: Variant) -> Dictionary:
	# Piskel guarda cada capa como un string JSON dentro del JSON principal.
	if typeof(layer_variant) == TYPE_STRING:
		var parsed: Variant = JSON.parse_string(layer_variant)
		return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	if typeof(layer_variant) == TYPE_DICTIONARY:
		return layer_variant
	return {}


static func _blend_chunk(chunk: Dictionary, width: int, height: int, opacity: float, images: Array[Image]) -> void:
	var data_url: String = String(chunk.get("base64PNG", ""))
	var comma: int = data_url.find(",")
	var sheet: Image = Image.new()
	if sheet.load_png_from_buffer(Marshalls.base64_to_raw(data_url.substr(comma + 1))) != OK:
		push_error("PiskelLoader: PNG de un chunk ilegible.")
		return
	sheet.convert(Image.FORMAT_RGBA8)
	var layout: Array = chunk.get("layout", [])
	for column: int in layout.size():
		var rows: Array = layout[column]
		for row: int in rows.size():
			var index: int = int(rows[row])
			if index < 0 or index >= images.size():
				continue
			var frame: Image = sheet.get_region(Rect2i(column * width, row * height, width, height))
			if opacity < 1.0:
				_apply_opacity(frame, opacity)
			images[index].blend_rect(frame, Rect2i(0, 0, width, height), Vector2i.ZERO)


static func _apply_opacity(image: Image, opacity: float) -> void:
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			c.a *= opacity
			image.set_pixel(x, y, c)
