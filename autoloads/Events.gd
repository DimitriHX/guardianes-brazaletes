extends Node
## Bus de eventos global (Autoload "Events").
## Solo declara señales para la comunicación transversal entre sistemas.
## No guarda estado ni contiene lógica de juego.
##
## Uso:
##   Events.player_died.emit()
##   Events.player_died.connect(_on_player_died)

# --- Jugador ---
@warning_ignore("unused_signal")
signal player_health_changed(current: int, maximum: int)
@warning_ignore("unused_signal")
signal player_died

# --- Entidades (enemigos, jefes) ---
@warning_ignore("unused_signal")
signal enemy_died(enemy: Node)

# --- Combate genérico (emitidas por HealthComponent para cualquier entidad) ---
## Cada golpe que quita vida. `entity` es el padre del HealthComponent.
@warning_ignore("unused_signal")
signal entity_damaged(entity: Node, amount: int)
## La vida cruza hacia abajo el umbral crítico (critical_health_ratio).
@warning_ignore("unused_signal")
signal entity_health_critical(entity: Node)
@warning_ignore("unused_signal")
signal entity_died(entity: Node)

# --- Pickups ---
@warning_ignore("unused_signal")
signal collectible_picked(value: int)

# --- Nivel ---
@warning_ignore("unused_signal")
signal collectibles_changed(collected: int, required: int)
@warning_ignore("unused_signal")
signal level_completed
@warning_ignore("unused_signal")
signal level_restart_requested
