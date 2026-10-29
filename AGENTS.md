# Directrices de Desarrollo y Arquitectura - Godot 4.7 (El Brazalete del Guardián)

## Rol y Alcance
- Eres el arquitecto de lógica, diseño de niveles y sistemas de juego en Godot 4.7.
- Tu trabajo abarca: lógica de GDScript, generación lógica de niveles desde texto plano, estructura de nodos de escenas (`.tscn`), capas de físicas, input map y autoloads.
- Respeta siempre el flujo visual de placeholders geométricos (`ColorRect` + `CollisionShape2D`) acompañados de `PlatformSkinner`, `ParallaxBackdrop` y `CharacterAnimator`.

## Convenciones de Código (GDScript)
1. **Tipado Estático Estricto Obligatorio:**
   - Define tipos explícitos en variables, parámetros, iteradores de bucles y retornos de funciones:
     `var speed: float = 220.0`
     `func take_damage(amount: int) -> void:`
2. **Estructura del Script:**
   - `class_name` (si aplica)
   - Señales (`signal`) y `enum` / `const`
   - `@export` variables
   - Variables públicas y privadas
   - `@onready` nodos
   - Métodos del ciclo de vida (`_ready`, `_physics_process`, `_process`)
   - Métodos públicos
   - Métodos privados / Callbacks de señales (`_on_...`)
3. **Desacoplamiento y Señales:**
   - Padre a hijo: llamadas directas a métodos.
   - Hijo a padre: señales (`signal`).
   - Sistemas globales: `Events.gd` (Autoload). **Nunca** conectar lambdas (`func(...)`) a señales de `Events`; conectar siempre métodos del nodo receptor para que Godot los desconecte automáticamente al liberar la escena.
4. **Cambios de Escena:**
   - Usar siempre `SceneTransition.change_scene(path)` o `Events.level_change_requested.emit(path)`.

## Capas de Colisión (2D Physics)
- Layer 1 (bit 1): `World` (Suelos, plataformas, muros, bloqueadores de puertas)
- Layer 2 (bit 2): `Player` (Cuerpo y Hurtbox del jugador)
- Layer 3 (bit 4): `Enemies` (Cuerpo y Hurtbox de enemigos y jefes)
- Layer 4 (bit 8): `PlayerProjectiles` (Proyectiles de luz de Emma)
- Layer 5 (bit 16): `Pickups` (Monedas de luz y pociones de vida)
- Layer 6 (bit 32): `Hazards` (Pinchos y trampas del escenario)

## Física del Plataformeo y Grilla Lógica (`PlatformGenerator`)
- **Unidad de celda (`CELL_SIZE`)**: `20 x 20 px` (alineada con `PlatformSkinner.tile_world_size = 20.0`).
- **Parámetros del Jugador (`Player.gd`)**:
  - `move_speed = 220.0 px/s` (11 celdas/s)
  - `jump_velocity = -430.0 px/s`
  - `gravity = 1200.0 px/s²` (subida), `fall_gravity = 1920.0 px/s²` (`1200 * 1.6`, bajada)
  - `coyote_time = 0.1 s`, `jump_buffer_time = 0.12 s`
- **Límites Matemáticos de Salto**:
  - Altura máxima teórica: $H_{\max} = \frac{430^2}{2 \times 1200} = 77.04\text{ px}$ ($\approx 3.85\text{ celdas}$).
  - **Desnivel máximo seguro hacia arriba ($\Delta y$)**: **3 celdas (`60 px`)**. Un escalón de 4 celdas (`80 px`) es físicamente imposible sin plataforma intermedia.
  - **Alcance horizontal máximo según desnivel**:
    $$D_{\max}(\Delta y) = v_x \left( \frac{|v_0|}{g_{\text{up}}} + \sqrt{\frac{2(H_{\max} - \Delta y)}{g_{\text{down}}}} \right)$$
    - Mismo nivel ($\Delta y = 0$): $141.1\text{ px}$ ($\approx 7\text{ celdas}$; hueco seguro: **2 a 5.5 celdas / 40–110 px**).
    - Subiendo 3 celdas ($\Delta y = +60\text{ px}$): $108.1\text{ px}$ ($\approx 5.4\text{ celdas}$; hueco horizontal seguro: **1 a 4 celdas / 20–80 px**).
    - Bajando 3 celdas ($\Delta y = -60\text{ px}$): $162.0\text{ px}$ ($\approx 8.1\text{ celdas}$; hueco horizontal seguro: **hasta 6 celdas / 120 px**).

## Progresión de los 3 Niveles (Sueño I)
1. **Nivel 1 (`res://levels/sueno_1/Bosque.tscn` / `bosque.txt`)**: *Sueño I: Bosque de los Pinos* (`Season.GREEN`). Introducción a movimiento, salto, disparo y recolección de 5 monedas de luz. Cruza hacia el Nivel 2.
2. **Nivel 2 (`res://levels/sueno_1/Sendero.tscn` / `sendero.txt`)**: *Sueño I: Sendero de las Sombras* (`Season.WINTER`). Plataformeo vertical/horizontal avanzado, fosos, pinchos (`HazardSpike`, capa 6), espíritus y demonios, 6 monedas de luz. Cruza hacia la Guarida.
3. **Nivel 3 - Boss (`res://levels/sueno_1/Guarida.tscn` / `guarida.txt`)**: *Sueño I: Guarida del Cadejo* (`Season.AUTUMN`). Pasillo previo con curación, reja automática (`ArenaGate`), plataformas `one_way` y combate por fases contra *El Cadejo negro*.
