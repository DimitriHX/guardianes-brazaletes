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
