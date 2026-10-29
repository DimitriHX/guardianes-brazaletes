class_name LevelManager
extends Node
## Controla el bucle del nivel:
## - Victoria según `win_condition`: recoger los coleccionables necesarios
##   o derrotar al jefe. Emite Events.level_completed y un mensaje en el HUD;
##   con pause_on_complete pausa el juego (final), si no, se sigue jugando
##   (p. ej. para cruzar la puerta que se acaba de abrir).
## - Reinicia el nivel al morir el jugador, al caer por debajo de kill_y
##   o al pulsar "restart".
## - Cambia de nivel cuando alguien emite Events.level_change_requested.
## Se coloca como hijo de la escena del nivel.

enum WinCondition { COLLECTIBLES, BOSS_DEFEATED }

@export var win_condition: WinCondition = WinCondition.COLLECTIBLES
## Coleccionables necesarios para ganar. 0 = la suma de todos los del nivel.
@export var required_collectibles: int = 0
@export var pause_on_complete: bool = true
@export_multiline var completed_message: String = "¡Nivel completado!\nPulsa R para reiniciar"
## Segundos entre la muerte del jugador y el reinicio.
@export var restart_delay: float = 1.5
## Si el jugador cae por debajo de esta Y, muere.
@export var kill_y: float = 1000.0

var collected: int = 0
var required: int = 0
var is_completed: bool = false

var _restarting: bool = false


func _ready() -> void:
	# Debe seguir funcionando con el árbol en pausa (victoria) para poder reiniciar.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.collectible_picked.connect(_on_collectible_picked)
	Events.player_died.connect(_on_player_died)
	Events.level_restart_requested.connect(_on_restart_requested)
	Events.level_change_requested.connect(change_level)
	Events.boss_defeated.connect(_on_boss_defeated)
	# Diferido: los Pickups se registran en el grupo durante su propio _ready.
	_count_required.call_deferred()


func _physics_process(_delta: float) -> void:
	if _restarting or get_tree().paused:
		return
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.global_position.y > kill_y and player.has_method("kill"):
		player.call("kill")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		Events.level_restart_requested.emit()


## Los cambios de escena pasan por SceneTransition (cubre, cambia, descubre;
## también quita la pausa).
func restart_level() -> void:
	SceneTransition.reload_scene()


func change_level(scene_path: String) -> void:
	if _restarting:
		return
	_restarting = true
	SceneTransition.change_scene(scene_path)


func _count_required() -> void:
	if required_collectibles > 0:
		required = required_collectibles
	else:
		required = 0
		for node: Node in get_tree().get_nodes_in_group("collectibles"):
			required += int(node.get("amount"))
	if required == 0 and win_condition == WinCondition.COLLECTIBLES:
		push_warning("LevelManager: el nivel no tiene coleccionables; no se podrá ganar.")
	Events.collectibles_changed.emit(collected, required)


func _complete() -> void:
	if is_completed:
		return
	is_completed = true
	Events.level_completed.emit()
	Events.hud_message.emit(completed_message, 0.0 if pause_on_complete else 2.5)
	if pause_on_complete:
		get_tree().paused = true


func _on_collectible_picked(value: int) -> void:
	collected += value
	Events.collectibles_changed.emit(collected, required)
	if win_condition == WinCondition.COLLECTIBLES and required > 0 and collected >= required:
		_complete()


func _on_boss_defeated(_boss: Node) -> void:
	if win_condition == WinCondition.BOSS_DEFEATED:
		_complete()


func _on_player_died() -> void:
	if _restarting or (is_completed and pause_on_complete):
		return
	_restarting = true
	# Conexión a un método (no await): si el nivel se recarga antes, se desconecta sola.
	get_tree().create_timer(restart_delay).timeout.connect(restart_level)


func _on_restart_requested() -> void:
	restart_level()
