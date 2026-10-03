#!/usr/bin/env python3
"""Cambia passes a true en UNA funcionalidad, sin tocar nada más del archivo.

Lo corre solo el agente evaluador, después de escribir su evidencia:

    python3 marcar-passes.py <id>

Lee `features` y `evidencia_dir` de .city.json en la raíz del repo y exige
<evidencia_dir>/<id>.md con la línea exacta "VEREDICTO: pasa". Edita el texto
en vez de reescribir el JSON, y solo guarda si el resultado difiere del
original únicamente en ese passes. Sale con 0 si lo cambió o ya estaba en
true, y con 1 si no puede.
"""
import json
import re
import subprocess
import sys
from pathlib import Path


def salir(motivo):
    print(f"marcar-passes: {motivo}", file=sys.stderr)
    sys.exit(1)


if len(sys.argv) != 2:
    salir("uso: marcar-passes.py <id>")
fid = sys.argv[1]

git = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
if git.returncode != 0:
    salir("no es un repo git")
raiz = Path(git.stdout.strip())
if not (raiz / ".city.json").is_file():
    salir("no hay .city.json en la raíz del repo")
cfg = json.loads((raiz / ".city.json").read_text(encoding="utf-8"))

evidencia = raiz / cfg["evidencia_dir"] / f"{fid}.md"
if not evidencia.is_file() or "VEREDICTO: pasa" not in evidencia.read_text(encoding="utf-8").splitlines():
    salir(f"falta {cfg['evidencia_dir'].rstrip('/')}/{fid}.md con la línea VEREDICTO: pasa")

archivo = raiz / cfg["features"]
texto = archivo.read_text(encoding="utf-8")
datos = json.loads(texto)
if not isinstance(datos, list):
    salir(f"{cfg['features']} no es una lista de funcionalidades")
mias = [f for f in datos if isinstance(f, dict) and f.get("id") == fid]
if len(mias) != 1:
    salir(f"{fid} aparece {len(mias)} veces en {cfg['features']}")
if mias[0].get("passes") is True:
    print(f"{fid}: passes ya estaba en true")
    sys.exit(0)

mias[0]["passes"] = True
for m in re.finditer(r'("passes"\s*:\s*)false\b', texto):
    nuevo = texto[: m.start()] + m.group(1) + "true" + texto[m.end():]
    if json.loads(nuevo) == datos:
        archivo.write_text(nuevo, encoding="utf-8")
        print(f"{fid}: passes true en {cfg['features']}")
        sys.exit(0)
salir(f"no encontré el passes false de {fid} en el texto de {cfg['features']}")
