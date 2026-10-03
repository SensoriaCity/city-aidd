# Piloto de AIDD Lite en city

Seis semanas, una o dos squads, BMAD intacto en el resto del equipo. En la semana 6 se decide si el piloto se amplía, se ajusta o se descarta. La decisión de volverlo el flujo por defecto necesita 12 semanas de datos, que es la ventana de curva J que usa `aidd-metrics`.

- **Inicio:** `<AAAA-MM-DD>`
- **Squads:** `<squad 1>`, `<squad 2>`
- **Módulos:** `<ids de módulo>`
- **Versión del kit al arrancar:** 0.2.0

## Cómo elegir las squads

- Una squad que quiera probarlo. Sin eso la comparación mide resistencia, no el método.
- Un módulo brownfield con trabajo variado: al menos una feature mediana, mejoras y bugs.
- Sin un hito BMAD grande a medias. Si lo hay, se termina en BMAD (ver `coexistencia-bmad.md`).
- Si se puede, una squad que haya usado BMAD a fondo, para comparar también contra su propia historia.
- Al menos una squad lleva una feature que cambie un contrato compartido, de `Shared` o de dos módulos. Sin eso, el piloto no dice si el método aguanta cambios de plataforma.

## Semana 0: preparación

1. **Publicar el kit.** Subir este repo como privado a `SensoriaCity/city-aidd`.
2. **Instalar en cada dev del piloto,** desde su clon de `city`:
   ```bash
   claude update
   claude plugin marketplace add SensoriaCity/city-aidd
   claude plugin install aidd-lite@sensoria --scope local
   ```
   El scope local deja el plugin activo solo para ese dev y solo en ese repo; la configuración queda en `.claude/settings.local.json`. Confirmar que ese archivo está en el `.gitignore` de `city` y escribir `/aidd-lite:` en una sesión para ver las tres skills.

   Después de mergear el PR de setup del paso 5, la configuración de QA local de `qa-navegador.md` §2: Chrome, Playwright, usuario QA en la base de Herd y `env` y permisos en `.claude/settings.local.json`. En `/mcp` debe aparecer `plugin:aidd-lite:playwright`.
3. **Despliegue y flags.** Resuelto el 2026-09-29: un merge a `main` no despliega; las versiones se liberan a producción a discreción. Un corte en `main` no llega por sí solo al usuario, pero sí en la siguiente versión que se libere. Por eso lo incompleto y visible va detrás de flag. Desplegar directo desde `main` queda fuera de este piloto.
4. **Labels en `city`:** `gh label create aidd-lite --description "Flujo AIDD Lite" --repo SensoriaCity/city` y `gh label create adr --description "Trae un ADR" --repo SensoriaCity/city`.
5. **Tests de navegador en `city`:** el PR de setup de `qa-navegador.md` §1 (Pest 4 browser, Playwright y un job de CI que no bloquea). Es el primer PR del piloto y sirve de ensayo del flujo completo, con ADR incluido.
6. **`aidd-metrics`:** aplicar `integracion-aidd-metrics.md`. GitHub guarda la historia de cada PR, así que esos números se pueden calcular después. Notion no guarda cuándo cambió de estado una tarea. Para medir cuánto tarda una tarea del piloto de En progreso a Finalizado, antes de la semana 1 hay que crear en Tareas v2 las dos automatizaciones de `programa-medicion.md` §10: `Inicio` se llena al pasar a En progreso y `Fin` al pasar a Finalizado.
7. **Notion:** cada spec es un hito en Hitos v2 y cada corte una tarea en Tareas v2 ligada al hito, con la URL de su PR.
8. **Kickoff de 45 minutos** con las squads: leer `metodo.md` juntos y hacer en vivo un cambio de una frase con UI con `/aidd-lite:build` y `/aidd-lite:ship`, para que vean al `qa-navegador` probar en `city.test`.
9. **Acuerdos:** primera revisión humana en máximo 1 día hábil, todo trabajo nuevo entra por AIDD Lite y la bitácora se llena cada viernes.

## Semanas 1 a 6

| Cuándo | Qué | Quién | Duración |
|---|---|---|---|
| Cada viernes | Entrada en `piloto/bitacora.md` con los números de la semana y los tropiezos | Alguien de cada squad | 15 min |
| Cada viernes | Máximo un cambio al kit, con versión y línea en `CHANGELOG.md` | CTO | |
| Semana 3 | Retro corta: qué sobra, qué falta, qué se saltó la gente | CTO + squads | 30 min |
| Semana 6 | Retro de cierre y sesión de decisión | CTO + squads + TLs | 60 min |

**Números de la semana.** Mientras el dashboard de `aidd-metrics` no tenga la clasificación por flujo (ING-007) y la página de revisión (DASH-030), salen de GitHub con:

```bash
gh pr list --repo SensoriaCity/city --state merged --limit 1000 \
  --search "merged:>=<inicio del piloto>" \
  --json number,title,author,headRefName,baseRefName,labels,createdAt,mergedAt,additions,deletions,changedFiles,files,reviews,commits \
  | python3 scripts/numeros.py
```

El script clasifica con una versión simplificada del ADR-008 y da, por flujo: n, tamaño p50 y p85, lead time del primer commit al merge, % sin revisión humana, primera revisión humana p50 y % de aprobación rápida. Con `--autores usuario1,usuario2` filtra por los autores de una squad.

**Actualizar el kit.** Cuando cambia la versión, cada dev corre `claude plugin marketplace update sensoria` y `claude plugin update aidd-lite@sensoria`, y reinicia Claude Code. La bitácora registra la versión que usó cada squad esa semana.

No se juzga el método antes de la semana 4. DORA espera una caída de productividad al inicio de cualquier cambio de proceso (curva J, informe p.8 a p.10).

## Criterios de decisión en la semana 6

Se compara `liviano` contra `bmad` en el mismo periodo del piloto (ADR-008) y contra la historia de las squads piloto.

**Guardarraíles.** Si alguno falla, no hay ampliación aunque el resto salga bien.

1. 0% de PRs `liviano` mergeados sin revisión humana (B6).
2. Arreglos a producción atribuibles a cambios `liviano` no mayores que los de `bmad` + 5 pp (B8, A3).
3. Churn a 21 días de los PRs `liviano` mergeados hasta la semana 3 no mayor que el de `bmad` del mismo tramo (B9). Los de semanas posteriores todavía no tienen 21 días.

**Flujo.**

4. Mejora en al menos uno de estos dos:
   - cycle time p50 de las tareas de Notion vinculadas a PRs `liviano` menor que el de las tareas `bmad`, con throughput de tareas no menor que la historia de la squad (C2, C4);
   - lead time p50 del cambio, primer commit → merge a `main`, menor en `liviano` que en `bmad` (A1).
5. Primera revisión humana p50 de `liviano` no peor que la de `bmad` (B3).

El tamaño p85 ≤ 400 se reporta como cumplimiento del método, no como criterio: la skill ya lo controla.

**Señales para la retro,** no deciden solas: el % de aprobación rápida de `numeros.py` (aprobaciones sin comentarios a más de 500 líneas por hora) y la proporción de hallazgos reales del `qa-navegador` que registra la bitácora.

**Personas.** La retro de cierre no es anónima, porque con dos squads no hay forma de que lo sea. Se decide con dos preguntas: si la mayoría de la squad quiere seguir con AIDD Lite y si alguien siente que revisar le cuesta más que en BMAD por una causa que el kit no puede corregir.

**Muestra.** Cada grupo necesita n ≥ 5 (`min_sample_size`). Si no se alcanza, el piloto se extiende 2 semanas en vez de decidir con muestra insuficiente.

Resultados posibles:

- **Ampliar.** Pasa guardarraíles, flujo y personas.
- **Ajustar.** Pasa guardarraíles pero no flujo o personas. Un ciclo más con los cambios que salgan de la bitácora.
- **Descartar.** Falla un guardarraíl y la causa es el método, no la adopción. Se desinstala el plugin y se documenta qué aprendimos.

## Si se decide ampliar

Cada fase se decide al cerrar la anterior.

1. **Ampliación.** La mitad de las squads, con el mismo esquema de scope local. BMAD sigue para el resto.
2. **Por defecto,** con 12 semanas de datos. El plugin se activa para todo el repo con `claude plugin marketplace add SensoriaCity/city-aidd --scope project` y `claude plugin install aidd-lite@sensoria --scope project`, que escriben la configuración en `.claude/settings.json` de `city`. Se agrega protección de rama en `main` con una aprobación obligatoria. BMAD queda para quien lo pida con motivo.
3. **Retiro de BMAD.** Tras un ciclo completo sin PRs `bmad`, un PR aparte archiva `_bmad/` y los comandos BMAD de `.claude/commands/`.

## Guía de la retro de cierre

1. ¿Entendías qué construir antes de empezar cada corte?
2. ¿El revisor y el QA en navegador encontraron problemas reales o ruido? ¿QA humano encontró en la feature completa algo que el agente debió ver?
3. ¿Revisar PRs de AIDD Lite cuesta más o menos que revisar PRs de BMAD, y por qué?
4. ¿Confías en el código que llegó a `main` por AIDD Lite?
5. ¿Quieres seguir con AIDD Lite?
6. ¿Qué quitarías o agregarías al método?
