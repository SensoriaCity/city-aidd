# Changelog

Una línea por cambio de comportamiento del kit. Durante la adopción, máximo uno por semana.

## city 1.1.1 · 2026-10-03
- `revisar` sin id de funcionalidad: si la rama y el título no traen id, ya no para; delega al `revisor` con `ninguna · rama · base`. Con id `ninguna`, el revisor no lee `features` y revisa solo reglas duras, seguridad, título como Conventional Commit y dependencias; la falta de id no es hallazgo y el veredicto sale de los hallazgos. Motivo: un PR con label `city` cuya rama o título no nombran funcionalidad quedaba en `no mergear` sin revisión. Sin entrada en `bitacora.md`: corrección de 1.1.0, no tropiezo.

## city 1.1.0 · 2026-10-03
- Un solo plugin, `city`: se borran `plugins/aidd-lite/`, `docs/qa-navegador.md` y `piloto/` (su estado queda en el tag `aidd-lite-0.2.0`); `validar.sh` valida solo `city`; `numeros.py` toma la firma (`ramas` y `label`) del `.city.json` del repo y mide el tamaño como `tamano.sh`. `docs/metodo.md` es el método de `city` (absorbe `plugin-city.md`), `docs/adopcion.md` reemplaza a `piloto.md`, y `bitacora.md` pasa a la raíz. Motivo: el piloto de AIDD Lite no empezó y `city` lo reemplaza. Sin entrada en `bitacora.md`: decisión de diseño, no tropiezo.
- Skill `revisar` para GitHub Actions y a mano: con el número de un PR lee solo rama, base y título, deduce el id desde la rama o el título, delega al `revisor` con `id · rama · base` y deja `veredicto.md` y `veredicto.txt`; es la única skill sin `disable-model-invocation`. `docs/metodo.md` trae el workflow en "En CI". Motivo: el check `revisor` del ruleset no tenía cómo correr. Sin entrada en `bitacora.md`: parte del diseño de 1.0, no tropiezo.

## city 1.0.3 · 2026-10-03
- Evaluador con reglas uniformes de prueba y alcance: una cláusula "con su prueba en <grupo o suite>" se verifica corriendo esa prueba en el clon con el comando de `tests` (y la receta de `tests.postgres`, campo opcional nuevo, si necesita base desechable), nunca leyendo CI; si no puede correrla, el paso queda `no verificado` y no cumple. Lo que encuentra fuera de la funcionalidad va en "Fuera de alcance", media como máximo, sin cambiar el veredicto. Guiones y logs solo en un `mktemp -d` propio que borra al terminar, nunca en el clon ni en el worktree, y la evidencia dice si algo quedó. `build` copia `.city.json` del worktree al clon si falta. El ejemplo de city-v2 nombra `bin/pest-postgres.sh`. Motivo: calibración del evaluador (la misma cláusula se verificaba distinto según el paso, hallazgos ajenos a la funcionalidad cambiaban el veredicto y quedaban archivos en el repo). Sin entrada en `piloto/bitacora.md`: corrección de 1.0.2, no tropiezo del piloto.

## city 1.0.2 · 2026-10-03
- Evaluador sobre el clon e instalación desechable: `build` le pasa `repo` (ruta del clon) e `instalacion: desechable` cuando la instalación es suya y la baja con `down -v`; el evaluador lee código y corre comandos en el clon y toma de ahí el hash de la evidencia; solo con la marca ejecuta pasos que borran o alteran filas, nunca `migrate:fresh` ni borra volúmenes; un paso bloqueado termina en `VEREDICTO: no pasa` y `BLOQUEADO` queda para cuando no pudo empezar. Motivo: calibración del evaluador (trabajaba sobre el worktree de la sesión y no sobre el clon; el paso 3 de S3-02 quedó en `BLOQUEADO` sin veredicto). Sin entrada en `piloto/bitacora.md`: corrección de 1.0.1, no tropiezo del piloto.

## city 1.0.1 · 2026-10-03
- Host de QA y usuario de prueba: el ejemplo de city-v2 apunta a `app.city.localhost` (`CITY_BASE_DOMAIN`); `.city.json` acepta `qa.usuario` y `qa.usuario_stdin`; `build` crea un usuario desechable con contraseña aleatoria y se lo pasa al evaluador, que entra por el login de la app y nunca lo copia a la evidencia. Motivo: el evaluador no tenía cómo entrar a los pasos con sesión y la URL del ejemplo no era el host de la app. Sin entrada en `piloto/bitacora.md`: corrección de 1.0.0, no tropiezo del piloto.

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
