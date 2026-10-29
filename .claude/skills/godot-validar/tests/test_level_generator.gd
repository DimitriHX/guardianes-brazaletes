extends SceneTree
## Test del algoritmo de plataformeo, generación en texto plano (.txt),
## validación matemática de saltos y construcción lógica de los 3 niveles.
## No tipar con class_name del proyecto (se compila antes que los autoloads).

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _run() -> void:
	var gen: GDScript = load("res://levels/common/PlatformGenerator.gd") as GDScript

	# 1. Exportar los 3 archivos .txt de Sueño 1
	gen.call("save_default_level_texts", "res://levels/sueno_1")
	_check(FileAccess.file_exists("res://levels/sueno_1/bosque.txt"), "bosque.txt generado en disco")
	_check(FileAccess.file_exists("res://levels/sueno_1/sendero.txt"), "sendero.txt generado en disco")
	_check(FileAccess.file_exists("res://levels/sueno_1/guarida.txt"), "guarida.txt generado en disco")

	# 2. Física matemática del salto
	var h_max: float = float(gen.call("get_max_jump_height_px"))
	_check(h_max > 76.5 and h_max < 77.5, "altura máxima de salto = 77.04 px (%.2f)" % h_max)
	var reach_flat: float = float(gen.call("get_max_horizontal_reach_px", 0.0, false))
	var reach_up3: float = float(gen.call("get_max_horizontal_reach_px", 60.0, false))
	var reach_impossible: float = float(gen.call("get_max_horizontal_reach_px", 80.0, false))
	_check(reach_flat > 140.0 and reach_flat < 143.0, "alcance horizontal plano ~141 px (%.1f)" % reach_flat)
	_check(reach_up3 > 105.0 and reach_up3 < 112.0, "alcance subiendo 3 celdas (60 px) ~108 px (%.1f)" % reach_up3)
	_check(is_zero_approx(reach_impossible), "subir 4 celdas (80 px) es físicamente inalcanzable (0.0)")

	# 3. Validación matemática de alcanzabilidad en los 3 niveles + procedimental
	for lvl_num: int in [1, 2, 3]:
		var txt: String = String(gen.call("generate_level_text", lvl_num))
		var rep: Dictionary = gen.call("validate_text", txt) as Dictionary
		_check(
			bool(rep["valid"]) and int(rep["unreachable_collectibles"]) == 0 and bool(rep["exit_reachable"]),
			"Nivel %d en texto plano es 100%% alcanzable (%d/%d plataformas, errores=%s)" % [
				lvl_num,
				int(rep["reachable_platforms"]),
				int(rep["total_platforms"]),
				str(rep["errors"]),
			]
		)

	var proc_txt: String = String(gen.call("generate_procedural_level_text", 2, 42))
	var proc_rep: Dictionary = gen.call("validate_text", proc_txt) as Dictionary
	_check(bool(proc_rep["valid"]), "generador procedimental produce nivel válido (errores=%s)" % str(proc_rep["errors"]))

	# Mapa inválido (plataforma a 5 celdas = 100 px de altura sobre el suelo) debe ser detectado
	var bad_txt: String = "\n".join([
		"@name = Nivel Imposible",
		"|....................|",
		"|.........===........|",
		"|..........C.........|",
		"|....................|",
		"|....................|",
		"|....................|",
		"|..P..............X..|",
		"|####################|",
	])
	var bad_rep: Dictionary = gen.call("validate_text", bad_txt) as Dictionary
	_check(not bool(bad_rep["valid"]), "el validador detecta plataformas inalcanzables (> 77 px)")

	# 4. Construcción lógica de escena desde texto plano (Nivel 2 con Hazards, Monedas y Enemigos)
	var built_lvl2: Node2D = gen.call("build_level_from_file", "res://levels/sueno_1/sendero.txt", "SenderoTxt") as Node2D
	root.add_child(built_lvl2)
	await _frames(6)

	var world: Node2D = built_lvl2.get_node("World") as Node2D
	var pickups: Node2D = built_lvl2.get_node("Pickups") as Node2D
	var hazards: Node2D = built_lvl2.get_node("Hazards") as Node2D
	var enemies: Node2D = built_lvl2.get_node("Enemies") as Node2D
	var player: CharacterBody2D = built_lvl2.get_node("Player") as CharacterBody2D
	_check(world.get_child_count() >= 8, "fusión Greedy Meshing crea las plataformas y muros (%d)" % world.get_child_count())
	_check(world.get_node("Ground1").has_node("TileSkin"), "PlatformSkinner viste las plataformas generadas desde texto")
	_check(pickups.get_child_count() == 13, "instancia las 10 monedas + 3 curaciones desde el texto (%d)" % pickups.get_child_count())
	_check(hazards.get_child_count() == 4, "instancia las 4 tiras de pinchos HazardSpike en capa 6 (%d)" % hazards.get_child_count())
	_check(enemies.get_child_count() == 6, "instancia los 6 enemigos del Nivel 2 (%d)" % enemies.get_child_count())

	# Probar que el HazardSpike (capa 6) daña al jugador al pisarlo
	for e: Node in enemies.get_children():
		e.queue_free()
	var spike: Area2D = hazards.get_child(0) as Area2D
	var hp_before: int = int(player.get_node("Stats").get("current_health"))
	player.global_position = spike.global_position
	await _frames(5)
	var hp_after: int = int(player.get_node("Stats").get("current_health"))
	_check(hp_after == hp_before - 1, "HazardSpike en capa 6 daña al jugador (hp %d -> %d)" % [hp_before, hp_after])

	built_lvl2.queue_free()
	await _frames(3)

	# 5. Construcción lógica del Nivel 3 (Boss) desde guarida.txt
	var built_boss: Node2D = gen.call("build_level_from_file", "res://levels/sueno_1/guarida.txt", "GuaridaTxt") as Node2D
	root.add_child(built_boss)
	await _frames(6)
	_check(built_boss.has_node("Cadejo") and built_boss.has_node("ArenaGate") and built_boss.has_node("ArenaTrigger"),
		"guarida.txt instancia Cadejo, ArenaGate y ArenaTrigger")
	var one_way_plat: CollisionShape2D = built_boss.get_node("World/OneWayPlatform1/CollisionShape2D") as CollisionShape2D
	_check(one_way_plat.one_way_collision, "símbolo '-' genera plataformas con one_way_collision = true")
	built_boss.queue_free()
	await _frames(2)

	print("RESULT: %d fallos" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, name: String) -> void:
	if not cond:
		_failures += 1
	print(("PASS " if cond else "FAIL ") + name)
