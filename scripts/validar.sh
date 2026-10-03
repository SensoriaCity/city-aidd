#!/usr/bin/env bash
# Valida el kit antes de publicar un cambio. Compatible con el bash 3.2 de macOS.
set -uo pipefail
cd "$(dirname "$0")/.."

PLUGIN=plugins/aidd-lite
fail=0
err() { echo "  ✗ $1"; fail=1; }

echo "1/8 claude plugin validate --strict (marketplace)"
claude plugin validate --strict . || fail=1

echo "2/8 claude plugin validate --strict (plugin y skills)"
claude plugin validate --strict "$PLUGIN" || fail=1
claude plugin validate --strict "$PLUGIN/skills" || fail=1

echo "3/8 frontmatter y tamaño de skills y agentes"
for f in "$PLUGIN"/skills/*/SKILL.md "$PLUGIN"/agents/*.md; do
  [ "$(head -1 "$f")" = "---" ] || err "sin frontmatter: $f"
  grep -q '^name: ' "$f" || err "sin name: $f"
  grep -q '^description: ' "$f" || err "sin description: $f"
  n=$(wc -l < "$f" | tr -d ' ')
  [ "$n" -le 120 ] || err "más de 120 líneas ($n): $f"
done
for f in "$PLUGIN"/skills/*/SKILL.md; do
  grep -q '^disable-model-invocation: true' "$f" || err "falta disable-model-invocation: true en $f"
done
for f in "$PLUGIN"/agents/*.md; do
  grep -qE '^tools: ' "$f" || err "sin lista de tools (heredaría las de edición): $f"
  if grep -E '^tools:' "$f" | grep -qE 'Edit|Write|NotebookEdit'; then
    err "tiene herramientas de edición: $f"
  fi
done

echo "4/8 el comando de tamaño es idéntico en build, ship y revisor"
n=$(grep -h 'diff --shortstat origin/main...HEAD' "$PLUGIN/skills/build/SKILL.md" "$PLUGIN/skills/ship/SKILL.md" "$PLUGIN/agents/revisor.md" \
  | sed 's/^[[:space:]]*//' | sort -u | wc -l | tr -d ' ')
[ "$n" -eq 1 ] || err "el comando de tamaño difiere entre build, ship y revisor ($n variantes)"

echo "5/8 archivos referenciados con \${CLAUDE_SKILL_DIR} y \${CLAUDE_PLUGIN_ROOT}"
for f in "$PLUGIN"/skills/*/SKILL.md; do
  d=$(dirname "$f")
  for ref in $(grep -oE '\$\{CLAUDE_SKILL_DIR\}/[A-Za-z0-9._/-]+' "$f" | sed 's|^\${CLAUDE_SKILL_DIR}/||' | sort -u); do
    [ -f "$d/$ref" ] || err "no existe $d/$ref (referenciado en $f)"
  done
done
for f in "$PLUGIN"/skills/*/SKILL.md "$PLUGIN"/agents/*.md; do
  for ref in $(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]+' "$f" | sed 's|^\${CLAUDE_PLUGIN_ROOT}/||' | sort -u); do
    [ -f "$PLUGIN/$ref" ] || err "no existe $PLUGIN/$ref (referenciado en $f)"
  done
done

echo "6/8 .mcp.json del plugin y herramientas del agente QA"
python3 - "$PLUGIN" <<'PY' || fail=1
import json, re, sys
plugin = sys.argv[1]
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
    if not re.search(r"@playwright/mcp@\d+\.\d+\.\d+", args):
        mal("la versión de @playwright/mcp no está fija")
tools = next((l for l in open(f"{plugin}/agents/qa-navegador.md") if l.startswith("tools:")), "")
prefijo = f"mcp__plugin_{nombre}_playwright__"
for necesaria in ("browser_navigate", "browser_snapshot", "browser_take_screenshot"):
    if prefijo + necesaria not in tools:
        mal(f"qa-navegador no tiene {prefijo}{necesaria}")
for prohibida in ("browser_run_code_unsafe", "browser_evaluate", prefijo + "*"):
    if prohibida in tools:
        mal(f"qa-navegador no debe tener {prohibida}")
sys.exit(0 if ok else 1)
PY

echo "7/8 la regla de ADR responde bien a nueve casos"
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

echo "8/8 versión del plugin registrada en CHANGELOG.md"
v=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$PLUGIN/.claude-plugin/plugin.json")
grep -q "^## $v " CHANGELOG.md || err "CHANGELOG.md no tiene entrada para $v"

if [ "$fail" -eq 0 ]; then echo "OK"; else echo "FALLÓ"; exit 1; fi
