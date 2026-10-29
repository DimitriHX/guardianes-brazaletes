---
name: sprint
description: >-
  Implementa el siguiente sprint (o el número indicado) del plan en sprints.md
  siguiendo las convenciones de AGENTS.md / CLAUDE.MD, lo valida en headless y
  marca su estado.
---

# Ejecutar un sprint del plan

1. Leer `sprints.md` y `AGENTS.md` / `CLAUDE.MD`.
2. Reutilizar componentes existentes (`Events`, `StatsComponent`, `HitboxComponent`, `HurtboxComponent`, `CharacterAnimator`, `PlatformSkinner`, `ParallaxBackdrop`, `PlatformGenerator`).
3. Respetar tipado estático estricto y capas de colisión (1 World, 2 Player, 3 Enemies, 4 PlayerProjectiles, 5 Pickups, 6 Hazards).
4. Ejecutar la skill `godot-validar` para verificar 0 fallos.
