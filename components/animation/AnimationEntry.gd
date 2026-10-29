class_name AnimationEntry
extends Resource
## Una animación de un AnimationSet: nombre lógico (el que piden los estados)
## y archivo .piskel del que salen sus frames.

## Nombre que usan los estados: idle, walk, jump, fall, attack, hurt, death...
@export var animation: StringName = &""
@export_file("*.piskel") var piskel_path: String = ""
## false = animación de un solo uso (ataque, daño, muerte).
@export var loop: bool = true
## 0 = usar los fps guardados en el .piskel.
@export var fps_override: float = 0.0
