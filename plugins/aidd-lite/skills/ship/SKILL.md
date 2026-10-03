---
name: ship
description: Abre el PR de un corte de AIDD Lite directo a main, con el label aidd-lite, la plantilla de PR, el reporte del QA en navegador y una persona asignada para revisarlo. Úsala al final de /aidd-lite:build, en la misma sesión.
argument-hint: "[vacío]"
disable-model-invocation: true
---

# /aidd-lite:ship

Abres el PR. No lo apruebas ni lo mergeas. La revisión antes de mezclar es el único control humano de AIDD Lite: la hace cualquier persona del equipo distinta del autor, después de leer el código, la spec y el ADR si lo hay.

## Chequeos previos (si uno falla, para y dilo)

1. La rama empieza por `lite/`.
2. `git status` limpio y la rama al día con `origin/main`. Si hace falta rebase, vuelve a correr los tests después.
3. Tamaño ≤400 líneas, inserciones más borrados:
   `git -C "$(git rev-parse --show-toplevel)" diff --shortstat origin/main...HEAD -- . ':!*composer.lock' ':!*package-lock.json' ':!*yarn.lock' ':!vendor/*' ':!public/build/*' ':!docs/apps/*/lite/*' ':!docs/adrs/*'`
4. Los tests del corte pasan ahora mismo, incluidos los de `tests/Browser/` del corte. Córrelos otra vez y guarda el final de la salida para el cuerpo del PR.
5. Hay un veredicto vigente del subagente `revisor` y, si el corte tiene UI, del subagente `qa-navegador`, con las reglas de `/aidd-lite:build` para UI y vigencia. Si falta uno, porque se hizo `/clear` o hubo cambios después, pídelo ahora como en `/aidd-lite:build`.
6. ADR: `php "${CLAUDE_PLUGIN_ROOT}/scripts/necesita-adr.php"`. Si dice `ADR: requerido` y el ADR no está cubierto, con la regla de `/aidd-lite:build`, para y vuelve a `/aidd-lite:build`.

## Abrir el PR

1. `git push -u origin HEAD`.
2. Arma el cuerpo con `${CLAUDE_SKILL_DIR}/plantilla-pr.md` en un archivo temporal. Llena cada sección con datos reales y borra las que no apliquen.
   - Copia los hallazgos medios y bajos del revisor en "Pendientes del revisor", y la tabla y los hallazgos del QA en navegador en "QA en navegador".
   - Si el revisor o el QA terminaron en CAMBIOS REQUERIDOS después de 2 vueltas, o el QA en BLOQUEADO, pon al inicio del cuerpo `**Bloqueado:** <quién y motivo>` para que decida quien revise el PR.
   - Si la spec dice `po: sin validar`, pon al inicio `**Criterios sin validar por PO.**`
3. Título: `[<Módulo>] <qué cambia>`, por ejemplo `[Contravencional] Filtro por estado en comparendos`. No uses "Story" ni "Historia" con número, porque es la firma de BMAD en las métricas.
4. Quién revisa: cualquier persona del equipo distinta del autor. Pregúntale a la persona a quién asignarlo; si no tiene preferencia, su compañero de squad. Si el cambio trae ADR, tiene que ser alguien de otra squad: díselo al preguntar y agrega el label `adr`.
5. Crea el PR:
   `gh pr create --base main --label aidd-lite [--label adr] --title "<título>" --body-file <archivo> --reviewer <usuario>`
   Si un label no existe, avisa al usuario. Créalo con `gh label create aidd-lite --description "Flujo AIDD Lite"` o `gh label create adr --description "Trae un ADR"` solo si el usuario lo confirma.

## Cierre

Responde en 5 líneas: URL del PR, quién lo revisa, tamaño, si lleva ADR y el veredicto del QA en navegador.

Si es el último corte de la spec, recuerda crear en Tareas v2 la tarea de QA humano de la feature completa, ligada al hito, con el entorno donde se va a probar antes de liberarla o encender el flag.

Recuerda pegar la URL del PR en el campo `PR` de la tarea de este corte en Notion; así se vincula la tarea con el PR en las métricas.
