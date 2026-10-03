---
name: spec
description: Entrevista a quien pide el cambio y escribe una spec de una página, que es un hito, con criterios verificables y cortes en vertical slices de ≤400 líneas. Decide si hace falta un ADR. Reemplaza la cadena PRD → arquitectura → épicas → historias de BMAD. Úsala antes de construir cualquier cambio que no quepa en una frase.
argument-hint: "[idea, enlace a la tarea de Notion o número de issue]"
disable-model-invocation: true
---

# /aidd-lite:spec

Vas a producir **una spec de una página** para este pedido: $ARGUMENTS

La spec es el único documento de planeación de AIDD Lite. La lee quien construya el corte, que puede ser otra persona en otra máquina, un subagente revisor que no vio esta conversación y quien revise el PR. Tiene que bastar sola. En AIDD Lite no hay roles: cualquier persona del equipo corre cualquier skill, y el único control humano es la revisión del PR antes de mezclar.

## Reglas

- No escribas código de implementación. Solo la spec y, si hace falta, el ADR.
- Si el cambio se puede describir en una frase, no hace falta spec. Dilo, recomienda `/aidd-lite:build "<la frase>"` y termina.
- Si es un arreglo a producción, no va por AIDD Lite: va por el flujo `hotfix/` del equipo. Dilo y termina.
- Máximo ~80 líneas. Si no cabe, el alcance es grande: pártelo en dos specs y dilo.
- No uses los comandos BMAD de `.claude/commands/` ni modifiques `_bmad/` ni los PRD, épicas, historias, tech-plans y `sprint-status` de `docs/apps/<app>/`. Puedes leerlos como contexto. Lo único que escribes ahí es `docs/apps/<app>/lite/`.
- Sigue el `CLAUDE.md` del repo en todo lo que no contradiga esta skill.

## Pasos

1. **Entiende antes de preguntar.** Con un subagente de exploración, para no llenar este contexto:
   - ubica la carpeta de la app en `docs/apps/` (nombres en inglés kebab, por ejemplo `photo-ticket`) y lee su PRD y su tech-plan si existen. Son contexto de negocio: si contradicen el código, manda el código y lo anotas en Riesgos;
   - explora el código del módulo: recursos de Filament, modelos, acciones y tests análogos;
   - anota las rutas de uno a tres ejemplos a imitar y cómo se maneja hoy un feature flag en el repo, si existe.

2. **Entrevista.** Usa AskUserQuestion, máximo dos rondas de hasta 4 preguntas. Pregunta solo lo que el código no responde:
   - para quién es y qué problema resuelve;
   - cómo sabremos que funciona, con un resultado observable;
   - qué queda fuera;
   - riesgos de datos existentes, permisos y roles, migraciones e integraciones externas;
   - si necesita feature flag hasta terminar todos los cortes;
   - qué criterios son flujos que el usuario hace en pantalla;
   - si es una feature de usuario, si el PO está en la entrevista o ya validó los criterios. Si no, la spec queda con `po: sin validar` y el PR lo dirá.

3. **Escribe la spec** con la plantilla `${CLAUDE_SKILL_DIR}/plantilla-spec.md` en `docs/apps/<app>/lite/<AAAA-MM-DD>-<slug>.md`. Si la app no tiene carpeta en `docs/apps/`, créala con el mismo patrón de nombre.
   - El slug no puede contener `story`, `stories`, `epic`, `prd`, `tech-plan` ni `sprint-status`, porque esas palabras en `docs/apps/` son la firma de BMAD en las métricas.
   - `<modulo>`, para la rama y el título del PR, es uno de: `shared`, `contravencional`, `movilidad`, `fotodeteccion`, `billetera-digital`, `tramites`, `archivo-digital`, `gestion-cartera`, `recuperacion-cartera`, `herramientas`, `paraderos-inteligentes`, `alumbrado-publico`, `seguridad`, `pqrs`, `pmt`, `sensor-ia`, `zep`, `zer`, `operativos`, `pantallas`, `autocheck`. Si el cambio no es de ningún módulo, `plataforma`.
   - Cada criterio de aceptación se verifica con un test Pest. Si es un flujo en pantalla, su tipo es `navegador`: lleva además un test de navegador y lo prueba el subagente `qa-navegador`. Cada corte con UI se marca `UI: sí`. QA humano no prueba cortes: prueba la feature completa antes de liberarla o de encender el flag.
   - Cada corte es un vertical slice: un comportamiento pequeño que se puede ejecutar de punta a punta y atraviesa las capas que necesite (migración, modelo, acción, recurso de Filament, test). No se corta por capas: "C1 solo migraciones" no es un corte. La única excepción es el corte 1 de una spec con ADR (paso 4).
   - Cada corte se puede mergear solo a `main` sin romper nada y cabe en ≤400 líneas cambiadas, contadas como en `/aidd-lite:build`. `main` se libera a producción a discreción, así que si un corte deja algo a medias visible para el usuario, la spec define un flag y ese corte va detrás de él.
   - En "Diseño" nombra archivos e interfaces. No pegues código.

4. **Decide si hace falta ADR.** No lo decide la persona: corre con las rutas que la spec planea tocar
   `php "${CLAUDE_PLUGIN_ROOT}/scripts/necesita-adr.php" <ruta> <ruta> …`
   - `ADR: requerido`: escribe el ADR.
   - `ADR: a criterio`: decide tú. Busca con grep si otros módulos usan lo que el cambio toca (modelo, tabla, clase, config, ruta). En una migración, busca qué modelos usan la tabla y de qué módulos son. Si otros lo usan y su comportamiento cambia, escribe el ADR.
   - `ADR: no requerido`: no hay ADR.
   Anota el veredicto y el motivo en "Diseño". El ADR usa `${CLAUDE_SKILL_DIR}/plantilla-adr.md`, va en `docs/adrs/ADR-<NNN>-<slug>.md` con el número siguiente al mayor de `git ls-tree --name-only origin/main docs/adrs/`, lleva su fila en el índice de `docs/adrs/README.md` y tiene máximo ~30 líneas. Enlázalo en el campo `adr` de la spec. Se aprueba al aprobar el PR del corte 1.
   Con ADR, el corte 1 lleva solo el cambio de contrato (lo que otros módulos usan: clase, tabla, config, ruta o evento), el ADR y sus tests, y su PR lo revisa alguien de otra squad. Lo que usa el contrato nuevo va del corte 2 en adelante.

5. **Revisa la spec contra esta lista** antes de mostrarla:
   - ¿Alguien que no estuvo aquí sabe qué construir en el corte 1?
   - ¿Cada criterio tiene su verificación? ¿Los de tipo `navegador` dicen qué ve el usuario al terminar?
   - ¿Algún corte pasa de 400 líneas? Pártelo.
   - ¿Hay algo en alcance que nadie pidió? Sácalo.

6. **Confirma.** Muestra un resumen de 5 líneas (problema, cortes, ADR sí o no, PO validó o no, riesgos) y la ruta del archivo. Ajusta lo que la persona corrija. No es una aprobación: la revisión humana ocurre al mezclar el PR.

7. **Publica la spec,** sin abrir PR, para que cualquiera pueda construir:
   ```bash
   git fetch origin
   git switch -c lite/<modulo>-<slug>-c1 origin/main
   git add docs/apps/<app>/lite/<archivo>.md   # y el ADR, si lo hay
   git commit -m "<mensaje según el CLAUDE.md del repo>"
   git push -u origin HEAD
   ```
   La spec y el ADR entran a `main` con el PR del corte 1, y quien lo revise los aprueba junto con el código. El corte 2 empieza cuando el 1 está mergeado.

8. **Cierra** con:
   - el recordatorio de crear el hito en Hitos v2 para esta spec y una tarea en Tareas v2 por cada corte, ligada al hito; cada tarea guarda un solo PR;
   - el comando para construir, en una sesión nueva: `/aidd-lite:build docs/apps/<app>/lite/<archivo>.md`.
