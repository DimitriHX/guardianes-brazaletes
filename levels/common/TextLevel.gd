class_name TextLevel
extends Node2D
## Nodo raíz de nivel capaz de construir toda su geometría, plataformas,
## enemigos, peligros y jefe en tiempo de ejecución a partir de un archivo de
## texto plano (`level_txt_path`) o de un bloque de texto (`inline_level_text`),
## utilizando `PlatformGenerator`.

@export_file("*.txt") var level_txt_path: String = ""
@export_multiline var inline_level_text: String = ""
## Si no hay archivo ni texto inline, genera el nivel indicado (1, 2 o 3).
@export_range(1, 3, 1) var fallback_level_number: int = 1


func _enter_tree() -> void:
	# Si la escena aún no tiene el nodo World montado, lo genera desde el texto plano
	# antes de que los hijos ejecuten su _ready().
	if has_node("World"):
		return
	var text: String = _resolve_level_text()
	if not text.is_empty():
		PlatformGenerator.populate_level_node(self, text)


func _resolve_level_text() -> String:
	if not level_txt_path.is_empty() and FileAccess.file_exists(level_txt_path):
		return FileAccess.get_file_as_string(level_txt_path)
	if not inline_level_text.is_empty():
		return inline_level_text
	return PlatformGenerator.generate_level_text(fallback_level_number)
