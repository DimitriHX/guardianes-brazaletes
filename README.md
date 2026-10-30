# El Brazalete del Guardián

Plataformas de acción 2D hecho en **Godot 4.7** con GDScript.

Emma se queda dormida y despierta en el mundo de los sueños, donde las leyendas
centroamericanas se han corrompido y convertido en monstruos. Guiada por la voz de su
pulsera mágica, debe atravesar el sueño, purificar a los espíritus y enfrentarse al
**Cadejo negro** para poder despertar.

Esta demo contiene el **Sueño I** completo: tres niveles y un combate contra un jefe.

---

## Cómo ejecutarlo

1. Instala **Godot 4.7** (versión estándar, no .NET).
2. Abre `project.godot` desde el gestor de proyectos de Godot.
3. Pulsa **F5** (Ejecutar proyecto).

> Todo el arte, las fuentes y el audio que usa el juego están incluidos en el repositorio.
> Autores y licencias en [`CREDITS.md`](CREDITS.md).

## Controles

| Acción | Teclado | Mando |
|---|---|---|
| Moverse | `A` / `D` o flechas ← → | Cruceta ← → |
| Saltar | `Espacio`, `W` o flecha ↑ | A |
| Disparar (poder de la pulsera) | `J` o `X` | X |
| Pausa | `Esc` o `P` | Start |
| Reiniciar nivel | `R` | Back |

Los menús se navegan con teclado, mando o ratón.

---

## Recorrido de la demo

1. **Pantalla de inicio** del estudio, con fundido.
2. **Menú principal**: Iniciar juego, Opciones (volumen de música y efectos, intensidad
   de la vibración de cámara, ventana o pantalla completa; se guardan entre partidas) y Salida.
3. **Historia**: texto en perspectiva que sube por la pantalla y cuenta la leyenda.
   Se puede saltar.
4. **Nivel 1 – Bosque de los Pinos** (tutorial): un escalón para aprender a saltar, un
   foso pequeño, el primer espíritu, una colina en escalones con ruta alta opcional, un
   altar de luz y los puentes de tablones sobre el arroyo antes del claro del demonio.
5. **Nivel 2 – Sendero de las Sombras**: las espinas y el hielo que se quiebra se
   presentan primero sobre suelo seguro y luego sobre el vacío: abismo de hielo, bloques
   entre espinas y una escalera alta sobre un campo de espinas, con altares antes de cada reto.
6. **Nivel 3 – Guarida del Cadejo**: la reja se cierra y empieza el combate contra el jefe.
7. Al purificar al Cadejo aparece un **portal**; al cruzarlo, Emma "despierta" con un
   fundido lento de vuelta al título.

## Mecánicas

### Movimiento con buena sensación de control
- **Aceleración y fricción** en vez de velocidad instantánea; control reducido en el aire.
- **Coyote time** (0,1 s): todavía se puede saltar un instante después de dejar el borde.
- **Jump buffering** (0,12 s): si pulsas saltar justo antes de aterrizar, el salto se
  ejecuta al tocar el suelo.
- **Salto variable**: soltar el botón antes corta el salto; mantenerlo salta más alto.
- **Gravedad de caída mayor** (×1,6) para que el salto se sienta firme y no flotante.
- **Plataformas one-way** que se atraviesan desde abajo, y plataformas finas por debajo
  de las cuales se puede pasar.

### Combate
- Emma dispara orbes de luz con la pulsera, con tiempo de recarga.
- Sistema de **hitbox/hurtbox**: quien inflige daño y quien lo recibe son componentes
  separados, reutilizables en jugador, enemigos y jefe.
- Retroceso (knockback) e invulnerabilidad breve al recibir daño.
- **Impacto** (*game feel*), varias respuestas pequeñas a la vez en cada golpe:
  - *hitstop*: el tiempo se congela unas centésimas;
  - **destello blanco** del sprite golpeado (shader `hit_flash`);
  - **aplastamiento** del personaje golpeado, que vuelve a su forma con un rebote;
  - **sacudida de cámara por "trauma"**: los golpes suman, el movimiento crece con el
    cuadrado del trauma (los pequeños apenas se notan, los grandes pegan) y siempre se
    apaga sola; su intensidad se ajusta en Opciones (accesibilidad);
  - partículas: chispas al recibir daño, polvo al saltar, aterrizar y correr.
- **Estirar y aplastar a Emma**: se estira al despegar, se aplasta al aterrizar (más
  cuanto más rápido cae; una caída fuerte sacude un poco la cámara) y retrocede al disparar.
- El contador de monedas da un saltito al recoger una, más grande con la última.

### Enemigos y obstáculos
- **Enemigos patrulla** que detectan el borde de las plataformas con *raycasts* y no se caen.
- **Demonios** más resistentes.
- **Pinchos** que dañan al tocarlos y **plataformas frágiles** que tiemblan y caen
  después de pisarlas.
- Caer al vacío reinicia el intento.

### Progreso
- **Monedas de luz**: hay que reunirlas todas para abrir la puerta del nivel.
- **Vida**: pociones que curan.
- **Altares de luz (checkpoints)**: al tocarlos se encienden, y al morir Emma revive allí
  en lugar de empezar el nivel desde el principio.
- **Diálogos** de la pulsera que se disparan al pasar por ciertos puntos del nivel.

### El jefe: el Cadejo negro
Controlado por una **máquina de estados** propia:
- **Dormido** hasta que Emma entra en la arena (la reja se cierra detrás de ella).
- **Persecución** → **embestida** → **retirada**, en ciclo.
- **Rugido** que empuja a Emma lejos.
- **Fase 2** al bajar del 50 % de vida: se vuelve más rápido.
- Barra de vida propia en el HUD, visible solo durante el combate.
- Al derrotarlo no muere: se **purifica** (se ilumina) y se abre el portal de salida.

### Presentación
- **Cámara** que sigue al jugador con suavizado, mira hacia donde avanza, no muestra el
  vacío fuera del nivel y mantiene el mismo encuadre a 720p y a 1080p.
- **Ambientación** por nivel: fondos con parallax de varias capas, tono de color propio,
  antorchas con luz dinámica y brillo suave (*glow*).
- **Clima**: hojas que caen en el Bosque y nieve en el Sendero, en dos capas de distinta
  profundidad, siempre por detrás de Emma, los enemigos y el terreno (no tapan la acción).
- **Suelo con profundidad**: la tierra toma el color de la estación junto a la superficie
  y se oscurece hacia abajo (shader `terrain_depth`), también en las plataformas sueltas.
- **Emma respira** cuando está quieta: hombros y cabeza bajan un píxel al ritmo de la
  respiración y de vez en cuando parpadea.
- **Pantalla de título** con el nombre del juego a la izquierda, con colores que fluyen,
  un destello, flotación y latido (shader `title_shimmer`), y los botones a la derecha
  entrando con una animación.
- **HUD** sencillo: el orbe de vida y el número de monedas recogidas, más mensajes y caja de diálogo.
- **Menú de pausa** (continuar, reiniciar, volver al menú) y transiciones con fundido
  entre escenas.
- Música y efectos de sonido gestionados por eventos, con volumen ajustable.

---

## Cómo lo hicimos

### Arquitectura
El código sigue unas reglas fijas para que cada parte sea independiente y fácil de cambiar:

- **GDScript con tipado estático** en todas las variables, parámetros y retornos.
- **Composición en vez de herencia**: la vida, las estadísticas, el daño y la recepción de
  golpes son componentes (`StatsComponent`, `HitboxComponent`, `HurtboxComponent`) que se
  añaden como nodos hijos a cualquier entidad.
- **Máquinas de estados** (`StateMachine` + `State`) para el jugador (quieto, caminar,
  saltar, caer, atacar, muerto) y para el jefe. Cada estado decide su propia animación.
- **Comunicación desacoplada**:
  - de padre a hijo, con llamadas directas a métodos;
  - de hijo a padre, con señales;
  - entre sistemas globales, con un **bus de eventos** (`Events`, autoload). Por ejemplo,
    el jugador solo anuncia "recibí daño", y la cámara, las partículas, el sonido y el HUD
    reaccionan cada uno por su cuenta.
- **Capas de colisión estándar**: 1 Mundo, 2 Jugador, 3 Enemigos, 4 Proyectiles del
  jugador, 5 Objetos recogibles, 6 Peligros.
- Toda la física se ejecuta en `_physics_process` con `move_and_slide()`.

### Niveles generados desde texto
Los niveles no se dibujan a mano en el editor: cada uno es un archivo `.txt` donde **cada
carácter es una celda de 20×20 px** (`levels/sueno_1/*.txt`).

```
|....P..T.......................E.............T.H......|
##########################....##########################
```

| Símbolo | Significado | Símbolo | Significado |
|---|---|---|---|
| `#` | Suelo | `C` | Moneda de luz |
| `=` | Plataforma fina | `H` | Poción de vida |
| `-` | Plataforma one-way | `E` / `e` | Enemigo patrulla |
| `~` | Plataforma que cae | `D` | Demonio |
| `^` | Pinchos | `B` | Jefe (Cadejo) |
| `\|` | Muro | `G` / `A` | Reja de la arena / su activador |
| `P` | Inicio del jugador | `X` | Puerta o portal de salida |
| `T` | Antorcha | `K` | Altar de luz (checkpoint) |
| `1`–`9` | Diálogo | | |

Una cabecera con directivas (`@name`, `@win_condition`, `@next_level`, `@dialogue_1`…)
configura cada nivel. `PlatformGenerator.gd` se encarga de:

1. **Modelar la física del salto** a partir de los valores reales del jugador
   (velocidad 220 px/s, impulso −430 px/s, gravedad 1200 px/s²). Con eso calcula que
   la altura máxima es de unas 3,8 celdas y que el escalón seguro es de 3.
2. **Validar** con una búsqueda en anchura (BFS) que todas las plataformas y monedas
   sean alcanzables. Ningún nivel se publica con zonas imposibles.
3. **Construir** el nivel en Godot, fusionando las celdas contiguas en rectángulos
   grandes (*greedy meshing*) para usar pocas colisiones.

`TextLevel.gd` carga el `.txt` al iniciar la escena. `TerrainRenderer.gd` dibuja el suelo
celda a celda (*autotile*): cada celda elige su pieza según sus vecinas, así que colinas,
escalones y fosos forman un terreno continuo, sin costuras. `PlatformSkinner.gd` viste el
resto (plataformas finas, tablones y muros). Para cambiar un nivel basta con editar el texto.

**Diseño de los niveles.** Cada nivel se divide en tramos con un propósito, siguiendo un
ciclo de *enseñar → practicar → poner a prueba*: cada peligro aparece primero donde no
puede matar (espinas de 2 celdas, hielo frágil sobre suelo firme) y después sobre el
vacío. Hay descansos y altares de luz antes de cada reto, y la dificultad sube en dientes
de sierra. Todas las medidas salen del salto real (sube 3 celdas como mucho; huecos de 5
celdas o menos). Cada `.txt` empieza con comentarios (`//`) que describen sus tramos y una
regla de columnas para ubicarse en la grilla.

### Animación independiente del arte
`CharacterAnimator` + `AnimationSet` (`.tres`) separan la lógica de la animación del
dibujo: los estados piden "caminar" o "atacar", y el animador elige los frames, gestiona
prioridades y animaciones de una sola vez, y emite señales en frames concretos (por
ejemplo, el momento exacto del golpe). Si falta el arte, el personaje se dibuja con un
rectángulo de color y el juego sigue funcionando.

### Arte y sonido
- **Emma** y el orbe de la pulsera: generados con SpriteCook. Los frames de respiración
  (`emma_idle.png`) se derivan del frame quieto moviendo píxeles a mano.
  La carrera (`emma_run.png`) se animó con PixelLab a partir de un frame de Emma y se
  limpió por código (estela y píxeles sueltos).
- **El Cadejo**, la puerta-portal, la reja y los pinchos: generados con PixelLab.
- Tablones y algunas composiciones (el vórtice del portal): dibujados por código.
- Escenarios, enemigos, objetos y efectos: paquetes gratuitos de itch.io (ver
  [`CREDITS.md`](CREDITS.md)).
- Fuentes: BoldPixels (interfaz) y Alagard (título).

### Proceso
El desarrollo se organizó en **sprints** cortos, cada uno con un entregable concreto:
física base y bus de eventos → jugador → disparo → enemigos → objetos → ciclo del nivel →
máquinas de estados → componentes → cámara → ambientación → impacto visual → niveles 2 y
3 → jefe → victoria y cierre. Después de cada sprint, todos los scripts y escenas se
validaron en modo *headless* (sin ventana) junto con pruebas automáticas de regresión del
movimiento, el combate, el jefe, la cámara, los menús y los niveles. La lógica se
desarrolló con asistencia de IA (Claude Code).

---

## Estructura del proyecto

```
autoloads/    Sistemas globales: Events (bus), SceneTransition, GameSettings, AudioManager
components/   Componentes reutilizables: stats, hitbox/hurtbox, cámara, feedback,
              máquina de estados y sistema de animación
entities/     Jugador, enemigos, jefe (bosses/cadejo), proyectiles, objetos,
              elementos de nivel (puertas, pinchos, plataformas, antorchas, altares) y efectos
levels/       common/: generador, constructor y gestor de niveles, ambientación
              sueno_1/: escenas y .txt de los tres niveles del Sueño I
ui/           HUD, menús (inicio, principal, pausa, victoria) e historia
shaders/      Transición de escena y perspectiva del texto de la historia
assets/       Arte y fuentes por función: backgrounds, tiles, enemies, items, fx, level,
              ui, fonts, pixellab (Cadejo, puertas, pinchos), spritecook (Emma)
audio/        Música y efectos de sonido
```
