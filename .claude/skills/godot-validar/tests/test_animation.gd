extends SceneTree
## Test del sistema de frames: PiskelLoader, AnimationSet y CharacterAnimator
## (prioridades, one-shots, fallback sin arte) e integración con el Player.
## No tipar con class_name del proyecto (se compila antes que los autoloads).

var finished: Array[String] = []
var frames_seen: int = 0
var died_count: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _seconds(s: float) -> void:
	await create_timer(s).timeout


func _run() -> void:
	var loader: GDScript = load("res://components/animation/PiskelLoader.gd")

	# --- PiskelLoader ---
	var walk: RefCounted = loader.call("load_piskel", "res://assets/cadejo/Caminar-20261027-190143.piskel")
	_check(walk != null and (walk.get("frames") as Array).size() == 6, "lee Caminar del Cadejo: 6 frames")
	_check(walk != null and walk.get("size") == Vector2i(32, 32) and is_equal_approx(float(walk.get("fps")), 12.0), "tamaño 32x32 y 12 fps del .piskel")
	var tex: Texture2D = (walk.get("frames") as Array)[0]
	_check(tex.get_image().get_used_rect().size.x > 10, "el frame tiene píxeles (no está vacío)")
	var again: RefCounted = loader.call("load_piskel", "res://assets/cadejo/Caminar-20261027-190143.piskel")
	_check(again == walk, "resultado cacheado")
	var hurt_path: String = ""
	for f: String in DirAccess.get_files_at("res://assets/cadejo"):
		if f.begins_with("RecibirDa"):
			hurt_path = "res://assets/cadejo/" + f
	_check(loader.call("load_piskel", hurt_path) != null, "rutas con 'ñ' funcionan (%s)" % hurt_path.get_file())
	_check(loader.call("load_piskel", "res://no/existe.piskel") == null, "ruta inexistente devuelve null")

	# --- AnimationSet ---
	var cadejo_set: Resource = load("res://entities/bosses/cadejo/cadejo_animations.tres")
	var sf: SpriteFrames = cadejo_set.call("build_sprite_frames")
	_check(sf.get_animation_names().size() == 9, "set del Cadejo: 9 animaciones (%s)" % str(sf.get_animation_names()))
	_check(sf.get_animation_loop(&"run") and not sf.get_animation_loop(&"attack") and not sf.get_animation_loop(&"death"), "loops: run en bucle; attack y death de un solo uso")
	var player_set: Resource = load("res://entities/player/player_animations.tres")
	_check((player_set.call("build_sprite_frames") as SpriteFrames).get_animation_names().is_empty(), "plantilla del jugador sin arte: 0 animaciones")

	# --- CharacterAnimator con arte (Cadejo) ---
	var anim: AnimatedSprite2D = (load("res://components/animation/CharacterAnimator.gd") as GDScript).new()
	anim.set("animation_set", cadejo_set)
	var prio: Dictionary[StringName, int] = {&"hurt": 1, &"attack": 2, &"special": 2, &"death": 3}
	anim.set("one_shot_priorities", prio)
	root.add_child(anim)
	anim.connect("one_shot_finished", func(a: StringName) -> void: finished.append(String(a)))
	anim.connect("frame_reached", func(_a: StringName, _f: int) -> void: frames_seen += 1)
	await _frames(1)
	_check(bool(anim.get("has_frames")) and anim.visible, "con arte: has_frames y visible")
	anim.call("play_state", &"walk")
	_check(anim.get("current_animation") == &"walk" and anim.is_playing(), "reproduce walk")
	anim.call("play_state", &"attack")
	anim.call("play_state", &"idle")
	_check(anim.get("current_animation") == &"attack", "la locomoción no interrumpe un ataque")
	anim.call("play_state", &"hurt")
	_check(anim.get("current_animation") == &"attack", "hurt (prioridad menor) no interrumpe el ataque")
	await _seconds(0.6)
	_check(finished == ["attack"], "one_shot_finished(attack) al acabar (%s)" % str(finished))
	_check(anim.get("current_animation") == &"idle", "vuelve a la última locomoción pedida (idle)")
	_check(frames_seen >= 4, "frame_reached se emite en cada frame (%d)" % frames_seen)
	anim.call("play_state", &"death")
	anim.call("play_state", &"attack")
	anim.call("play_state", &"run")
	await _seconds(0.6)
	_check(anim.get("current_animation") == &"death" and finished.has("death"), "death gana, termina y queda fija")
	anim.queue_free()

	# --- Player: sin arte (fallback) ---
	var fb: StaticBody2D = StaticBody2D.new()
	var cs: CollisionShape2D = CollisionShape2D.new()
	var r: RectangleShape2D = RectangleShape2D.new()
	r.size = Vector2(4000, 20)
	cs.shape = r
	fb.add_child(cs)
	fb.position = Vector2(0, 110)
	root.add_child(fb)
	root.get_node("Events").connect("player_died", func() -> void: died_count += 1)
	var p: CharacterBody2D = (load("res://entities/player/Player.tscn") as PackedScene).instantiate() as CharacterBody2D
	root.add_child(p)
	await _frames(40)
	var p_anim: AnimatedSprite2D = p.get_node("Visual/Animator") as AnimatedSprite2D
	_check(not bool(p_anim.get("has_frames")) and (p.get_node("Visual/Body") as CanvasItem).visible, "Player sin arte: se ven los placeholders")
	p.call("take_damage", 1)
	_check(p.call("get_displayed_animation") == &"hurt", "al recibir daño muestra 'hurt'")
	await _frames(3)
	_check(p.call("get_displayed_animation") == &"idle", "sin arte, hurt termina solo y vuelve a idle")
	await _frames(70)
	p.call("take_damage", 99)
	_check(p.call("get_displayed_animation") == &"death" and died_count == 0, "muerte: anim death antes de notificar")
	await _frames(3)
	_check(died_count == 1, "player_died tras la animación de muerte")

	print("RESULT: %d fallos" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, name: String) -> void:
	if not cond:
		_failures += 1
	print(("PASS " if cond else "FAIL ") + name)
