---
name: godot-validar
description: Valida la sintaxis y el tipado de los scripts GDScript y que las escenas .tscn carguen, usando Godot 4.7 en modo headless. Usar después de crear o editar cualquier .gd o .tscn, y antes de dar un sprint por terminado.
---

# Validar proyecto Godot (headless)

Ejecutable: `./Godot_v4.7.2-stable_win64_console.exe` (en la raíz del proyecto).
Usa siempre la versión `_console` para tener la salida en la terminal.

## Pasos

1. Reimportar para que Godot registre `class_name`, autoloads y UIDs nuevos:

   ```bash
   ./Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
   ```

2. Ejecutar el validador `validate.gd` de esta skill. Carga cada `.gd` y `.tscn`
   de `autoloads/ components/ entities/ levels/` con los autoloads ya registrados
   y termina con exit code 1 si algo falla:

   ```bash
   timeout 120 ./Godot_v4.7.2-stable_win64_console.exe --headless --path . \
     --script "$(pwd -W)/.claude/skills/godot-validar/validate.gd" 2>&1 \
     | grep -E '^(OK|FAIL|VALIDATE)|SCRIPT ERROR|Parse Error|at: GDScript'
   ```

   NO usar `--check-only` por archivo: no registra autoloads y da falsos
   `Identifier not found: Events`.

3. Tests de regresión permanentes (en `tests/` de esta skill). Ejecutarlos todos
   tras cualquier cambio en el jugador, estados o componentes; deben acabar en
   `RESULT: 0 fallos` (exit code 0):

   ```bash
   for t in .claude/skills/godot-validar/tests/*.gd; do
     echo "== $t"
     timeout 150 ./Godot_v4.7.2-stable_win64_console.exe --headless --path . \
       --script "$(pwd -W)/$t" 2>&1 | grep -E 'FAIL|RESULT|SCRIPT ERROR'
   done
   ```

   Al añadir una mecánica nueva que deba mantenerse, añadir aquí su test.

4. Pruebas puntuales (opcional): escribir un `extends SceneTree` temporal
   en `.tmpcheck/` y borrarlo al terminar. Reglas (también para `tests/`):
   - Empezar el trabajo en `_initialize()` con `_run.call_deferred()`.
   - **No** tipar con `class_name` del proyecto (`Player`, `HealthComponent`…)
     en el script del test: se compila antes que los autoloads y rompe la carga.
     Usar tipos del motor (`CharacterBody2D`, `Node`) y `load()` en runtime.
   - Lanzar siempre con `timeout` para que un test colgado no bloquee la sesión.
   - `Input.action_press()` y los nodos recién añadidos se procesan en el
     siguiente frame de físicas: esperar 2–3 frames antes de comprobar.

## Interpretación

- `FAIL` + `Parse Error` → error de sintaxis o de tipos: corregir y repetir.
- `Identifier "X" not declared` sobre un autoload → no está en `[autoload]` de `project.godot`.
- Los `ERROR: ... leaked at exit` / `BUG: Unreferenced static string` al salir son ruido del modo headless.
- Reportar al usuario los fallos con `archivo:línea`. No dar por buena una tarea con fallos.
