class_name PlatformSkinner
extends Node
## Viste con tiles las plataformas existentes sin redibujar el nivel.
## Recorre los StaticBody2D hijos de `platforms_root`, lee su RectangleShape2D
## y le añade un NinePatchRect con la pieza adecuada de la hoja de tiles
## (GandalfHardcore "Floor Tiles"): bloque 3x3 para suelos, plataforma fina de
## 1 tile de alto y columna de 1 tile de ancho para paredes. Oculta el ColorRect provisional.
## La colisión no cambia: el arte se adapta al tamaño de cada plataforma.

enum Season { GREEN, AUTUMN, WINTER }

## Tamaño de un tile en la hoja (px) y separación vertical entre estaciones.
const TILE: int = 32
const SEASON_STRIDE: int = 192
## Piezas de la hoja (estación verde; las demás se desplazan SEASON_STRIDE).
const BLOCK_REGION: Rect2 = Rect2(0, 0, 96, 96)
const THIN_REGION: Rect2 = Rect2(192, 160, 96, 32)
## Pared: columna central del bloque (hierba arriba, tierra continua debajo).
const PILLAR_REGION: Rect2 = Rect2(32, 0, 32, 64)

@export var platforms_root: Node
@export var tileset: Texture2D
@export var season: Season = Season.GREEN
## Tamaño de un tile en el mundo. 20 = los tiles de 32 px se ven a 0.625; con la
## cámara a zoom 1.6 cada píxel del arte ocupa exactamente 1 píxel de pantalla.
@export var tile_world_size: float = 20.0
## Nombre del nodo provisional a ocultar dentro de cada plataforma.
@export var placeholder_name: StringName = &"Visual"


func _ready() -> void:
	if platforms_root == null or tileset == null:
		push_warning("PlatformSkinner: falta platforms_root o tileset.")
		return
	# Diferido: las plataformas pueden estar aún montándose en este momento.
	skin_all.call_deferred()


func skin_all() -> void:
	for child: Node in platforms_root.get_children():
		var body: StaticBody2D = child as StaticBody2D
		if body != null:
			skin(body)


## Añade el NinePatchRect a una plataforma. Devuelve null si no tiene forma rectangular.
func skin(body: StaticBody2D) -> NinePatchRect:
	if body.has_node("TileSkin"):
		return body.get_node("TileSkin") as NinePatchRect
	var shape_node: CollisionShape2D = _find_rect_shape(body)
	if shape_node == null:
		return null
	var size: Vector2 = (shape_node.shape as RectangleShape2D).size
	var texel: float = tile_world_size / float(TILE)
	var patch: NinePatchRect = NinePatchRect.new()
	patch.name = "TileSkin"
	patch.texture = tileset
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	patch.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT

	var region: Rect2
	if size.y <= tile_world_size + 0.5:
		region = THIN_REGION
		patch.patch_margin_left = TILE
		patch.patch_margin_right = TILE
	elif size.x <= tile_world_size + 0.5:
		region = PILLAR_REGION
		patch.patch_margin_top = TILE
	else:
		region = BLOCK_REGION
		patch.patch_margin_left = TILE
		patch.patch_margin_right = TILE
		patch.patch_margin_top = TILE
		patch.patch_margin_bottom = TILE
	region.position.y += float(season) * SEASON_STRIDE
	patch.region_rect = region

	patch.size = size / texel
	patch.scale = Vector2(texel, texel)
	patch.position = shape_node.position - size / 2.0
	var placeholder: CanvasItem = body.get_node_or_null(NodePath(placeholder_name)) as CanvasItem
	if placeholder != null:
		placeholder.hide()
	body.add_child(patch)
	return patch


func _find_rect_shape(body: StaticBody2D) -> CollisionShape2D:
	for child: Node in body.get_children():
		var shape_node: CollisionShape2D = child as CollisionShape2D
		if shape_node != null and shape_node.shape is RectangleShape2D:
			return shape_node
	return null
