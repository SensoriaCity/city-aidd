# aidd-lite

Kit para probar en `city` una forma liviana de desarrollar con Claude Code, al lado de BMAD y sin tocarlo. Es un plugin de Claude Code más un plan de piloto medido con `aidd-metrics`.

## Qué trae

| Skill o agente | Quién lo usa | Qué hace |
|---|---|---|
| `/aidd-lite:spec` | Cualquiera | Entrevista y spec de una página con criterios verificables y cortes de ≤400 líneas; decide si hace falta ADR y la publica en la rama del corte 1 |
| `/aidd-lite:build` | Cualquiera | Implementa un corte con tests primero (también de navegador), hace commit, controla tamaño y ADR, y pasa por el revisor y por el QA en navegador |
| `/aidd-lite:ship` | Cualquiera | Abre el PR a `main` con label `aidd-lite`, la plantilla, el reporte del QA y otra persona asignada para revisarlo |
| `aidd-lite:revisor` | Lo invocan build y ship | Revisor escéptico en contexto limpio; bloquea solo por hallazgos altos |
| `aidd-lite:qa-navegador` | Lo invocan build y ship en cortes con UI | Prueba el corte en `city.test` con Playwright como lo haría un usuario y deja evidencia para el PR |

## Empezar

1. Leer `docs/metodo.md`.
2. Seguir la semana 0 de `docs/piloto.md`.
3. En `aidd-metrics`, aplicar `docs/integracion-aidd-metrics.md`.
4. Para el QA en navegador, seguir `docs/qa-navegador.md`: un PR de setup en `city` y una configuración por dev.

Instalación para un dev del piloto, desde su clon de `city`:

```bash
claude plugin marketplace add SensoriaCity/city-aidd
claude plugin install aidd-lite@sensoria --scope local
```

Para probarlo antes de publicar el repo, con la ruta local:

```bash
claude plugin marketplace add ~/Projects/city-aidd
claude plugin install aidd-lite@sensoria --scope local
```

## Estructura

```
.claude-plugin/marketplace.json     marketplace "sensoria" con un plugin
plugins/aidd-lite/
  .claude-plugin/plugin.json        versión del kit
  .mcp.json                         servidor de Playwright, con versión fija, para el agente QA
  skills/spec/                      SKILL.md + plantilla-spec.md + plantilla-adr.md
  skills/build/                     SKILL.md
  skills/ship/                      SKILL.md + plantilla-pr.md
  agents/revisor.md                 subagente revisor
  agents/qa-navegador.md            subagente de QA en navegador
  scripts/necesita-adr.php          regla que decide si un cambio necesita ADR
  scripts/entorno-qa.php            confirma que la app que prueba el agente QA es local
docs/
  metodo.md                         el método: ciclo, roles, reglas y decisiones
  fundamentos.md                    DORA y Anthropic detrás de cada regla
  coexistencia-bmad.md              qué no se toca y cómo no contaminar la comparación
  piloto.md                         semana 0, rituales, criterios de decisión y retro
  integracion-aidd-metrics.md       firma liviano y evento del piloto
  qa-navegador.md                   setup en city, configuración por dev y límites del QA en navegador
piloto/bitacora.md                  registro semanal de las squads
scripts/numeros.py                  números del piloto desde GitHub, sin esperar al dashboard
scripts/validar.sh                  valida el kit antes de publicar un cambio
CHANGELOG.md                        un cambio por semana durante el piloto
```

## Mantener el kit

Ver `CLAUDE.md`. Antes de publicar cualquier cambio: `./scripts/validar.sh`.
