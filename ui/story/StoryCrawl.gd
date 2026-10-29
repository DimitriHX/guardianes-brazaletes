class_name StoryCrawl
extends Control
## Secuencia de historia estilo "crawl" de película: prólogo que aparece y se
## desvanece, y después el texto sube en perspectiva hasta perderse en el fondo.
## Reutilizable entre sueños: el texto y la escena siguiente son exports.
## Se salta con Aceptar / Cancelar / clic. Al terminar emite `finished` y, si
## hay `next_scene`, pide el cambio de escena con la transición global.

signal finished

## Frase breve antes del crawl (vacía = sin prólogo).
@export_multiline var prologue: String = "Hace no mucho tiempo, en un sueño muy, muy profundo..."
@export var title: String = "EL BRAZALETE\nDEL GUARDIÁN"
@export var episode: String = "Sueño I: El Cadejo negro"
@export_multiline var paragraphs: PackedStringArray = []
@export_file("*.tscn") var next_scene: String = ""
## Velocidad de subida del texto (px del SubViewport por segundo).
@export var scroll_speed: float = 70.0
## La historia termina cuando el final del texto sube por encima de esta fracción
## del SubViewport: con la perspectiva y el fundido del shader, por encima de
## ~0.3 el texto ya no se lee (esperar a que salga del todo dejaba la pantalla
## varios segundos solo con estrellas).
@export_range(0.0, 1.0, 0.05) var end_at_ratio: float = 0.3
@export var outro_fade_time: float = 1.0
@export var prologue_fade_time: float = 1.2
@export var prologue_hold_time: float = 2.6
@export_group("Estrellas")
@export var star_count: int = 220
@export var star_seed: int = 11

var _skipped: bool = false
var _crawling: bool = false
var _stars: PackedVector3Array = PackedVector3Array()

@onready var _prologue_label: Label = %PrologueLabel
@onready var _viewport: SubViewport = %CrawlViewport
@onready var _crawl_view: TextureRect = %CrawlView
@onready var _text_box: VBoxContainer = %TextBox
@onready var _title_label: Label = %TitleLabel
@onready var _episode_label: Label = %EpisodeLabel
@onready var _body_label: Label = %BodyLabel


func _ready() -> void:
	_crawl_view.texture = _viewport.get_texture()
	_title_label.text = title
	_episode_label.text = episode
	_body_label.text = "\n\n".join(paragraphs)
	_prologue_label.text = prologue
	_prologue_label.modulate.a = 0.0
	_generate_stars()
	resized.connect(_generate_stars)
	AudioManager.play_music(&"menu")
	_start.call_deferred()


func _process(delta: float) -> void:
	if not _crawling:
		return
	_text_box.position.y -= scroll_speed * delta
	if _text_box.position.y + _text_box.size.y < float(_viewport.size.y) * end_at_ratio:
		_crawling = false
		_fade_out_and_finish()


func _draw() -> void:
	for star: Vector3 in _stars:
		var c: Color = Color(1.0, 1.0, 1.0, star.z)
		draw_rect(Rect2(star.x, star.y, 2.0, 2.0), c)


func _unhandled_input(event: InputEvent) -> void:
	var skip: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		skip = skip or (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT)
	if skip:
		get_viewport().set_input_as_handled()
		skip_story()


## Salta el resto de la secuencia.
func skip_story() -> void:
	_finish()


func is_crawling() -> bool:
	return _crawling


func _start() -> void:
	if not prologue.is_empty():
		var tween: Tween = create_tween()
		tween.tween_property(_prologue_label, "modulate:a", 1.0, prologue_fade_time)
		tween.tween_interval(prologue_hold_time)
		tween.tween_property(_prologue_label, "modulate:a", 0.0, prologue_fade_time)
		await tween.finished
	if _skipped:
		return
	# El texto entra por el borde inferior del SubViewport (el más cercano).
	_text_box.position.y = float(_viewport.size.y)
	_crawling = true


func _fade_out_and_finish() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_crawl_view, "modulate:a", 0.0, outro_fade_time)
	await tween.finished
	_finish()


func _finish() -> void:
	if _skipped:
		return
	_skipped = true
	_crawling = false
	finished.emit()
	if next_scene.is_empty():
		return
	# Si aún se está revelando la transición de entrada, change_scene se
	# ignoraría y la historia se quedaría atascada: esperar a que acabe.
	if SceneTransition.is_transitioning:
		await SceneTransition.finished
	SceneTransition.change_scene(next_scene)


func _generate_stars() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = star_seed
	_stars.clear()
	for i: int in star_count:
		_stars.append(Vector3(
			rng.randf_range(0.0, size.x),
			rng.randf_range(0.0, size.y),
			rng.randf_range(0.25, 1.0)
		))
	queue_redraw()
