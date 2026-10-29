extends SceneTree
## Test de la puerta del Nivel 1 y del combate contra el Cadejo en BossLevel.
## No tipar con class_name del proyecto (se compila antes que los autoloads).

var events: Node
var log_events: Array[String] = []
var player_hits: Array[int] = []
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _player() -> CharacterBody2D:
	return current_scene.get_node("Player") as CharacterBody2D


func _run() -> void:
	events = root.get_node("Events")
	events.connect("boss_fight_started", func(_b: Node, n: String, c: int, m: int) -> void: log_events.append("start:%s:%d/%d" % [n, c, m]))
	events.connect("boss_phase_changed", func(_b: Node, ph: int) -> void: log_events.append("phase:%d" % ph))
	events.connect("boss_defeated", func(_b: Node) -> void: log_events.append("defeated"))
	events.connect("entity_damaged", func(e: Node, a: int) -> void:
		if e.is_in_group("player"):
			player_hits.append(a))

	# ================= Nivel 1: la puerta =================
	change_scene_to_file("res://levels/sueno_1/Bosque.tscn")
	await _frames(5)
	for e: Node in get_nodes_in_group("enemies"):
		e.queue_free()
	var door: Area2D = current_scene.get_node("ExitDoor") as Area2D
	var p: CharacterBody2D = _player()
	_check(not bool(door.get("is_open")), "la puerta empieza cerrada")
	p.position = Vector2(door.position.x - 90.0, 580)
	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	_check(current_scene.name == "Bosque" and p.position.x < door.position.x - 13.0, "cerrada bloquea el paso (x=%.0f)" % p.position.x)
	for n: Node in get_nodes_in_group("collectibles"):
		p.global_position = (n as Node2D).global_position
		p.velocity = Vector2.ZERO
		await _frames(4)
	await _frames(2)
	_check(bool(door.get("is_open")) and not paused, "al recoger todo se abre y el juego sigue (sin pausa)")
	p.position = Vector2(door.position.x - 90.0, 580)
	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	await _frames(5)
	_check(current_scene != null and current_scene.name == "Sendero", "cruzar la puerta del Nivel 1 carga el Nivel 2 (Sendero)")

	# ================= Nivel 2: Sendero -> Guarida =================
	for e2: Node in get_nodes_in_group("enemies"):
		e2.queue_free()
	var door2: Area2D = current_scene.get_node("ExitDoor") as Area2D
	p = _player()
	_check(not bool(door2.get("is_open")), "la puerta del Nivel 2 empieza cerrada")
	for n2: Node in get_nodes_in_group("collectibles"):
		p.global_position = (n2 as Node2D).global_position
		p.velocity = Vector2.ZERO
		await _frames(4)
	await _frames(2)
	_check(bool(door2.get("is_open")) and not paused, "al recoger las monedas del Nivel 2 se abre la puerta")
	p.position = Vector2(door2.position.x - 90.0, 580)
	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	await _frames(5)
	_check(current_scene != null and current_scene.name == "Guarida", "cruzar la puerta del Nivel 2 carga BossLevel (Guarida)")

	# ================= BossLevel =================
	var boss: CharacterBody2D = current_scene.get_node("Cadejo") as CharacterBody2D
	var gate: Area2D = current_scene.get_node("ArenaGate") as Area2D
	var hud: CanvasLayer = current_scene.get_node("HUD") as CanvasLayer
	var boss_stats: Node = boss.get_node("Stats")
	p = _player()
	await _frames(10)
	_check(boss.call("get_state_name") == &"Dormant", "el jefe espera dormido")
	_check(bool((boss.get_node("Visual/Animator") as AnimatedSprite2D).get("has_frames")), "el Cadejo usa sus .piskel reales")
	boss_stats.call("take_damage", 5)
	_check(int(boss_stats.get("current_health")) == 24, "dormido es invulnerable")
	_check(bool(gate.get("is_open")), "la reja de la arena empieza abierta")

	# Entrar en la arena
	Input.action_press("move_right")
	await _frames(150)
	Input.action_release("move_right")
	await _frames(2)
	_check(log_events.has("start:El Cadejo negro:24/24"), "boss_fight_started con nombre y vida (%s)" % str(log_events))
	_check(not bool(gate.get("is_open")), "la reja se cierra detrás del jugador")
	_check((hud.get_node("BossPanel") as Control).visible, "barra de vida del jefe visible")

	# Observar la IA (jugador inmune para no morir)
	p.get_node("Stats").set("damage_taken_multiplier", 0.0)
	var states: Dictionary = {}
	var pushed: bool = false
	var d0: float = float(boss.call("distance_to_target"))
	var d_min: float = d0
	for i: int in 600:
		await physics_frame
		states[String(boss.call("get_state_name"))] = true
		d_min = minf(d_min, float(boss.call("distance_to_target")))
		if bool(p.call("is_knocked_back")):
			pushed = true
	_check(d_min < d0 - 100.0, "persigue al jugador (%.0f -> %.0f)" % [d0, d_min])
	_check(states.has("Chase") and states.has("Charge") and states.has("Retreat"), "ciclo Perseguir -> Embestir -> Retroceder (%s)" % str(states.keys()))
	_check(states.has("Roar") and pushed, "ruge y empuja al jugador al acercarse")

	# Daño de la embestida = x2
	p.get_node("Stats").set("damage_taken_multiplier", 1.0)
	p.get_node("Stats").set("max_health", 99)
	p.get_node("Stats").call("reset")
	# A media distancia del jefe, en zona libre de la arena, para que embista.
	var px: float = boss.position.x - 320.0 if boss.position.x - 320.0 > 600.0 else boss.position.x + 320.0
	p.position = Vector2(px, 580)
	p.velocity = Vector2.ZERO
	player_hits.clear()
	for i: int in 600:
		await physics_frame
		if player_hits.has(2):
			break
	_check(player_hits.has(2), "la embestida hace daño x2 (%s)" % str(player_hits))
	p.get_node("Stats").set("damage_taken_multiplier", 0.0)

	# Fase 2
	boss_stats.call("take_damage", 12)
	await _frames(2)
	_check(log_events.has("phase:2") and int(boss.get("phase")) == 2, "al 50 %% pasa a fase 2")
	_check(is_equal_approx(float(boss.call("speed_multiplier")), 1.4), "fase 2 más rápida (x1.4)")
	await create_timer(0.4).timeout
	_check(roundi(float(hud.get_node("BossPanel/VBox/BossBar").get("value"))) == 12, "la barra del HUD baja con la vida")

	# Derrota
	boss_stats.call("take_damage", 99)
	await _frames(2)
	_check(boss.call("get_state_name") == &"Dead" and not log_events.has("defeated"), "muere: estado Dead y espera a la animación")
	await create_timer(0.8).timeout
	_check(log_events.has("defeated"), "boss_defeated al acabar la animación de muerte")
	await create_timer(0.4).timeout
	_check(not (hud.get_node("BossPanel") as Control).visible, "la barra del jefe se oculta")
	_check(bool(gate.get("is_open")), "la reja se vuelve a abrir")
	_check(not paused and bool(hud.call("is_message_visible")), "victoria: mensaje y el juego sigue (sin pausa)")
	var exit_door: Area2D = current_scene.get_node("ExitDoor") as Area2D
	_check(exit_door.visible and bool(exit_door.get("is_open")), "al purificar al Cadejo aparece el portal de salida")

	# Regresión: tras reiniciar el nivel no quedan conexiones de Events a nodos liberados
	# (antes: "Attempt to call function 'null::close (Callable)'" al empezar el combate).
	paused = false
	var old_scene: Node = current_scene
	reload_current_scene()
	while current_scene == null or current_scene == old_scene:
		await process_frame
	await _frames(5)
	var stale: Array[String] = []
	for sig: String in ["boss_fight_started", "boss_defeated", "level_completed", "player_died", "hud_message"]:
		for conn: Dictionary in events.get_signal_connection_list(sig):
			var target: Object = (conn["callable"] as Callable).get_object()
			if target == null or not is_instance_valid(target):
				stale.append(sig)
	_check(stale.is_empty(), "tras reiniciar no hay conexiones a nodos liberados (%s)" % str(stale))
	var p2: CharacterBody2D = _player()
	p2.position = Vector2(640, 560)
	await _frames(10)
	_check(not bool((current_scene.get_node("ArenaGate") as Area2D).get("is_open")), "tras reiniciar, la reja vuelve a cerrarse al empezar el combate")
	_check(not (current_scene.get_node("ExitDoor") as Area2D).visible, "el portal final está oculto hasta derrotar al jefe")

	# ================= Portal final: fundido lento al título =================
	var boss2: CharacterBody2D = current_scene.get_node("Cadejo") as CharacterBody2D
	boss2.call("activate", p2)
	await _frames(2)
	p2.get_node("Stats").set("damage_taken_multiplier", 0.0)
	boss2.get_node("Stats").call("take_damage", 99)
	await create_timer(1.6).timeout
	var portal: Area2D = current_scene.get_node("ExitDoor") as Area2D
	p2.global_position = portal.global_position + Vector2(0, 28)
	p2.velocity = Vector2.ZERO
	await create_timer(1.2).timeout
	var st: CanvasLayer = root.get_node("SceneTransition") as CanvasLayer
	var fade_text: String = String(st.call("get_fade_text"))
	_check(current_scene.name == "Guarida" and fade_text.ends_with("%") and not fade_text.ends_with(" 0%") and not fade_text.ends_with("100%"),
		"cruzar el portal funde poco a poco con porcentaje (%s)" % fade_text)
	for i: int in 600:
		if current_scene != null and current_scene.name == "MainMenu":
			break
		await process_frame
	_check(current_scene != null and current_scene.name == "MainMenu", "al terminar el fundido vuelve al título")

	print("RESULT: %d fallos" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, name: String) -> void:
	if not cond:
		_failures += 1
	print(("PASS " if cond else "FAIL ") + name)
