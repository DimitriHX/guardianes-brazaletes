extends BossState
## Derrotado: se detiene y reproduce "death". BossBase emite
## Events.boss_defeated cuando termina la animación.


func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	boss.velocity.x = 0.0
