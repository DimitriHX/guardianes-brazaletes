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
| [ ] | 08: Componentización Avanzada | `StatsComponent` (vida máx., daño base, multiplicadores) evolucionando `HealthComponent`. `HitboxComponent` (inflige) y `HurtboxComponent` (recibe). Señales globales de muerte/daño crítico en `Events`. | `components/StatsComponent.gd`, `HitboxComponent.gd`, `HurtboxComponent.gd` |

### Fase 2: Game Feel & Polish

| Estado | Sprint | Tarea de Claude Code | Entregable de Código |
|---|---|---|---|
| [x] | 09: Control Maestro de Plataformas | Coyote time, jump buffering y altura de salto variable. **Ya implementado y probado en el Sprint 02.** | `entities/player/Player.gd` |
| [ ] | 10: Impacto Visual y Feedback | Hitstop (`Engine.time_scale`) al impactar, camera shake procedural y partículas básicas (polvo al saltar/correr, chispas al recibir daño). | Sistema de hitstop, cámara con shake, escenas de partículas |

### Fase 3: Boss AI Framework

| Estado | Sprint | Tarea de Claude Code | Entregable de Código |
|---|---|---|---|
| [ ] | 11: Framework de IA para Jefes | `BossBase` con máquina de estados y fases. Ataques como "acciones" elegidas según distancia, vida y tiempo. Primer jefe (El Cadejo): persecución, salto/embestida, rugido que empuja. | `entities/bosses/BossBase.gd`, acciones, jefe Cadejo |
| [ ] | 12: Fases y Progresión | Transición Fase 1 → Fase 2 (velocidad, nuevos ataques). Barra de vida del jefe en el HUD vía `Events`. | Gestión de fases, barra de vida del jefe |

### Matriz de calidad (cada sprint)
1. Tipado estático. 2. Hijo→padre con señales, global vía `Events`. 3. `/godot-validar` + tests de regresión. 4. `TODO(assets):` en todo recurso pendiente.
