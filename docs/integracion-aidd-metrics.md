# Integración con aidd-metrics

`aidd-metrics` ya prevé un flujo `liviano` (ADR-008) con la firma vacía y un evento `metodo-liviano` sin fecha. Para medir el piloto hacen falta dos cambios de configuración en ese repo. La clasificación por flujo todavía no está implementada (feature ING-007 en `false`); mientras tanto, `scripts/numeros.py` de este repo da los números de control desde GitHub.

## 1. Firma del flujo liviano

En `config/settings.yaml`, bloque `workflow_classification`:

```yaml
  liviano:                        # firma de AIDD Lite; basta con cumplir una de las dos
    branch_regex: '^lite/'
    labels: ["aidd-lite"]
```

`branch_regex` y `labels` se combinan con O: un PR es `liviano` si su rama empieza por `lite/` o si tiene el label. Hay que dejarlo así en ING-007.

La precedencia de ADR-008 se mantiene: `hotfix`, `experimento`, `proceso`, `bmad`, `liviano`, `clasico`. Consecuencias:

- las specs viven en `docs/apps/<app>/lite/` y su slug no usa `story`, `epic`, `prd`, `tech-plan` ni `sprint-status`, así que no activan la regla de documentos de BMAD. Si el nombre de alguna carpeta de app contiene una de esas palabras (por ejemplo `history`), hay que ajustar `bmad.doc_path_regex` para que solo mire el nombre del archivo;
- un PR con rama `lite/` que modifique archivos BMAD de `docs/apps/<app>/` cae en `bmad`;
- un PR que solo toca documentación cae en `proceso`; por eso la spec viaja con el código del corte 1;
- un arreglo a producción va por `hotfix/` y queda como `hotfix`, que es lo correcto para el change failure rate.

## 2. Evento del piloto

En `config/events.yaml`:

```yaml
  - id: aidd-lite-piloto
    date: "<AAAA-MM-DD>"           # inicio de la semana 1
    name: "Piloto de AIDD Lite en <squads>"
    kind: process_change
    confirmed: true
```

Los eventos de `aidd-metrics` son globales: la banda antes/después se dibuja para toda la organización aunque solo cambien una o dos squads. Para el piloto, la lectura principal es el filtro por flujo; el evento sirve para la comparación de las squads piloto contra su propia historia, filtrando por equipo. `metodo-liviano` queda para la adopción general, si llega.

## Qué mirar

- **Comparación principal.** Filtro `workflow`: `liviano` contra `bmad` en el mismo periodo. Separa el efecto del método del paso del tiempo.
- **Comparación secundaria.** Squads piloto antes y después de `aidd-lite-piloto`.
- **Lead time.** Con PRs directos a `main` el cálculo del ADR-004 es más simple: primer commit del PR → merge a `main`. Sigue siendo proxy de deploy (ADR-001).
- **Vínculo con Notion.** Cada spec es un hito en Hitos v2 y cada corte una tarea en Tareas v2 ligada al hito, con la URL del PR en el campo `PR`: método 1 del ADR-005, confianza alta. Mejora posible en `aidd-metrics`: leer también las líneas `Hito:` y `Tarea:` del cuerpo del PR, que la plantilla de AIDD Lite siempre llena.
- **Atribución a IA.** Con la decisión del 2026-09-29 (ADR-003, atribución por política) no hace falta trailer. El label `aidd-lite` queda como evidencia observable de uso.
