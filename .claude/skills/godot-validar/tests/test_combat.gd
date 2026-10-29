extends SceneTree
## Test de combate: StatsComponent, eventos globales, Hitbox/Hurtbox.
## No tipar con class_name del proyecto (se compila antes que los autoloads).

var damaged: Array[String] = []
var critical: Array[String] = []
var died: Array[String] = []
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _box(size: Vector2, pos: Vector2) -> StaticBody2D:
	var b: StaticBody2D = StaticBody2D.new()
	b.collision_layer = 1
	var cs: CollisionShape2D = CollisionShape2D.new()
	var r: RectangleShape2D = RectangleShape2D.new()
	r.size = size
	cs.shape = r
	b.add_child(cs)
	b.position = pos
	root.add_child(b)
	return b


func _spawn(path: String, pos: Vector2) -> CharacterBody2D:
	var n: CharacterBody2D = (load(path) as PackedScene).instantiate() as CharacterBody2D
	n.position = pos
	root.add_child(n)
	return n


func _hp(entity: Node) -> int:
	return int(entity.get_node("Stats").get("current_health"))


func _run() -> void:
	var events: Node = root.get_node("Events")
	events.entity_damaged.connect(func(e: Node, a: int) -> void: damaged.append("%s:%d" % [e.name, a]))
	events.entity_health_critical.connect(func(e: Node) -> void: critical.append(String(e.name)))
	events.entity_died.connect(func(e: Node) -> void: died.append(String(e.name)))

	# --- StatsComponent aislado ---
	var holder: Node = Node.new()
	holder.name = "Dummy"
	var stats: Node = (load("res://components/StatsComponent.gd") as GDScript).new()
	stats.set("max_health", 4)
	stats.set("base_damage", 2)
	stats.set("damage_multiplier", 1.5)
	holder.add_child(stats)
	root.add_child(holder)
	await _frames(1)
	_check(int(stats.call("get_damage")) == 3, "get_damage = base 2 x 1.5 = 3")
	stats.set("damage_taken_multiplier", 0.5)
	stats.call("take_damage", 4)
	_check(int(stats.get("current_health")) == 2, "damage_taken 0.5: 4 de daño quita 2")
	_check(damaged == ["Dummy:2"], "Events.entity_damaged con entidad y daño real (%s)" % str(damaged))
	stats.set("damage_taken_multiplier", 0.0)
	stats.call("take_damage", 10)
	_check(int(stats.get("current_health")) == 2 and damaged.size() == 1, "damage_taken 0 = inmune")
	stats.set("damage_taken_multiplier", 1.0)
	stats.call("take_damage", 1)
	_check(critical == ["Dummy"], "vida crítica (1/4 <= 25%%) emite una vez (%s)" % str(critical))
	stats.call("heal", 1)
	stats.call("take_damage", 1)
	_check(critical.size() == 2, "volver a cruzar el umbral la emite de nuevo")
	stats.call("take_damage", 1)
	_check(died == ["Dummy"] and critical.size() == 2, "muerte emite entity_died y no critical")
	stats.call("reset")
	died.clear()
	stats.call("kill")
	_check(died == ["Dummy"], "kill() también emite entity_died")
	holder.queue_free()

	# --- Contacto enemigo -> Hurtbox del jugador ---
	_box(Vector2(6000, 20), Vector2(0, 110))
	var p: CharacterBody2D = _spawn("res://entities/player/Player.tscn", Vector2(0, 80))
	await _frames(20)
	var e: CharacterBody2D = _spawn("res://entities/enemies/EnemyBase.tscn", Vector2(5, 80))
	e.set("move_speed", 0.0)
	await _frames(5)
	_check(_hp(p) == 4, "Hitbox continuo del enemigo daña al Hurtbox del jugador (hp=%d)" % _hp(p))
	await _frames(30)
	_check(_hp(p) == 4, "las i-frames limitan el daño continuo")
	await _frames(45)
	_check(_hp(p) == 3, "tras las i-frames vuelve a dañar (hp=%d)" % _hp(p))
	_check(_hp(e) == 2, "el enemigo no se daña a sí mismo")

	# Hitbox inactivo
	(e.get_node("Hitbox") as Area2D).set("active", false)
	await _frames(80)
	_check(_hp(p) == 3, "Hitbox con active=false no daña")
	e.queue_free()
	await _frames(2)

	# --- Proyectil -> Hurtbox enemigo ---
	died.clear()
	var target: CharacterBody2D = _spawn("res://entities/enemies/EnemyBase.tscn", Vector2(250, 80))
	target.set("move_speed", 0.0)
	await _frames(5)
	Input.action_press("shoot")
	await _frames(2)
	Input.action_release("shoot")
	await _frames(40)
	_check(_hp(target) == 1, "1 disparo (base_damage 1) quita 1 (hp=%d)" % _hp(target))
	await _frames(20)
	Input.action_press("shoot")
	await _frames(2)
	Input.action_release("shoot")
	await _frames(40)
	_check(not is_instance_valid(target), "2.º disparo elimina al enemigo")
	_check(died.has("EnemyBase"), "entity_died del enemigo (%s)" % str(died))

	# Multiplicador del jugador: daño x2 mata de un disparo
	p.get_node("Stats").set("damage_multiplier", 2.0)
	var target2: CharacterBody2D = _spawn("res://entities/enemies/EnemyBase.tscn", Vector2(250, 80))
	target2.set("move_speed", 0.0)
	await _frames(30)
	Input.action_press("shoot")
	await _frames(2)
	Input.action_release("shoot")
	await _frames(40)
	_check(not is_instance_valid(target2), "damage_multiplier 2 del jugador mata de un disparo")

	# Proyectil contra pared (World)
	_box(Vector2(20, 200), Vector2(150, 0))
	await _frames(20)
	Input.action_press("shoot")
	await _frames(2)
	Input.action_release("shoot")
	await _frames(20)
	_check(get_nodes_in_group("player_projectiles").is_empty(), "la pared destruye el proyectil")

	# Enemigos entre sí no se dañan
	var e1: CharacterBody2D = _spawn("res://entities/enemies/EnemyBase.tscn", Vector2(2000, 80))
	var e2: CharacterBody2D = _spawn("res://entities/enemies/EnemyBase.tscn", Vector2(2005, 80))
	e1.set("move_speed", 0.0)
	e2.set("move_speed", 0.0)
	await _frames(30)
	_check(_hp(e1) == 2 and _hp(e2) == 2, "los enemigos no se dañan entre sí")

	print("RESULT: %d fallos" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, name: String) -> void:
	if not cond:
		_failures += 1
	print(("PASS " if cond else "FAIL ") + name)
