class_name AnimationSet
extends Resource
## Conjunto de animaciones de un personaje. Se guarda como .tres y se asigna a un
## CharacterAnimator. El diseñador solo rellena nombre + .piskel + loop.

@export var entries: Array[AnimationEntry] = []


## Construye un SpriteFrames con todas las entradas que tengan archivo válido.
## Las entradas sin piskel_path se ignoran (plantilla aún sin arte).
func build_sprite_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	for entry: AnimationEntry in entries:
		if entry == null or entry.animation == &"" or entry.piskel_path.is_empty():
			continue
		var data: PiskelLoader.Result = PiskelLoader.load_piskel(entry.piskel_path)
		if data == null or data.frames.is_empty():
			continue
		frames.add_animation(entry.animation)
		frames.set_animation_loop(entry.animation, entry.loop)
		frames.set_animation_speed(entry.animation, entry.fps_override if entry.fps_override > 0.0 else data.fps)
		for texture: Texture2D in data.frames:
			frames.add_frame(entry.animation, texture)
	return frames


func get_entry(anim: StringName) -> AnimationEntry:
	for entry: AnimationEntry in entries:
		if entry != null and entry.animation == anim:
			return entry
	return null
