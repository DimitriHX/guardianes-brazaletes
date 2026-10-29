class_name LevelManager
extends Node
## Controla el bucle del nivel:
## - Cuenta los coleccionables recogidos (Events.collectible_picked) y declara
##   la victoria al llegar a los necesarios (Events.level_completed + pausa).
## - Reinicia el nivel al morir el jugador, al caer por debajo de kill_y
##   o al pulsar "restart".
## Se coloca como hijo de la escena del nivel.

## Coleccionables necesarios para ganar. 0 = la suma de todos los del nivel.
@export var required_collectibles: int = 0
## Segundos entre la muerte del jugador y el reinicio.
@export var restart_delay: float = 1.5
## Si el jugador cae por debajo de esta Y, muere.
@export var kill_y: float = 1000.0

var collected: int = 0
var required: int = 0

var _finished: bool = false


func _ready() -> void:
	# Debe seguir funcionando con el árbol en pausa (victoria) para poder reiniciar.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.collectible_picked.connect(_on_collectible_picked)
	Events.player_died.connect(_on_player_died)
	Events.level_restart_requested.connect(_on_restart_requested)
	# Diferido: los Pickups se registran en el grupo durante su propio _ready.
	_count_required.call_deferred()


func _physics_process(_delta: float) -> void:
	if _finished:
		return
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.global_position.y > kill_y and player.has_method("kill"):
		player.call("kill")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		Events.level_restart_requested.emit()


func restart_level() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene.call_deferred()


func _count_required() -> void:
	if required_collectibles > 0:
		required = required_collectibles
	else:
		required = 0
		for node: Node in get_tree().get_nodes_in_group("collectibles"):
			required += int(node.get("amount"))
	if required == 0:
		push_warning("LevelManager: el nivel no tiene coleccionables; no se podrá ganar.")
	Events.collectibles_changed.emit(collected, required)


func _win() -> void:
	_finished = true
	Events.level_completed.emit()
	get_tree().paused = true


func _on_collectible_picked(value: int) -> void:
	if _finished:
		return
	collected += value
	Events.collectibles_changed.emit(collected, required)
	if required > 0 and collected >= required:
		_win()


func _on_player_died() -> void:
	if _finished:
		return
	_finished = true
	# Conexión a un método (no await): si el nivel se recarga antes, se desconecta sola.
	get_tree().create_timer(restart_delay).timeout.connect(restart_level)


func _on_restart_requested() -> void:
	restart_level()
