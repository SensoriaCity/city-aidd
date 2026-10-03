# Convivencia con BMAD

BMAD sigue igual en `city` mientras dura la prueba. AIDD Lite no lee, no usa y no modifica nada de BMAD. La idea es comparar los dos flujos en el mismo periodo, con squads distintas, antes de decidir.

## Qué no se toca en `city`

- `_bmad/` y los comandos de `.claude/commands/`: analyst, architect, pm, create-story, dev-story, qa, quick-dev, hito-writer.
- Los PRD, tech-plans, épicas, historias y `sprint-status` de `docs/apps/<app>/`. La skill `spec` los puede leer como contexto, sin modificarlos.
- El `CLAUDE.md` raíz y `.claude/settings.json`.
- Las ramas `hito/*` y `tarea/*` y su flujo apilado.
- Los revisores de GitHub, CodeRabbit y Claude Code Review.

Lo que AIDD Lite agrega al repo son las specs en `docs/apps/<app>/lite/`, los PRs con rama `lite/` y label `aidd-lite`, y los tests de navegador en `tests/Browser/` con su PR de setup (ver `qa-navegador.md`). Ese setup no cambia nada para las squads BMAD: Husky y los shards de CI no corren `tests/Browser/`, y su job de CI no bloquea el merge durante el piloto. El plugin, con su servidor de Playwright, vive en la máquina de cada dev del piloto.

## Equivalencias

| BMAD | AIDD Lite |
|---|---|
| analyst + pm → PRD | `/aidd-lite:spec`: entrevista y spec de una página |
| architect → tech-plan | Sección "Diseño" de la spec: archivos, interfaces y patrón a imitar. Si el cambio toca algo compartido, un ADR corto que pide la regla y se aprueba con el PR |
| sm → épicas, historias, `sprint-status` | Cortes en vertical slices dentro de la spec; en Notion la spec es un hito y cada corte una tarea |
| dev-story | `/aidd-lite:build`, un corte por sesión |
| quick-dev | `/aidd-lite:build "<cambio en una frase>"` |
| qa / tea | Tests Pest primero, también de navegador; subagente `revisor`; subagente `qa-navegador` en `city.test`; revisión humana del PR. QA humano prueba la feature completa |
| PR `tarea/* → hito/*`, luego `hito/* → main` | Un PR por corte directo a `main`; lo incompleto va detrás de un flag |

## Reglas para no contaminar la comparación

1. **Un PR es de un solo flujo.** En una rama `lite/` no se usan comandos BMAD, y en ramas `hito/*` o `tarea/*` no se usan las skills ni el revisor de AIDD Lite.
2. **Trabajo en curso.** Si la squad piloto tiene un hito BMAD a medias al arrancar, lo termina en BMAD. Todo trabajo nuevo desde la semana 1 entra por AIDD Lite.
3. **Si algo no cabe en AIDD Lite,** la squad no vuelve a BMAD en silencio. Lo anota en `piloto/bitacora.md` con el motivo, y el CTO decide si ese trabajo sale del piloto.
4. **Títulos.** Los PRs de AIDD Lite no usan "Story" ni "Historia" con número, porque es la firma de BMAD en `aidd-metrics`.
5. **Specs en su subcarpeta.** Las specs van en `docs/apps/<app>/lite/`, con un slug sin `story`, `epic`, `prd`, `tech-plan` ni `sprint-status`. Un PR que modifica archivos BMAD de `docs/apps/<app>/` queda clasificado como BMAD aunque tenga rama `lite/`.
6. **Hotfix aparte.** Los arreglos a producción van por `hotfix/`, en los dos flujos.

## Salida de emergencia

Si el piloto no funciona, cada dev corre `claude plugin uninstall aidd-lite@sensoria --scope local` y la squad vuelve a BMAD. Las specs de `docs/apps/<app>/lite/` se quedan como documentación de lo que se construyó.
