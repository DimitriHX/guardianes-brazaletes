class_name AnimationEntry
extends Resource
## Una animación de un AnimationSet: nombre lógico (el que piden los estados)
## y de dónde salen sus frames. Dos fuentes posibles:
## - Un archivo .piskel (piskel_path).
## - Una hoja de sprites PNG/JPEG (sheet) + regiones, o una rejilla de columnas.
## Si hay `sheet`, se usa la hoja y se ignora piskel_path.

## Nombre que usan los estados: idle, walk, jump, fall, attack, hurt, death...
@export var animation: StringName = &""
## false = animación de un solo uso (ataque, daño, muerte).
@export var loop: bool = true
## 0 = usar los fps del .piskel o el default_fps del AnimationSet.
@export var fps_override: float = 0.0

@export_group("Piskel")
@export_file("*.piskel") var piskel_path: String = ""

@export_group("Hoja de sprites")
@export var sheet: Texture2D
## Alternativa a `sheet` para hojas de paquetes que no están en el repositorio:
## se carga por ruta solo si el archivo existe (si no, el animador usa su
## placeholder). Con ruta, `sheet` no se guarda en el .tres.
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var sheet_path: String = "":
	set(value):
		sheet_path = value
		sheet = load(value) as Texture2D if not value.is_empty() and ResourceLoader.exists(value) else null
## Regiones (en píxeles de la hoja) de cada frame, en orden.
@export var regions: Array[Rect2i] = []
## Alternativa a `regions`: área de la hoja dividida en `grid_columns` frames iguales.
@export var grid_area: Rect2i = Rect2i()
@export var grid_columns: int = 0
## Para hojas con fondo opaco (JPEG): quitarlo al cargar.
@export var remove_background: bool = false
## Color típico del fondo de la hoja (se compara su tinte, no su brillo).
@export var background_key: Color = Color8(6, 12, 16)
@export_range(0.0, 0.2, 0.005) var background_tolerance: float = 0.03


func _validate_property(property: Dictionary) -> void:
	if property.name == "sheet" and not sheet_path.is_empty():
		property.usage &= ~PROPERTY_USAGE_STORAGE


func uses_sheet() -> bool:
	return sheet != null


func get_regions() -> Array[Rect2i]:
	if not regions.is_empty():
		return regions
	return SpriteSheetSlicer.grid_regions(grid_area, grid_columns)
