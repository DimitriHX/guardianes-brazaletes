---
name: generador-niveles
description: >-
  Genera, valida matemáticamente y construye niveles de plataformas en Godot 4.7
  a partir de texto plano (.txt) usando PlatformGenerator.gd. Usar cuando el
  usuario pida crear, modificar, validar o entender la generación de niveles
  en texto plano o la física de salto de las plataformas.
---

# Algoritmo de Plataformeo y Generación de Niveles en Texto Plano

El sistema vive en `res://levels/common/PlatformGenerator.gd` (`class_name PlatformGenerator`) y `res://levels/common/TextLevel.gd` (`class_name TextLevel`).

## 1. Modelo Matemático del Plataformeo (Grilla 20x20 px)
Cada carácter del mapa de texto plano equivale a una celda de **`20 x 20 px`** (`PlatformGenerator.CELL_SIZE = 20.0`), coincidiendo con `PlatformSkinner.tile_world_size`.

A partir de los parámetros de `Player.gd` (`move_speed = 220`, `jump_velocity = -430`, `gravity = 1200`, `fall_gravity_multiplier = 1.6`, `coyote_time = 0.1`):
- **Altura máxima de salto ($H_{\max}$)**:
  $$H_{\max} = \frac{v_0^2}{2 g_{\text{up}}} = \frac{430^2}{2400} \approx 77.04\text{ px} \approx 3.85\text{ celdas}$$
  - Límite vertical seguro hacia arriba: **3 celdas (`60 px`)**.
- **Tiempo de vuelo y alcance horizontal ($D_{\max}(\Delta y)$)** para un desnivel $\Delta y \le H_{\max}$:
  $$t(\Delta y) = \frac{|v_0|}{g_{\text{up}}} + \sqrt{\frac{2(H_{\max} - \Delta y)}{g_{\text{down}}}}, \quad D_{\max}(\Delta y) = v_x \cdot t(\Delta y)$$
  - $\Delta y = +60\text{ px}$ (subir 3 celdas): alcance máx. $\approx 108\text{ px}$ (hueco seguro: **1 a 4 celdas**).
  - $\Delta y = 0\text{ px}$ (mismo nivel): alcance máx. $\approx 141\text{ px}$ (hueco seguro: **2 a 5.5 celdas**).
  - $\Delta y = -60\text{ px}$ (bajar 3 celdas): alcance máx. $\approx 162\text{ px}$ (hueco seguro: **hasta 6 celdas**).

## 2. Sintaxis del Archivo de Nivel en Texto Plano (`.txt`)
```text
@name = Sueño I: Bosque de los Pinos
@season = GREEN
@win_condition = COLLECTIBLES
@pause_on_complete = false
@completed_message = ¡La luz abrió la puerta!
@next_level = res://levels/sueno_1/Sendero.tscn
@kill_y = 800
@dialogue_1 = Línea 1 | Línea 2

|..............................................|
|....1...........C.............................|
|...............===..........E..........X......|
|...P.......................===................|
|#########...##################################|
|#########...##################################|
```

### Leyenda de Símbolos (Grilla 20x20 px)
- `.` o espacio: Aire
- `#`: Suelo grueso (`StaticBody2D`, `BLOCK_REGION` 3x3)
- `=`: Plataforma fina sólida (arte de 20 px, `THIN_REGION`; colisión de 10 px pegada arriba para poder pasar por debajo)
- `-`: Plataforma fina `one_way_collision = true` (atravesable desde abajo; se dibuja como tablones de madera)
- `|`: Muro vertical (`StaticBody2D` de 20 px de ancho, `PILLAR_REGION`)
- `^`: Pinchos / Peligro (`HazardSpike`, capa 6 `Hazards`)
- `P`: Jugador (`Player` + `GameCamera`)
- `C`: Coleccionable / Moneda de luz (`Pickup` tipo `COLLECTIBLE`)
- `H`: Poción de curación (`Pickup` tipo `HEALTH`)
- `E` / `e`: Enemigo patrullero (`EnemyBase`, `E` = izq, `e` = der)
- `D`: Enemigo demonio rápido (`EnemyDemon`)
- `X`: Puerta-portal de salida (`PortalDoor`: `Door` con sprite, hacia `@next_level`, se abre en `LEVEL_COMPLETED`). Con `@exit_fade = <s>` está oculta hasta ganar y funde lentamente (con porcentaje) a `@next_level`.
- `G`: Reja de arena (`ArenaGate`, empieza abierta, se cierra en `BOSS_FIGHT_STARTED` y se abre en `BOSS_DEFEATED`)
- `A`: Disparador de arena (`BossArena` que activa al jefe)
- `B`: Jefe (`Cadejo`)
- `1`..`9`: Disparador de diálogo (`DialogueTrigger` con las líneas de `@dialogue_N` separadas por `|`)

## 3. Escenas de nivel
`Bosque.tscn`, `Sendero.tscn` y `Guarida.tscn` son solo un nodo `TextLevel` que apunta a su `.txt`: el diseño
vive en `_build_level_1_text()` / `_build_level_2_text()` y los `.txt` se regeneran con
`save_default_level_texts()` (lo hace también `test_level_generator.gd`). Editar el builder, no el `.txt`.
Si el `.txt` no está (p. ej. en una exportación sin `*.txt`), `fallback_level_number` genera el nivel desde código.

## 4. Uso en Código GDScript
- **Generar texto plano de cualquiera de los 3 niveles**:
  `var txt: String = PlatformGenerator.generate_level_text(1) # 1=Bosque, 2=Sendero, 3=Guarida (Boss)`
- **Validar alcanzabilidad matemática**:
  `var report: Dictionary = PlatformGenerator.validate_text(txt)`
- **Construir el nodo de nivel completo desde texto o archivo `.txt`**:
  `var level_node: Node2D = PlatformGenerator.build_level_from_file("res://levels/sueno_1/bosque.txt")`
