# AIDD Lite

AIDD Lite es la forma liviana de desarrollar con Claude Code en `city`. Cambia la cadena de BMAD (PRD, arquitectura, épicas, historias, hitos apilados) por una spec de una página, cortes pequeños que van directo a `main` y tres revisiones: un agente revisor con contexto limpio, un agente QA que prueba la app en el navegador y una persona que lee el código.

Lo que buscamos atacar está medido en `aidd-metrics/docs/descubrimiento.md`. En el periodo BMAD el tamaño mediano de PR a `main` pasó de 144 a 507 líneas, el p85 de 806 a 4.240, la apertura → merge mediana de 42 h a 143 h, y el 92% de los PRs a `main` se mergeó sin revisión humana. Son señales exploratorias, no métricas validadas, pero apuntan a lotes grandes y a un impuesto de verificación que nadie está pagando.

## El ciclo

```
Cualquier persona del equipo con Claude, una sesión por paso                                                        Otra persona
/aidd-lite:spec ─▶ /aidd-lite:build ─▶ revisor ─▶ qa-navegador ─▶ /aidd-lite:ship ─▶ lee y aprueba ─▶ squash a main
spec de 1 página;   tests primero,       contexto     si hay UI:       PR a main con el
la regla decide     también de           limpio       prueba en        reporte del QA,
si hay ADR          navegador; ≤400                   city.test        label aidd-lite
```

Si el cambio cabe en una frase, se salta la spec: `/aidd-lite:build "agregar filtro por estado a la tabla de comparendos"`.

## Sin roles

Cualquier persona del equipo corre `spec`, `build` y `ship`, y cualquiera hace push a sus ramas `lite/`. No hay aprobaciones de senior ni de TL mientras se trabaja. La única regla sobre personas es que quien revisa un PR no es quien lo escribió.

Fuera del desarrollo participan tres roles:

| Rol | Qué hace en AIDD Lite |
|---|---|
| PO | Participa en la entrevista de la spec o valida sus criterios cuando es una feature de usuario. Si no lo hace, la spec queda `po: sin validar` y el PR lo dice. Decide cuándo se enciende el flag. |
| QA | No prueba cortes: eso lo hace el agente `qa-navegador`. Prueba la feature completa antes de liberarla o de encender el flag, y lo que encuentra se vuelve criterio o test. |
| Diseño | Deja el enlace de Figma en la spec cuando hay UI nueva. |

## Reglas

1. Un cambio que cabe en una frase no lleva spec.
2. La spec cabe en una página. No se aprueba aparte: se revisa con el PR del corte 1.
3. Un corte es un vertical slice: un comportamiento que funciona de punta a punta, en un PR a `main` de máximo 400 líneas, contando inserciones y borrados sin lockfiles, `vendor/`, `public/build/`, la spec ni el ADR. No se corta por capas, y no hay ramas `hito/*` ni PRs apilados.
4. Lo que está incompleto para el usuario va detrás de un feature flag, no en una rama larga. Un merge a `main` no despliega, pero `main` se libera a discreción y la versión siguiente lo llevaría.
5. Cada criterio de aceptación tiene su test, escrito antes de la implementación. Los flujos en pantalla llevan además un test de navegador de Pest 4. "Listo" es la salida de los tests a la vista.
6. Quien construye no aprueba. Primero el subagente `revisor` en contexto limpio, después el subagente `qa-navegador` si el corte tiene UI, y al final otra persona.
7. Todo PR a `main` tiene al menos una aprobación de una persona distinta del autor que leyó el diff completo.
8. Ramas `lite/<modulo>-<slug>-c<N>`, o `lite/<modulo>-<slug>` en cambios de una frase, y label `aidd-lite`. Sin eso el piloto no se puede medir.
9. Los arreglos a producción siguen por el flujo `hotfix/` de siempre, nunca por `lite/`. Si no, el change failure rate de AIDD Lite queda subcontado.
10. Si un cambio necesita ADR lo decide el sistema, no la persona. `scripts/necesita-adr.php` lo pide cuando el cambio toca `Shared` o dos o más módulos; si toca código fuera de los módulos, Claude busca si otras apps lo usan. El ADR tiene máximo ~30 líneas y se aprueba al aprobar el PR que lo trae.
11. Con ADR, el corte 1 lleva solo el cambio de contrato, el ADR y sus tests, y su PR lo revisa alguien de otra squad, con el label `adr`.

## Seguimiento

- **Por feature.** La spec es un hito en Hitos v2. Cada corte se marca `[x]` en la spec dentro del mismo PR del corte, así que en `main` la spec muestra solo lo mergeado.
- **Por squad y entre squads.** Cada corte es una tarea en Tareas v2 ligada al hito, con su squad y la URL de su PR. Es el mismo tablero que usa BMAD.
- **Por sesión.** Una sesión por corte y sin archivo de progreso: el estado queda en git (rama, commits y PR). Si una sesión se corta, `/aidd-lite:build` con la misma spec retoma la rama.

## Un solo control humano

La revisión del PR antes de mezclar. Una persona distinta del autor lee el diff completo y el reporte del QA en navegador, y aprueba en un solo acto el código, la spec y el ADR si lo hay. Los agentes no reemplazan esta lectura. La primera revisión llega en máximo 1 día hábil. Si el PR trae ADR, esa persona es de otra squad.

La prueba de QA humano sobre la feature completa y encender un flag son decisiones de producto y de liberación, fuera del flujo de desarrollo. Al abrir el PR del último corte, `/aidd-lite:ship` recuerda crear la tarea de QA humano en Tareas v2, con el entorno donde se va a probar.

### Cómo se decide un ADR

1. `/aidd-lite:spec` corre la regla sobre las rutas que planea tocar y, si hace falta, escribe el ADR junto a la spec.
2. `/aidd-lite:build` y `/aidd-lite:ship` la corren otra vez sobre el diff real. Si el código terminó tocando algo compartido que la spec no previó, `build` escribe el ADR y `ship` no abre el PR sin él.
3. El subagente `revisor` marca como hallazgo alto un contrato compartido cambiado sin ADR.
4. Quien revisa el PR acepta o rechaza la decisión junto con el código. Un ADR en `main` está aceptado.

## Qué no trae, a propósito

- Personas de agente (analyst, pm, architect, sm, dev, qa). Un agente con la spec y el código a la mano hace ese trabajo con un plan corto.
- PRD, documento de arquitectura por módulo, épicas y `sprint-status`. La spec, el hito y las tareas de Notion cubren eso. La arquitectura se decide solo cuando un cambio cruza módulos, con un ADR corto.
- Hooks propios. Husky ya corre Pint, PHPStan y Pest en pre-commit.
- Contratos por ronda entre el generador y el evaluador. Anthropic quitó los sprints de su propio harness al pasar a Opus 4.6 y dejó el evaluador en una pasada al final (ver `fundamentos.md`). Aquí el QA en navegador pasa una vez por corte, con máximo 2 vueltas.
- Cambios al `CLAUDE.md` de `city`. El método vive en el plugin.
- Cambios a los revisores de GitHub (CodeRabbit y Claude Code Review). Siguen igual para los dos flujos, así la comparación es justa.

## Decisiones de diseño

- **Plugin y no archivos copiados en `city`.** Las skills quedan con prefijo (`/aidd-lite:spec`) y no chocan con los comandos BMAD de `.claude/commands/`. Cada dev del piloto lo instala en scope local y se quita sin dejar rastro. El kit se versiona en este repo.
- **Specs en `docs/apps/<app>/lite/`.** Quedan junto a la documentación de cada app, en una subcarpeta propia. `aidd-metrics` reconoce los archivos de BMAD en `docs/apps/` por su nombre (story, epic, prd, tech-plan, sprint-status), así que el slug de una spec no usa esas palabras (ADR-008). La spec viaja en la rama del corte 1 para que quien construya la tenga sin depender de un PR aparte.
- **ADR solo para contratos compartidos.** En la muestra de `aidd-metrics` el 17% de los PRs toca dos o más módulos y el 12% solo código compartido. Ahí una spec de una página no alcanza para decidir cómo cambia algo que usan otras apps. El ADR deja esa decisión escrita y revisable sin volver al architect de BMAD, y la regla que decide cuándo hace falta es la misma para todos. Los ADRs van en `docs/adrs/` con la convención que ya tiene `city` (`ADR-NNN-titulo.md` y una fila en el índice del README).
- **La spec lee el PRD y el tech-plan de la app.** Son contexto de negocio que no está en el código. Se leen sin modificarlos y, si contradicen el código, manda el código.
- **400 líneas.** Es el objetivo de la acción P-07 del programa de medición. La skill lo controla, así que no se usa como criterio de éxito del piloto.
- **PR directo a `main`.** Elimina la espera de integración en la rama de hito (P-20) y el tramo `hito → main` donde casi nadie revisa.
- **El revisor es un subagente y no la sesión que construyó.** Anthropic reporta que es más fácil calibrar un evaluador escéptico aparte que volver crítico al que genera. Solo bloquea por hallazgos altos; los medios van al PR y decide el humano.
- **QA en navegador desde el día 1, en dos capas.** La meta es AIDD completo: que el corte llegue al PR probado como lo usaría una persona, no solo con tests unitarios. Los tests de navegador de Pest 4 quedan como regresión; el agente `qa-navegador` explora lo que nadie escribió como test, como hace el evaluador con Playwright del harness de Anthropic. Anthropic advierte que el evaluador vale su costo cuando la tarea está más allá de lo que el modelo hace bien solo, así que la bitácora registra si sus hallazgos son reales o ruido. Detalle en `qa-navegador.md`.
- **QA local y no en la review app.** En `city.test` el agente prueba dentro de la sesión de build, sin esperar el deploy de Forge, y el dev corrige en el mismo contexto. La review app queda para quien revisa el PR, si quiere ver el flujo.

## Cómo evoluciona el kit

Cada pieza del kit es un supuesto sobre algo que el modelo no hace solo, y esos supuestos caducan cuando cambia el modelo. Por eso:

- durante el piloto entra máximo un cambio al kit por semana, con versión en `plugin.json` y línea en `CHANGELOG.md`, para poder atribuir efectos en las métricas;
- después del piloto se prueba quitar una pieza a la vez. Primero la entrevista en cambios pequeños, luego el revisor local si repite lo que ya dicen los revisores de GitHub, y el QA en navegador en los cortes donde sus hallazgos resulten ser ruido;
- una skill nueva, como las convenciones de Filament de un módulo, entra solo cuando la bitácora muestra el mismo tropiezo dos veces.
