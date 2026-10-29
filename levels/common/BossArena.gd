class_name BossArena
extends Area2D
## Zona de entrada a la arena del jefe. Cuando el jugador la cruza, activa al
## jefe asignado (que emite Events.boss_fight_started; las puertas configuradas
## con close_on = BOSS_FIGHT_STARTED se cierran solas). Se dispara una vez.
## Area2D sin capa; detecta al Player (2).

signal fight_started

@export var boss: BossBase

var _triggered: bool = false


func _ready() -> void:
	if boss == null:
		push_warning("BossArena '%s' sin jefe asignado." % get_path())


func _physics_process(_delta: float) -> void:
	if _triggered or boss == null:
		return
	for body: Node2D in get_overlapping_bodies():
		if body.is_in_group("player"):
			_triggered = true
			boss.activate(body)
			fight_started.emit()
			return
