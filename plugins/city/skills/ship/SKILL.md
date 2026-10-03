---
name: ship
description: Abre el PR de la funcionalidad construida con /city:build, con la plantilla del repo y el label de .city.json, y lo deja en auto-merge por squash. Antes comprueba rama, árbol, tamaño, pruebas, veredictos vigentes del revisor y del evaluador, y la evidencia de passes. Úsala al final de /city:build, en la misma sesión.
argument-hint: "(sin argumentos)"
disable-model-invocation: true
---

# /city:ship

Abres el PR y activas el auto-merge. No apruebas ni mergeas a mano: el PR entra solo cuando pasan los checks requeridos. Si CODEOWNERS lo retiene, lo lee una persona.

## Configuración

Lee `.city.json` en la raíz del repo (`git rev-parse --show-toplevel`). Si no existe, detente y dilo: el kit no sabe nada del stack y no adivina comandos. De ahí salen los comandos (`tests`, `qa`), las rutas (`features`, `evidencia_dir`, `adr_dir`), el prefijo de rama (`ramas`), el `label`, los `codeowners_paths` y el tope (`tope_lineas`). Su contrato está en `${CLAUDE_PLUGIN_ROOT}/city.schema.json`. Para lo propio de la máquina (puertos, versiones, servidores locales, cómo bajar una instalación), ver `docs/harness/entorno.md` del repo si existe; no lo supongas.

## Chequeos (si uno falla, detente y dilo)

1. **Rama.** Empieza por `ramas`. El id de la funcionalidad es lo que sigue a la fecha.
2. **Árbol limpio y al día.** `git status --porcelain` vacío, `git fetch origin` y `git merge-base --is-ancestor origin/main HEAD`. Si no está al día: `git rebase origin/main` si la rama aún no está en `origin`, o `git merge origin/main` si ya está (nunca `push --force`). Con conflictos, detente. Después, vuelve a correr las pruebas.
3. **Tamaño:** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/tamano.sh"`. Si sale con 1, detente y propón cómo partir.
4. **Pruebas en verde ahora mismo.** Corre otra vez, literales, los comandos de `tests` que aplican al corte, con la regla de `/city:build`: un comando que no existe en el repo se anota y no se reemplaza. Guarda el final de cada salida para el PR.
5. **Veredictos vigentes** del subagente `city:revisor`; del `city:seguridad`, si el diff toca su superficie; y del `city:evaluador`. Vigente es sin commits con cambios de código después de él; un rebase o merge de `origin/main` sin conflictos no lo invalida. Si falta uno (hubo `/clear`, es otra sesión o hubo cambios después), repítelo ahora como en los pasos 9 y 10 de `/city:build`, con sus 2 vueltas.
6. **passes con evidencia.** `git diff origin/main...HEAD -- <features>`. Si una funcionalidad pasa a `"passes": true`, debe ser la de esta rama y debe existir en la rama `<evidencia_dir>/<id>.md` con el encabezado `# Evidencia · <id> · …` y la última línea `VEREDICTO: pasa`, lo mismo que exige `scripts/passes.sh`. Si no, detente: `passes` solo cambia con la evidencia del evaluador.
7. **ADR.** La regla del paso 8 de `/city:build`. Si falta, detente y vuelve a `/city:build`.

## Abrir el PR

1. `git push -u origin HEAD`.
2. **Cuerpo.** Usa `.github/PULL_REQUEST_TEMPLATE.md` del repo si existe; si no, `${CLAUDE_SKILL_DIR}/plantilla-pr.md`. Llénalo en un archivo temporal fuera del repo, con datos reales; borra lo que no aplique y no dejes comentarios de la plantilla sin responder. Si la plantilla no las trae, agrega al final:
   - "Decisiones del ejecutor": las que tomó `/city:build`, qué y por qué, o "ninguna".
   - "Evidencia": el final de la salida del chequeo 4 y del tamaño.
   - "Veredictos": revisor, seguridad y evaluador, vueltas y pendientes `debería` y `sugerencia`.
   Si alguno quedó en rojo tras 2 vueltas, la primera línea del cuerpo es `**Bloqueado:** <quién y motivo>`.
3. **Título:** Conventional Commit en español, `feat(<ámbito>): <qué cambia>`. Si el repo versiona por título del PR, el tipo define la versión.
4. `gh pr create --base main --label <label> --title "<título>" --body-file <archivo>`. Si el label no existe, dilo; créalo solo si la persona lo confirma.
5. **Bitácora.** Si el repo tiene `PROGRESO.md` en la raíz, escribe la entrada con su formato y en la ruta que indica, con el número del PR; commit `docs(<ámbito>): bitácora de <id>` y push a la misma rama. Si no existe, no hay bitácora.
6. **Auto-merge:** `gh pr merge <n> --auto --squash`, salvo que el PR nazca bloqueado. Si el repo no permite auto-merge, dilo; no mergees a mano.
7. **CODEOWNERS.** `gh pr view <n> --json files,reviewRequests`. Si un archivo del PR coincide con un patrón de `codeowners_paths`, el PR queda retenido hasta que lo apruebe una persona: di qué archivos y a quién, según `reviewRequests` o el archivo CODEOWNERS del repo (`.github/`, raíz o `docs/`).

## Cierre

Responde en 5 líneas:
1. PR: URL y título.
2. Tamaño y ADR.
3. Revisor y evaluador: veredictos; `passes` y su evidencia, si cambió.
4. Merge: auto-merge activo, bloqueado (motivo) o retenido por CODEOWNERS (archivos y a quién).
5. Bitácora: ruta de la entrada, o "sin bitácora".
