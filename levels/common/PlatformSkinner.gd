class_name PlatformSkinner
extends Node
## Viste con tiles las plataformas existentes sin redibujar el nivel.
## Recorre los StaticBody2D hijos de `platforms_root`, lee su RectangleShape2D
## y le añade un NinePatchRect con la pieza adecuada de la hoja de tiles
## (GandalfHardcore "Floor Tiles"): bloque 3x3 para suelos, plataforma fina de
## 1 tile de alto y columna de 1 tile de ancho para paredes. Oculta el ColorRect provisional.
## Las plataformas one-way (atravesables desde abajo) se dibujan como tablones de
## madera (`bridge_texture`) para que se distingan de las sólidas.
## La colisión no cambia: el arte se adapta al tamaño de cada plataforma.
## Los suelos marcados con el meta `drawn_by_terrain` los dibuja TerrainRenderer.

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
@export_group("Plataformas one-way")
## Tile de tablones que se repite a lo ancho. Vacío = misma pieza que las sólidas.
@export var bridge_texture: Texture2D = preload("res://assets/platforms/bridge_planks.png")
## Zona útil del tile de tablones (vacía = la textura entera).
@export var bridge_region: Rect2 = Rect2()
@export var bridge_scale: float = 1.25


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


## Añade el arte ("TileSkin") a una plataforma: NinePatchRect, o TextureRect de
## tablones si es one-way. Devuelve null si no tiene forma rectangular o si es
## suelo dibujado por TerrainRenderer.
func skin(body: StaticBody2D) -> Control:
	if body.has_node("TileSkin"):
		return body.get_node("TileSkin") as Control
	# Suelo de niveles de texto: lo dibuja TerrainRenderer celda a celda.
	if body.has_meta(&"drawn_by_terrain"):
		_hide_placeholder(body)
		return null
	var shape_node: CollisionShape2D = _find_rect_shape(body)
	if shape_node == null:
		return null
	var size: Vector2 = (shape_node.shape as RectangleShape2D).size
	if shape_node.one_way_collision and bridge_texture != null:
		return _skin_bridge(body, shape_node, size)
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

	# Las plataformas finas tienen una colisión más delgada que la celda
	# (para poder pasar por debajo): el arte ocupa la celda entera desde arriba.
	var art_size: Vector2 = size
	if region.size.y == THIN_REGION.size.y:
		art_size.y = tile_world_size
	patch.size = art_size / texel
	patch.scale = Vector2(texel, texel)
	patch.position = shape_node.position - size / 2.0
	_hide_placeholder(body)
	body.add_child(patch)
	return patch


func _skin_bridge(body: StaticBody2D, shape_node: CollisionShape2D, size: Vector2) -> TextureRect:
	var region: Rect2 = bridge_region if bridge_region.has_area() else Rect2(Vector2.ZERO, bridge_texture.get_size())
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = bridge_texture
	atlas.region = region
	var rect: TextureRect = TextureRect.new()
	rect.name = "TileSkin"
	rect.texture = atlas
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_TILE
	rect.scale = Vector2(bridge_scale, bridge_scale)
	rect.size = Vector2(size.x / bridge_scale, region.size.y)
	# Tablones apoyados en el borde superior de la colisión (donde se pisa).
	rect.position = shape_node.position - size / 2.0
	_hide_placeholder(body)
	body.add_child(rect)
	return rect


func _hide_placeholder(body: StaticBody2D) -> void:
	var placeholder: CanvasItem = body.get_node_or_null(NodePath(placeholder_name)) as CanvasItem
	if placeholder != null:
		placeholder.hide()


func _find_rect_shape(body: StaticBody2D) -> CollisionShape2D:
	for child: Node in body.get_children():
		var shape_node: CollisionShape2D = child as CollisionShape2D
		if shape_node != null and shape_node.shape is RectangleShape2D:
			return shape_node
	return null
