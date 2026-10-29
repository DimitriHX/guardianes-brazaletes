---
name: godot-validar
description: >-
  Valida la sintaxis y el tipado de los scripts GDScript y que las escenas .tscn
  carguen, usando Godot 4.7 en modo headless. Usar después de crear o editar
  cualquier .gd o .tscn, y antes de dar una tarea o sprint por terminado.
---

# Validar proyecto Godot (headless)

Ejecutable: `./Godot_v4.7.2-stable_win64_console.exe` (en la raíz del proyecto).
Usa siempre la versión `_console` para tener la salida en la terminal.

## Pasos

1. Reimportar para que Godot registre `class_name`, autoloads y UIDs nuevos:

   ```powershell
   .\Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
   ```

2. Ejecutar el validador `validate.gd`. Carga cada `.gd` y `.tscn` de
   `autoloads/`, `components/`, `entities/`, `levels/` y `ui/` con los autoloads
   ya registrados y termina con exit code 1 si algo falla:

   ```powershell
   .\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script "$PWD\.claude\skills\godot-validar\validate.gd"
   ```

3. Ejecutar los tests de regresión permanentes en `.claude/skills/godot-validar/tests/*.gd`:

   ```powershell
   Get-ChildItem .claude\skills\godot-validar\tests\*.gd | ForEach-Object {
     Write-Host "== $($_.Name)"
     .\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script $_.FullName
   }
   ```
