class_name Effect
extends AnimatedSprite2D
## Efecto visual de un solo uso (impacto, estallido, destello): reproduce la
## animación "play" de su AnimationSet y se libera al terminar.
## Uso: Effect.spawn(impact_scene, self, global_position)

@export var animation_set: AnimationSet
## Si no hay arte, se libera tras este tiempo.
@export var fallback_lifetime: float = 0.3


## Instancia el efecto en la escena actual (no como hijo de quien lo crea, que
## puede liberarse justo después). Devuelve null si no hay escena.
static func spawn(scene: PackedScene, from: Node, at: Vector2) -> Node2D:
	if scene == null or from == null or not from.is_inside_tree():
		return null
	var tree: SceneTree = from.get_tree()
	var container: Node = tree.current_scene if tree.current_scene != null else tree.root
	var effect: Node2D = scene.instantiate() as Node2D
	container.add_child(effect)
	effect.global_position = at
	return effect


func _ready() -> void:
	if animation_set != null:
		sprite_frames = animation_set.build_sprite_frames()
	if sprite_frames != null and sprite_frames.has_animation(&"play"):
		animation_finished.connect(queue_free)
		play(&"play")
	else:
		get_tree().create_timer(fallback_lifetime).timeout.connect(queue_free)
