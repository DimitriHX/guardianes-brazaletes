# Plan de Sprints

Sigue este orden secuencial para pedirle tareas a Claude Code en la terminal
(o usa `/sprint` para ejecutar el siguiente pendiente).

| Estado | Sprint | Tarea de Claude Code | Entregable de Código |
|---|---|---|---|
| [x] | 01: Base de Físicas y Bus | Configurar `Events.gd` y la clase base de entidad con vida/daño (`HealthComponent.gd` o métodos estándar). | `autoloads/Events.gd`, `components/HealthComponent.gd` |
| [x] | 02: Jugador y Plataformeo | Implementar `Player.tscn` (CharacterBody2D) con salto con coyote-time/jump-buffer básico y ColorRect temporal. | `entities/player/Player.gd`, `Player.tscn` |
| [x] | 03: Mecánica de Disparo | Crear la escena `Projectile.tscn` y el punto de anclaje Marker2D en el jugador para disparar con cooldown. | `entities/projectile/Projectile.gd` y actualización del Player |
| [x] | 04: Patrullaje Enemigo | Crear `EnemyBase.tscn` con detección de plataformas mediante RayCast2D y daño por contacto. | `entities/enemies/EnemyPatrol.gd`, `EnemyBase.tscn` |
| [x] | 05: Sistema de Pickups | Crear `Pickup.tscn` configurable por export con tipos: vida y coleccionable. | `entities/items/Pickup.gd`, `Pickup.tscn` |
| [x] | 06: Loop del Nivel | Crear `LevelManager.gd` que controle el contador de coleccionables necesarios para ganar y reinicio por muerte. | `levels/LevelManager.gd`, escena de prueba `TestLevel.tscn` |

## Evolución

### Fase 1: Cimientos y Robustez (Core Técnico)

| Estado | Sprint | Tarea de Claude Code | Entregable de Código |
|---|---|---|---|
| [x] | 07: Máquina de Estados | Clase base `State` (enter/exit/update/physics_update) y `StateMachine`. Migrar `Player.gd` a estados: Idle, Walk, Jump, Fall, Attack (+ Dead). Cada estado decide su animación. | `components/state_machine/State.gd`, `StateMachine.gd`, `entities/player/states/*.gd` |
| [x] | 08: Componentización Avanzada | `StatsComponent` (vida máx., daño base, multiplicadores) evolucionando `HealthComponent`. `HitboxComponent` (inflige) y `HurtboxComponent` (recibe). Señales globales de muerte/daño crítico en `Events`. | `components/StatsComponent.gd`, `HitboxComponent.gd`, `HurtboxComponent.gd` |

### Fase 2: Game Feel & Polish

| Estado | Sprint | Tarea de Claude Code | Entregable de Código |
|---|---|---|---|
| [x] | 09: Control Maestro de Plataformas | Coyote time, jump buffering y altura de salto variable. **Ya implementado y probado en el Sprint 02.** | `entities/player/Player.gd` |

## Ruta hacia el jefe (plan fusionado)

Orden de ejecución: **A → B → 10 → C → D (incluye 11 y 12) → E**.
Arte: placeholders (ColorRect/colores) + `TODO(assets):`; el diseñador cambia texturas.

| Estado | Sprint | Tarea de Claude Code | Entregable de Código |
|---|---|---|---|
| [x] | A: Cámara y Enfoque | Camera2D reutilizable: zoom cerrado sobre el jugador, `position_smoothing`, márgenes de arrastre, look-ahead hacia donde mira y límites automáticos desde un rectángulo de bounds del nivel (sin mostrar el vacío). | `components/GameCamera.gd`, `CameraBounds` en TestLevel |
| [ ] | B: Ambientación y Capas | Parallax de varias capas (fondo lejano, montañas, árboles cercanos), `CanvasModulate` con tono ambiental, `PointLight2D` en antorchas/puntos de interés y `WorldEnvironment` con glow suave. | Escena de ambientación reutilizable por nivel |
| [ ] | 10: Impacto Visual y Feedback | Hitstop (`Engine.time_scale`) al impactar, camera shake procedural (sobre GameCamera) y partículas básicas (polvo al saltar/correr, chispas al recibir daño), todo vía `Events`. | Sistema de hitstop, shake, escenas de partículas |
| [x] | C: Nivel 2 (parcial: puerta + transición hechas; faltan paleta propia y hazards) | Meta/bandera al final del Nivel 1 que hace que `LevelManager` cargue el Nivel 2. Nivel 2 con otra paleta (cueva o cementerio) sobre TileMapLayer placeholder. Nuevos obstáculos: plataformas móviles/que caen y Hazards (pinchos) en la capa 6. | Goal, transición en LevelManager, `levels/sueno_1/Sendero.tscn`, `entities/level/HazardSpike.tscn` |
| [x] | D: Arena y Jefe (incl. 11 y 12) | Arena cerrada al final del Nivel 2 que bloquea la salida hasta derrotar al jefe. `BossBase` con máquina de estados, ataques como acciones y fases. El Cadejo: Perseguir → Atacar (embestida/salto) → Retroceder, rugido que empuja y fase 2 más rápida. Barra de vida del jefe en el HUD solo durante el combate. Animaciones: AnimatedSprite2D preparado para los sprites del jefe (los .piskel deben exportarse a PNG). | `entities/bosses/*`, arena, barra de vida del jefe |
| [ ] | E: Victoria y Cierre | Secuencia de derrota del jefe y aparición de la bandera final. Pantalla "¡Victoria!" con reiniciar / volver al menú principal (menú simple). | Secuencia de derrota, `VictoryScreen`, `MainMenu` |

### Extra hecho fuera de orden
- **Sistema de frames**: `PiskelLoader` (lee .piskel sin exportar), `AnimationSet` (.tres), `CharacterAnimator` (prioridades, one-shots, señales por frame, fallback sin arte). Jugador con anim. de daño y muerte notificada al acabar la animación.
- **BossLevel**: puerta del Nivel 1 → Nivel 2 (`Sendero.tscn`) → Nivel del jefe (`Guarida.tscn`); reja que se cierra al empezar el combate; El Cadejo con sus .piskel reales.
- **Generador Lógico y Físico de Niveles en Texto Plano (`PlatformGenerator.gd` y `TextLevel.gd`)**: modelo matemático de alcance de salto en grilla de `20x20 px`, generador de los 3 niveles en `.txt` (`bosque.txt`, `sendero.txt`, `guarida.txt`), validador BFS de alcanzabilidad de plataformas/monedas y constructor lógico con fusión Greedy Meshing 2D.

- **Arte PixelLab + menú e historia**: Cadejo con animaciones de PixelLab (`cadejo_pixellab_animations.tres`), puerta-portal animada (`PortalDoor.tscn`, símbolo `X`), pinchos con tile. `GameCamera` escala el zoom con la resolución (encuadre de 720p también a 1080p). Niveles 1 y 2 alargados (3600 y 4000 px) y `Bosque.tscn`/`Sendero.tscn` construidos desde su `.txt` con `TextLevel`. `MainMenu` adaptado de `referencia/` y `StoryCrawl` (texto en perspectiva que sube) al pulsar Iniciar juego.
- **Pulido de bordes, plataformas y arena**: muros de borde de 2 celdas como bloque de tierra hasta el fondo; plataformas one-way dibujadas como tablones; `Guarida.tscn` generada desde `guarida.txt` con arena en escalera (tablones + plataforma alta con curación) y reja con sprite que cae al empezar el combate (`ArenaGate.tscn`). La intro termina sola cuando el texto deja de leerse (con fundido) y no se atasca si se salta durante la transición. Opciones: selector VENTANA / COMPLETA y deslizadores con estilo.

### Matriz de calidad (cada sprint)
1. Tipado estático. 2. Hijo→padre con señales, global vía `Events`. 3. `/godot-validar` + tests de regresión. 4. `TODO(assets):` en todo recurso pendiente.
