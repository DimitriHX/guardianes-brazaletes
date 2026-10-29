---
name: sprint
description: Implementa el siguiente sprint (o el número indicado) del plan en sprints.md siguiendo las convenciones de CLAUDE.md, lo valida en headless y marca su estado. Usar cuando el usuario diga "sprint", "siguiente sprint", "sprint 03", etc.
---

# Ejecutar un sprint del plan

Argumento opcional: número de sprint (`01`–`06`). Sin argumento, toma el primero
con estado `[ ]` en `sprints.md`.

## Pasos

1. Leer `sprints.md` y `CLAUDE.MD`. Revisar el código ya existente de sprints
   anteriores para reutilizarlo (Events, HealthComponent, Player…) en vez de duplicarlo.
2. Implementar SOLO los entregables de ese sprint, respetando CLAUDE.MD:
   - Tipado estático en todo; orden de secciones del script.
   - Hijo→padre con `signal`; sistemas globales vía el autoload `Events`.
   - Movimiento en `_physics_process`, `move_and_slide()` sin argumentos.
   - Capas: 1 World, 2 Player, 3 Enemies, 4 PlayerProjectiles, 5 Pickups, 6 Hazards.
     Configurar `collision_layer` / `collision_mask` como máscara de bits
     (capa N = `1 << (N-1)`, p. ej. Player=2, Enemies=4, Pickups=16).
   - Visuales con `ColorRect` + `CollisionShape2D`; marcar `# TODO(assets): ...`
     donde vaya un sprite/animación (los .piskel de `assets/` son del diseñador).
   - Acciones de input disponibles: `move_left`, `move_right`, `jump`, `shoot`, `restart`.
     Si hace falta otra, añadirla a `[input]` de `project.godot` sin tocar el resto.
   - Al crear un autoload, registrarlo en `[autoload]` de `project.godot`.
   - Daño: usar `HitboxComponent` (inflige; layer 0, mask = capa del objetivo) y
     `HurtboxComponent` (recibe; layer = capa del dueño, mask 0, `health` → Stats).
     Vida/estadísticas con `StatsComponent`. No reimplementar daño a mano.
   - Animación: `CharacterAnimator` (AnimatedSprite2D) + un `AnimationSet` .tres que
     apunta a los .piskel de `assets/`. Los estados llaman a play_animation(); no
     reproducir animaciones a mano.
   - Conexiones a señales de `Events` (autoload): SIEMPRE a métodos del nodo, nunca
     lambdas (`func(...)`). Las lambdas sobreviven al reinicio del nivel y llaman a
     nodos liberados ("Attempt to call function 'null::...'").
   - Hojas de sprites (PNG/JPEG): `AnimationEntry.sheet` + `regions`; para JPEG con
     fondo opaco `remove_background` y `AnimationSet.align_sheet_frames`.
   - Cambios de escena: SIEMPRE `SceneTransition.change_scene(path)` /
     `SceneTransition.reload_scene()` (o Events.level_change_requested), nunca
     `get_tree().change_scene_to_file` directo.
   - Plataformas: colisión con StaticBody2D + RectangleShape2D; el arte lo pone
     `PlatformSkinner` (no dibujar tiles a mano). Medidas en múltiplos de 20.
   - Assets con licencia que prohíbe redistribuir: añadirlos a `.gitignore` y a
     CREDITS.md (el repo es público).
   - Plataformas que deban atravesar jefes/enemigos altos: `one_way_collision = true`.
   - `Area2D` que deban detectar cuerpos: NO poner `monitorable = false`.
     En Godot 4.7 eso impide detectar StaticBody2D (verificado en el Sprint 03).
3. Escribir los `.tscn` a mano en formato 3 (`[gd_scene format=3]`), sin `uid=`
   inventados: Godot los asigna al reimportar. Referenciar scripts por ruta `res://`.
4. Ejecutar la skill `godot-validar`. Corregir hasta que todo pase.
5. Marcar el sprint como `[x]` en `sprints.md` y resumir al usuario: archivos
   creados, cómo probarlo en el editor, y TODO(assets) pendientes.
