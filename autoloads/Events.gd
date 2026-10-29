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
@warning_ignore("unused_signal")
signal player_jumped
## El jugador disparó; `cooldown` = segundos hasta poder volver a disparar.
@warning_ignore("unused_signal")
signal player_shot(cooldown: float)

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

# --- Jefes ---
@warning_ignore("unused_signal")
signal boss_fight_started(boss: Node, display_name: String, current: int, maximum: int)
@warning_ignore("unused_signal")
signal boss_health_changed(current: int, maximum: int)
@warning_ignore("unused_signal")
signal boss_phase_changed(boss: Node, phase: int)
## Se emite al terminar la animación de muerte del jefe.
@warning_ignore("unused_signal")
signal boss_defeated(boss: Node)

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
## Pide cambiar a otra escena de nivel (p. ej. al cruzar una puerta).
@warning_ignore("unused_signal")
signal level_change_requested(scene_path: String)

## Un nivel acaba de empezar (el HUD muestra su nombre).
@warning_ignore("unused_signal")
signal level_started(level_name: String)

## Se recogió un pickup ("collectible", "health"...).
@warning_ignore("unused_signal")
signal pickup_collected(kind: StringName)

# --- Audio ---
## Pide un efecto de sonido por nombre (ver AudioManager.SFX).
@warning_ignore("unused_signal")
signal sfx_requested(sfx_name: StringName)

# --- UI ---
## Muestra líneas de diálogo en la caja inferior (no pausa el juego).
@warning_ignore("unused_signal")
signal dialogue_requested(speaker: String, lines: PackedStringArray)
## La caja de diálogo terminó todas las líneas pendientes.
@warning_ignore("unused_signal")
signal dialogue_finished
## Mensaje centrado en el HUD. duration <= 0 = permanente.
@warning_ignore("unused_signal")
signal hud_message(text: String, duration: float)
