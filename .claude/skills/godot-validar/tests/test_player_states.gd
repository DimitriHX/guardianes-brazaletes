extends SceneTree
## Test de la máquina de estados del jugador: transiciones y animación por estado.
## No tipar con class_name del proyecto (se compila antes que los autoloads).

var p: CharacterBody2D
var log_changes: Array[String] = []
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _state() -> String:
	return String(p.call("get_state_name"))


func _anim() -> String:
	return String(p.get("current_animation"))


func _run() -> void:
	var fb: StaticBody2D = StaticBody2D.new()
	var cs: CollisionShape2D = CollisionShape2D.new()
	var r: RectangleShape2D = RectangleShape2D.new()
	r.size = Vector2(4000, 20)
	cs.shape = r
	fb.add_child(cs)
	fb.position = Vector2(0, 110)
	root.add_child(fb)

	p = (load("res://entities/player/Player.tscn") as PackedScene).instantiate() as CharacterBody2D
	p.position = Vector2(0, 40)
	root.add_child(p)
	var sm: Node = p.get_node("StateMachine")
	sm.connect("state_changed", func(from: StringName, to: StringName) -> void: log_changes.append("%s>%s" % [from, to]))

	await _frames(3)
	_check(_state() == "Fall" and _anim() == "fall", "spawn en el aire: Idle > Fall (anim fall)")
	await _frames(40)
	_check(_state() == "Idle" and _anim() == "idle", "aterriza: Idle (anim idle)")

	Input.action_press("move_right")
	await _frames(5)
	_check(_state() == "Walk" and _anim() == "walk", "input horizontal: Walk")
	Input.action_release("move_right")
	await _frames(5)
	_check(_state() == "Idle", "sin input: Idle")

	Input.action_press("jump")
	await _frames(3)
	_check(_state() == "Jump" and _anim() == "jump", "salto: Jump")
	await _frames(25)
	_check(_state() == "Fall", "apogeo: Jump > Fall")
	Input.action_release("jump")
	await _frames(60)
	_check(_state() == "Idle", "aterriza tras salto: Idle")

	log_changes.clear()
	Input.action_press("shoot")
	await _frames(3)
	_check(_state() == "Attack" and _anim() == "attack", "disparo: Attack")
	Input.action_release("shoot")
	await _frames(15)
	_check(_state() == "Idle", "Attack termina y vuelve a Idle")

	# Ataque aéreo: vuelve a Fall, no a Jump (no repite el impulso)
	Input.action_press("jump")
	await _frames(4)
	Input.action_press("shoot")
	await _frames(2)
	Input.action_release("shoot")
	_check(_state() == "Attack", "disparo en el aire: Attack")
	await _frames(12)
	_check(_state() == "Fall", "ataque aéreo termina en Fall")
	Input.action_release("jump")
	await _frames(60)

	# Saltar durante el ataque en suelo
	Input.action_press("shoot")
	await _frames(2)
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("shoot")
	_check(_state() == "Jump", "se puede saltar durante Attack")
	Input.action_release("jump")
	await _frames(60)

	# Muerte: Dead desde cualquier estado y es terminal
	Input.action_press("move_right")
	await _frames(5)
	p.call("kill")
	await _frames(2)
	_check(_state() == "Dead" and _anim() == "death", "kill(): Dead (anim death)")
	Input.action_press("jump")
	Input.action_press("shoot")
	await _frames(20)
	Input.action_release("jump")
	Input.action_release("shoot")
	Input.action_release("move_right")
	_check(_state() == "Dead", "Dead es terminal")

	# Transición inválida no rompe nada
	sm.call("transition_to", &"NoExiste")
	_check(_state() == "Dead", "transición a estado inexistente se ignora")

	print("RESULT: %d fallos" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, name: String) -> void:
	if not cond:
		_failures += 1
	print(("PASS " if cond else "FAIL ") + name + "   [estado=%s anim=%s]" % [_state(), _anim()])
