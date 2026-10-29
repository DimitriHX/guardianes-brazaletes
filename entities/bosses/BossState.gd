class_name BossState
extends State
## Base de los estados de un jefe. Recibe al BossBase mediante setup().

var boss: BossBase


func setup(controlled: BossBase) -> void:
	boss = controlled


func enter(_previous: StringName) -> void:
	boss.play_animation(animation)
