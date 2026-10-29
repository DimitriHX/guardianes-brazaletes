extends SceneTree
## Test de la historia: diálogos de la pulsera (caja, máquina de escribir,
## avance automático, disparadores) y purificación del jefe.
## No tipar con class_name del proyecto (se compila antes que los autoloads).

var dialogues: Array[String] = []
var finished: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var events: Node = root.get_node("Events")
	events.connect("dialogue_requested", func(sp: String, lines: PackedStringArray) -> void: dialogues.append("%s:%d" % [sp, lines.size()]))
	events.connect("dialogue_finished", func() -> void: finished += 1)
	change_scene_to_file("res://levels/TestLevel.tscn")
	await _frames(8)
	var box: Control = current_scene.get_node("HUD/DialogueBox") as Control
	var text: Label = box.get_node("%Text") as Label

	# --- Diálogo de introducción ---
	_check(dialogues.has("Pulsera:3") and box.visible, "al empezar habla la pulsera (3 líneas)")
	_check((box.get_node("%Speaker") as Label).text == "Pulsera", "nombre de quien habla")
	_check(text.visible_characters < text.get_total_character_count(), "efecto máquina de escribir (%d/%d)" % [text.visible_characters, text.get_total_character_count()])
	var first_line: String = String(box.call("get_current_text"))
	await create_timer(5.0).timeout
	_check(String(box.call("get_current_text")) != first_line and box.visible, "avanza sola a la siguiente línea")
	box.call("clear")
	_check(not box.visible and finished == 1, "clear() la cierra y emite dialogue_finished")

	# --- Disparador de un solo uso, solo al entrar ---
	var player: CharacterBody2D = current_scene.get_node("Player") as CharacterBody2D
	for e: Node in get_nodes_in_group("enemies"):
		e.queue_free()
	dialogues.clear()
	player.position = Vector2(420, 580)
	await _frames(5)
	_check(dialogues == ["Pulsera:1"], "zona 'FirstSpirit' habla al entrar (%s)" % str(dialogues))
	await _frames(20)
	player.position = Vector2(250, 580)
	await _frames(5)
	player.position = Vector2(420, 580)
	await _frames(5)
	_check(dialogues.size() == 1, "no se repite al volver a entrar (una sola vez)")
	_check(box.visible, "el diálogo no pausa el juego (%s)" % ("pausado" if paused else "en marcha"))
	_check(not paused, "el juego sigue en marcha durante el diálogo")

	# --- Purificación del jefe ---
	change_scene_to_file("res://levels/BossLevel.tscn")
	while current_scene == null or current_scene.name != "BossLevel":
		await process_frame
	await _frames(5)
	dialogues.clear()
	var boss: CharacterBody2D = current_scene.get_node("Cadejo") as CharacterBody2D
	boss.call("activate", current_scene.get_node("Player"))
	boss.get_node("Stats").call("take_damage", 12)
	await _frames(3)
	_check(dialogues.has("Pulsera:1"), "la pulsera comenta la fase 2")
	boss.get_node("Stats").call("take_damage", 99)
	await create_timer(1.6).timeout
	var visual: Node2D = boss.get_node("Visual") as Node2D
	_check(visual.modulate.a < 0.05, "purificación: la silueta se desvanece (alpha %.2f)" % visual.modulate.a)
	_check(dialogues.has("Pulsera:2"), "diálogo de purificación tras la derrota (%s)" % str(dialogues))
	_check((current_scene.get_node("HUD/MessagePanel/MessageLabel") as Label).text.begins_with("¡El Cadejo negro ha sido purificado!"), "mensaje final de purificación")

	paused = false
	print("RESULT: %d fallos" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, name: String) -> void:
	if not cond:
		_failures += 1
	print(("PASS " if cond else "FAIL ") + name)
