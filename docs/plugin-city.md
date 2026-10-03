# Plugin `city` · el flujo de desarrollo con agentes para todo Sensoria

Diseño del kit que reemplaza a aidd-lite y sirve a `city` (Filament) y a
`city-v2` (Laravel + React) con un solo juego de comandos. Decidido con Belmar
el 2026-10-03; la decisión de arquitectura del lado de city-v2 es su
ADR-0031. Lo que sigue describe el kit versión 1.0; se implementa en el orden
de "Adopción".

## Qué cambia frente a aidd-lite

| aidd-lite 0.2 | `city` 1.0 | Por qué |
|---|---|---|
| Una persona aprueba cada PR (regla 7) | El PR se mergea solo cuando pasan los checks; la persona lee la feature completa antes del flag y los PR que CODEOWNERS retiene | El control humano por PR era el cuello; Anthropic: supervisar por excepción con el perímetro puesto |
| `build` prueba y el QA opina | `passes` solo cambia con la evidencia del agente `evaluador` (`scripts/passes.sh`); el que construye nunca se califica | *Harness design*: el generador aprueba stubs; un evaluador aparte sí se calibra |
| `revisor` y `qa` corren dentro de la sesión de build | Corren además como checks de CI, con el diff y la spec, nunca con la prosa del PR | *Auto mode*: al clasificador se le quita la prosa del asistente para que no lo convenza |
| Hooks y permisos como freno | Sandbox (FS = worktree, red = `github.com`) + ruleset + CODEOWNERS + token acotado; el hook es segunda capa | *How we contain Claude*: entorno primero, modelo después |
| Una sesión por corte, a mano | `/city:goal` encadena cortes y PR hasta cerrar la spec o parar | Objetivo → automático → comprobación corta |
| Rama `lite/`, label `aidd-lite` | Rama `city/`, label `city` | Firma nueva para `aidd-metrics`; la vieja sigue valiendo para el histórico |

Se conserva: spec de una página = hito, cortes verticales ≤400 líneas, tests
primero, regla de ADR por sistema, sin roles, flags para lo incompleto,
hotfix por su flujo, máximo un cambio al kit por semana, quitar piezas de a una.

## Estructura

```
plugins/city/
  .claude-plugin/plugin.json      versión del kit
  .mcp.json                       Playwright MCP, versión fija, para el evaluador
  skills/
    spec/      SKILL.md + plantilla-spec.md + plantilla-adr.md
    build/     SKILL.md
    ship/      SKILL.md + plantilla-pr.md
    goal/      SKILL.md             el bucle
    check/     SKILL.md + plantilla-cierre.md
    retro/     SKILL.md             números DORA y poda del kit
    adr/       SKILL.md
  agents/
    revisor.md     solo lee y corre tests; bloquea por hallazgos altos
    evaluador.md   prueba como usuario (navegador, API, smoke); su salida es la evidencia; sin edición
    seguridad.md   checklist de seguridad; solo en auth, permisos, archivos, integraciones
  scripts/
    necesita-adr.php   la regla de ADR, con el mapa de módulos de .city.json
    tamano.sh          el único comando de tamaño (build, ship y revisor lo llaman)
    entorno-qa.py      confirma que la app que prueba el evaluador es local
    passes.sh          único camino a passes: exige la evidencia con VEREDICTO: pasa
    cierre.sh          arma el reporte de /city:check desde gh y git
```

Cada repo trae `.city.json` en la raíz; el kit no sabe nada del stack:

```json
{
  "app": "city-v2",
  "modulos": "docs/modulos.json",
  "tests": { "unit": "...", "navegador": "...", "lint": "...", "estatico": "..." },
  "tope_lineas": 400,
  "qa": { "url": "http://app.localhost:8080", "instalar": "bin/city install --lab", "smoke": "bin/city smoke" },
  "flags": "config/features.php",
  "spec_dir": "docs/specs",
  "adr_dir": "docs/adr",
  "ramas": "city/",
  "label": "city"
}
```

## Comandos

| Comando | Quién | Entrada | Qué deja |
|---|---|---|---|
| `/city:spec` | Cualquiera | idea, tarea de Notion o issue | Spec de 1 página en `spec_dir`, hito en Notion, cortes como pasos verificables, ADR si la regla lo pide. Publicada en la rama del corte 1. |
| `/city:build` | Cualquiera | spec y `c<N>`, o una frase | Un corte en rama `city/<app>-<slug>-c<N>`: tests primero, implementación, tamaño, ADR, veredictos del `revisor` y del `evaluador`. Guarda la evidencia y, si pasa, corre `passes.sh`. |
| `/city:ship` | Cualquiera | nada | PR a `main`, label `city`, `gh pr merge --auto --squash`. Si CODEOWNERS retiene, lo dice y a quién. |
| `/city:goal` | Cualquiera | spec o hito | Corre build → ship por corte en worktrees hasta cerrar o parar. Escribe `goal.md` en la rama con qué hizo, qué paró y por qué. |
| `/city:check` | Quien libera | spec, día o semana | Reporte de 10 minutos: PR mergeados y versiones, `passes` con evidencia del evaluador, smoke del entorno, PR retenidos (los únicos diffs que se leen), ADR y decisiones pendientes, qué clickear en la review app, costo en sesiones. Termina con el botón del flag. |
| `/city:retro` | Semanal | nada | Números desde GitHub (`numeros.py`), hito cumplido o no, qué pieza del kit se quita esta semana y se mide. |
| `/city:adr` | Cualquiera | decisión | ADR de ≤30 líneas con la plantilla; se acepta al mergearse. |

Flujo de una persona con una feature, de punta a punta:

```
/city:spec ──▶ /city:goal ──────────────────────────────▶ /city:check ──▶ flag
 1 página      c1 build→ship ✓ · c2 build→ship ✓ · c3 ⏸ ADR   10 min       on
                        ▲ evidencia del evaluador → passes.sh
                        ▲ revisor + evidencia como checks; auto-merge
```

`/city:goal` es `/city:build` + `/city:ship` en bucle: quien prefiera ir
corte por corte usa los dos a mano y obtiene lo mismo.

## Agentes

- **`revisor`.** Contexto limpio. Recibe una línea: id, rama, base. Lee el
  diff completo, corre los tests, aplica las reglas duras del `CLAUDE.md` del
  repo, el checklist de seguridad (`seguridad_checklist`) y los chequeos del
  stack (`revisor_extra`). Hallazgos `bloquea`, `debería` o `sugerencia`;
  termina en "listo para merge" o "no mergear". Máximo dos vueltas; a la
  tercera, el PR nace bloqueado y lo decide una persona.
- **`evaluador`.** Contexto limpio, sin edición, sin `browser_evaluate` ni
  `browser_run_code_unsafe`. Recibe el id y la URL de una instalación local
  limpia (`entorno-qa.py` lo confirma). Ejecuta cada paso como un usuario:
  UI con Playwright, API con curl, infra con curl, bash y `qa.smoke`;
  umbral duro por paso: uno falla, no pasa. Calibrado con tres ejemplos de "esto no pasa"
  (acción sin efecto visible, dato que no sobrevive a recargar, error en
  consola o 500). No escribe nada: `/city:build` guarda su salida en
  `<evidencia_dir>/<id>.md` y, si termina en `VEREDICTO: pasa`, corre
  `passes.sh`, el único camino a `passes`.
- **`seguridad`.** Solo cuando el diff toca auth, permisos, archivos,
  integraciones o el CLI, y solo sobre los archivos que le pasan. Mismo
  veredicto que el revisor.
- Los tres corren dos veces: dentro de `/city:build` (para corregir en
  contexto) y como checks de CI (para decidir el merge, con solo el diff).

## Las cuatro capas que sostienen el auto-merge

1. **Sandbox de Claude Code.** Sistema de archivos: el worktree. Red:
   `github.com` y el registro de imágenes del repo. Sin registries de
   paquetes: instalar una dependencia es imposible por construcción; el
   agente la pide en un PR que CODEOWNERS retiene. Lo que hoy es `ask` sobre
   archivos de política pasa a `deny` (en auto, `ask` no pregunta).
2. **Ruleset en `main`.** Checks requeridos: CI del repo + `revisor` +
   `evidencia` (`evaluador`, opcional). Historial lineal, squash, sin push
   directo. CODEOWNERS con el TL de la app en `.claude/**`, `.github/**`, manifiestos, lockfiles, ADR,
   `Shared/` (city) o `app/Domain/Core` (city-v2).
3. **Token acotado.** `gh` por sesión: push a `city/*`, crear PR, habilitar
   auto-merge. Sin merge, sin admin, sin secretos. El despliegue lo hace CI
   en cada tag; ninguna credencial de un entorno entra a una sesión.
4. **Flags.** Lo incompleto para el usuario va tras flag (regla 4 de
   aidd-lite). El flag lo enciende una persona después de `/city:check`.

Límites conocidos: el clasificador de auto mode deja pasar un 17 % de
acciones peligrosas (dato de Anthropic); el CLI de Docker habla con el daemon
fuera del sandbox. Por eso el alcance es el repo y los entornos de prueba,
nunca una instancia municipal.

## Varias personas, varias tareas, varias apps

- Una spec = un hito = una persona de punta a punta. Sus cortes son
  secuenciales (c2 arranca con c1 en `main`); distintas specs y apps corren
  en paralelo sin tocarse.
- El reclamo de un corte es su PR abierto: dos sesiones no pueden abrir el
  mismo. Sin PR apilados: lo que espera, espera en `main`.
- Un corte que toca contrato compartido lleva ADR y lo retiene CODEOWNERS de
  otra squad: es el único punto donde una persona lee código de otra.
- Las paradas de `/city:goal` son las mismas para todos: necesita ADR, dos
  bloqueos del revisor en el mismo PR, tres sesiones sin `passes` en el
  mismo corte, más de tres PR retenidos, o el presupuesto de sesiones.

## Control humano, en tres lugares

1. `/city:check` al cerrar un objetivo: 10 minutos, con el reporte armado.
2. QA humano de la feature completa antes del flag (sigue en Tareas v2).
3. `/city:retro` cada viernes: números, y una pieza menos del kit a probar.

Nadie lee cada PR. Quien quiera leer uno, puede; no es la compuerta.

## Adopción

| Semana | Qué | Quién |
|---|---|---|
| 1 | Plugin `city` 1.0 desde aidd-lite 0.2 (renombre, `.city.json`, `goal`, `check`, `evaluador`); ruleset, CODEOWNERS y jobs de CI en city-v2; sandbox y `deny` | Belmar en city-v2, con el harness de la semana 3 |
| 2 | `/city:goal` sobre el hito de la semana 4 de city-v2; primera retro con la pieza "plan diario" quitada | Belmar |
| 3 a 4 | Una squad en `city` con `.city.json` propio; aidd-lite congelado, su histórico sigue en `aidd-metrics` por la firma `lite/` | Squad piloto + TL |
| 5 en adelante | Resto de squads, una por semana; un cambio al kit por semana | Todos |

Lo que no se hace: correr `/city:goal` en un runner de nube (pide su ADR y
secretos en GitHub), contratos por ronda entre generador y evaluador
(Anthropic los quitó al cambiar de modelo), personas de agente por rol.
