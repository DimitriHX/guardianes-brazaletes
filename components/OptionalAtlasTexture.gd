@tool
class_name OptionalAtlasTexture
extends AtlasTexture
## AtlasTexture cuya imagen se indica por ruta y es opcional.
## Para paquetes de terceros que no se incluyen en el repositorio (ver CREDITS.md):
## si el archivo existe se usa como `atlas`; si no, la textura queda vacía y la
## escena sigue cargando (un AtlasTexture con `atlas = ExtResource(...)` a un
## archivo inexistente hace fallar la carga de toda la escena).
## `atlas` no se guarda en el .tscn: solo `source_path`.

@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var source_path: String = "":
	set(value):
		source_path = value
		atlas = load(value) as Texture2D if not value.is_empty() and ResourceLoader.exists(value) else null


func _validate_property(property: Dictionary) -> void:
	if property.name == "atlas":
		property.usage &= ~PROPERTY_USAGE_STORAGE


## true si `texture` tiene imagen (un AtlasTexture sin `atlas` no es null pero no dibuja nada).
static func has_image(texture: Texture2D) -> bool:
	if texture == null:
		return false
	if texture is AtlasTexture:
		return (texture as AtlasTexture).atlas != null
	return true
