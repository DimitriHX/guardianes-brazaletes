extends SceneTree
## Test de regresión del jugador (movimiento, salto, disparo, vida).
## Ejecutar: Godot_console --headless --path . --script <ruta absoluta a este archivo>
## No tipar con class_name del proyecto (se compila antes que los autoloads).

const FLOOR_TOP: float = 100.0

var p: CharacterBody2D
var died_count: int = 0
var hp_events: Array[String] = []
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _box(layer: int, size: Vector2, pos: Vector2, script: GDScript = null) -> StaticBody2D:
	var b: StaticBody2D = StaticBody2D.new()
	b.collision_layer = layer
	b.collision_mask = 0
	if script != null:
		b.set_script(script)
	var cs: CollisionShape2D = CollisionShape2D.new()
	var r: RectangleShape2D = RectangleShape2D.new()
	r.size = size
	cs.shape = r
	b.add_child(cs)
	b.position = pos
	root.add_child(b)
	return b


func _tap(action: String, hold_frames: int = 2) -> void:
	Input.action_press(action)
	await _frames(hold_frames)
	Input.action_release(action)


func _run() -> void:
	_box(1, Vector2(4000, 20), Vector2(0, FLOOR_TOP + 10))
	var events: Node = root.get_node("Events")
	events.player_died.connect(func() -> void: died_count += 1)
	events.player_health_changed.connect(func(c: int, m: int) -> void: hp_events.append("%d/%d" % [c, m]))

	p = (load("res://entities/player/Player.tscn") as PackedScene).instantiate() as CharacterBody2D
	root.add_child(p)
	await _frames(60)
	_check(p.is_on_floor(), "cae y aterriza en el suelo")
	_check(absf(p.position.y - (FLOOR_TOP - 20)) < 1.5, "apoyado sobre el suelo (y=%.1f)" % p.position.y)

	# Movimiento
	var x0: float = p.position.x
	Input.action_press("move_right")
	await _frames(30)
	Input.action_release("move_right")
	_check(p.position.x > x0 + 50.0 and p.get("facing") == 1, "avanza a la derecha")
	await _tap("move_left", 5)
	_check(p.get("facing") == -1, "gira a la izquierda")
	await _frames(40)
	_check(absf(p.velocity.x) < 1.0, "fricción lo detiene")

	# Salto normal
	Input.action_press("jump")
	await _frames(3)
	_check(p.velocity.y < -300.0, "salta desde el suelo")
	await _frames(90)
	Input.action_release("jump")
	await _frames(30)

	# Salto variable
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	await _frames(2)
	_check(p.velocity.y > -250.0, "soltar el salto corta la subida (vy=%.0f)" % p.velocity.y)
	await _frames(90)

	# Coyote time
	p.position.y -= 40.0
	p.velocity = Vector2.ZERO
	await _frames(3)
	_check(not p.is_on_floor(), "en el aire para coyote")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	_check(p.velocity.y < -300.0, "coyote time permite saltar")
	await _frames(120)

	# Sin coyote tras expirar
	p.position.y -= 200.0
	p.velocity = Vector2.ZERO
	await _frames(15)
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	_check(p.velocity.y >= 0.0, "no salta en el aire tras expirar coyote")
	await _frames(120)

	# Jump buffer
	var y_ground: float = p.position.y
	p.position.y -= 120.0
	p.velocity = Vector2.ZERO
	var guard: int = 0
	while p.position.y < y_ground - 12.0 and guard < 300:
		await physics_frame
		guard += 1
	await _tap("jump", 1)
	var jumped: bool = false
	for i: int in 15:
		await physics_frame
		if p.velocity.y < -200.0:
			jumped = true
	_check(jumped, "jump buffer salta al aterrizar")
	await _frames(120)

	# Disparo
	var dummy: GDScript = GDScript.new()
	dummy.source_code = "extends StaticBody2D\nvar hits: int = 0\nfunc take_damage(a: int) -> void:\n\thits += a\n"
	dummy.reload()
	await _tap("move_right", 3)
	await _frames(30)
	var target: StaticBody2D = _box(4, Vector2(20, 60), Vector2(p.position.x + 200.0, 70), dummy)
	await _frames(2)
	await _tap("shoot")
	_check(get_nodes_in_group("player_projectiles").size() == 1, "un toque de disparo = un proyectil")
	await _frames(40)
	_check(int(target.get("hits")) == 1, "el proyectil impacta y daña")
	target.queue_free()

	var seen: Dictionary = {}
	Input.action_press("shoot")
	for i: int in 60:
		await physics_frame
		for n: Node in get_nodes_in_group("player_projectiles"):
			seen[n.get_instance_id()] = true
	Input.action_release("shoot")
	_check(seen.size() >= 4 and seen.size() <= 5, "cooldown limita la cadencia (%d en 1 s)" % seen.size())
	await _frames(90)

	# Disparar en el aire no impide caer ni aterrizar
	Input.action_press("jump")
	await _frames(6)
	await _tap("shoot")
	Input.action_release("jump")
	await _frames(90)
	_check(p.is_on_floor(), "disparar en el aire y aterrizar")

	# Vida y muerte
	hp_events.clear()
	p.call("take_damage", 1)
	p.call("take_damage", 1)
	_check(hp_events == ["4/5"], "daño + i-frames emiten a Events (%s)" % str(hp_events))
	await _frames(70)
	p.call("take_damage", 99)
	_check(bool(p.call("is_dead")) and died_count == 1, "muerte emite Events.player_died")
	var pos_dead: Vector2 = p.position
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(20)
	Input.action_release("move_right")
	Input.action_release("jump")
	_check(p.position.distance_to(pos_dead) < 0.5, "muerto no se mueve")

	print("RESULT: %d fallos" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, name: String) -> void:
	if not cond:
		_failures += 1
	print(("PASS " if cond else "FAIL ") + name)
