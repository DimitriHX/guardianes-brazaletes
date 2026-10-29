class_name ParticleBurst
extends CPUParticles2D
## Emisor de partículas de un solo uso (polvo al saltar/correr, chispas de daño).
## Activa `emitting = true` al entrar en escena y se libera automáticamente tras
## terminar su ciclo de vida (incluso en modo headless).

@export var particle_group: StringName = &"fx_particles"


static func spawn(scene: PackedScene, from: Node, at: Vector2) -> CPUParticles2D:
	if scene == null or from == null or not from.is_inside_tree():
		return null
	var tree: SceneTree = from.get_tree()
	var container: Node = tree.current_scene if tree.current_scene != null else tree.root
	var burst: CPUParticles2D = scene.instantiate() as CPUParticles2D
	if burst == null:
		return null
	container.add_child(burst)
	burst.global_position = at
	return burst


func _ready() -> void:
	add_to_group("fx_particles")
	if particle_group != &"":
		add_to_group(particle_group)
	one_shot = true
	emitting = true
	finished.connect(queue_free)
	# Respaldo para modo headless donde el renderizador puede no emitir `finished`.
	var ttl: float = maxf(lifetime, 0.1) + 0.15
	get_tree().create_timer(ttl, true, false, true).timeout.connect(queue_free)
