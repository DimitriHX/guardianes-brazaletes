class_name Door
extends Area2D
## Puerta configurable:
## - Cerrada: su Blocker (StaticBody2D en World) impide el paso.
## - Abierta + target_scene: al tocarla el jugador pide el cambio de nivel
##   (Events.level_change_requested; lo ejecuta el LevelManager).
## - Abierta sin target_scene: simple paso (p. ej. reja de una arena).
## Se abre/cierra por código (open/close) o sola, reaccionando a Events.
## Area2D sin capa; detecta al Player (2).

signal opened
signal closed
signal player_entered

enum Trigger { NONE, LEVEL_COMPLETED, BOSS_FIGHT_STARTED, BOSS_DEFEATED }

@export_file("*.tscn") var target_scene: String = ""
@export var start_open: bool = false
## Evento global que la abre.
@export var open_on: Trigger = Trigger.NONE
## Evento global que la cierra.
@export var close_on: Trigger = Trigger.NONE
@export_group("Sprite")
## Arte de la puerta cerrada. Vacío = se usa el ColorRect provisional
## (p. ej. la reja de la arena, que aún no tiene arte).
@export var closed_texture: Texture2D
## Arte de la puerta abierta (portal). Vacío = se reutiliza closed_texture.
@export var open_texture: Texture2D
## Frames en horizontal dentro de open_texture (animación del vórtice).
@export_range(1, 16, 1) var open_frames: int = 1
@export var open_fps: float = 8.0
## Reja: al abrirse el sprite sube y se oculta; al cerrarse cae de golpe.
## (Se ignora open_texture.)
@export var slides_open: bool = false
@export var slide_time: float = 0.35
## Pulso de brillo del portal abierto (0 = sin pulso).
@export_range(0.0, 1.0, 0.05) var open_pulse: float = 0.35
@export_group("Placeholder")
@export var closed_color: Color = Color(0.45, 0.28, 0.15)
@export var open_color: Color = Color(0.1, 0.08, 0.06, 0.6)

var is_open: bool = false

var _used: bool = false
var _pulse_tween: Tween
var _frame_time: float = 0.0

@onready var _blocker_shape: CollisionShape2D = $Blocker/CollisionShape2D
@onready var _visual: ColorRect = $Visual
@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	_set_open(start_open, false)
	_connect_trigger(open_on, open)
	_connect_trigger(close_on, close)


func _process(delta: float) -> void:
	if not is_open or _sprite.hframes <= 1:
		return
	_frame_time += delta * open_fps
	_sprite.frame = int(_frame_time) % _sprite.hframes


func _physics_process(_delta: float) -> void:
	if not is_open or target_scene.is_empty() or _used:
		return
	for body: Node2D in get_overlapping_bodies():
		if body.is_in_group("player") and not (body.has_method("is_dead") and bool(body.call("is_dead"))):
			_used = true
			player_entered.emit()
			Events.level_change_requested.emit(target_scene)
			return


func open() -> void:
	_set_open(true, true)


func close() -> void:
	_set_open(false, true)


func _set_open(value: bool, notify: bool) -> void:
	if notify and value == is_open:
		return
	is_open = value
	# set_deferred: puede llamarse durante un callback de física.
	_blocker_shape.set_deferred("disabled", value)
	_visual.color = open_color if value else closed_color
	_update_sprite(value)
	if notify:
		if value:
			opened.emit()
			Events.sfx_requested.emit(&"door_open")
		else:
			closed.emit()


func _update_sprite(value: bool) -> void:
	var has_art: bool = closed_texture != null
	_sprite.visible = has_art
	_visual.visible = not has_art
	if not has_art:
		# TODO(assets): sprite de la reja de la arena con animación de apertura.
		return
	if slides_open:
		_slide_sprite(value)
		return
	var use_open: bool = value and open_texture != null
	_sprite.texture = open_texture if use_open else closed_texture
	_sprite.hframes = open_frames if use_open else 1
	_sprite.frame = 0
	_frame_time = 0.0
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	_sprite.modulate = Color.WHITE
	if value and open_pulse > 0.0:
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(_sprite, "modulate", Color(1.0 + open_pulse, 1.0 + open_pulse, 1.0 + open_pulse), 0.8).set_trans(Tween.TRANS_SINE)
		_pulse_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_SINE)


func _slide_sprite(value: bool) -> void:
	_sprite.texture = closed_texture
	var height: float = closed_texture.get_size().y
	var target_y: float = -height if value else 0.0
	var target_a: float = 0.0 if value else 1.0
	if _pulse_tween != null:
		_pulse_tween.kill()
	if not is_inside_tree() or not is_node_ready():
		_sprite.position.y = target_y
		_sprite.modulate.a = target_a
		return
	_pulse_tween = create_tween().set_parallel()
	# Abrir: sube despacio. Cerrar: cae rápido (golpe de la reja).
	var t: float = slide_time if value else slide_time * 0.5
	var trans: Tween.TransitionType = Tween.TRANS_SINE if value else Tween.TRANS_QUAD
	_pulse_tween.tween_property(_sprite, "position:y", target_y, t).set_trans(trans).set_ease(Tween.EASE_IN)
	_pulse_tween.tween_property(_sprite, "modulate:a", target_a, t)


## Conecta siempre a MÉTODOS de este nodo (no lambdas): Godot los desconecta
## solo al liberar la puerta. Una lambda conectada a un autoload sobrevive al
## reinicio del nivel y acaba llamando a open/close sobre una puerta liberada.
func _connect_trigger(trigger: Trigger, callback: Callable) -> void:
	var opens: bool = callback == open
	match trigger:
		Trigger.LEVEL_COMPLETED:
			Events.level_completed.connect(open if opens else close)
		Trigger.BOSS_FIGHT_STARTED:
			Events.boss_fight_started.connect(_on_boss_fight_started_open if opens else _on_boss_fight_started_close)
		Trigger.BOSS_DEFEATED:
			Events.boss_defeated.connect(_on_boss_defeated_open if opens else _on_boss_defeated_close)


func _on_boss_fight_started_open(_boss: Node, _name: String, _current: int, _maximum: int) -> void:
	open()


func _on_boss_fight_started_close(_boss: Node, _name: String, _current: int, _maximum: int) -> void:
	close()


func _on_boss_defeated_open(_boss: Node) -> void:
	open()


func _on_boss_defeated_close(_boss: Node) -> void:
	close()
