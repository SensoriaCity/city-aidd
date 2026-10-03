# Changelog

Una línea por cambio de comportamiento del kit. Durante el piloto, máximo uno por semana.

## 0.2.0 · 2026-09-30
Antes de arrancar el piloto, así que entra junto.
- QA en navegador: agente `qa-navegador` con Playwright MCP 0.0.83 contra `city.test`, tests de navegador de Pest 4 en `build` y reporte del QA en el PR. QA humano pasa a probar la feature completa.
- ADR: el corte 1 lleva solo el contrato, el ADR y sus tests; lo revisa otra squad; label `adr`.
- `numeros.py`: % de aprobación rápida como señal de revisión de trámite.
- Spec: campo `po`; si el PO no validó los criterios, el PR lo dice.
- `necesita-adr.php`: módulo de las migraciones y de lang por nombre de archivo; factories y seeders heredan el módulo del resto del cambio; los tests no suman módulos; los ADRs van en `docs/adrs/` con la convención de `city`.
- `numeros.py`: excluye las revisiones del propio autor, usa el total del PR cuando gh trunca archivos, clasifica `experimento` y filtra por `--autores`.
- Chequeo de entorno (`entorno-qa.php`) antes de migrar y de probar: local, base `AIDD_QA_DB` y correo que no sale.

## 0.1.0 · 2026-09-29
- Versión inicial: skills `spec`, `build` y `ship`, agente `revisor`, regla de ADR (`necesita-adr.php`), plan de piloto, script de números desde GitHub e integración con `aidd-metrics`. Sin roles: el único control humano es la revisión del PR.
