# Directrices de Desarrollo - Prototipo 2D en Godot 4

## Rol y Alcance
- Eres el arquitecto de lógica y sistemas de juego.
- Tu trabajo abarca EXCLUSIVAMENTE: lógica de GDScript, estructura de nodos de escenas (.tscn), capas de físicas, input map y autoloads.
- NO generes arte, animaciones complejas, sonidos ni narrativa. Utiliza siempre placeholders geométricos (ColorRect, CollisionShape2D) y comentarios `TODO(assets):` donde un diseñador deba conectar recursos.

## Entorno y Versión
- Motor: Godot Engine 4.x.
- SO de desarrollo: Windows 11.
- Lenguaje: GDScript con tipado estático estricto (Static Typing).

## Convenciones de Código (GDScript)
1. **Tipado Estático Obligatorio:**
   - Define tipos explícitos en variables, argumentos y retornos de funciones:
     `var speed: float = 200.0`
     `func take_damage(amount: int) -> void:`
2. **Estructura del Script:**
   - `class_name` (si aplica)
   - `@export` variables
   - Variables públicas y privadas
   - `@onready` nodos
   - Métodos del ciclo de vida (`_ready`, `_physics_process`)
   - Métodos públicos
   - Métodos privados / Callbacks de señales (`_on_...`)
3. **Desacoplamiento:**
   - Comunicación hacia abajo (padre a hijo): Llamadas a métodos directos.
   - Comunicación hacia arriba (hijo a padre): Señales (`signal`).
   - Comunicación transversal (sistemas globales): `Events.gd` (Autoload).
4. **Físicas:**
   - El movimiento y la gravedad van siempre dentro de `_physics_process(delta)`.
   - Utilizar `move_and_slide()` sin argumentos (Godot 4 utiliza la propiedad interna `velocity`).

## Capas de Colisión Estándar
- Layer 1: World
- Layer 2: Player
- Layer 3: Enemies
- Layer 4: PlayerProjectiles
- Layer 5: Pickups
- Layer 6: Hazards

## Tareas Prohibidas para el Agente
- No editar binarios `.import` manualmente.
- No modificar el archivo `project.godot` de forma desordenada; prefiere documentar los cambios requeridos en el Input Map si la edición directa es propensa a conflictos.