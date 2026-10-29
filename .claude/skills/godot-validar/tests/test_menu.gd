extends SceneTree
## Test del menú principal y la secuencia de historia (StoryCrawl):
## foco inicial, panel de opciones, Iniciar -> historia -> Nivel 1, y saltar.
## No tipar con class_name del proyecto (se compila antes que los autoloads).

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _wait_scene(scene_name: String, max_frames: int = 300) -> void:
	for i: int in max_frames:
		if current_scene != null and current_scene.name == scene_name:
			return
		await process_frame


func _run() -> void:
	change_scene_to_file("res://ui/menus/MainMenu.tscn")
	await _wait_scene("MainMenu")
	await _frames(3)
	var menu: Control = current_scene as Control
	var start: Button = menu.get_node("%StartButton") as Button
	_check(menu.get_viewport().gui_get_focus_owner() == start, "el foco empieza en INICIAR JUEGO")

	(menu.get_node("%OptionsButton") as Button).emit_signal("pressed")
	await _frames(2)
	_check(bool(menu.call("is_options_open")) and not (menu.get_node("%MainButtons") as Control).visible, "OPCIONES abre su panel y oculta los botones")
	var windowed: Button = menu.get_node("%WindowedButton") as Button
	var fullscreen: Button = menu.get_node("%FullscreenButton") as Button
	_check(windowed.button_group != null and windowed.button_group == fullscreen.button_group and windowed.button_pressed != fullscreen.button_pressed,
		"pantalla: VENTANA / COMPLETA excluyentes")
	(menu.get_node("%BackButton") as Button).emit_signal("pressed")
	await _frames(2)
	_check(not bool(menu.call("is_options_open")) and (menu.get_node("%MainButtons") as Control).visible, "VOLVER cierra el panel de opciones")

	start.emit_signal("pressed")
	await _wait_scene("StoryCrawl")
	_check(current_scene != null and current_scene.name == "StoryCrawl", "INICIAR JUEGO abre la historia")
	var crawl: Control = current_scene as Control
	var body: Label = crawl.get_node("%BodyLabel") as Label
	_check(body.text.contains("Emma") and body.text.contains("CADEJO"), "el texto resume la historia del juego")
	await create_timer(6.0).timeout
	_check(bool(crawl.call("is_crawling")), "tras el prólogo el texto empieza a subir")
	var box: Control = crawl.get_node("%TextBox") as Control
	var y0: float = box.position.y
	await create_timer(0.5).timeout
	_check(box.position.y < y0, "el texto sube (%.0f -> %.0f)" % [y0, box.position.y])

	# Sin saltar: al acabar el texto termina sola (sin quedarse en bucle/negro).
	crawl.set("scroll_speed", 3000.0)
	await _wait_scene("Bosque", 600)
	_check(current_scene != null and current_scene.name == "Bosque", "al terminar el texto la historia carga el Nivel 1 sola")

	change_scene_to_file("res://ui/story/StoryCrawl.tscn")
	await _wait_scene("StoryCrawl")
	await _frames(3)
	current_scene.call("skip_story")
	await _wait_scene("Bosque")
	_check(current_scene != null and current_scene.name == "Bosque", "saltar la historia carga el Nivel 1")

	print("RESULT: %d fallos" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, name: String) -> void:
	if not cond:
		_failures += 1
	print(("PASS " if cond else "FAIL ") + name)
