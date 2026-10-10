# Qué es un corte

Un corte es una funcionalidad de `features` y un PR a `main`. Lo construye `/city:build` en una sesión, lo prueba el evaluador solo y entra por auto-merge. Si un corte no es vertical o no cabe, se rompe todo lo de después: el evaluador no puede probarlo solo, el PR pasa el tope y `/city:goal` para.

## Las cinco reglas

1. **Un comportamiento observable de punta a punta.** Una persona, la API o el CLI lo pueden ver o usar cuando el corte entra. Atraviesa las capas que necesita (datos, dominio, API, interfaz) y nada más. La excepción es el corte de contrato de la regla 5.
2. **Se prueba solo.** El evaluador lo verifica con lo que ya está en `main` más este corte. Si un paso necesita un corte posterior, el paso está en el corte equivocado.
3. **De 2 a 5 pasos,** cada uno verificable como usuario, con curl, con el CLI o con una prueba nombrada ("con su prueba en <grupo o suite>").
4. **Estimación de máximo el 75 % de `tope_lineas`** (300 de 400), contando código, pruebas, migraciones con su reversa, lo generado que el repo versiona y la documentación que cambia. El resto queda para las vueltas del revisor y del evaluador.
5. **Nunca por capa.** No hay cortes de "migración y modelos", "API", "pantalla", "fundaciones", "refactor previo", "deuda" ni "pruebas". La única excepción es el corte 1 de un contrato compartido: el contrato, su ADR (máximo 30 líneas) y sus pruebas. Sus pasos pueden ser solo "con su prueba en <grupo o suite>".

## Cómo partir

En este orden, hasta que cada corte cumpla las cinco reglas:

1. **Esqueleto que camina:** el camino más corto de punta a punta, con lo mínimo de datos y de interfaz.
2. **Caso normal completo.**
3. **Validaciones y errores.**
4. **Permisos y alcance:** quién ve y quién puede hacer qué.
5. **Casos borde, volumen y rendimiento.**

Si un tramo sigue sin caber, pártelo por operación (crear, listar, editar, anular) o por tipo de dato o regla. Lo que no sirve a una persona hasta el último corte va tras un flag que la spec nombra; el flag no reemplaza la regla 1, cada corte se sigue probando solo.

## Calibración

| Así no | Así sí |
|---|---|
| "Migración y modelo", "API" y "pantalla" de la misma solicitud, en tres cortes | c1: un ciudadano radica una solicitud con un campo y la ve en su lista. c2: la solicitud valida los datos y adjunta documentos. c3: solo la dependencia asignada la ve |
| "Fundaciones": componentes o servicios que ninguna pantalla ni endpoint usa todavía | El primer corte que necesita el componente lo crea y lo usa |
| Una funcionalidad de 11 pasos que después se parte en entregas E1 a E6 bajo el mismo id | Tantas funcionalidades como comportamientos, cada una con sus pasos, su evidencia y su `passes` |
| "Refactor del servicio" antes de la funcionalidad | El refactor va en el corte que lo necesita, si cabe; si no cabe, ese corte se parte por comportamiento |
| "Medir en CI" o "deuda de los revisores" como funcionalidad | Va en el corte cuyo comportamiento lo necesita, o es un PR `chore/` sin funcionalidad |
| Un paso que dice "la pantalla de c3 muestra lo de c2" en el corte c2 | Ese paso va en c3 |
