#!/usr/bin/env bash
# Tamaño de un corte: inserciones más borrados contra la base, sin lockfiles,
# vendor ni la carpeta de evidencia. Es el único comando de tamaño del kit:
# build, ship y revisor lo llaman. Compatible con el bash 3.2 de macOS.
# Uso: tamano.sh [base]   (por omisión origin/main; si no existe, main)
# Lee tope_lineas y evidencia_dir de .city.json en la raíz del repo; sin él,
# tope 400. Sale con 0 si cabe, 1 si pasa el tope y 2 si no puede medir.
set -euo pipefail

raiz=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "tamano: no es un repo git" >&2; exit 2; }
cd "$raiz"

campo() { # campo <clave>: valor de primer nivel de .city.json, vacío si no está
  [ -f .city.json ] || return 0
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$1" '.[$k] // empty' .city.json
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; v=json.load(open(".city.json")).get(sys.argv[1]); print("" if v is None else v)' "$1"
  else
    echo "tamano: sin jq ni python3 no leo .city.json; uso los valores por omisión" >&2
  fi
}

tope=$(campo tope_lineas); tope=${tope:-400}
case "$tope" in ''|*[!0-9]*) echo "tamano: tope_lineas no es un entero: $tope" >&2; exit 2 ;; esac
evidencia=$(campo evidencia_dir); evidencia=${evidencia%/}

base=${1:-}
if [ -z "$base" ]; then
  for b in origin/main main; do
    if git rev-parse -q --verify "$b^{commit}" >/dev/null; then base=$b; break; fi
  done
fi
if [ -z "$base" ] || ! git rev-parse -q --verify "$base^{commit}" >/dev/null; then
  echo "tamano: no encuentro la base ${base:-origin/main ni main}" >&2; exit 2
fi

excluir=(':!*composer.lock' ':!*package-lock.json' ':!*pnpm-lock.yaml' ':!*yarn.lock' ':!*bun.lockb' ':!vendor/*' ':!*/vendor/*')
if [ -n "$evidencia" ]; then excluir+=(":!$evidencia/*"); fi

lineas=$(git diff --numstat "$base"...HEAD -- . "${excluir[@]}" | awk '$1 ~ /^[0-9]+$/ { n += $1 + $2 } END { print n + 0 }')
echo "Tamaño: $lineas líneas contra $base (tope $tope)"
if [ "$lineas" -gt "$tope" ]; then echo "Pasa el tope: parte el corte." >&2; exit 1; fi
