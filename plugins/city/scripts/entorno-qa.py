#!/usr/bin/env python3
"""Confirma que la instalación que va a probar el evaluador está en esta máquina.

    python3 entorno-qa.py [url]    (por omisión, qa.url de .city.json)

Local es solo: localhost, 127.0.0.1, un nombre que termina en .localhost, o
uno que termina en .test y resuelve únicamente a 127.0.0.1 en esta máquina
(Herd). Cualquier otro host, o un .test que no resuelve, bloquea. Imprime
"ENTORNO: local (<url>)" y sale con 0, o "ENTORNO: BLOQUEADO: <motivo>" y sale
con 1. No sabe nada del stack: la base y el correo los cuida el smoke del repo
(qa.smoke).
"""
import json
import socket
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlsplit


def bloquear(motivo):
    print(f"ENTORNO: BLOQUEADO: {motivo}")
    sys.exit(1)


url = sys.argv[1] if len(sys.argv) > 1 else ""
if not url:
    git = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    cfg = Path(git.stdout.strip() or ".") / ".city.json"
    if not cfg.is_file():
        bloquear("no hay .city.json en la raíz del repo ni URL en el argumento")
    url = json.loads(cfg.read_text(encoding="utf-8")).get("qa", {}).get("url", "")

try:
    partes = urlsplit(url)
    host = (partes.hostname or "").lower().rstrip(".")
    partes.port  # un puerto inválido lanza ValueError
except ValueError:
    bloquear(f"URL inválida: {url!r}")
if partes.scheme not in ("http", "https") or not host:
    bloquear(f"URL inválida: {url!r}")

if host in ("localhost", "127.0.0.1") or host.endswith(".localhost"):
    print(f"ENTORNO: local ({url})")
    sys.exit(0)
if not host.endswith(".test"):
    bloquear(f"{host} no es local (solo localhost, 127.0.0.1, *.localhost o *.test en 127.0.0.1)")
try:
    direcciones = {info[4][0] for info in socket.getaddrinfo(host, partes.port or 80)}
except socket.gaierror:
    bloquear(f"{host} no resuelve")
if direcciones != {"127.0.0.1"}:
    bloquear(f"{host} resuelve a {', '.join(sorted(direcciones))}, no solo a 127.0.0.1")
print(f"ENTORNO: local ({url})")
