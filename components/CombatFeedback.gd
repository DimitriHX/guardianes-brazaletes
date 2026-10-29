class_name CombatFeedback
extends Node
## Sistema de impacto visual y feedback de movimiento por nivel (Sprint 10):
## - Hitstop (`Engine.time_scale`): congela brevemente el tiempo al impactar
##   (`Events.entity_damaged` o `Events.hitstop_requested`), midiendo la duración
##   en tiempo real (`Time.get_ticks_usec`) para no depender de `time_scale`.
## - Partículas vía `Events`:
##   - `DustParticles.tscn` en los pies del jugador al saltar (`Events.player_jumped`),
##     al aterrizar y periódicamente mientras corre por el suelo.
##   - `HitSparkParticles.tscn` sobre la entidad dañada (`Events.entity_damaged`).
##   - Peticiones explícitas vía `Events.particles_requested(kind, world_pos)`.

const DUST_SCENE: PackedScene = preload("res://entities/fx/DustParticles.tscn")
const SPARKS_SCENE: PackedScene = preload("res://entities/fx/HitSparkParticles.tscn")

@export_group("Hitstop")
@export var hitstop_enabled: bool = true
@export var player_hurt_scale: float = 0.12
@export var player_hurt_duration: float = 0.055
@export var enemy_hit_scale: float = 0.18
@export var enemy_hit_duration: float = 0.04
@export_group("Partículas de Movimiento")
@export var foot_offset: Vector2 = Vector2(0.0, 20.0)
@export var run_dust_interval: float = 0.22
@export var min_run_speed_for_dust: float = 80.0

var _hitstop_end_usec: int = 0
var _run_dust_timer: float = 0.0
var _was_on_floor: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("combat_feedback")
	Events.hitstop_requested.connect(trigger_hitstop)
	Events.entity_damaged.connect(_on_entity_damaged)
	Events.player_jumped.connect(_on_player_jumped)
	Events.particles_requested.connect(spawn_particles)


func _exit_tree() -> void:
	if _hitstop_end_usec > 0 or Engine.time_scale != 1.0:
		_hitstop_end_usec = 0
		Engine.time_scale = 1.0


func _process(delta: float) -> void:
	if _hitstop_end_usec > 0 and Time.get_ticks_usec() >= _hitstop_end_usec:
		_hitstop_end_usec = 0
		Engine.time_scale = 1.0
	if get_tree().paused:
		return
	_update_player_movement_dust(delta)


func trigger_hitstop(scale: float = 0.15, duration: float = 0.045) -> void:
	if not hitstop_enabled or duration <= 0.0:
		return
	var clamped_scale: float = clampf(scale, 0.02, 1.0)
	var end_usec: int = Time.get_ticks_usec() + int(duration * 1000000.0)
	if _hitstop_end_usec == 0 or clamped_scale < Engine.time_scale:
		Engine.time_scale = clamped_scale
	_hitstop_end_usec = maxi(_hitstop_end_usec, end_usec)


func is_hitstop_active() -> bool:
	return _hitstop_end_usec > 0 and Engine.time_scale < 1.0


func spawn_particles(kind: StringName, world_pos: Vector2) -> CPUParticles2D:
	var scene: PackedScene = SPARKS_SCENE if kind == &"sparks" else DUST_SCENE
	return ParticleBurst.spawn(scene, self, world_pos)


func _update_player_movement_dust(delta: float) -> void:
	var player: CharacterBody2D = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null or (player.has_method("is_dead") and bool(player.call("is_dead"))):
		return
	var on_floor: bool = player.is_on_floor()
	if on_floor and not _was_on_floor:
		spawn_particles(&"dust", player.global_position + foot_offset)
		_run_dust_timer = run_dust_interval * 0.5
	_was_on_floor = on_floor

	if on_floor and absf(player.velocity.x) >= min_run_speed_for_dust:
		_run_dust_timer -= delta
		if _run_dust_timer <= 0.0:
			_run_dust_timer = run_dust_interval
			spawn_particles(&"dust", player.global_position + foot_offset)
	else:
		_run_dust_timer = 0.0


func _on_player_jumped() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		spawn_particles(&"dust", player.global_position + foot_offset)
		_was_on_floor = false


func _on_entity_damaged(entity: Node, _amount: int) -> void:
	var node2d: Node2D = entity as Node2D
	if node2d != null:
		spawn_particles(&"sparks", node2d.global_position)
	if entity != null and entity.is_in_group("player"):
		trigger_hitstop(player_hurt_scale, player_hurt_duration)
	else:
		trigger_hitstop(enemy_hit_scale, enemy_hit_duration)
