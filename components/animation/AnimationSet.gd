class_name AnimationSet
extends Resource
## Conjunto de animaciones de un personaje. Se guarda como .tres y se asigna a un
## CharacterAnimator. Cada entrada sale de un .piskel o de una hoja de sprites.
## El resultado se cachea por recurso: procesar una hoja (recorte, quitar fondo,
## alinear) solo ocurre la primera vez, no en cada reinicio del nivel.

## Fps de las entradas de hoja de sprites sin fps_override.
@export var default_fps: float = 8.0
## Recortar los frames de hoja a su contenido y alinearlos por los pies en un
## lienzo común (necesario si las regiones de la hoja no están alineadas).
@export var align_sheet_frames: bool = false
@export var entries: Array[AnimationEntry] = []

static var _built_cache: Dictionary = {}


## Construye (o devuelve del caché) el SpriteFrames. Las entradas sin fuente
## válida se ignoran (plantilla aún sin arte).
func build_sprite_frames() -> SpriteFrames:
	var key: String = resource_path if not resource_path.is_empty() else str(get_instance_id())
	if _built_cache.has(key):
		return _built_cache[key]
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")

	# Frames de hoja: se procesan juntos para compartir lienzo y anclaje.
	var sheet_images: Array[Image] = []
	var sheet_counts: Dictionary[StringName, int] = {}
	for entry: AnimationEntry in entries:
		if entry == null or entry.animation == &"" or not entry.uses_sheet():
			continue
		var images: Array[Image] = SpriteSheetSlicer.slice(entry.sheet, entry.get_regions())
		if entry.remove_background:
			for image: Image in images:
				SpriteSheetSlicer.remove_background(image, entry.background_key, entry.background_tolerance)
		sheet_counts[entry.animation] = images.size()
		sheet_images.append_array(images)
	if align_sheet_frames and not sheet_images.is_empty():
		sheet_images = SpriteSheetSlicer.align_bottom_center(sheet_images)

	var next_sheet_image: int = 0
	for entry: AnimationEntry in entries:
		if entry == null or entry.animation == &"":
			continue
		var textures: Array[Texture2D] = []
		var fps: float = default_fps
		if entry.uses_sheet():
			for i: int in sheet_counts.get(entry.animation, 0):
				textures.append(ImageTexture.create_from_image(sheet_images[next_sheet_image]))
				next_sheet_image += 1
		elif not entry.piskel_path.is_empty():
			var data: PiskelLoader.Result = PiskelLoader.load_piskel(entry.piskel_path)
			if data != null:
				textures = data.frames
				fps = data.fps
		if textures.is_empty():
			continue
		frames.add_animation(entry.animation)
		frames.set_animation_loop(entry.animation, entry.loop)
		frames.set_animation_speed(entry.animation, entry.fps_override if entry.fps_override > 0.0 else fps)
		for texture: Texture2D in textures:
			frames.add_frame(entry.animation, texture)
	_built_cache[key] = frames
	return frames


func get_entry(anim: StringName) -> AnimationEntry:
	for entry: AnimationEntry in entries:
		if entry != null and entry.animation == anim:
			return entry
	return null


static func clear_cache() -> void:
	_built_cache.clear()
