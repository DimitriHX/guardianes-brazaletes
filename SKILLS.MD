1. Servidores MCP Recomendados para Windows
Configura tu archivo de configuración de Claude Code (claude_desktop_config.json o la configuración MCP del CLI) con herramientas nativas del sistema de archivos y ejecución:

filesystem (Oficial de Anthropic):

Propósito: Lectura y escritura rápida en el árbol de directorios de Godot (res://), gestión de archivos .gd, .tscn y .godot.

Comando: npx -y @modelcontextprotocol/server-filesystem "C:\\Ruta\\A\\Tu\\ProyectoGodot"

godot-mcp (o integración CLI de Godot via Windows Terminal / PowerShell):

Propósito: Permitir al agente ejecutar el ejecutable de Godot en modo headless para validar sintaxis de scripts o correr escenas de prueba de forma no interactiva:

PowerShell
godot.exe --headless --check-only -s script.gd