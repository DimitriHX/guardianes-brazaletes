extends SceneTree
## Test de la interfaz de los niveles (rótulo, monedas, mensajes, pausa) y del
## arte nuevo (enemigos animados, pickups, efectos).
## No tipar con class_name del proyecto (se compila antes que los autoloads).

var enemy_died: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _press(action: String) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	await process_frame


func _effects(prefix: String) -> int:
	var n: int = 0
	for child: Node in current_scene.get_children():
		if String(child.name).begins_with(prefix):
			n += 1
	return n


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("Events").connect("enemy_died", func(_e: Node) -> void: enemy_died += 1)
	change_scene_to_file("res://levels/sueno_1/Bosque.tscn")
	await _frames(5)
	var hud: CanvasLayer = current_scene.get_node("HUD") as CanvasLayer
	var player: CharacterBody2D = current_scene.get_node("Player") as CharacterBody2D

	# --- Rótulo y monedas ---
	var banner: Control = hud.get_node("LevelBanner") as Control
	_check(banner.visible and (banner.get_node("BannerLabel") as Label).text == "Sueño I: Bosque de los Pinos", "rótulo con el nombre del nivel")
	_check(banner.get_combined_minimum_size().x > 200.0, "el tablón se adapta al texto (%.0f px)" % banner.get_combined_minimum_size().x)
	await create_timer(3.0).timeout
	_check(not banner.visible, "el rótulo desaparece solo")
	var coins: Label = hud.get_node("CoinCounter/HBox/CoinLabel") as Label
	_check((hud.get_node("CoinCounter") as Control).visible and coins.text == "0/5", "contador de monedas 0/5")

	# --- Pickups con sprite y destello ---
	var coin: Area2D = get_nodes_in_group("collectibles")[0] as Area2D
	_check((coin.get_node("Sprite") as Sprite2D).visible and not (coin.get_node("Visual") as CanvasItem).visible, "la moneda usa su sprite (no el cuadrado)")
	player.global_position = coin.global_position
	await _frames(4)
	_check(coins.text == "1/5", "contador sube al recoger (%s)" % coins.text)
	_check(_effects("SparkleEffect") >= 1, "destello al recoger")

	# --- Enemigo animado, efecto al morir y desaparición tras la animación ---
	var enemy: CharacterBody2D = current_scene.get_node("Enemies/Enemy1") as CharacterBody2D
	var animator: AnimatedSprite2D = enemy.get_node("Visual/Animator") as AnimatedSprite2D
	_check(bool(animator.get("has_frames")) and animator.get("current_animation") == &"walk", "el enemigo camina con sprite animado")
	var demon: Node = current_scene.get_node("Enemies/Enemy3")
	_check((demon.get_node("Visual/Animator") as AnimatedSprite2D).get("animation_set").resource_path.ends_with("demon_animations.tres"), "el 3.er enemigo es el Demon")
	player.get_node("Stats").set("damage_taken_multiplier", 0.0)
	enemy.get_node("Stats").call("take_damage", 99)
	await _frames(2)
	_check(enemy_died == 1 and is_instance_valid(enemy) and enemy.collision_layer == 0, "al morir: avisa, deja de colisionar y sigue visible")
	_check(animator.get("current_animation") == &"death" and _effects("BurstEffect") == 1, "anim. de muerte + estallido")
	await create_timer(1.0).timeout
	_check(not is_instance_valid(enemy), "se libera al terminar la animación")

	# --- Impacto del proyectil ---
	player.position = Vector2(100, 580)
	await _frames(10)
	Input.action_press("move_left")
	await _frames(3)
	Input.action_release("move_left")
	Input.action_press("shoot")
	await _frames(2)
	Input.action_release("shoot")
	await _frames(20)
	_check(_effects("ImpactEffect") >= 1, "chispas al impactar contra la pared")

	# --- Mensajes ---
	root.get_node("Events").call("emit_signal", "hud_message", "Hola", 0.5)
	await create_timer(0.3).timeout
	var panel: Control = hud.get_node("MessagePanel") as Control
	_check(panel.visible and is_equal_approx(panel.scale.x, 1.0) and (panel.get_node("MessageLabel") as Label).text == "Hola", "mensaje en tablón con animación de entrada")
	await create_timer(0.6).timeout
	_check(not panel.visible, "el mensaje temporal se oculta")

	# --- Menú de pausa ---
	var menu: Control = hud.get_node("PauseMenu") as Control
	await _press("pause")
	_check(menu.visible and paused, "Esc/P abre el menú y pausa")
	_check(menu.get_viewport().gui_get_focus_owner() == menu.get_node("%ContinueButton"), "el foco está en Continuar (teclado/mando)")
	var pos_before: Vector2 = player.position
	Input.action_press("move_right")
	await _frames(10)
	Input.action_release("move_right")
	_check(player.position.is_equal_approx(pos_before), "en pausa el jugador no se mueve")
	await _press("pause")
	_check(not menu.visible and not paused, "volver a pulsar cierra y reanuda")
	await _press("pause")
	(menu.get_node("%ContinueButton") as Button).emit_signal("pressed")
	await process_frame
	_check(not menu.visible and not paused, "botón Continuar reanuda")
	paused = true
	await _press("pause")
	_check(not menu.visible, "no se abre si el juego ya está pausado por otro sistema (victoria)")
	paused = false
	await _press("pause")
	var old_id: int = current_scene.get_instance_id()
	(menu.get_node("%RestartButton") as Button).emit_signal("pressed")
	await create_timer(1.3).timeout
	_check(current_scene.get_instance_id() != old_id and not paused, "Reiniciar nivel recarga la escena")

	# --- Barra del jefe ---
	await create_timer(0.6).timeout  # que termine de descubrirse la transición
	change_scene_to_file("res://levels/sueno_1/Guarida.tscn")
	while current_scene == null or current_scene.name != "Guarida":
		await process_frame
	await _frames(3)
	var boss_bar: Control = current_scene.get_node("HUD/BossPanel/VBox/BossBar") as Control
	current_scene.get_node("Cadejo").call("activate", current_scene.get_node("Player"))
	await process_frame
	_check((current_scene.get_node("HUD/BossPanel") as Control).visible and is_equal_approx(float(boss_bar.call("get_ratio")), 1.0), "barra del jefe llena al empezar")
	current_scene.get_node("Cadejo/Stats").call("take_damage", 6)
	await create_timer(0.4).timeout
	_check(is_equal_approx(float(boss_bar.call("get_ratio")), 0.75), "barra del jefe animada al 75%% (%.2f)" % float(boss_bar.call("get_ratio")))

	print("RESULT: %d fallos" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, name: String) -> void:
	if not cond:
		_failures += 1
	print(("PASS " if cond else "FAIL ") + name)
