extends SceneTree
## Test de la integración visual: tiles (PlatformSkinner), fondo parallax
## (ParallaxBackdrop) y barra de vida del jugador (PlayerHealthBar).
## No tipar con class_name del proyecto (se compila antes que los autoloads).

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _view_rect() -> Rect2:
	var cam: Camera2D = root.get_viewport().get_camera_2d()
	var size: Vector2 = cam.get_viewport_rect().size / cam.zoom
	return Rect2(cam.get_screen_center_position() - size / 2.0, size)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://levels/TestLevel.tscn")
	await _frames(6)
	for e: Node in get_nodes_in_group("enemies"):
		e.queue_free()

	# --- Tiles ---
	var all_skinned: bool = true
	var sizes_match: bool = true
	var placeholders_hidden: bool = true
	for body: Node in current_scene.get_node("World").get_children():
		var patch: NinePatchRect = body.get_node_or_null("TileSkin") as NinePatchRect
		if patch == null:
			all_skinned = false
			continue
		var shape: RectangleShape2D = (body.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
		if not (patch.size * patch.scale).is_equal_approx(shape.size):
			sizes_match = false
			print("   tamaño distinto en ", body.name, ": ", patch.size * patch.scale, " vs ", shape.size)
		if (body.get_node("Visual") as CanvasItem).visible:
			placeholders_hidden = false
	_check(all_skinned, "todas las plataformas del Nivel 1 tienen tiles")
	_check(sizes_match, "el arte de cada plataforma mide lo mismo que su colisión")
	_check(placeholders_hidden, "los ColorRect provisionales se ocultan")
	var ground: NinePatchRect = current_scene.get_node("World/Ground1/TileSkin") as NinePatchRect
	var thin: NinePatchRect = current_scene.get_node("World/PlatformA/TileSkin") as NinePatchRect
	var wall: NinePatchRect = current_scene.get_node("World/WallLeft/TileSkin") as NinePatchRect
	_check(ground.region_rect == Rect2(0, 0, 96, 96), "suelo grueso = bloque 3x3 (%s)" % str(ground.region_rect))
	_check(thin.region_rect == Rect2(192, 160, 96, 32), "plataforma fina = pieza de 1 tile (%s)" % str(thin.region_rect))
	_check(wall.region_rect == Rect2(192, 96, 32, 64), "pared = pilar (%s)" % str(wall.region_rect))
	_check(is_equal_approx(ground.scale.x * root.get_viewport().get_camera_2d().zoom.x, 1.0), "pixel-perfect: 1 píxel del tile = 1 píxel de pantalla")

	# --- Fondo parallax ---
	await process_frame
	await process_frame
	var backdrop: Node2D = current_scene.get_node("Backdrop") as Node2D
	var layers: Array = backdrop.call("get_layer_sprites")
	_check(layers.size() == 6, "fondo con 6 capas")
	var view: Rect2 = _view_rect()
	var covers: bool = true
	for sprite: Sprite2D in layers:
		var r: Rect2 = Rect2(sprite.global_position, sprite.region_rect.size * sprite.scale)
		if not r.grow(0.5).encloses(view):
			covers = false
			print("   capa ", sprite.name, " no cubre la vista: ", r, " vs ", view)
	_check(covers, "cada capa cubre toda la vista")
	var before: Array[float] = []
	for sprite: Sprite2D in layers:
		before.append(sprite.region_rect.position.x)
	var player: CharacterBody2D = current_scene.get_node("Player") as CharacterBody2D
	# x=1200: lejos del pickup de vida de (1000, 575), que curaría al jugador.
	player.position = Vector2(1200, 580)
	await _frames(90)
	var moved: Array[float] = []
	for i: int in layers.size():
		moved.append(((layers[i] as Sprite2D).region_rect.position.x - before[i]) * (layers[i] as Sprite2D).scale.x)
	_check(is_zero_approx(moved[0]) and moved[1] < moved[3] and moved[3] < moved[5] and moved[5] > 0.0,
		"parallax: el cielo no se mueve y las capas cercanas se mueven más (%s)" % str(moved.map(func(v: float) -> int: return roundi(v))))

	# --- Barra de vida ---
	var bar: Control = current_scene.get_node("HUD/PlayerHealthBar") as Control
	_check(is_equal_approx(float(bar.call("get_health_ratio")), 1.0), "orbe lleno al empezar")
	player.call("take_damage", 2)
	await create_timer(0.4).timeout
	_check(is_equal_approx(float(bar.call("get_health_ratio")), 0.6), "orbe al 60%% con 3/5 (%.2f)" % float(bar.call("get_health_ratio")))
	_check((bar.get_node("HealthLabel") as Label).text == "3/5", "texto de vida 3/5")
	var cooldown: TextureProgressBar = bar.get_node("CooldownBar") as TextureProgressBar
	Input.action_press("shoot")
	await _frames(2)
	Input.action_release("shoot")
	await _frames(1)
	_check(cooldown.value < cooldown.max_value * 0.3, "barra amarilla se vacía al disparar")
	await create_timer(0.35).timeout
	_check(is_equal_approx(cooldown.value, cooldown.max_value), "y se rellena al acabar la recarga")
	var collect: TextureProgressBar = bar.get_node("CollectBar") as TextureProgressBar
	_check(collect.visible and is_zero_approx(collect.value), "barra azul visible y vacía (0 coleccionables)")
	var first: Node2D = get_nodes_in_group("collectibles")[0] as Node2D
	player.global_position = first.global_position
	await _frames(4)
	_check(collect.value > 0.0, "barra azul avanza al recoger (%.0f)" % collect.value)

	# --- Nivel del jefe: tiles de otoño y sin barra azul ---
	change_scene_to_file("res://levels/BossLevel.tscn")
	await _frames(6)
	var boss_floor: NinePatchRect = current_scene.get_node("World/Floor/TileSkin") as NinePatchRect
	_check(boss_floor.region_rect.position.y == 192.0, "BossLevel usa los tiles de otoño")
	_check(not (current_scene.get_node("HUD/PlayerHealthBar/CollectBar") as CanvasItem).visible, "sin coleccionables la barra azul se oculta")

	print("RESULT: %d fallos" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, name: String) -> void:
	if not cond:
		_failures += 1
	print(("PASS " if cond else "FAIL ") + name)
