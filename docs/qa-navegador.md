# QA en navegador

AIDD Lite prueba en navegador cada corte con UI antes de abrir el PR, en dos capas:

| Capa | Qué es | Quién la hace | Dónde corre |
|---|---|---|---|
| Tests de navegador | Tests de Pest 4 en `tests/Browser/` con el camino feliz de cada criterio de tipo `navegador`. Quedan en el repo como regresión. | `/aidd-lite:build`, antes de implementar | En la máquina del dev y en un job propio de CI |
| Agente QA | El subagente `qa-navegador` confirma que la app es local, la abre con Playwright, sigue los criterios como usuario, prueba bordes (validación, roles, 390 px, textos) y revisa consola, red y el log de Laravel. Deja un reporte con evidencia. | `/aidd-lite:build` después del `revisor`; `/aidd-lite:ship` lo pide si falta | En `city.test`, la app local de Herd del dev |

Las dos capas se complementan. El test de navegador es determinista y protege contra regresiones. El agente encuentra lo que nadie escribió como test.

QA humano ya no prueba cortes. Prueba la feature completa antes de liberarla o de encender el flag, y lo que encuentre se vuelve criterio o test.

## 1. PR de setup en `city`, una sola vez

Lo abre cualquiera del piloto con `/aidd-lite:build "habilitar tests de navegador de Pest 4"`. Instala paquetes, así que según el `CLAUDE.md` de `city` necesita el visto bueno explícito del CTO. La regla de ADR lo marca `a criterio` porque toca dependencias y CI de todos. Lleva un ADR corto en `docs/adrs/` (el ADR-006 si nadie tomó ese número antes), que dice qué se agrega, que no cambia nada para las squads BMAD y cuándo entra a `ci-gate`.

1. Paquetes:
   ```bash
   composer require pestphp/pest-plugin-browser --dev
   npm install --save-dev playwright
   npx playwright install chromium
   ```
2. En `tests/Pest.php`, junto al bloque de `Feature`:
   ```php
   pest()->extend(Tests\TestCase::class)
       ->use(Illuminate\Foundation\Testing\RefreshDatabase::class)
       ->in('Browser');
   ```
3. **No** agregar una suite `Browser` a `phpunit.xml`. Husky corre `vendor/bin/pest --parallel` con las suites de `phpunit.xml`, y los shards de CI solo recorren `tests/Feature` y `tests/Unit`. Así las squads BMAD no necesitan Playwright y su pre-commit no se hace más lento.
4. `.gitignore`: agregar `tests/Browser/Screenshots`. `.playwright-mcp/` ya está.
5. Primer test, `tests/Browser/SmokeTest.php`:
   ```php
   <?php

   it('opens the default panel as the authenticated user', function () {
       visit('/mobility')
           ->assertPathIs('/mobility')
           ->assertNoSmoke();
   });
   ```
   El `TestCase` de `city` ya hace `actingAs()` con un `super_admin`. Si este test termina en `/mobility/login`, la sesión de `actingAs()` no llega al navegador. En ese caso, los tests de navegador inician sesión por el formulario con un helper en `tests/Pest.php`, y eso se anota en el ADR.
6. Job `browser-tests` en `.github/workflows/ pull-request-validation.yml` (el nombre del archivo empieza con un espacio). Copia del job `tests` los pasos de PHP, Composer y Node, y agrega:
   - `npx playwright install --with-deps chromium`;
   - los assets compilados: descarga el artefacto `build-assets-files` del job `setup` o corre `npm run build`;
   - `vendor/bin/pest tests/Browser --parallel`;
   - si falla, sube `tests/Browser/Screenshots` como artefacto.

   Durante el piloto el job **no** entra en `needs` de `ci-gate`: un test inestable no debe bloquear PRs de BMAD. Entra cuando lleve dos semanas estable, y eso se decide en la retro de la semana 3.

## 2. Cada dev del piloto, una sola vez

Cuando el PR de setup ya está en `main`:

1. Google Chrome instalado. El servidor de Playwright del plugin lo usa en modo headless.
2. `git pull`, `composer install`, `npm install` y `npx playwright install chromium` en el clon de `city`, para los tests de navegador.
3. Un usuario QA local en la base de Herd, con una clave que solo existe en tu máquina:
   ```bash
   php artisan tinker --execute '$u = App\Models\User::factory()->create(["name" => "QA AIDD", "email" => "qa-aidd@local.test", "password" => bcrypt("<clave-local>")]); $u->assignRole("super_admin");'
   ```
4. En `.claude/settings.local.json` de `city`, que no se versiona, agrega estas claves a las que ya tiene el archivo:
   ```json
   {
     "env": {
       "AIDD_QA_EMAIL": "qa-aidd@local.test",
       "AIDD_QA_PASSWORD": "<clave-local>",
       "AIDD_QA_DB": "<nombre de tu base local, el DB_DATABASE de tu .env>"
     },
     "permissions": {
       "allow": ["mcp__plugin_aidd-lite_playwright"],
       "deny": [
         "mcp__plugin_aidd-lite_playwright__browser_run_code_unsafe",
         "mcp__plugin_aidd-lite_playwright__browser_evaluate"
       ]
     }
   }
   ```
   - `AIDD_QA_EMAIL` y `AIDD_QA_PASSWORD` son las credenciales del agente.
   - `AIDD_QA_DB` es la base donde el agente puede crear datos. Si la base que Laravel usa de verdad no se llama así, el chequeo de entorno bloquea. Esto evita probar contra una base remota que escuche en `127.0.0.1`, como un proxy de Cloud SQL o un túnel SSH.
   - `allow` evita que Claude pida permiso en cada clic del navegador. `deny` cierra las dos herramientas que ejecutan código arbitrario; el agente tampoco las tiene en su lista.
5. Reinicia Claude. En `/mcp` debe aparecer `plugin:aidd-lite:playwright` conectado.

## Cómo corre en cada corte

1. `/aidd-lite:build` escribe los tests (Livewire para la lógica y los bordes, navegador para el camino feliz), implementa y pasa por el `revisor`.
2. Si el corte tiene UI, corre el chequeo de entorno (`scripts/entorno-qa.php` del plugin). Solo si dice `ENTORNO: local`, corre `php artisan migrate` y, si el diff toca `resources/` o rutas de Filament o Livewire, `npm run build`. Luego delega al `qa-navegador` con una línea: spec, corte y `APP_URL`.
3. El agente repite el chequeo, crea sus datos con factories marcados `QA-AIDD`, prueba criterio por criterio, revisa consola y red en cada página, explora bordes y devuelve APROBADO, CAMBIOS REQUERIDOS o BLOQUEADO con capturas en `.playwright-mcp/`.
4. Los hallazgos altos se corrigen y el agente vuelve a probar, máximo 2 vueltas. Los medios y bajos van al PR.
5. `/aidd-lite:ship` pega en el PR la tabla del agente, sus pendientes y la salida de los tests de navegador.

## Límites

- **Solo local.** El agente no prueba en la review app ni en servidores compartidos. El chequeo de entorno lee la configuración que Laravel usa de verdad, incluida la cacheada, y bloquea si `APP_ENV` no es `local`, si la base no está en la máquina o no es `AIDD_QA_DB`, o si el correo sale a un servidor externo. Es una barrera del kit y del prompt, no del sistema operativo: el agente tiene Bash.
- **Worktrees.** `city.test` sirve la carpeta del clon. El QA se hace desde el clon, no desde un worktree.
- **Integraciones externas.** SIMIT, RUNT y pagos no se prueban de punta a punta. El agente no llama esos servicios.
- **Datos.** La base local no es la de producción. Los riesgos sobre datos existentes los revisan el `revisor` y la persona que revisa el PR.
- **Evidencia.** Las capturas quedan en la máquina de quien construyó. En el PR va la tabla del agente, y quien revisa puede pedir las capturas o repetir los pasos en la review app.
- **Costo.** Anthropic reporta que su harness con evaluador en navegador costó más de 20 veces una corrida sola en una app completa. Aquí el alcance es un corte, pero el costo no está medido: la bitácora registra cuánto tardó el QA y si sus hallazgos fueron reales o ruido.
