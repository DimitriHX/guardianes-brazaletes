extends SceneTree
## Regresiones de colisiones:
## - Se puede caminar por debajo de las plataformas finas (sólidas y one-way)
##   colocadas a 3 celdas del suelo.
## - Se puede saltar por encima del Cadejo sin tocarlo.
## - El Cadejo no gira en cada frame cuando el jugador pasa por encima.
## No tipar con class_name del proyecto (se compila antes que los autoloads).

var _failures: int = 0
var _player_hits: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _load(path: String, scene_name: String) -> void:
	change_scene_to_file(path)
	while current_scene == null or current_scene.name != scene_name:
		await process_frame
	await _frames(5)
	current_scene.get_node("HUD/DialogueBox").call("clear")
	for e: Node in get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(2)


## Primera plataforma fina (one-way o no) cuya cara superior está a 3 celdas
## del suelo (y = 540), sobre suelo firme.
func _find_low_platform(one_way: bool) -> Rect2:
	for body: Node in current_scene.get_node("World").get_children():
		var shape_node: CollisionShape2D = body.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node == null or shape_node.one_way_collision != one_way:
			continue
		var size: Vector2 = (shape_node.shape as RectangleShape2D).size
		var rect: Rect2 = Rect2((body as Node2D).global_position + shape_node.position - size / 2.0, size)
		if is_equal_approx(rect.position.y, 540.0) and size.y < 20.0:
			return rect
	return Rect2()


func _walk_under(one_way: bool, label: String) -> void:
	var rect: Rect2 = _find_low_platform(one_way)
	if not rect.has_area():
		_check(false, "hay una %s a 3 celdas del suelo" % label)
		return
	var p: CharacterBody2D = current_scene.get_node("Player") as CharacterBody2D
	p.global_position = Vector2(rect.position.x - 40.0, 580.0)
	p.velocity = Vector2.ZERO
	await _frames(10)
	Input.action_press("move_right")
	await _frames(int((rect.size.x + 100.0) / 220.0 * 60.0) + 30)
	Input.action_release("move_right")
	_check(p.global_position.x > rect.end.x + 20.0 and p.is_on_floor(),
		"se camina por debajo de %s (x=%.0f, fin=%.0f)" % [label, p.global_position.x, rect.end.x])


func _run() -> void:
	root.get_node("Events").connect("entity_damaged", func(e: Node, _a: int) -> void:
		if e.is_in_group("player"):
			_player_hits += 1)

	# --- Plataformas a 3 celdas del suelo (Nivel 1) ---
	await _load("res://levels/sueno_1/Bosque.tscn", "Bosque")
	await _walk_under(false, "plataforma sólida (=)")
	await _walk_under(true, "plataforma one-way (-)")

	# --- Saltar por encima del Cadejo (quieto, dormido) ---
	await _load("res://levels/sueno_1/Guarida.tscn", "Guarida")
	var boss: CharacterBody2D = current_scene.get_node("Cadejo") as CharacterBody2D
	var p: CharacterBody2D = current_scene.get_node("Player") as CharacterBody2D
	p.global_position = Vector2(boss.global_position.x - 110.0, 580.0)
	p.velocity = Vector2.ZERO
	await _frames(15)
	_player_hits = 0
	Input.action_press("move_right")
	await _frames(6)
	Input.action_press("jump")
	await _frames(50)
	Input.action_release("jump")
	await _frames(20)
	Input.action_release("move_right")
	_check(p.global_position.x > boss.global_position.x + 50.0 and _player_hits == 0,
		"se salta por encima del Cadejo sin tocarlo (x=%.0f, jefe=%.0f, golpes=%d)" % [p.global_position.x, boss.global_position.x, _player_hits])

	# --- El jefe no gira con el jugador justo encima ---
	p.get_node("Stats").set("damage_taken_multiplier", 0.0)
	p.global_position = Vector2(boss.global_position.x - 300.0, 580.0)
	boss.call("activate", p)
	await _frames(3)
	var flips: int = 0
	var last_facing: int = int(boss.get("facing"))
	for i: int in 40:
		# Jugador oscilando justo sobre el jefe (como al saltar por encima).
		p.global_position = Vector2(boss.global_position.x + (10.0 if i % 2 == 0 else -10.0), 470.0)
		p.velocity = Vector2.ZERO
		await physics_frame
		var f: int = int(boss.get("facing"))
		if f != last_facing:
			flips += 1
		last_facing = f
	_check(flips <= 1, "el Cadejo no tiembla girando con el jugador encima (%d giros)" % flips)

	print("RESULT: %d fallos" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, name: String) -> void:
	if not cond:
		_failures += 1
	print(("PASS " if cond else "FAIL ") + name)
