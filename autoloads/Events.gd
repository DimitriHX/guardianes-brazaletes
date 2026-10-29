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
