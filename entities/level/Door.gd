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
@export_group("Placeholder")
@export var closed_color: Color = Color(0.45, 0.28, 0.15)
@export var open_color: Color = Color(0.1, 0.08, 0.06, 0.6)

var is_open: bool = false

var _used: bool = false

@onready var _blocker_shape: CollisionShape2D = $Blocker/CollisionShape2D
@onready var _visual: ColorRect = $Visual


func _ready() -> void:
	_set_open(start_open, false)
	_connect_trigger(open_on, open)
	_connect_trigger(close_on, close)


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
	# TODO(assets): animación de apertura/cierre y sprite de puerta/reja.
	_visual.color = open_color if value else closed_color
	if notify:
		if value:
			opened.emit()
		else:
			closed.emit()


func _connect_trigger(trigger: Trigger, callback: Callable) -> void:
	match trigger:
		Trigger.LEVEL_COMPLETED:
			Events.level_completed.connect(callback)
		Trigger.BOSS_FIGHT_STARTED:
			Events.boss_fight_started.connect(func(_b: Node, _n: String, _c: int, _m: int) -> void: callback.call())
		Trigger.BOSS_DEFEATED:
			Events.boss_defeated.connect(func(_b: Node) -> void: callback.call())
