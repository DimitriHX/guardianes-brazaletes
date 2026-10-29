class_name StateMachine
extends Node
## Máquina de estados genérica. Sus hijos de tipo State son los estados,
## identificados por el nombre del nodo.
## El dueño (Player, jefes...) llama a start() cuando está listo y luego a
## update / physics_update / handle_input desde sus propios callbacks, para que
## el orden respecto a move_and_slide() sea explícito y predecible.

signal state_changed(from: StringName, to: StringName)

@export var initial_state: State

var current_state: State

var _states: Dictionary[StringName, State] = {}


func _ready() -> void:
	for child: Node in get_children():
		var state: State = child as State
		if state == null:
			continue
		_states[state.name] = state
		state.transition_requested.connect(transition_to)


func start() -> void:
	if initial_state == null:
		if _states.is_empty():
			push_error("StateMachine '%s' no tiene estados hijos." % get_path())
			return
		initial_state = _states.values()[0]
	current_state = initial_state
	current_state.enter(&"")
	state_changed.emit(&"", current_state.name)


func update(delta: float) -> void:
	if current_state != null:
		current_state.update(delta)


func physics_update(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


func handle_input(event: InputEvent) -> void:
	if current_state != null:
		current_state.handle_input(event)


func transition_to(target: StringName) -> void:
	var next: State = _states.get(target, null)
	if next == null:
		push_error("StateMachine: el estado '%s' no existe." % target)
		return
	if next == current_state:
		return
	var previous: StringName = current_state.name if current_state != null else &""
	if current_state != null:
		current_state.exit()
	current_state = next
	current_state.enter(previous)
	state_changed.emit(previous, current_state.name)


func get_current_state_name() -> StringName:
	return current_state.name if current_state != null else &""
