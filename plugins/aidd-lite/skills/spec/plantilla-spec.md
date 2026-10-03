---
titulo: <cambio en pocas palabras>
modulo: <id del módulo>
autor: <quien corrió /aidd-lite:spec>
po: <nombre del PO que validó los criterios, o "sin validar", o "no aplica" si no es una feature de usuario>
hito_notion: <URL del hito en Hitos v2>
diseno: <URL de Figma o "no aplica">
flag: <nombre del feature flag o "no aplica">
adr: <ruta del ADR o "no aplica">
creada: <AAAA-MM-DD>
---

# <Título>

## Para quién y qué problema
<Una o dos frases. Quién sufre el problema hoy y qué pasa.>

## Resultado esperado
<Qué puede hacer el usuario cuando esto esté en producción. Observable.>

## Alcance
- <qué entra>

## Fuera de alcance
- <qué no entra, aunque parezca relacionado>

## Diseño
- Contexto leído: `docs/apps/<app>/…` o "ninguno"
- Módulos que toca: <ids> · ADR: <requerido, no requerido o a criterio, y el motivo>
- Archivos a tocar: `<ruta>` …
- Interfaces nuevas o cambiadas: <firma de acción, endpoint, columna, permiso>
- Patrón a imitar: `<ruta de un recurso, acción o test existente parecido>`
- Patrón de flag: `<ruta donde el repo define o consulta flags>` o "no aplica"
- Datos: <migraciones, backfill, datos existentes afectados>

## Criterios de aceptación
| # | Dado / cuando / entonces | Tipo | Verificación |
|---|---|---|---|
| CA1 | <…; en `navegador`, qué ve el usuario al terminar> | lógica · navegador | test `tests/Feature/…/XTest.php` · y `tests/Browser/…/XTest.php` si es `navegador` |

## Cortes
Cada corte es un vertical slice y una tarea en Tareas v2 ligada al hito: un comportamiento que funciona de punta a punta, un PR a `main`, ≤400 líneas, mergeable solo. El corte 2 empieza cuando el 1 está mergeado. Con ADR, C1 lleva solo el contrato, el ADR y sus tests.
- [ ] C1 · <qué puede hacer el usuario o el sistema al terminar> · CA1, CA2 · UI: <sí o no> · rama `lite/<modulo>-<slug>-c1` · tarea: <URL>
- [ ] C2 · <…>

QA humano: prueba la feature completa antes de liberarla o de encender el flag.

## Riesgos y preguntas abiertas
- <riesgo concreto y cómo se mitiga, o la pregunta y quién la responde>
