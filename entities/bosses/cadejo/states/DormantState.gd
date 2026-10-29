extends BossState
## Esperando a que empiece el combate (BossBase.activate). Quieto e inofensivo.


func physics_update(delta: float) -> void:
	boss.apply_gravity(delta)
	boss.velocity.x = 0.0
