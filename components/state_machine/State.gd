class_name State
extends Node
## Clase base de un estado. Se sobrescriben los métodos virtuales que hagan falta.
## Un estado NO cambia de estado por sí mismo: pide la transición a su
## StateMachine (padre) emitiendo `transition_requested` con el nombre del nodo destino.

signal transition_requested(target: StringName)

## Animación asociada. La reproduce el estado al entrar, no el cuerpo.
@export var animation: StringName = &""


## Llamado al activarse. `previous` es el nombre del estado anterior (&"" al arrancar).
func enter(_previous: StringName) -> void:
	pass


## Llamado justo antes de cambiar a otro estado.
func exit() -> void:
	pass


## Equivalente a _process mientras el estado está activo.
func update(_delta: float) -> void:
	pass


## Equivalente a _physics_process mientras el estado está activo.
func physics_update(_delta: float) -> void:
	pass


## Equivalente a _unhandled_input mientras el estado está activo.
func handle_input(_event: InputEvent) -> void:
	pass
