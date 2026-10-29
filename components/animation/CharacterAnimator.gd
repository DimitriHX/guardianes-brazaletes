class_name CharacterAnimator
extends AnimatedSprite2D
## Lógica de frames de un personaje, independiente del arte:
## - Construye sus SpriteFrames desde un AnimationSet (.piskel).
## - Prioridades: una animación de un solo uso (ataque, daño, muerte) no la
##   interrumpe la locomoción; solo otra de prioridad igual o mayor. Al terminar,
##   vuelve a la última animación pedida. "death" queda fija en su último frame.
## - Señales: one_shot_finished (fin de ataque/daño/muerte) y frame_reached
##   (cada cambio de frame, para sincronizar golpes o sonidos con un frame).
## - Sin arte asignado sigue funcionando: registra la animación pedida y da por
##   terminadas las de un solo uso tras `fallback_one_shot_time`.

signal one_shot_finished(anim: StringName)
signal frame_reached(anim: StringName, frame_index: int)

@export var animation_set: AnimationSet
## Animaciones de un solo uso y su prioridad (mayor gana). Las que no estén
## aquí se consideran bucles de locomoción (prioridad 0).
@export var one_shot_priorities: Dictionary[StringName, int] = {
	&"attack": 1,
	&"hurt": 2,
	&"death": 3,
}
## Nodos provisionales (ColorRect) que se ocultan cuando hay sprite real.
@export var placeholders: Array[CanvasItem] = []
## Duración simulada de una animación de un solo uso sin arte (0 = un frame).
@export var fallback_one_shot_time: float = 0.0
## Colocar el origen del sprite en el centro de su borde inferior (los pies):
## así basta con poner el nodo en la base de la colisión.
@export var anchor_bottom: bool = false

## Última animación pedida por los estados (la de "fondo").
var requested_animation: StringName = &""
## Animación que se está mostrando ahora.
var current_animation: StringName = &""
var has_frames: bool = false

var _locked_by: StringName = &""
var _token: int = 0


func _ready() -> void:
	if animation_set != null:
		sprite_frames = animation_set.build_sprite_frames()
	has_frames = sprite_frames != null and not sprite_frames.get_animation_names().is_empty()
	visible = has_frames
	if has_frames and anchor_bottom:
		var first: StringName = sprite_frames.get_animation_names()[0]
		offset.y = -float(sprite_frames.get_frame_texture(first, 0).get_height()) / 2.0
	for placeholder: CanvasItem in placeholders:
		if placeholder != null:
			placeholder.visible = not has_frames
	animation_finished.connect(_on_animation_finished)
	frame_changed.connect(_on_frame_changed)


func play_state(anim: StringName) -> void:
	if anim == &"":
		return
	if is_one_shot(anim):
		if _locked_by == &"death":
			return
		if _locked_by != &"" and get_priority(anim) < get_priority(_locked_by):
			return
		_locked_by = anim
		_start(anim)
		return
	requested_animation = anim
	if _locked_by == &"":
		_start(anim)


func is_one_shot(anim: StringName) -> bool:
	if has_frames and sprite_frames.has_animation(anim):
		return not sprite_frames.get_animation_loop(anim)
	return one_shot_priorities.has(anim)


func get_priority(anim: StringName) -> int:
	return one_shot_priorities.get(anim, 0)


func is_locked() -> bool:
	return _locked_by != &""


func _start(anim: StringName) -> void:
	current_animation = anim
	_token += 1
	if has_frames and sprite_frames.has_animation(anim):
		play(anim)
		frame = 0
		return
	# TODO(assets): falta la animación en el AnimationSet; se simula su duración.
	if is_one_shot(anim):
		var token: int = _token
		if fallback_one_shot_time <= 0.0:
			_finish_one_shot.call_deferred(anim, token)
		else:
			get_tree().create_timer(fallback_one_shot_time).timeout.connect(_finish_one_shot.bind(anim, token))


func _finish_one_shot(anim: StringName, token: int) -> void:
	# Ignorar finales obsoletos (otra animación empezó entretanto).
	if token != _token or _locked_by != anim:
		return
	if anim != &"death":
		_locked_by = &""
	one_shot_finished.emit(anim)
	if _locked_by == &"" and requested_animation != &"":
		_start(requested_animation)


func _on_animation_finished() -> void:
	_finish_one_shot(current_animation, _token)


func _on_frame_changed() -> void:
	frame_reached.emit(current_animation, frame)
