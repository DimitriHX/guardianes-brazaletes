extends SceneTree
## Validador del proyecto: carga cada .gd y .tscn con los autoloads ya registrados.
## (--check-only no registra autoloads y da falsos "Identifier not found: Events").
## No referenciar aquí ningún class_name del proyecto: este script se compila
## antes de que existan los autoloads.

const DIRS: Array[String] = ["res://autoloads", "res://components", "res://entities", "res://levels"]

var _failures: int = 0
var _checked: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for dir: String in DIRS:
		_scan(dir)
	print("VALIDATE: %d archivos, %d fallos" % [_checked, _failures])
	quit(1 if _failures > 0 else 0)


func _scan(dir: String) -> void:
	var da: DirAccess = DirAccess.open(dir)
	if da == null:
		return
	for sub: String in da.get_directories():
		_scan(dir.path_join(sub))
	for file: String in da.get_files():
		var path: String = dir.path_join(file)
		if file.ends_with(".gd"):
			_check_script(path)
		elif file.ends_with(".tscn"):
			_check_scene(path)


func _check_script(path: String) -> void:
	_checked += 1
	var script: Script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Script
	if script == null or not script.can_instantiate():
		_fail(path)
	else:
		print("OK   ", path)


func _check_scene(path: String) -> void:
	_checked += 1
	var scene: PackedScene = ResourceLoader.load(path) as PackedScene
	if scene == null or not scene.can_instantiate():
		_fail(path)
		return
	var node: Node = scene.instantiate()
	if node == null:
		_fail(path)
		return
	node.free()
	print("OK   ", path)


func _fail(path: String) -> void:
	_failures += 1
	print("FAIL ", path)
