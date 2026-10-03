---
name: build
description: Implementa UN corte de una spec de AIDD Lite, o un cambio de una frase, con tests primero (incluidos los de navegador), verificación ejecutable, revisión del subagente revisor y QA en navegador del subagente qa-navegador antes de abrir PR. Úsala en una sesión nueva por cada corte.
argument-hint: "[ruta de la spec] [c<N>] o \"<cambio en una frase>\""
disable-model-invocation: true
---

# /aidd-lite:build

Entrada: $ARGUMENTS

Construyes **un solo corte** y dejas la rama lista para PR. Al terminar, el siguiente paso es `/aidd-lite:ship` en esta misma sesión. El corte siguiente va en una sesión nueva.

## Reglas

- No te autoapruebas. "Listo" significa: tests del corte en verde con la salida a la vista, ≤400 líneas, veredicto del subagente `revisor` y, si el corte tiene UI, veredicto del subagente `qa-navegador`.
- El corte tiene UI si la spec lo marca `UI: sí` o si el diff toca `resources/`, `lang/`, `routes/web.php` o una ruta con `/Filament/` o `/Livewire/`.
- Un veredicto del `revisor` o del `qa-navegador` vale mientras no haya commits con cambios del corte después de él. Un rebase sin conflictos no lo invalida.
- Muestra evidencia, no afirmaciones. Pega el final de la salida de cada comando de verificación.
- Nada de stubs, `TODO` ni código muerto para "después". Si algo no alcanza, se reduce el alcance y se anota en la spec.
- No cambies nada fuera de lo que pide el corte. Si ves otro problema, anótalo al final del reporte.
- Arreglos a producción no van por aquí: van por el flujo `hotfix/` del equipo.
- No uses los comandos BMAD ni modifiques sus archivos: `_bmad/` y los PRD, épicas, historias, tech-plans y `sprint-status` de `docs/apps/<app>/`. Lo único que AIDD Lite escribe ahí es `docs/apps/<app>/lite/`.
- Commits según el `CLAUDE.md` del repo, incluida su política de mensajes.
- Si una corrección falla dos veces seguidas, para y pide al usuario más contexto en vez de insistir.

## Pasos

1. **Orientarse.**
   - `git status` limpio y `git fetch origin`.
   - Con spec: si el archivo no está en tu copia, está en la rama del corte 1, donde la publicó `/aidd-lite:spec`: búscala con `git branch -r --list 'origin/lite/*-<slug>-c1'`, haz `git switch` a ella y léela ahí. Toma el primer corte sin marcar, o el que indique `c<N>`. Para los demás cortes, confirma que el anterior está mergeado y crea `lite/<modulo>-<slug>-c<N>` desde `origin/main`.
   - Con una frase: el corte es esa frase. Deduce el módulo de las rutas que vas a tocar y crea `lite/<modulo>-<slug>` desde `origin/main`.
   - Si la rama del corte ya tiene commits además del de la spec, es una sesión interrumpida: haz `git switch` a ella, lee `git log --oneline origin/main..HEAD` y `git diff origin/main...HEAD`, compáralo con los criterios del corte y sigue desde lo que falta.
   - El prefijo `lite/` es obligatorio. Es la firma con la que las métricas distinguen este flujo de BMAD.

2. **Plan corto.** Si el corte toca más de 3 archivos o tiene incertidumbre, escribe un plan de 5 a 10 líneas con archivos, orden y tests, y espera el OK del usuario antes de editar. Si el diff cabe en una frase, sigue directo.

3. **Tests primero.** Por cada criterio de aceptación del corte, escribe o ajusta el test Pest que lo verifica, córrelo y confirma que falla por la razón correcta. Imita los tests existentes del módulo.
   - Si el criterio es de tipo `navegador`, escribe además un test de navegador de Pest 4 en `tests/Browser/<Panel>/<Qué>Test.php` con el camino feliz de punta a punta: `visit()`, `click()`, `type()`, `press()`, `assertSee()` y `assertNoJavaScriptErrors()`. Las validaciones y los bordes siguen en tests de Livewire, que son más rápidos.
   - Córrelos con `./vendor/bin/pest tests/Browser/<ruta>`. Husky no los corre y en CI tienen su propio job.
   - Si `pestphp/pest-plugin-browser` no está en `composer.json`, no escribas tests de navegador y dilo en el reporte. El QA en navegador del paso 9 sigue igual.

4. **Implementa** siguiendo el patrón que nombra la spec. Busca el análogo en el módulo antes de inventar estructura. Si el corte deja comportamiento visible e incompleto y la spec no define flag, para y pregunta.

5. **Verifica.** Usa los comandos del `CLAUDE.md` del repo. Si no los define:
   - tests del corte: `./vendor/bin/pest <rutas de test>`;
   - formato: `./vendor/bin/pint --dirty`;
   - estático: `./vendor/bin/phpstan analyse <rutas cambiadas>`;
   - navegador, si el corte tiene tests en `tests/Browser/`: `./vendor/bin/pest <esas rutas>`.

6. **Commit.** Marca el corte como `[x]` en la spec e inclúyelo en el commit. Husky corre Pint, PHPStan y Pest; si falla, corrige y vuelve a intentar.

7. **Tamaño.** Inserciones más borrados, desde cualquier carpeta del repo:
   `git -C "$(git rev-parse --show-toplevel)" diff --shortstat origin/main...HEAD -- . ':!*composer.lock' ':!*package-lock.json' ':!*yarn.lock' ':!vendor/*' ':!public/build/*' ':!docs/apps/*/lite/*' ':!docs/adrs/*'`
   Si pasa de 400, para y propone cómo partir el corte.

   **ADR.** Corre `php "${CLAUDE_PLUGIN_ROOT}/scripts/necesita-adr.php"` sobre el diff. Lo decide la regla, no la persona.
   - Cubierto: el diff trae el ADR, o la spec tiene `adr:` y ese archivo ya está en `main` (`git cat-file -e origin/main:<ruta>`).
   - Falta: dice `ADR: requerido`, o `a criterio` y grep muestra que otros módulos usan lo que cambió, y no está cubierto. Para: un ADR imprevisto parte el corte. Propón un corte con solo el contrato, el ADR (`${CLAUDE_PLUGIN_ROOT}/skills/spec/plantilla-adr.md`, en `docs/adrs/` como dice `/aidd-lite:spec`) y sus tests, actualiza la spec y sigue con ese.

8. **Revisión independiente.** Delega al subagente `revisor` de este plugin (aparece como `aidd-lite:revisor`). Pásale solo una línea, sin tu resumen:
   `spec: <ruta> · corte: C<N> · base: origin/main` o, para una frase, `cambio: "<frase>" · base: origin/main`.
   Espera su veredicto sin editar archivos mientras corre los tests. Corrige los hallazgos altos, haz commit y pide otra revisión. Máximo 2 vueltas. Los hallazgos medios y bajos no bloquean: guárdalos para el cuerpo del PR.
   Si tras 2 vueltas sigue en CAMBIOS REQUERIDOS, no insistas: el PR se abre marcado como bloqueado y decide quien lo revise.

9. **QA en navegador,** solo si el corte tiene UI.
   - `city.test` sirve la carpeta del clon. En un worktree no sirve tu rama: díselo a la persona y haz el QA desde el clon.
   - Chequeo de entorno antes de tocar la base: `php artisan tinker --execute "require '${CLAUDE_PLUGIN_ROOT}/scripts/entorno-qa.php';"`. Si no imprime `ENTORNO: local`, no migres ni delegues: dile a la persona el motivo y cómo resolverlo (https://github.com/SensoriaCity/aidd-lite/blob/main/docs/qa-navegador.md).
   - Prepara la app: `php artisan migrate` (nunca `migrate:fresh`) y, si el diff toca `resources/` o una ruta con `/Filament/` o `/Livewire/`, `npm run build`.
   - Delega al subagente `aidd-lite:qa-navegador` con una sola línea, sin tu resumen: `spec: <ruta> · corte: C<N> · url: <URL que imprimió el chequeo>` o `cambio: "<frase>" · url: <URL>`.
   - Corrige los hallazgos altos, haz commit y pide otra pasada. Máximo 2 vueltas. Si las correcciones cambian más que unas líneas, pide también otra vuelta al `revisor`.
   - BLOQUEADO no es aprobado. Si la causa es local (credenciales, migración, Chrome), resuélvela con la persona y repite. Si no, anótalo para el PR.

10. **Reporte** en máximo 7 líneas: corte, archivos, evidencia de tests, líneas cambiadas, ADR sí o no, veredictos del revisor y del QA en navegador con hallazgos pendientes, y el siguiente paso: `/aidd-lite:ship` en esta sesión.
