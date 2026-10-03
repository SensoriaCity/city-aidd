# aidd-lite

Repo del kit AIDD Lite: un plugin de Claude Code en `plugins/aidd-lite/`, su marketplace en `.claude-plugin/marketplace.json` y la documentación del método y del piloto en `docs/`. El código que construyen las squads vive en `SensoriaCity/city`, no aquí.

## Reglas para cambiar el kit

- Todo en español. Nombres de archivos, comandos y rutas en backticks.
- Durante el piloto entra máximo un cambio de comportamiento por semana. Cada cambio sube la versión en `plugins/aidd-lite/.claude-plugin/plugin.json` y agrega una línea en `CHANGELOG.md` con fecha y motivo, enlazando la entrada de `piloto/bitacora.md` que lo pidió.
- Una skill o regla nueva entra solo si la bitácora muestra el mismo tropiezo dos veces.
- Cada `SKILL.md` se queda por debajo de 120 líneas. Lo que no quepa va a un archivo de apoyo en la misma carpeta, referenciado con `${CLAUDE_SKILL_DIR}`.
- Las skills llevan `disable-model-invocation: true`: las invoca la persona, no el modelo.
- No hay roles: ninguna skill distingue senior, junior ni TL. El único control humano es la revisión del PR por alguien distinto del autor.
- El mapa de módulos de `plugins/aidd-lite/scripts/necesita-adr.php` es copia de `config/modules.yaml` de `aidd-metrics`. Si cambia uno, se cambia el otro. El mapa de migraciones por nombre de archivo y la herencia de módulo son propios del script.
- Los agentes `revisor` y `qa-navegador` no tienen herramientas de edición y no se les agregan. Su Bash no está restringido por el runtime, así que sus límites viven en el prompt: el revisor solo lee y corre tests; el QA solo prueba en un entorno local y nunca borra datos.
- La versión de `@playwright/mcp` va fija en `plugins/aidd-lite/.mcp.json`. Subirla es un cambio de comportamiento del kit. Si cambia el nombre del servidor (`playwright`), cambian los nombres de sus herramientas: hay que actualizar `tools` de `qa-navegador.md` y la regla de permisos de `docs/qa-navegador.md`.
- Los agentes de un plugin ignoran `mcpServers`, `hooks` y `permissionMode` en su frontmatter. Por eso el servidor de Playwright va en `.mcp.json` del plugin y no en el agente.
- `qa-navegador` lista sus herramientas de Playwright una por una, sin comodín: `browser_run_code_unsafe` y `browser_evaluate` ejecutan código arbitrario y no se le dan. Antes de tocar la base, `build` y el agente corren `scripts/entorno-qa.php`.
- El comando de tamaño es el mismo en `build`, `ship` y `revisor`. `validar.sh` falla si difieren.
- Nada del kit usa los comandos BMAD ni modifica `_bmad/` o los archivos BMAD de `docs/apps/<app>/`. La skill `spec` puede leer el PRD y el tech-plan de la app como contexto y escribe solo en `docs/apps/<app>/lite/`.
- La firma del flujo (rama `lite/`, label `aidd-lite`, specs en `docs/apps/<app>/lite/`) no cambia sin actualizar `docs/integracion-aidd-metrics.md`, `scripts/numeros.py` y la config de `aidd-metrics`.

## Verificar

```bash
./scripts/validar.sh
```

Corre `claude plugin validate --strict` sobre el marketplace, el plugin y sus skills, revisa frontmatter, tamaño, que los agentes no editen, archivos referenciados, que el comando de tamaño coincida en los tres archivos, el `.mcp.json` y las herramientas del QA, que la regla de ADR responda bien a siete casos y que la versión tenga entrada en el changelog.

Para probar un cambio en `city` sin instalar, desde el clon de `city`:

```bash
claude --plugin-dir ~/Projects/aidd-lite/plugins/aidd-lite
```
