#!/usr/bin/env bash
# Valida el kit antes de publicar un cambio. Compatible con el bash 3.2 de macOS.
set -uo pipefail
cd "$(dirname "$0")/.."

PLUGIN=plugins/aidd-lite   # checks propios de aidd-lite
CITY=plugins/city
PLUGINS="$PLUGIN $CITY"
fail=0
err() { echo "  ✗ $1"; fail=1; }

echo "1/10 claude plugin validate --strict (marketplace)"
claude plugin validate --strict . || fail=1

echo "2/10 claude plugin validate --strict (plugins y skills)"
for P in $PLUGINS; do
  claude plugin validate --strict "$P" || fail=1
  claude plugin validate --strict "$P/skills" || fail=1
done

echo "3/10 frontmatter y tamaño de skills y agentes"
for f in plugins/*/skills/*/SKILL.md plugins/*/agents/*.md; do
  [ -f "$f" ] || continue
  [ "$(head -1 "$f")" = "---" ] || err "sin frontmatter: $f"
  grep -q '^name: ' "$f" || err "sin name: $f"
  grep -q '^description: ' "$f" || err "sin description: $f"
  n=$(wc -l < "$f" | tr -d ' ')
  [ "$n" -le 120 ] || err "más de 120 líneas ($n): $f"
done
for f in plugins/*/skills/*/SKILL.md; do
  grep -q '^disable-model-invocation: true' "$f" || err "falta disable-model-invocation: true en $f"
  grep -q '^argument-hint: ' "$f" || err "falta argument-hint en $f"
done
for f in plugins/*/agents/*.md; do
  [ -f "$f" ] || continue
  grep -qE '^tools: ' "$f" || err "sin lista de tools (heredaría las de edición): $f"
  if grep -E '^tools:' "$f" | grep -qE 'Edit|Write|MultiEdit|NotebookEdit'; then
    err "tiene herramientas de edición: $f"
  fi
done
for f in "$CITY"/agents/*.md; do
  grep -qx 'model: inherit' "$f" || err "falta model: inherit en $f"
done

echo "4/10 aidd-lite: el comando de tamaño es idéntico en build, ship y revisor"
n=$(grep -h 'diff --shortstat origin/main...HEAD' "$PLUGIN/skills/build/SKILL.md" "$PLUGIN/skills/ship/SKILL.md" "$PLUGIN/agents/revisor.md" \
  | sed 's/^[[:space:]]*//' | sort -u | wc -l | tr -d ' ')
[ "$n" -eq 1 ] || err "el comando de tamaño difiere entre build, ship y revisor ($n variantes)"

echo "5/10 archivos referenciados con \${CLAUDE_SKILL_DIR} y \${CLAUDE_PLUGIN_ROOT}"
for f in plugins/*/skills/*/SKILL.md; do
  d=$(dirname "$f")
  for ref in $(grep -oE '\$\{CLAUDE_SKILL_DIR\}/[A-Za-z0-9._/-]+' "$f" | sed 's|^\${CLAUDE_SKILL_DIR}/||' | sort -u); do
    [ -f "$d/$ref" ] || err "no existe $d/$ref (referenciado en $f)"
  done
done
for f in plugins/*/skills/*/SKILL.md plugins/*/agents/*.md; do
  [ -f "$f" ] || continue
  P=$(echo "$f" | cut -d/ -f1-2)
  for ref in $(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]+' "$f" | sed 's|^\${CLAUDE_PLUGIN_ROOT}/||' | sort -u); do
    [ -f "$P/$ref" ] || err "no existe $P/$ref (referenciado en $f)"
  done
done

echo "6/10 .mcp.json de cada plugin y herramientas de su agente de navegador"
for par in "$PLUGIN:qa-navegador" "$CITY:evaluador"; do
python3 - "${par%%:*}" "${par#*:}" <<'PY' || fail=1
import json, re, sys
plugin, agente = sys.argv[1], sys.argv[2]
cfg = json.load(open(f"{plugin}/.mcp.json"))["mcpServers"]
nombre = json.load(open(f"{plugin}/.claude-plugin/plugin.json"))["name"]
ok = True
def mal(m):
    global ok
    print(f"  ✗ {m}"); ok = False
if "playwright" not in cfg:
    mal("falta el servidor playwright en .mcp.json")
else:
    args = " ".join(cfg["playwright"].get("args", []))
    version = re.search(r"@playwright/mcp@(\d+\.\d+\.\d+)", args)
    if not version:
        mal("la versión de @playwright/mcp no está fija")
# Herramientas de cada versión fija de @playwright/mcp (tools/list). Al subir
# la versión, agrega su lista aquí.
EXISTEN = {
    "0.0.83": set("""browser_click browser_close browser_console_messages browser_drag browser_drop
        browser_emulate_media browser_evaluate browser_file_upload browser_fill_form browser_find
        browser_handle_dialog browser_hover browser_navigate browser_navigate_back
        browser_network_request browser_network_requests browser_press_key browser_resize
        browser_run_code_unsafe browser_select_option browser_snapshot browser_tabs
        browser_take_screenshot browser_type browser_wait_for""".split()),
}
linea = next((l for l in open(f"{plugin}/agents/{agente}.md") if l.startswith("tools:")), "")
tools = [t.strip() for t in linea[len("tools:"):].split(",") if t.strip()]
prefijo = f"mcp__plugin_{nombre}_playwright__"
existen = EXISTEN.get(version.group(1)) if "playwright" in cfg and version else None
if "playwright" in cfg and version and existen is None:
    mal(f"validar.sh no conoce las herramientas de @playwright/mcp@{version.group(1)}")
for t in tools:
    if not t.startswith("mcp__"):
        continue
    if not t.startswith(prefijo):
        mal(f"{agente}: {t} no es de un servidor de {plugin}/.mcp.json")
    elif "*" in t:
        mal(f"{agente} no debe tener comodines: {t}")
    elif existen is not None and t[len(prefijo):] not in existen:
        mal(f"{agente}: {t} no existe en @playwright/mcp@{version.group(1)}")
for necesaria in ("browser_navigate", "browser_snapshot", "browser_take_screenshot"):
    if prefijo + necesaria not in tools:
        mal(f"{agente} no tiene {prefijo}{necesaria}")
for t in tools:
    if t.endswith("browser_run_code_unsafe") or t.endswith("browser_evaluate") or t == prefijo.rstrip("_"):
        mal(f"{agente} no debe tener {t}")
sys.exit(0 if ok else 1)
PY
done

echo "7/10 aidd-lite: la regla de ADR responde bien a nueve casos"
if command -v php >/dev/null 2>&1; then
  R="$PLUGIN/scripts/necesita-adr.php"
  php -l "$R" >/dev/null || err "necesita-adr.php no compila"
  [ "$(php "$R" app/Shared/Payments/X.php | head -1)" = "ADR: requerido" ] || err "Shared debería pedir ADR"
  [ "$(php "$R" app/Filament/Pqrs/A.php app/Filament/PhotoTicket/B.php | head -1)" = "ADR: requerido" ] || err "dos módulos deberían pedir ADR"
  [ "$(php "$R" app/Filament/Pqrs/A.php tests/Feature/App/Filament/Pqrs/ATest.php | head -1)" = "ADR: no requerido" ] || err "un solo módulo no debería pedir ADR"
  [ "$(php "$R" config/app.php | head -1)" = "ADR: a criterio" ] || err "código fuera de módulos debería quedar a criterio"
  [ "$(php "$R" database/migrations/2026_09_25_090100_tools__fill_span.php app/Filament/Tools/A.php | head -1)" = "ADR: no requerido" ] || err "una migración con dominio en el nombre debería ser de ese módulo"
  [ "$(php "$R" database/migrations/2026_09_01_000001_add_origin_to_resolutions_table.php app/Filament/Pqrs/A.php | head -1)" = "ADR: a criterio" ] || err "una migración sin dominio en el nombre debería quedar a criterio"
  [ "$(php "$R" app/Filament/Zer/X.php database/factories/XFactory.php lang/es/zer.php | head -1)" = "ADR: no requerido" ] || err "factories y lang deberían heredar el módulo"
  [ "$(php "$R" app/Filament/Mobility/X.php tests/Browser/Contraventional/XTest.php | head -1)" = "ADR: no requerido" ] || err "los tests no deberían sumar módulos"
  [ "$(php "$R" app/Filament/Zer/X.php lang/es/pqrs.php | head -1)" = "ADR: requerido" ] || err "un archivo de lang de otro módulo debería contar como ese módulo"
  php -l "$PLUGIN/scripts/entorno-qa.php" >/dev/null || err "entorno-qa.php no compila"
else
  echo "  (sin php en esta máquina: se salta)"
fi

echo "8/10 aidd-lite: versión del plugin registrada en CHANGELOG.md"
v=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$PLUGIN/.claude-plugin/plugin.json")
grep -q "^## $v " CHANGELOG.md || err "CHANGELOG.md no tiene entrada para $v"

echo "9/10 city: el kit no sabe nada del stack"
for f in "$CITY"/skills/*/SKILL.md "$CITY"/agents/*.md; do
  grep -q '\.city\.json' "$f" || err "no lee .city.json: $f"
done
for a in revisor evaluador seguridad; do [ -f "$CITY/agents/$a.md" ] || err "falta el agente $a"; done
if grep -rn 'php84\|pnpm -C web\|bin/city\|8080' "$CITY/skills" "$CITY/agents"; then err "stack en duro en $CITY"; fi
if grep -rn 'diff --shortstat' "$CITY/skills" "$CITY/agents"; then err "el tamaño se mide solo con scripts/tamano.sh"; fi
for f in "$CITY/skills/build/SKILL.md" "$CITY/skills/ship/SKILL.md"; do
  grep -qF 'bash "${CLAUDE_PLUGIN_ROOT}/scripts/tamano.sh"' "$f" || err "no llama a scripts/tamano.sh: $f"
done
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$CITY/city.schema.json" || err "city.schema.json no es JSON"

echo "10/10 city: tamano.sh, passes.sh y entorno-qa.py en un repo de prueba"
T="$(pwd)/$CITY/scripts/tamano.sh"
bash -n "$T" || err "tamano.sh no compila"
tmp=$(mktemp -d)
(
  cd "$tmp" && git init -q && git checkout -q -b main \
    && git -c user.name=v -c user.email=v@v commit -q --allow-empty -m base \
    && git checkout -q -b city/prueba && mkdir -p ev \
    && printf 'a\nb\nc\n' > a.txt && printf 'x\n' > composer.lock && printf 'e\n' > ev/S1.md \
    && git add . && git -c user.name=v -c user.email=v@v commit -q -m corte
) || err "no pude armar el repo de prueba"
[ "$(cd "$tmp" && bash "$T" 2>/dev/null)" = "Tamaño: 4 líneas contra main (tope 400)" ] || err "sin .city.json debería contar 4 líneas contra main"
printf '{"tope_lineas": 3, "evidencia_dir": "ev/"}\n' > "$tmp/.city.json"
(cd "$tmp/ev" && bash "$T" >/dev/null 2>&1) || err "con evidencia_dir fuera, 3 líneas caben en tope 3"
printf '{"tope_lineas": 2, "evidencia_dir": "ev"}\n' > "$tmp/.city.json"
(cd "$tmp" && bash "$T" >/dev/null 2>&1); [ $? -eq 1 ] || err "3 líneas deberían pasar el tope 2 y salir con 1"
(cd / && bash "$T" >/dev/null 2>&1); [ $? -eq 2 ] || err "fuera de un repo git debería salir con 2"

# passes.sh, con cada bash que haya en la máquina (el 3.2 de macOS y el de PATH).
S="$(pwd)/$CITY/scripts/passes.sh"
bashes=$( { echo /bin/bash; command -v bash; ls /opt/homebrew/bin/bash /usr/local/bin/bash 2>/dev/null; } | sort -u)
printf '{"features": "f.json", "evidencia_dir": "ev"}\n' > "$tmp/.city.json"
printf '[\n  {\n    "id": "S1",\n    "pasos": [\n      "a"\n    ],\n    "passes": false\n  },\n  {\n    "id": "S2",\n    "passes": false\n  }\n]\n' > "$tmp/f.orig"
cabecera='# Evidencia · S2 · 2026-10-03 · abc1234\n\n| Paso | Qué hizo | Resultado |\n|---|---|---|\n| 1 | … | cumple |\n\n## Hallazgos\nNinguno.\n\n'
passes() { (cd "$tmp" && "$B" "$S" "$@" >/dev/null 2>&1); }
for B in $bashes; do
  v=$("$B" -c 'echo $BASH_VERSION')
  "$B" -n "$S" || err "passes.sh no compila con bash $v"
  cp "$tmp/f.orig" "$tmp/f.json"; rm -f "$tmp/ev/S2.md"
  passes S2 && err "bash $v: passes.sh sin evidencia debería fallar"
  printf "$cabecera" > "$tmp/ev/S2.md"
  passes S2 && err "bash $v: passes.sh con un reporte sin veredicto debería fallar"
  printf "${cabecera}VEREDICTO: no pasa\n" > "$tmp/ev/S2.md"
  passes S2 && err "bash $v: passes.sh con VEREDICTO: no pasa debería fallar"
  printf "$(echo "$cabecera" | sed 's/S2/S1/')VEREDICTO: pasa\n" > "$tmp/ev/S2.md"
  passes S2 && err "bash $v: passes.sh con un reporte de otro id debería fallar"
  cmp -s "$tmp/f.json" "$tmp/f.orig" || err "bash $v: passes.sh no debería tocar features cuando falla"
  printf "${cabecera}VEREDICTO: pasa\n" > "$tmp/ev/S2.md"
  passes S2 || err "bash $v: passes.sh con un reporte correcto debería cambiar S2"
  [ "$(diff "$tmp/f.orig" "$tmp/f.json" | grep -c '^[<>]')" -eq 2 ] || err "bash $v: passes.sh debería cambiar una sola línea"
  [ "$(jq -c '[.[].passes]' "$tmp/f.json")" = "[false,true]" ] || err "bash $v: passes.sh debería cambiar S2 y no S1"
  passes S2 || err "bash $v: passes.sh sobre un passes ya en true debería salir con 0"
  passes S3 && err "bash $v: passes.sh con un id que no está en features debería fallar"
  printf '[{"id": "S1", "passes": false}, {"id": "S2", "passes": false}]\n' > "$tmp/f.json"
  cp "$tmp/f.json" "$tmp/f.compacto"
  passes S2 && err "bash $v: passes.sh no debería reformatear un features sin el formato de jq"
  cmp -s "$tmp/f.json" "$tmp/f.compacto" || err "bash $v: passes.sh no debería tocar un features sin el formato de jq"
done
rm -rf "$tmp"

E="$CITY/scripts/entorno-qa.py"
for u in http://app.localhost:18080 http://127.0.0.1:18080 http://LOCALHOST/ https://app.city.localhost; do
  python3 "$E" "$u" >/dev/null || err "entorno-qa debería aceptar $u"
done
for u in https://example.com http://10.0.0.5 'http://[::1]/' http://localhost.example.com \
  http://localhost@example.com ftp://localhost http://localhost:99999 'sin url'; do
  python3 "$E" "$u" >/dev/null && err "entorno-qa debería bloquear $u"
done
# *.test con la resolución simulada: entra solo si todas sus direcciones son 127.0.0.1.
qa_test() { # qa_test <direcciones separadas por coma, o vacío si no resuelve>
  python3 - "$E" "$1" >/dev/null <<'PY'
import runpy, socket, sys
script, ips = sys.argv[1], [d for d in sys.argv[2].split(",") if d]
def falsa(host, *a, **k):
    if not ips:
        raise socket.gaierror(8, "no resuelve")
    return [(socket.AF_INET6 if ":" in d else socket.AF_INET, 1, 6, "", (d, 80)) for d in ips]
socket.getaddrinfo = falsa
sys.argv = [script, "http://city.test"]
runpy.run_path(script, run_name="__main__")
PY
}
qa_test 127.0.0.1 || err "entorno-qa debería aceptar un .test que resuelve a 127.0.0.1"
for ips in 10.0.0.5 127.0.0.1,10.0.0.5 127.0.0.1,::1 ''; do
  qa_test "$ips" && err "entorno-qa debería bloquear un .test que resuelve a '${ips:-nada}'"
done
python3 "$E" http://city.example >/dev/null && err "entorno-qa debería bloquear un dominio que no es .test"

if [ "$fail" -eq 0 ]; then echo "OK"; else echo "FALLÓ"; exit 1; fi
