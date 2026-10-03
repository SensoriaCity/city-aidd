## Qué cambia
<Una o dos frases para quien revisa. Qué comportamiento nuevo existe y dónde.>

- Spec: `docs/apps/<app>/lite/<archivo>.md` · corte C<N> de <total>
- Hito: <URL del hito en Hitos v2>
- Tarea: <URL de la tarea del corte en Tareas v2>
- PO: <nombre, o "sin validar">
- Flag: <nombre o "no aplica">
- ADR: <ruta o "no aplica">

## Criterios de aceptación de este corte
| # | Verificación | Resultado |
|---|---|---|
| CA1 | `tests/…/XTest.php` | pasa |

## QA en navegador
Subagente `qa-navegador` sobre <APP_URL local> en el commit <sha corto>: <APROBADO, CAMBIOS REQUERIDOS o BLOQUEADO> en <n> vuelta(s). Las capturas quedan en `.playwright-mcp/` de quien construyó.

| Criterio | Qué hizo | Resultado |
|---|---|---|
| CA1 | <…> | cumple |

- <hallazgos medios y bajos, con pasos para reproducirlos, o "ninguno">

<Si el corte no tiene UI, reemplaza esta sección por "Sin UI: no aplica".>

## Datos para reproducir (opcional)
- <qué datos y qué rol necesita quien quiera ver el flujo en `pr-<N>.sensoria.app`; los datos del agente solo existen en la máquina de quien construyó>

## Evidencia
```
<final de la salida de pest (incluidos los tests de navegador), pint y phpstan>
```

## Riesgos
- <migración, datos existentes, permisos, integraciones; o "ninguno identificado">

## Pendientes del revisor
- <hallazgos medios y bajos del subagente `revisor`, o "ninguno">

## Para quien revisa
Aprobar este PR aprueba el código, la spec y el ADR si lo hay.

- [ ] Leí el diff completo y entiendo qué hace cada archivo
- [ ] Si hay ADR, soy de otra squad y estoy de acuerdo con la decisión y sus consecuencias para otros módulos
- [ ] Los tests fallarían si el criterio no se cumple
- [ ] Leí el reporte del QA en navegador y sus pendientes
- [ ] No hay cambios fuera del corte
- [ ] Permisos y datos existentes revisados

Revisión del subagente `revisor`: <APROBADO o CAMBIOS REQUERIDOS> en <n> vuelta(s).
