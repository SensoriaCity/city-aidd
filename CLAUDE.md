# city-aidd

Repo del plugin `city` de Claude Code en `plugins/city/`, su marketplace en `.claude-plugin/marketplace.json` y la documentación del método y de la adopción en `docs/`. El código que construyen las squads vive en `SensoriaCity/city` y `SensoriaCity/city-v2`, no aquí.

## Reglas para cambiar el kit

- Todo en español. Nombres de archivos, comandos y rutas en backticks.
- Durante la adopción entra máximo un cambio de comportamiento por semana. Cada cambio sube la versión en `plugins/city/.claude-plugin/plugin.json` y agrega una línea en `CHANGELOG.md` bajo `## city <versión> · <fecha>`, con el motivo y la entrada de `bitacora.md` que lo pidió.
- Una skill o regla nueva entra solo si la bitácora muestra el mismo tropiezo dos veces.
- Cada `SKILL.md` se queda por debajo de 120 líneas. Lo que no quepa va a un archivo de apoyo en la misma carpeta, referenciado con `${CLAUDE_SKILL_DIR}`.
- Las skills llevan `disable-model-invocation: true`: las invoca la persona, no el modelo. La única excepción es `revisar`, que corre en GitHub Actions sin persona; no pasa de 60 líneas, lee del PR solo rama, base y título, y delega al revisor con una sola línea.
- No hay roles: ninguna skill distingue senior, junior ni TL. El control humano está en `/city:check`, en la feature completa antes del flag, en la retro y en los PR que retiene CODEOWNERS.
- El kit no sabe nada del stack: todo lo que ejecuta o lee sale de `.city.json`, cuyo contrato es `plugins/city/city.schema.json`. `validar.sh` falla si una skill o agente nombra un comando de un stack o no lee `.city.json`.
- Los agentes `revisor`, `seguridad` y `evaluador` no tienen herramientas de edición y no se les agregan. Su Bash no está restringido por el runtime, así que sus límites viven en el prompt: el revisor y seguridad solo leen y corren pruebas; el evaluador solo prueba en una instalación local, nunca reinicia la base ni borra volúmenes, y escribe solo en su `mktemp -d`.
- `passes` cambia solo con `plugins/city/scripts/passes.sh`, que exige la evidencia del evaluador con `VEREDICTO: pasa`. Nada del kit lo cambia de otra forma.
- El tamaño se mide solo con `plugins/city/scripts/tamano.sh`. `validar.sh` falla si una skill o agente usa otro comando.
- La versión de `@playwright/mcp` va fija en `plugins/city/.mcp.json`. Subirla es un cambio de comportamiento del kit y pide agregar su lista de herramientas a `validar.sh`. Si cambia el nombre del servidor (`playwright`), cambian los nombres de sus herramientas: hay que actualizar `tools` de `evaluador.md`.
- Los agentes de un plugin ignoran `mcpServers`, `hooks` y `permissionMode` en su frontmatter. Por eso el servidor de Playwright va en `.mcp.json` del plugin y el hook de dependencias en `hooks/hooks.json`.
- `evaluador` lista sus herramientas de Playwright una por una, sin comodín: `browser_run_code_unsafe` y `browser_evaluate` ejecutan código arbitrario y no se le dan. Antes de tocar nada, corre `scripts/entorno-qa.py`.
- Nada del kit usa los comandos BMAD ni modifica `_bmad/` o los archivos BMAD de `docs/apps/<app>/` de `city`.
- La firma del flujo (rama con el prefijo `ramas` de `.city.json`, label `city`) no cambia sin actualizar `docs/integracion-aidd-metrics.md`, `scripts/numeros.py` y la config de `aidd-metrics`.

## Verificar

```bash
./scripts/validar.sh
```

Corre `claude plugin validate --strict` sobre el marketplace, el plugin y sus skills; revisa frontmatter, tamaño, que los agentes no editen, archivos referenciados, el `.mcp.json` y las herramientas del evaluador, que la versión tenga entrada en el changelog, que el kit no nombre el stack, `tamano.sh`, `passes.sh` y `entorno-qa.py` en un repo de prueba, la prueba del hook de dependencias, y ShellCheck y la prueba en seco de `goal.sh` (necesita `shellcheck`).

Para probar un cambio en un repo sin instalar, desde su clon:

```bash
claude --plugin-dir ~/Projects/city-aidd/plugins/city
```
