extends SceneTree
## Test de SceneTransition (shader de transición) y de la fuente del proyecto.
## No tipar con class_name del proyecto (se compila antes que los autoloads).

var covered_count: int = 0
var finished_count: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _run() -> void:
	var st: CanvasLayer = root.get_node("SceneTransition") as CanvasLayer
	st.connect("covered", func() -> void: covered_count += 1)
	st.connect("finished", func() -> void: finished_count += 1)
	var cover: ColorRect = st.get_node("Cover") as ColorRect
	_check((cover.material as ShaderMaterial).shader.resource_path == "res://shader/transition.gdshader", "usa shader/transition.gdshader")
	_check(not cover.visible and is_zero_approx(float(st.call("get_factor"))), "en reposo: invisible y factor 0")

	change_scene_to_file("res://levels/TestLevel.tscn")
	await _frames(5)
	var first_id: int = current_scene.get_instance_id()

	# Cambio de escena con transición
	st.call("change_scene", "res://levels/BossLevel.tscn")
	await create_timer(0.2).timeout
	var mid: float = float(st.call("get_factor"))
	_check(mid > 0.1 and mid < 1.0 and cover.visible, "cubriendo a mitad (factor %.2f)" % mid)
	_check(current_scene.get_instance_id() == first_id, "la escena no cambia hasta estar cubierta")
	st.call("change_scene", "res://levels/TestLevel.tscn")
	await create_timer(0.4).timeout
	_check(covered_count == 1 and current_scene != null and current_scene.name == "BossLevel", "cubierta: cambia a BossLevel (ignora la 2.ª petición)")
	await create_timer(0.7).timeout
	_check(finished_count == 1 and not cover.visible and is_zero_approx(float(st.call("get_factor"))), "se descubre y termina")
	_check(not bool(st.get("is_transitioning")), "is_transitioning vuelve a false")

	# Reinicio con R desde el LevelManager, con el juego en pausa (pantalla de victoria)
	var boss_id: int = current_scene.get_instance_id()
	paused = true
	var ev: InputEventAction = InputEventAction.new()
	ev.action = "restart"
	ev.pressed = true
	Input.parse_input_event(ev)
	await create_timer(1.3, true, false, true).timeout
	_check(current_scene.get_instance_id() != boss_id and not paused, "R reinicia con transición aunque esté en pausa")
	_check(finished_count == 2, "segunda transición completa")

	# Fuente del proyecto
	var font_path: String = String(ProjectSettings.get_setting("gui/theme/custom_font"))
	_check(font_path.ends_with("boldpixels.ttf") and load(font_path) is FontFile, "fuente BoldPixels configurada y cargable")
	var label: Label = current_scene.get_node("HUD/MessagePanel/MessageLabel") as Label
	_check(label.get_theme_font("font").resource_path == font_path, "las etiquetas del HUD usan BoldPixels")

	print("RESULT: %d fallos" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, name: String) -> void:
	if not cond:
		_failures += 1
	print(("PASS " if cond else "FAIL ") + name)
