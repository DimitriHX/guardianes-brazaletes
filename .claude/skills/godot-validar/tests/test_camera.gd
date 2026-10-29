extends SceneTree
## Test de GameCamera en TestLevel: zoom, límites desde CameraBounds,
## look-ahead y que nunca se vea fuera del mapa.
## No tipar con class_name del proyecto (se compila antes que los autoloads).

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _view_rect(cam: Camera2D) -> Rect2:
	var size: Vector2 = cam.get_viewport_rect().size / cam.zoom
	return Rect2(cam.get_screen_center_position() - size / 2.0, size)


func _clear_enemies() -> void:
	for e: Node in get_nodes_in_group("enemies"):
		e.queue_free()


func _run() -> void:
	change_scene_to_file("res://levels/sueno_1/Bosque.tscn")
	await _frames(5)
	_clear_enemies()
	var player: CharacterBody2D = current_scene.get_node("Player") as CharacterBody2D
	var cam: Camera2D = player.get_node("GameCamera") as Camera2D
	var bounds: Rect2 = (current_scene.get_node("CameraBounds") as Control).get_global_rect()

	_check(cam.is_current(), "GameCamera es la cámara activa")
	# Arranque: la cámara no viaja desde el origen y no muestra el vacío
	var v0: Rect2 = _view_rect(cam)
	_check(bounds.encloses(v0), "al cargar, la vista está dentro del mapa %s" % str(v0))
	var zl: float = float(cam.get("zoom_level"))
	_check(cam.zoom.x >= zl and cam.zoom.x == cam.zoom.y, "zoom >= zoom_level %.1f (%s)" % [zl, str(cam.zoom)])
	var vs: Vector2 = cam.get_viewport_rect().size / cam.zoom
	_check(vs.x <= bounds.size.x + 0.5 and vs.y <= bounds.size.y + 0.5, "ventana alta (%s): el zoom sube para caber en el mapa" % str(cam.get_viewport_rect().size))
	root.size = Vector2i(1280, 720)
	await _frames(3)
	_check(is_equal_approx(cam.zoom.x, zl), "ventana 16:9 (%s): zoom exacto = zoom_level (%s)" % [str(cam.get_viewport_rect().size), str(cam.zoom)])
	_check(cam.position_smoothing_enabled, "position_smoothing activado")
	_check(cam.limit_left == floori(bounds.position.x) and cam.limit_right == ceili(bounds.end.x)
		and cam.limit_top == floori(bounds.position.y) and cam.limit_bottom == ceili(bounds.end.y),
		"límites = CameraBounds (%d,%d,%d,%d)" % [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom])

	var v: Rect2 = _view_rect(cam)
	_check(bounds.grow(0.5).encloses(v), "tras cambiar a 16:9 la vista sigue dentro del mapa %s" % str(v))

	# Look-ahead hacia la derecha
	player.position = Vector2(900, 580)
	Input.action_press("move_right")
	await _frames(90)
	Input.action_release("move_right")
	_check(cam.position.x > 30.0, "look-ahead hacia la derecha (%.1f)" % cam.position.x)
	Input.action_press("move_left")
	await _frames(4)
	Input.action_release("move_left")
	await _frames(90)
	_check(cam.position.x < -30.0, "look-ahead se invierte al mirar a la izquierda (%.1f)" % cam.position.x)

	# Bordes: nunca fuera del mapa
	var all_inside: bool = true
	for pos: Vector2 in [Vector2(30, 580), Vector2(1880, 580), Vector2(1450, 460)]:
		player.position = pos
		player.velocity = Vector2.ZERO
		await _frames(120)
		v = _view_rect(cam)
		if not bounds.grow(0.5).encloses(v):
			all_inside = false
			print("   vista fuera en ", pos, ": ", v)
	_check(all_inside, "en los extremos del nivel la vista no sale de los límites")

	# El jugador sigue en pantalla
	v = _view_rect(cam)
	_check(v.has_point(player.global_position), "el jugador está dentro de la vista")

	print("RESULT: %d fallos" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, name: String) -> void:
	if not cond:
		_failures += 1
	print(("PASS " if cond else "FAIL ") + name)
