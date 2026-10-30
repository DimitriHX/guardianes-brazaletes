class_name PlatformGenerator
extends RefCounted
## Algoritmo de análisis físico de plataformeo, generación en texto plano y
## construcción lógica de niveles para Godot 4.7.
##
## 1. MODELO MATEMÁTICO DE SALTO (basado en Player.gd y PlatformSkinner.gd):
##    - Unidad de grilla: CELL_SIZE = 20.0 px (múltiplo exacto del tile_world_size).
##    - Velocidad horizontal máxima: v_x = 220.0 px/s (11 celdas/s).
##    - Velocidad inicial de salto: v_0 = -430.0 px/s.
##    - Gravedad de subida: g_up = 1200.0 px/s².
##    - Gravedad de caída: g_down = 1200.0 * 1.6 = 1920.0 px/s².
##    - Altura máxima teórica: H_max = v_0² / (2 * g_up) = 77.04 px (~3.85 celdas).
##    - Escalón vertical máximo seguro hacia arriba: 3 celdas (60 px).
##
## 2. FORMATO DE TEXTO PLANO (.txt):
##    - Cabecera con directivas `@clave = valor`.
##    - Grilla ASCII donde cada carácter representa una celda de 20x20 px:
##      `.` Aire | `#` Suelo grueso | `=` Plataforma fina | `-` Plataforma one-way
##      `|` Muro | `^` Pinchos (Hazard) | `P` Player | `C` Moneda | `H` Vida
##      `E`/`e` Enemigo patrulla (izq/der) | `D` Demonio | `X` Puerta-portal de salida
##      (con `@exit_fade = s` aparece al ganar y funde lentamente a @next_level)
##      `G` Reja de arena | `A` Disparador de arena | `B` Jefe (Cadejo)
##      `T` Antorcha con PointLight2D | `~` Plataforma frágil que cae (`FallingPlatform`)
##      `K` Altar de control intermedio (`Checkpoint`)
##      `1`..`9` Disparadores de diálogo (@dialogue_1..@dialogue_9)

const CELL_SIZE: float = 20.0
const PLAYER_SPEED: float = 220.0
const JUMP_VELOCITY: float = -430.0
const GRAVITY_UP: float = 1200.0
const GRAVITY_DOWN: float = 1920.0
const COYOTE_TIME: float = 0.1
const SAFETY_HEADROOM_PX: float = 6.0

## Límites discretos recomendados en celdas de 20x20 px.
const MAX_SAFE_CELLS_UP: int = 3
const MAX_SAFE_FLAT_GAP_CELLS: int = 5
## Filas de suelo grueso en los niveles 1 y 2: llega al borde inferior de la
## cámara (fila 30..34) para que no se vea el vacío bajo el suelo.
const GROUND_DEPTH: int = 5
## Ancho (celdas) de los muros de borde y cuánto suben por encima del mapa.
const BORDER_WALL_CELLS: int = 2
const BORDER_WALL_TOP_PX: float = 100.0
## Grosor de la colisión de las plataformas finas (= y -), pegada a su borde
## superior. El arte sigue ocupando la celda entera (20 px), pero con 10 px de
## colisión quedan 50 px libres bajo una plataforma a 3 celdas del suelo y el
## jugador (40 px de alto) puede pasar por debajo.
const THIN_COLLISION_PX: float = 10.0

const HUD_SCENE_PATH: String = "res://ui/hud/HUD.tscn"
const PLAYER_SCENE_PATH: String = "res://entities/player/Player.tscn"
const ENEMY_BASE_SCENE_PATH: String = "res://entities/enemies/EnemyBase.tscn"
const ENEMY_DEMON_SCENE_PATH: String = "res://entities/enemies/EnemyDemon.tscn"
const PICKUP_SCENE_PATH: String = "res://entities/items/Pickup.tscn"
const DOOR_SCENE_PATH: String = "res://entities/level/Door.tscn"
const ARENA_GATE_SCENE_PATH: String = "res://entities/level/ArenaGate.tscn"
const PORTAL_DOOR_SCENE_PATH: String = "res://entities/level/PortalDoor.tscn"
const CADEJO_SCENE_PATH: String = "res://entities/bosses/cadejo/Cadejo.tscn"
const HAZARD_SPIKE_SCENE_PATH: String = "res://entities/level/HazardSpike.tscn"
const AMBIENCE_SCENE_PATH: String = "res://levels/common/LevelAmbience.tscn"
const TORCH_SCENE_PATH: String = "res://entities/level/Torch.tscn"
const FALLING_PLATFORM_SCENE_PATH: String = "res://entities/level/FallingPlatform.tscn"
const CHECKPOINT_SCENE_PATH: String = "res://entities/level/Checkpoint.tscn"
const TILESET_PATH: String = "res://assets/tiles/floor_tiles.png"

const BG_PATHS: Dictionary = {
	0: [
		"res://assets/backgrounds/normal/layer_5.png",
		"res://assets/backgrounds/normal/layer_4.png",
		"res://assets/backgrounds/normal/castle.png",
		"res://assets/backgrounds/normal/layer_3.png",
		"res://assets/backgrounds/normal/layer_2.png",
		"res://assets/backgrounds/normal/layer_1.png",
	],
	1: [
		"res://assets/backgrounds/autumn/layer_5.png",
		"res://assets/backgrounds/autumn/layer_4.png",
		"res://assets/backgrounds/autumn/castle.png",
		"res://assets/backgrounds/autumn/layer_3.png",
		"res://assets/backgrounds/autumn/layer_2.png",
		"res://assets/backgrounds/autumn/layer_1.png",
	],
	2: [
		"res://assets/backgrounds/winter/layer_5.png",
		"res://assets/backgrounds/winter/layer_4.png",
		"res://assets/backgrounds/winter/castle.png",
		"res://assets/backgrounds/winter/layer_3.png",
		"res://assets/backgrounds/winter/layer_2.png",
		"res://assets/backgrounds/winter/layer_1.png",
	],
}


# ==============================================================================
# 1. FÍSICA Y MATEMÁTICA DE PLATAFORMEO
# ==============================================================================

## Altura máxima teórica del salto en píxeles: v0^2 / (2 * g_up) = 77.04 px.
static func get_max_jump_height_px() -> float:
	return (JUMP_VELOCITY * JUMP_VELOCITY) / (2.0 * GRAVITY_UP)


## Tiempo en segundos desde el despegue hasta el ápice del salto (~0.358 s).
static func get_time_to_apex() -> float:
	return absf(JUMP_VELOCITY) / GRAVITY_UP


## Tiempo total de vuelo (s) para aterrizar en un desnivel `delta_y_up_px`
## (positivo = subir, 0 = plano, negativo = bajar). Devuelve 0.0 si es inalcanzable.
static func get_flight_time_for_delta_y(delta_y_up_px: float) -> float:
	var h_max: float = get_max_jump_height_px()
	if delta_y_up_px > h_max - SAFETY_HEADROOM_PX:
		return 0.0
	var fall_distance: float = h_max - delta_y_up_px
	var t_up: float = get_time_to_apex()
	var t_down: float = sqrt((2.0 * fall_distance) / GRAVITY_DOWN)
	return t_up + t_down


## Distancia horizontal máxima (px) que el jugador puede cubrir para un
## desnivel vertical `delta_y_up_px` (positivo = subir, negativo = bajar).
static func get_max_horizontal_reach_px(delta_y_up_px: float, include_coyote: bool = false) -> float:
	var t_flight: float = get_flight_time_for_delta_y(delta_y_up_px)
	if t_flight <= 0.0:
		return 0.0
	var extra_time: float = COYOTE_TIME if include_coyote else 0.0
	return PLAYER_SPEED * (t_flight + extra_time)


## Comprueba si el jugador puede saltar desde la superficie de `from_rect` hasta `to_rect`.
static func can_jump_between(from_rect: Rect2, to_rect: Rect2) -> bool:
	var delta_y_up_px: float = from_rect.position.y - to_rect.position.y
	if delta_y_up_px > get_max_jump_height_px() - SAFETY_HEADROOM_PX:
		return false
	var gap_x: float = 0.0
	if to_rect.position.x > from_rect.end.x:
		gap_x = to_rect.position.x - from_rect.end.x
	elif from_rect.position.x > to_rect.end.x:
		gap_x = from_rect.position.x - to_rect.end.x
	else:
		gap_x = 0.0
	var max_reach: float = get_max_horizontal_reach_px(delta_y_up_px, false) + 12.0
	return gap_x <= max_reach


# ==============================================================================
# 2. GENERACIÓN DE LOS 3 NIVELES EN TEXTO PLANO
# ==============================================================================

## Genera en texto plano cualquiera de los 3 niveles principales (1, 2 o 3).
static func generate_level_text(level_number: int) -> String:
	match level_number:
		1:
			return _build_level_1_text()
		2:
			return _build_level_2_text()
		3:
			return _build_level_3_boss_text()
		_:
			return _build_level_1_text()


## Guarda en disco los 3 archivos .txt de los niveles de Sueño 1.
static func save_default_level_texts(base_dir: String = "res://levels/sueno_1") -> void:
	var files: Dictionary = {
		1: base_dir.path_join("bosque.txt"),
		2: base_dir.path_join("sendero.txt"),
		3: base_dir.path_join("guarida.txt"),
	}
	for num: int in files.keys():
		var f: FileAccess = FileAccess.open(String(files[num]), FileAccess.WRITE)
		if f != null:
			f.store_string(generate_level_text(num))
			f.close()


## Genera procedimentalmente un nivel en texto plano a partir de una semilla,
## garantizando que cada salto cumpla las ecuaciones de alcance del Player.
static func generate_procedural_level_text(
	level_number: int,
	seed_value: int = 12345,
	width_cells: int = 96,
	height_cells: int = 35
) -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var grid: Array[PackedStringArray] = _create_empty_grid(width_cells, height_cells)

	# Muros laterales en col 0 y col width_cells - 1
	for r: int in range(0, height_cells):
		grid[r][0] = "|"
		grid[r][width_cells - 1] = "|"

	var ground_row: int = 30
	if level_number == 3:
		# Nivel de jefe: suelo continuo y arena con plataformas one-way
		_paint_rect(grid, 1, ground_row, width_cells - 2, 2, "#")
		grid[ground_row - 1][5] = "P"
		grid[ground_row - 1][5] = "P"
		grid[ground_row - 4][5] = "1"
		grid[ground_row - 1][16] = "H"
		grid[ground_row - 4][22] = "2"
		grid[ground_row - 1][26] = "G"
		grid[ground_row - 4][32] = "A"
		_paint_rect(grid, 38, ground_row - 3, 7, 1, "-")
		_paint_rect(grid, 70, ground_row - 3, 7, 1, "-")
		grid[ground_row - 1][62] = "B"
		var headers_boss: PackedStringArray = PackedStringArray([
			"@name = Sueño I: Guarida del Cadejo",
			"@season = AUTUMN",
			"@win_condition = BOSS_DEFEATED",
			"@pause_on_complete = true",
			"@completed_message = ¡El Cadejo negro ha sido purificado!\\nPulsa R para reiniciar",
			"@kill_y = 800",
			"@tint = 0.62, 0.55, 0.62, 1.0",
			"@dialogue_1 = Aquí habita el Cadejo negro, el que acecha a los viajeros en la noche. | Si lo purificamos, el Cadejo blanco volverá a protegerlos.",
			"@dialogue_2 = Ya viene... ¡Prepárate, Emma!",
		])
		return _serialize_grid(headers_boss, grid)

	# Niveles de plataformas (1 y 2): tramos de suelo con huecos validados
	var cursor_x: int = 1
	var segments: Array[Vector2i] = []
	while cursor_x < width_cells - 18:
		var seg_len: int = rng.randi_range(22, 34)
		if cursor_x + seg_len >= width_cells - 16:
			seg_len = (width_cells - 1) - cursor_x
		_paint_rect(grid, cursor_x, ground_row, seg_len, 2, "#")
		segments.append(Vector2i(cursor_x, seg_len))
		cursor_x += seg_len
		if cursor_x < width_cells - 18:
			var gap_cells: int = rng.randi_range(3, MAX_SAFE_FLAT_GAP_CELLS)
			# Moneda sobre el arco del salto del foso
			var mid_gap: int = cursor_x + gap_cells / 2
			grid[ground_row - 3][mid_gap] = "C"
			cursor_x += gap_cells

	if cursor_x < width_cells - 1:
		var tail_len: int = (width_cells - 1) - cursor_x
		_paint_rect(grid, cursor_x, ground_row, tail_len, 2, "#")
		segments.append(Vector2i(cursor_x, tail_len))

	# Cadena de plataformas elevadas sobre cada segmento respetando MAX_SAFE_CELLS_UP (<= 3 celdas)
	for seg_idx: int in segments.size():
		var seg: Vector2i = segments[seg_idx]
		var sx: int = seg.x
		var slen: int = seg.y
		if slen < 18:
			continue
		var p1_x: int = sx + 8
		var p1_w: int = 8
		var p1_y: int = ground_row - 3
		_paint_rect(grid, p1_x, p1_y, p1_w, 1, "=")
		grid[p1_y - 2][p1_x + p1_w / 2] = "C"

		if slen >= 28:
			var p2_x: int = p1_x + p1_w + rng.randi_range(2, 4)
			var p2_w: int = 7
			var p2_y: int = p1_y - 3
			if p2_x + p2_w < sx + slen - 4:
				_paint_rect(grid, p2_x, p2_y, p2_w, 1, "=")
				grid[p2_y - 2][p2_x + p2_w / 2] = "C"

		# Enemigo y peligros en el segmento
		var enemy_x: int = sx + slen - 7
		if enemy_x > sx + 10 and enemy_x < width_cells - 8:
			grid[ground_row - 1][enemy_x] = "D" if (level_number == 2 and seg_idx == segments.size() - 1) else "E"
		if level_number == 2 and slen >= 26 and seg_idx > 0:
			var spike_x: int = sx + 4
			_paint_rect(grid, spike_x, ground_row - 1, 2, 1, "^")

	# Jugador, diálogos, salud y puerta de salida
	grid[ground_row - 1][5] = "P"
	grid[ground_row - 4][5] = "1"
	if segments.size() > 1:
		grid[ground_row - 1][segments[1].x + 3] = "H"
	grid[ground_row - 1][width_cells - 6] = "C"
	grid[ground_row - 1][width_cells - 3] = "X"

	var next_scene: String = "res://levels/sueno_1/Sendero.tscn" if level_number == 1 else "res://levels/sueno_1/Guarida.tscn"
	var season_str: String = "GREEN" if level_number == 1 else "WINTER"
	var title: String = "Sueño I: Bosque de los Pinos" if level_number == 1 else "Sueño I: Sendero de las Sombras"
	var headers: PackedStringArray = PackedStringArray([
		"@name = " + title,
		"@season = " + season_str,
		"@win_condition = COLLECTIBLES",
		"@pause_on_complete = false",
		"@completed_message = ¡La luz abrió la puerta!",
		"@next_level = " + next_scene,
		"@kill_y = 800",
		"@dialogue_1 = Reúne las monedas de luz para abrir el portal hacia el siguiente sueño.",
	])
	return _serialize_grid(headers, grid)


static func _build_level_1_text() -> String:
	# 180 celdas = 3600 px (antes 96). Cinco tramos de suelo separados por fosos;
	# cada tramo tiene su propia escalera de plataformas (subidas de 3 celdas).
	var width_cells: int = 180
	var height_cells: int = 35
	var grid: Array[PackedStringArray] = _create_empty_grid(width_cells, height_cells)

	# Muros laterales
	for r: int in range(0, height_cells):
		grid[r][0] = "|"
		grid[r][width_cells - 1] = "|"

	# --- Tramo 1 (cols 1..39): zona de aprendizaje ---
	_paint_rect(grid, 0, 30, 40, GROUND_DEPTH, "#")
	_paint_rect(grid, 14, 27, 8, 1, "=")
	# Foso 1: cols 40..43 (4 celdas = 80 px, salto plano)

	# --- Tramo 2 (cols 44..79): escalera de tres alturas ---
	_paint_rect(grid, 44, 30, 36, GROUND_DEPTH, "#")
	_paint_rect(grid, 50, 27, 6, 1, "=")
	_paint_rect(grid, 58, 24, 6, 1, "=")
	_paint_rect(grid, 66, 21, 7, 1, "-")
	# Foso 2: cols 80..89 (10 celdas) con plataforma flotante en medio
	_paint_rect(grid, 83, 27, 4, 1, "=")

	# --- Tramo 3 (cols 90..129): plataformas en zigzag ---
	_paint_rect(grid, 90, 30, 40, GROUND_DEPTH, "#")
	_paint_rect(grid, 104, 27, 7, 1, "-")
	_paint_rect(grid, 113, 24, 6, 1, "=")
	_paint_rect(grid, 121, 27, 6, 1, "=")
	# Foso 3: cols 130..134 (5 celdas = 100 px)

	# --- Tramo 4 (cols 135..178): recta final hacia la puerta ---
	_paint_rect(grid, 135, 30, 45, GROUND_DEPTH, "#")
	_paint_rect(grid, 142, 27, 8, 1, "=")
	_paint_rect(grid, 152, 24, 7, 1, "-")

	# Jugador y diálogos
	grid[29][5] = "P"
	grid[22][5] = "1"
	grid[22][24] = "2"
	grid[22][165] = "3"

	# 8 monedas de luz (C) y 2 curaciones (H)
	grid[25][18] = "C"
	grid[27][42] = "C"
	grid[19][69] = "C"
	grid[25][85] = "C"
	grid[22][115] = "C"
	grid[27][132] = "C"
	grid[22][155] = "C"
	grid[29][171] = "C"
	grid[29][48] = "H"
	grid[29][138] = "H"

	# Enemigos: 4 espíritus y 1 demonio
	grid[29][32] = "E"
	grid[23][60] = "e"
	grid[29][100] = "E"
	grid[29][146] = "e"
	grid[29][125] = "D"

	# Puerta de salida hacia Nivel 2 (Sendero), altar de control (K) y antorchas (T)
	grid[29][8] = "T"
	grid[29][46] = "T"
	grid[29][92] = "K"
	grid[29][94] = "T"
	grid[29][140] = "T"
	grid[29][173] = "T"
	grid[29][175] = "X"

	var headers: PackedStringArray = PackedStringArray([
		"@name = Sueño I: Bosque de los Pinos",
		"@season = GREEN",
		"@win_condition = COLLECTIBLES",
		"@pause_on_complete = false",
		"@completed_message = ¡La luz abrió la puerta!",
		"@next_level = res://levels/sueno_1/Sendero.tscn",
		"@kill_y = 800",
		"@dialogue_1 = Emma... ¿me escuchas? Soy la voz de tu pulsera. | Te has dormido y estás en el mundo de los sueños. Las leyendas se han convertido en monstruos. | Reúne las monedas de luz para abrir la puerta. Yo te guiaré.",
		"@dialogue_2 = Ese espíritu está corrompido. ¡Usa mi poder con J o X para purificarlo!",
		"@dialogue_3 = El bosque se congela más adelante... Cruza la puerta hacia el Sendero de las Sombras.",
	])
	return _serialize_grid(headers, grid)


static func _build_level_2_text() -> String:
	# 200 celdas = 4000 px (antes 104). Pinchos bajo las plataformas: el suelo
	# deja de ser seguro y obliga a usar las rutas elevadas.
	var width_cells: int = 200
	var height_cells: int = 35
	var grid: Array[PackedStringArray] = _create_empty_grid(width_cells, height_cells)

	for r: int in range(0, height_cells):
		grid[r][0] = "|"
		grid[r][width_cells - 1] = "|"

	# --- Tramo 1 (cols 1..34) ---
	_paint_rect(grid, 0, 30, 35, GROUND_DEPTH, "#")
	_paint_rect(grid, 12, 27, 7, 1, "=")
	_paint_rect(grid, 21, 24, 6, 1, "=")
	# Foso 1: cols 35..38 (4 celdas)

	# --- Tramo 2 (cols 39..74): puente sobre pinchos ---
	_paint_rect(grid, 39, 30, 36, GROUND_DEPTH, "#")
	_paint_rect(grid, 45, 27, 8, 1, "=")
	_paint_rect(grid, 47, 29, 4, 1, "^")
	_paint_rect(grid, 56, 24, 7, 1, "~")
	# Foso 2: cols 75..84 (10 celdas) con plataforma flotante frágil
	_paint_rect(grid, 78, 27, 4, 1, "~")

	# --- Tramo 3 (cols 85..124): escalera alta ---
	_paint_rect(grid, 85, 30, 40, GROUND_DEPTH, "#")
	_paint_rect(grid, 92, 29, 3, 1, "^")
	_paint_rect(grid, 97, 27, 6, 1, "=")
	_paint_rect(grid, 105, 24, 6, 1, "=")
	_paint_rect(grid, 105, 29, 4, 1, "^")
	_paint_rect(grid, 113, 21, 6, 1, "-")
	# Foso 3: cols 125..129 (5 celdas)

	# --- Tramo 4 (cols 130..164): campo de espinas, solo por arriba ---
	_paint_rect(grid, 130, 30, 35, GROUND_DEPTH, "#")
	_paint_rect(grid, 136, 27, 6, 1, "=")
	_paint_rect(grid, 144, 24, 6, 1, "=")
	_paint_rect(grid, 152, 27, 6, 1, "=")
	_paint_rect(grid, 143, 29, 8, 1, "^")
	# Foso 4: cols 165..169 (5 celdas)

	# --- Tramo 5 (cols 170..198): antesala de la guarida ---
	_paint_rect(grid, 170, 30, 30, GROUND_DEPTH, "#")

	# Jugador y Diálogos
	grid[29][5] = "P"
	grid[22][5] = "1"
	grid[22][42] = "2"
	grid[22][185] = "3"

	# 10 Monedas de luz (C) y 3 Curaciones (H)
	grid[22][24] = "C"
	grid[27][37] = "C"
	grid[24][49] = "C"
	grid[22][59] = "C"
	grid[25][80] = "C"
	grid[25][99] = "C"
	grid[19][116] = "C"
	grid[27][127] = "C"
	grid[22][146] = "C"
	grid[29][190] = "C"
	grid[29][42] = "H"
	grid[29][88] = "H"
	grid[29][160] = "H"

	# Enemigos (3 espíritus + 3 demonios)
	grid[29][28] = "E"
	grid[26][48] = "e"
	grid[29][68] = "D"
	grid[23][107] = "e"
	grid[29][120] = "D"
	grid[29][178] = "D"

	# Puerta hacia la Guarida del Jefe (Nivel 3), altar de control (K) y antorchas (T)
	grid[29][8] = "T"
	grid[29][40] = "T"
	grid[29][86] = "T"
	grid[29][90] = "K"
	grid[29][132] = "T"
	grid[29][193] = "T"
	grid[29][195] = "X"

	var headers: PackedStringArray = PackedStringArray([
		"@name = Sueño I: Sendero de las Sombras",
		"@season = WINTER",
		"@win_condition = COLLECTIBLES",
		"@pause_on_complete = false",
		"@completed_message = ¡El sello de la guarida se ha roto!",
		"@next_level = res://levels/sueno_1/Guarida.tscn",
		"@kill_y = 800",
		"@tint = 0.78, 0.84, 0.96, 1.0",
		"@dialogue_1 = El sueño se vuelve más frío y profundo. Cuidado con las espinas oscuras del suelo.",
		"@dialogue_2 = Usa las plataformas altas para esquivar las espinas y alcanzar las monedas de luz.",
		"@dialogue_3 = Esa puerta lleva a la guarida del Cadejo negro. Ten valor, Emma.",
	])
	return _serialize_grid(headers, grid)


static func _build_level_3_boss_text() -> String:
	# Pasillo de entrada (cols 0..33) + arena cerrada (cols 34..95, 1240 px).
	# El jefe embiste por el suelo; la arena ofrece dos rutas de esquiva en
	# escalera (tablones one-way) hacia una plataforma alta central con curación.
	var width_cells: int = 96
	var height_cells: int = 35
	var grid: Array[PackedStringArray] = _create_empty_grid(width_cells, height_cells)

	for r: int in range(0, height_cells):
		grid[r][0] = "|"
		grid[r][width_cells - 1] = "|"

	# Suelo continuo (el jefe no debe poder caer): de muro a muro.
	_paint_rect(grid, 0, 30, width_cells, GROUND_DEPTH, "#")

	# Arena: escalera izquierda, plataforma alta central, escalera derecha.
	_paint_rect(grid, 37, 27, 6, 1, "-")
	_paint_rect(grid, 46, 24, 6, 1, "-")
	_paint_rect(grid, 56, 21, 10, 1, "=")
	_paint_rect(grid, 70, 24, 6, 1, "-")
	_paint_rect(grid, 79, 27, 6, 1, "-")
	# Repisa junto al muro derecho para escapar si el jefe te arrincona.
	_paint_rect(grid, 90, 27, 5, 1, "-")

	# Jugador, curaciones, reja, disparador de arena, jefe y diálogos
	grid[29][5] = "P"
	grid[22][5] = "1"
	grid[29][16] = "H"
	grid[22][23] = "2"
	grid[29][26] = "G"
	grid[22][31] = "A"
	grid[20][61] = "H"
	grid[29][62] = "B"
	# Portal de salida: aparece al purificar al Cadejo y vuelve al título.
	grid[29][8] = "T"
	grid[29][24] = "T"
	grid[20][58] = "T"
	grid[20][64] = "T"
	grid[29][85] = "T"
	grid[29][87] = "X"

	var headers: PackedStringArray = PackedStringArray([
		"@name = Sueño I: Guarida del Cadejo",
		"@season = AUTUMN",
		"@win_condition = BOSS_DEFEATED",
		"@pause_on_complete = false",
		"@next_level = res://ui/menus/MainMenu.tscn",
		"@exit_fade = 3.5",
		"@completed_message = ¡El Cadejo negro ha sido purificado!\\nCruza el portal para despertar.",
		"@kill_y = 800",
		"@tint = 0.62, 0.55, 0.62, 1.0",
		"@dialogue_1 = Aquí habita el Cadejo negro, el que acecha a los viajeros en la noche. | Si lo purificamos, el Cadejo blanco volverá a protegerlos.",
		"@dialogue_2 = Ya viene... ¡Prepárate, Emma! Sube a los tablones para esquivar sus embestidas.",
	])
	return _serialize_grid(headers, grid)


# ==============================================================================
# 3. PARSER Y VALIDADOR MATEMÁTICO DE ALCANZABILIDAD
# ==============================================================================

## Analiza un nivel en texto plano y devuelve un diccionario estructurado con:
## metadata, width_cells, height_cells, platforms, walls, hazards, entities.
static func parse_text(text: String) -> Dictionary:
	var metadata: Dictionary = {
		"name": "Nivel Generado",
		"season": "GREEN",
		"win_condition": "COLLECTIBLES",
		"pause_on_complete": "false",
		"completed_message": "¡Nivel completado!",
		"next_level": "",
		"kill_y": "800",
		"tint": "1.0, 1.0, 1.0, 1.0",
		"dialogues": {},
	}
	var grid_lines: PackedStringArray = PackedStringArray()
	for raw_line: String in text.split("\n"):
		var line: String = raw_line.strip_edges(false, true)
		if line.is_empty() or line.begins_with("//") or line.begins_with(";"):
			continue
		if line.begins_with("@"):
			var eq_idx: int = line.find("=")
			if eq_idx > 1:
				var key: String = line.substr(1, eq_idx - 1).strip_edges()
				var val: String = line.substr(eq_idx + 1).strip_edges().replace("\\n", "\n")
				if key.begins_with("dialogue_"):
					var dlg_id: String = key.trim_prefix("dialogue_")
					var parts: PackedStringArray = PackedStringArray()
					for part: String in val.split("|"):
						parts.append(part.strip_edges())
					(metadata["dialogues"] as Dictionary)[dlg_id] = parts
				else:
					metadata[key] = val
		else:
			grid_lines.append(line)

	var height_cells: int = grid_lines.size()
	var width_cells: int = 0
	for gl: String in grid_lines:
		width_cells = maxi(width_cells, gl.length())

	var used: Array[Array] = []
	for r: int in height_cells:
		var row_arr: Array[bool] = []
		row_arr.resize(width_cells)
		row_arr.fill(false)
		used.append(row_arr)

	var platforms: Array[Dictionary] = []
	var walls: Array[Dictionary] = []
	var hazards: Array[Rect2] = []
	var entities: Array[Dictionary] = []

	# 1. Extraer muros laterales en col 0 y col width_cells - 1 si están marcados con '|'.
	# Son de BORDER_WALL_CELLS de ancho (la mitad queda fuera de la cámara), van de
	# arriba hasta el fondo del mapa y se dibujan como bloque de tierra: así el
	# borde se ve como un acantilado y no como una columna suelta.
	if width_cells > 0 and height_cells > 0:
		var wall_w: float = float(BORDER_WALL_CELLS) * CELL_SIZE
		var wall_h: float = float(height_cells) * CELL_SIZE + BORDER_WALL_TOP_PX
		walls.append({
			"name": "WallLeft",
			"rect": Rect2(CELL_SIZE - wall_w, -BORDER_WALL_TOP_PX, wall_w, wall_h),
		})
		walls.append({
			"name": "WallRight",
			"rect": Rect2(float(width_cells - 1) * CELL_SIZE, -BORDER_WALL_TOP_PX, wall_w, wall_h),
		})
		for r: int in height_cells:
			if _char_at(grid_lines, r, 0) == "|":
				used[r][0] = true
			if _char_at(grid_lines, r, width_cells - 1) == "|":
				used[r][width_cells - 1] = true

	# 2. Greedy Meshing para suelos (#), plataformas finas (=), one-way (-), frágiles (~), muros internos (|) y pinchos (^)
	var ground_idx: int = 1
	var plat_idx: int = 1
	var one_way_idx: int = 1
	var falling_idx: int = 1
	var wall_idx: int = 1

	for r: int in height_cells:
		for c: int in width_cells:
			if bool(used[r][c]):
				continue
			var ch: String = _char_at(grid_lines, r, c)
			if ch == "#" or ch == "=" or ch == "-" or ch == "~" or ch == "|" or ch == "^":
				# Expandir horizontalmente
				var w: int = 1
				while c + w < width_cells and not bool(used[r][c + w]) and _char_at(grid_lines, r, c + w) == ch:
					w += 1
				# Expandir verticalmente para '#' y '|'
				var h: int = 1
				if ch == "#" or ch == "|":
					var can_expand: bool = true
					while can_expand and r + h < height_cells:
						for cc: int in range(c, c + w):
							if bool(used[r + h][cc]) or _char_at(grid_lines, r + h, cc) != ch:
								can_expand = false
								break
						if can_expand:
							h += 1
				for rr: int in range(r, r + h):
					for cc: int in range(c, c + w):
						used[rr][cc] = true

				var rect_px: Rect2 = Rect2(
					float(c) * CELL_SIZE,
					float(r) * CELL_SIZE,
					float(w) * CELL_SIZE,
					float(h) * CELL_SIZE
				)
				if ch == "#":
					platforms.append({
						"name": "Ground%d" % ground_idx,
						"kind": "ground",
						"rect": rect_px,
						"one_way": false,
					})
					ground_idx += 1
				elif ch == "=":
					platforms.append({
						"name": "Platform%d" % plat_idx,
						"kind": "thin",
						"rect": Rect2(rect_px.position, Vector2(rect_px.size.x, THIN_COLLISION_PX)),
						"one_way": false,
					})
					plat_idx += 1
				elif ch == "-":
					platforms.append({
						"name": "OneWayPlatform%d" % one_way_idx,
						"kind": "one_way",
						"rect": Rect2(rect_px.position, Vector2(rect_px.size.x, THIN_COLLISION_PX)),
						"one_way": true,
					})
					one_way_idx += 1
				elif ch == "~":
					platforms.append({
						"name": "FallingPlatform%d" % falling_idx,
						"kind": "falling",
						"rect": Rect2(rect_px.position, Vector2(rect_px.size.x, THIN_COLLISION_PX)),
						"one_way": true,
					})
					falling_idx += 1
				elif ch == "|":
					walls.append({
						"name": "WallInner%d" % wall_idx,
						"rect": rect_px,
					})
					wall_idx += 1
				elif ch == "^":
					hazards.append(Rect2(rect_px.position.x, rect_px.position.y + 4.0, rect_px.size.x, 16.0))
			elif ch != "." and ch != " ":
				used[r][c] = true
				var surface_y: float = _find_surface_y_below(grid_lines, r, c, height_cells)
				var center_x: float = (float(c) + 0.5) * CELL_SIZE
				var center_y: float = (float(r) + 0.5) * CELL_SIZE
				entities.append({
					"symbol": ch,
					"cell": Vector2i(c, r),
					"world_pos": Vector2(center_x, center_y),
					"surface_y": surface_y,
				})

	return {
		"metadata": metadata,
		"width_cells": width_cells,
		"height_cells": height_cells,
		"platforms": platforms,
		"walls": walls,
		"hazards": hazards,
		"entities": entities,
	}


## Valida matemáticamente que todas las plataformas, coleccionables y metas del
## nivel en texto plano sean alcanzables por el jugador.
static func validate_text(text: String) -> Dictionary:
	var parsed: Dictionary = parse_text(text)
	return validate_level_reachability(parsed)


static func validate_level_reachability(parsed: Dictionary) -> Dictionary:
	var platforms: Array = parsed["platforms"] as Array
	var entities: Array = parsed["entities"] as Array
	var errors: Array[String] = []

	if platforms.is_empty():
		errors.append("El nivel no contiene ninguna plataforma ni suelo.")
		return {
			"valid": false,
			"reachable_platforms": 0,
			"total_platforms": 0,
			"unreachable_collectibles": 0,
			"exit_reachable": false,
			"errors": errors,
		}

	# Encontrar la plataforma inicial bajo el Player ('P')
	var player_pos: Vector2 = Vector2(100.0, 560.0)
	var has_player: bool = false
	for ent: Dictionary in entities:
		if String(ent["symbol"]) == "P":
			player_pos = ent["world_pos"] as Vector2
			has_player = true
			break
	if not has_player:
		errors.append("Falta el símbolo 'P' (posición inicial del Player).")

	var start_idx: int = _find_supporting_platform_index(platforms, player_pos)
	if start_idx == -1:
		start_idx = 0

	# BFS sobre el grafo dirigido de saltos válidos entre plataformas
	var visited: Array[bool] = []
	visited.resize(platforms.size())
	visited.fill(false)
	var queue: Array[int] = [start_idx]
	visited[start_idx] = true
	var reachable_count: int = 0

	while not queue.is_empty():
		var current: int = queue.pop_front()
		reachable_count += 1
		var from_rect: Rect2 = (platforms[current] as Dictionary)["rect"] as Rect2
		for next_idx: int in platforms.size():
			if visited[next_idx]:
				continue
			var to_rect: Rect2 = (platforms[next_idx] as Dictionary)["rect"] as Rect2
			if can_jump_between(from_rect, to_rect):
				visited[next_idx] = true
				queue.append(next_idx)

	for i: int in platforms.size():
		if not visited[i]:
			var p_dict: Dictionary = platforms[i] as Dictionary
			errors.append("Plataforma inalcanzable: %s en %s" % [String(p_dict["name"]), str(p_dict["rect"])])

	# Verificar que cada moneda ('C') y puerta ('X') o jefe ('B') sea alcanzable desde alguna plataforma visitada
	var unreachable_collectibles: int = 0
	var exit_or_boss_reachable: bool = false
	var has_exit_or_boss: bool = false

	for ent: Dictionary in entities:
		var sym: String = String(ent["symbol"])
		var pos: Vector2 = ent["world_pos"] as Vector2
		if sym == "C":
			if not _is_point_reachable_from_visited(pos, platforms, visited):
				unreachable_collectibles += 1
				errors.append("Moneda 'C' inalcanzable en %s" % str(pos))
		elif sym == "X" or sym == "B":
			has_exit_or_boss = true
			if _is_point_reachable_from_visited(pos, platforms, visited):
				exit_or_boss_reachable = true
			else:
				errors.append("Meta/Jefe '%s' inalcanzable en %s" % [sym, str(pos)])

	if not has_exit_or_boss:
		errors.append("El nivel no tiene puerta de salida ('X') ni jefe ('B').")

	var is_valid: bool = (
		has_player
		and reachable_count == platforms.size()
		and unreachable_collectibles == 0
		and exit_or_boss_reachable
	)
	return {
		"valid": is_valid,
		"reachable_platforms": reachable_count,
		"total_platforms": platforms.size(),
		"unreachable_collectibles": unreachable_collectibles,
		"exit_reachable": exit_or_boss_reachable,
		"errors": errors,
	}


# ==============================================================================
# 4. CONSTRUCTOR LÓGICO DE ESCENA DESDE TEXTO PLANO
# ==============================================================================

## Carga un archivo .txt y devuelve el árbol completo del nivel (Node2D).
static func build_level_from_file(path: String, root_name: String = "") -> Node2D:
	if not FileAccess.file_exists(path):
		push_error("PlatformGenerator: no existe el archivo '%s'." % path)
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var default_name: String = path.get_file().get_basename().capitalize() if root_name.is_empty() else root_name
	return build_level_from_text(text, default_name)


## Construye un Node2D jugable completo a partir de la definición en texto plano.
static func build_level_from_text(text: String, root_name: String = "GeneratedLevel") -> Node2D:
	var root: Node2D = Node2D.new()
	root.name = root_name
	populate_level_node(root, text)
	return root


## Puebla un nodo `root` con todos los sistemas, geometría y entidades descritos en `text`.
static func populate_level_node(root: Node2D, text: String) -> void:
	var parsed: Dictionary = parse_text(text)
	var meta: Dictionary = parsed["metadata"] as Dictionary
	var width_cells: int = int(parsed["width_cells"])
	var height_cells: int = int(parsed["height_cells"])
	var world_width_px: float = maxf(float(width_cells) * CELL_SIZE, 1280.0)
	var world_height_px: float = maxf(float(height_cells) * CELL_SIZE, 700.0)

	var season_idx: int = _parse_season(String(meta.get("season", "GREEN")))
	var win_cond: int = 1 if String(meta.get("win_condition", "COLLECTIBLES")) == "BOSS_DEFEATED" else 0
	var pause_complete: bool = String(meta.get("pause_on_complete", "false")).to_lower() == "true"

	# 1. LevelManager + CombatFeedback (Sprint 10)
	var lm: Node = (load("res://levels/common/LevelManager.gd") as GDScript).new()
	lm.name = "LevelManager"
	lm.set("level_name", String(meta.get("name", "")))
	lm.set("win_condition", win_cond)
	lm.set("pause_on_complete", pause_complete)
	lm.set("completed_message", String(meta.get("completed_message", "¡Nivel completado!")))
	lm.set("kill_y", float(String(meta.get("kill_y", "800"))))
	root.add_child(lm)

	var feedback: Node = (load("res://components/CombatFeedback.gd") as GDScript).new()
	feedback.name = "CombatFeedback"
	root.add_child(feedback)

	# 2. HUD
	var hud: CanvasLayer = (load(HUD_SCENE_PATH) as PackedScene).instantiate() as CanvasLayer
	hud.name = "HUD"
	root.add_child(hud)

	# 3. CameraBounds
	var bounds: ReferenceRect = ReferenceRect.new()
	bounds.name = "CameraBounds"
	bounds.add_to_group("camera_bounds")
	bounds.offset_left = 0.0
	bounds.offset_top = 100.0
	bounds.offset_right = world_width_px
	bounds.offset_bottom = world_height_px
	bounds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bounds.border_color = Color(0.2, 0.9, 1.0, 1.0)
	bounds.border_width = 3.0
	root.add_child(bounds)

	# 4. Backdrop (Parallax 6 capas)
	var backdrop: Node2D = (load("res://levels/common/ParallaxBackdrop.gd") as GDScript).new()
	backdrop.name = "Backdrop"
	var bg_textures: Array[Texture2D] = []
	var paths: Array = BG_PATHS.get(season_idx, BG_PATHS[0]) as Array
	for p: String in paths:
		var tex: Texture2D = load(p) as Texture2D
		if tex != null:
			bg_textures.append(tex)
	backdrop.set("layers", bg_textures)
	var factors: Array[float] = [0.0, 0.08, 0.1, 0.22, 0.38, 0.55]
	backdrop.set("scroll_factors", factors)
	backdrop.set("tint", _parse_color(String(meta.get("tint", "1.0, 1.0, 1.0, 1.0"))))
	root.add_child(backdrop)

	# 4b. Ambience (CanvasModulate + WorldEnvironment con glow suave)
	var ambience_scene: PackedScene = load(AMBIENCE_SCENE_PATH) as PackedScene
	if ambience_scene != null:
		var ambience: Node2D = ambience_scene.instantiate() as Node2D
		ambience.name = "Ambience"
		var custom_ambient: Color = Color(0.0, 0.0, 0.0, 0.0)
		if meta.has("ambient"):
			custom_ambient = _parse_color(String(meta["ambient"]))
		ambience.call("set_season", season_idx, custom_ambient)
		root.add_child(ambience)

	# 5. World (Plataformas y Muros) + PlatformSkinner
	var world: Node2D = Node2D.new()
	world.name = "World"
	root.add_child(world)

	var skinner: Node = (load("res://levels/common/PlatformSkinner.gd") as GDScript).new()
	skinner.name = "PlatformSkinner"
	skinner.set("platforms_root", world)
	skinner.set("tileset", load(TILESET_PATH) as Texture2D)
	skinner.set("season", season_idx)
	root.add_child(skinner)

	var falling_scene: PackedScene = load(FALLING_PLATFORM_SCENE_PATH) as PackedScene
	for p_info: Dictionary in parsed["platforms"] as Array:
		var p_rect: Rect2 = p_info["rect"] as Rect2
		var p_kind: String = String(p_info.get("kind", ""))
		if p_kind == "falling" and falling_scene != null:
			var fp: StaticBody2D = falling_scene.instantiate() as StaticBody2D
			fp.name = String(p_info["name"])
			fp.position = p_rect.get_center()
			fp.call("set_size_px", p_rect.size)
			world.add_child(fp)
		else:
			var body: StaticBody2D = _create_platform_body(
				String(p_info["name"]),
				p_rect,
				bool(p_info["one_way"])
			)
			world.add_child(body)

	for w_info: Dictionary in parsed["walls"] as Array:
		var wall_body: StaticBody2D = _create_platform_body(
			String(w_info["name"]),
			w_info["rect"] as Rect2,
			false
		)
		world.add_child(wall_body)

	# 6. Contenedores de Peligros (Hazards), Pickups, Enemigos y Story
	var hazards_root: Node2D = Node2D.new()
	hazards_root.name = "Hazards"
	root.add_child(hazards_root)

	var spike_scene: PackedScene = load(HAZARD_SPIKE_SCENE_PATH) as PackedScene
	var spike_idx: int = 1
	for h_rect: Rect2 in parsed["hazards"] as Array:
		var spike: Area2D = spike_scene.instantiate() as Area2D
		spike.name = "Spike%d" % spike_idx
		spike.position = h_rect.get_center()
		spike.call("set_size_px", h_rect.size)
		hazards_root.add_child(spike)
		spike_idx += 1

	var pickups_root: Node2D = Node2D.new()
	pickups_root.name = "Pickups"
	root.add_child(pickups_root)

	var enemies_root: Node2D = Node2D.new()
	enemies_root.name = "Enemies"
	root.add_child(enemies_root)

	var story_root: Node2D = Node2D.new()
	story_root.name = "Story"
	root.add_child(story_root)

	var torches_root: Node2D = Node2D.new()
	torches_root.name = "Torches"
	root.add_child(torches_root)

	var checkpoints_root: Node2D = Node2D.new()
	checkpoints_root.name = "Checkpoints"
	root.add_child(checkpoints_root)

	# 7. Instanciar Entidades
	var pickup_scene: PackedScene = load(PICKUP_SCENE_PATH) as PackedScene
	var enemy_scene: PackedScene = load(ENEMY_BASE_SCENE_PATH) as PackedScene
	var demon_scene: PackedScene = load(ENEMY_DEMON_SCENE_PATH) as PackedScene
	var portal_scene: PackedScene = load(PORTAL_DOOR_SCENE_PATH) as PackedScene
	var gate_scene: PackedScene = load(ARENA_GATE_SCENE_PATH) as PackedScene
	var torch_scene: PackedScene = load(TORCH_SCENE_PATH) as PackedScene
	var checkpoint_scene: PackedScene = load(CHECKPOINT_SCENE_PATH) as PackedScene
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH) as PackedScene

	var collect_idx: int = 1
	var health_idx: int = 1
	var enemy_idx: int = 1
	var torch_idx: int = 1
	var checkpoint_idx: int = 1
	var player_pos: Vector2 = Vector2(100.0, 560.0)
	var boss_node: Node2D = null
	var arena_trigger_pos: Vector2 = Vector2.ZERO
	var has_arena_trigger: bool = false
	var dialogues_dict: Dictionary = meta.get("dialogues", {}) as Dictionary

	for ent: Dictionary in parsed["entities"] as Array:
		var sym: String = String(ent["symbol"])
		var world_pos: Vector2 = ent["world_pos"] as Vector2
		var surface_y: float = float(ent["surface_y"])

		match sym:
			"P":
				player_pos = Vector2(world_pos.x, surface_y - 40.0)
			"C":
				var coin: Area2D = pickup_scene.instantiate() as Area2D
				coin.name = "Collect%d" % collect_idx
				coin.set("type", 1)
				coin.position = Vector2(world_pos.x, world_pos.y)
				pickups_root.add_child(coin)
				collect_idx += 1
			"H":
				var heal_item: Area2D = pickup_scene.instantiate() as Area2D
				heal_item.name = "Health%d" % health_idx
				heal_item.set("type", 0)
				heal_item.set("amount", 2 if win_cond == 1 else 1)
				heal_item.position = Vector2(world_pos.x, surface_y - 25.0)
				pickups_root.add_child(heal_item)
				health_idx += 1
			"E", "e":
				var enemy: CharacterBody2D = enemy_scene.instantiate() as CharacterBody2D
				enemy.name = "Enemy%d" % enemy_idx
				enemy.set("start_direction", 1 if sym == "e" else -1)
				enemy.position = Vector2(world_pos.x, surface_y - 20.0)
				enemies_root.add_child(enemy)
				enemy_idx += 1
			"D":
				var demon: CharacterBody2D = demon_scene.instantiate() as CharacterBody2D
				demon.name = "Enemy%d" % enemy_idx
				demon.position = Vector2(world_pos.x, surface_y - 20.0)
				enemies_root.add_child(demon)
				enemy_idx += 1
			"X":
				var exit_door: Area2D = portal_scene.instantiate() as Area2D
				exit_door.name = "ExitDoor"
				exit_door.position = Vector2(world_pos.x, surface_y - 48.0)
				exit_door.set("target_scene", String(meta.get("next_level", "")))
				exit_door.set("open_on", 1)
				# Puerta final: aparece al completar el nivel y lleva a la escena
				# con un fundido lento y porcentual en vez de la transición normal.
				var exit_fade: float = float(String(meta.get("exit_fade", "0")))
				if exit_fade > 0.0:
					exit_door.set("hidden_until_open", true)
					exit_door.set("fade_out_time", exit_fade)
				root.add_child(exit_door)
			"G":
				var gate: Area2D = gate_scene.instantiate() as Area2D
				gate.name = "ArenaGate"
				gate.position = Vector2(world_pos.x, surface_y - 48.0)
				gate.set("start_open", true)
				gate.set("open_on", 3)
				gate.set("close_on", 2)
				root.add_child(gate)
			"B":
				var cadejo_scene: PackedScene = load(CADEJO_SCENE_PATH) as PackedScene
				boss_node = cadejo_scene.instantiate() as Node2D
				boss_node.name = "Cadejo"
				boss_node.position = Vector2(world_pos.x, surface_y - 32.0)
				root.add_child(boss_node)
			"A":
				arena_trigger_pos = Vector2(world_pos.x, 450.0)
				has_arena_trigger = true
			"T":
				if torch_scene != null:
					var torch: Node2D = torch_scene.instantiate() as Node2D
					torch.name = "Torch%d" % torch_idx
					torch.position = Vector2(world_pos.x, surface_y - 10.0)
					torches_root.add_child(torch)
					torch_idx += 1
			"K":
				if checkpoint_scene != null:
					var ckpt: Area2D = checkpoint_scene.instantiate() as Area2D
					ckpt.name = "Checkpoint%d" % checkpoint_idx
					ckpt.position = Vector2(world_pos.x, surface_y - 14.0)
					checkpoints_root.add_child(ckpt)
					checkpoint_idx += 1
			_:
				if dialogues_dict.has(sym):
					var dlg: Area2D = (load("res://entities/level/DialogueTrigger.gd") as GDScript).new()
					dlg.name = "Intro" if sym == "1" else "Dialogue%s" % sym
					dlg.position = Vector2(world_pos.x, 450.0)
					dlg.collision_layer = 0
					dlg.collision_mask = 2
					dlg.set("lines", dialogues_dict[sym] as PackedStringArray)
					var cs: CollisionShape2D = CollisionShape2D.new()
					var r_shape: RectangleShape2D = RectangleShape2D.new()
					r_shape.size = Vector2(40.0, 300.0)
					cs.shape = r_shape
					dlg.add_child(cs)
					story_root.add_child(dlg)

	if has_arena_trigger and boss_node != null:
		var arena: Area2D = (load("res://levels/common/BossArena.gd") as GDScript).new()
		arena.name = "ArenaTrigger"
		arena.position = arena_trigger_pos
		arena.collision_layer = 0
		arena.collision_mask = 2
		arena.set("boss", boss_node)
		var cs_arena: CollisionShape2D = CollisionShape2D.new()
		var r_arena: RectangleShape2D = RectangleShape2D.new()
		r_arena.size = Vector2(40.0, 300.0)
		cs_arena.shape = r_arena
		arena.add_child(cs_arena)
		root.add_child(arena)

	# 8. Player + GameCamera
	var player: CharacterBody2D = player_scene.instantiate() as CharacterBody2D
	player.name = "Player"
	player.position = player_pos
	root.add_child(player)

	var cam: Camera2D = (load("res://components/GameCamera.gd") as GDScript).new()
	cam.name = "GameCamera"
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	cam.drag_vertical_enabled = true
	cam.drag_top_margin = 0.25
	cam.drag_bottom_margin = 0.15
	player.add_child(cam)


# ==============================================================================
# PRIVADOS AUXILIARES
# ==============================================================================

static func _create_empty_grid(w: int, h: int) -> Array[PackedStringArray]:
	var grid: Array[PackedStringArray] = []
	for r: int in h:
		var row: PackedStringArray = PackedStringArray()
		row.resize(w)
		row.fill(".")
		grid.append(row)
	return grid


static func _paint_rect(grid: Array[PackedStringArray], x: int, y: int, w: int, h: int, sym: String) -> void:
	var max_h: int = grid.size()
	for rr: int in range(max(0, y), min(max_h, y + h)):
		var max_w: int = grid[rr].size()
		for cc: int in range(max(0, x), min(max_w, x + w)):
			grid[rr][cc] = sym


static func _serialize_grid(headers: PackedStringArray, grid: Array[PackedStringArray]) -> String:
	var out: PackedStringArray = PackedStringArray()
	for h_line: String in headers:
		out.append(h_line)
	out.append("")
	for row: PackedStringArray in grid:
		out.append("".join(row))
	return "\n".join(out) + "\n"


static func _char_at(lines: PackedStringArray, r: int, c: int) -> String:
	if r < 0 or r >= lines.size():
		return "."
	var line: String = lines[r]
	if c < 0 or c >= line.length():
		return "."
	return line.substr(c, 1)


static func _find_surface_y_below(lines: PackedStringArray, start_r: int, c: int, height_cells: int) -> float:
	for rr: int in range(start_r + 1, height_cells):
		var ch: String = _char_at(lines, rr, c)
		if ch == "#" or ch == "=" or ch == "-" or ch == "~":
			return float(rr) * CELL_SIZE
	return 600.0


static func _find_supporting_platform_index(platforms: Array, pos: Vector2) -> int:
	var best_idx: int = -1
	var best_dist: float = INF
	for i: int in platforms.size():
		var rect: Rect2 = (platforms[i] as Dictionary)["rect"] as Rect2
		if pos.x >= rect.position.x - CELL_SIZE and pos.x <= rect.end.x + CELL_SIZE:
			var dy: float = rect.position.y - pos.y
			if dy >= -CELL_SIZE and dy < best_dist:
				best_dist = dy
				best_idx = i
	return best_idx


static func _is_point_reachable_from_visited(pt: Vector2, platforms: Array, visited: Array[bool]) -> bool:
	var h_max: float = get_max_jump_height_px()
	for i: int in platforms.size():
		if not visited[i]:
			continue
		var rect: Rect2 = (platforms[i] as Dictionary)["rect"] as Rect2
		var dy_up: float = rect.position.y - pt.y
		if dy_up > h_max + 24.0 or dy_up < -220.0:
			continue
		var dx: float = 0.0
		if pt.x < rect.position.x:
			dx = rect.position.x - pt.x
		elif pt.x > rect.end.x:
			dx = pt.x - rect.end.x
		var max_x: float = get_max_horizontal_reach_px(maxf(0.0, dy_up), true) + 28.0
		if dx <= max_x:
			return true
	return false


static func _create_platform_body(node_name: String, rect: Rect2, one_way: bool) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = node_name
	body.position = rect.get_center()
	body.collision_layer = 1
	body.collision_mask = 0

	var visual: ColorRect = ColorRect.new()
	visual.name = "Visual"
	visual.offset_left = -rect.size.x * 0.5
	visual.offset_top = -rect.size.y * 0.5
	visual.offset_right = rect.size.x * 0.5
	visual.offset_bottom = rect.size.y * 0.5
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.color = Color(0.35, 0.33, 0.4, 1.0)
	body.add_child(visual)

	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	cs.one_way_collision = one_way
	body.add_child(cs)
	return body


static func _parse_season(season_str: String) -> int:
	match season_str.to_upper():
		"AUTUMN":
			return 1
		"WINTER":
			return 2
		_:
			return 0


static func _parse_color(color_str: String) -> Color:
	var parts: PackedStringArray = color_str.split(",")
	if parts.size() >= 3:
		var r: float = float(parts[0].strip_edges())
		var g: float = float(parts[1].strip_edges())
		var b: float = float(parts[2].strip_edges())
		var a: float = float(parts[3].strip_edges()) if parts.size() >= 4 else 1.0
		return Color(r, g, b, a)
	return Color(1.0, 1.0, 1.0, 1.0)
