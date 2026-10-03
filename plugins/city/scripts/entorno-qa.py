#!/usr/bin/env python3
"""Confirma que la instalación que va a probar el evaluador está en esta máquina.

    python3 entorno-qa.py [url]    (por omisión, qa.url de .city.json)

Local es: localhost o *.localhost, una IP de loopback, o un nombre *.test que
resuelve solo a loopback. Cualquier otro host, o uno que no resuelve, bloquea.
Imprime "ENTORNO: local (<url>)" y sale con 0, o "ENTORNO: BLOQUEADO: <motivo>"
y sale con 1. No sabe nada del stack: la base y el correo los cuida el smoke
del repo (qa.smoke).
"""
import ipaddress
import json
import socket
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlsplit


def bloquear(motivo):
    print(f"ENTORNO: BLOQUEADO: {motivo}")
    sys.exit(1)


def loopback(direccion):
    try:
        return ipaddress.ip_address(direccion.split("%")[0]).is_loopback
    except ValueError:
        return False


url = sys.argv[1] if len(sys.argv) > 1 else ""
if not url:
    git = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    cfg = Path(git.stdout.strip() or ".") / ".city.json"
    if not cfg.is_file():
        bloquear("no hay .city.json en la raíz del repo ni URL en el argumento")
    url = json.loads(cfg.read_text(encoding="utf-8")).get("qa", {}).get("url", "")

partes = urlsplit(url)
host = (partes.hostname or "").lower()
if partes.scheme not in ("http", "https") or not host:
    bloquear(f"URL inválida: {url!r}")

if host == "localhost" or host.endswith(".localhost") or loopback(host):
    print(f"ENTORNO: local ({url})")
    sys.exit(0)
if not host.endswith(".test"):
    bloquear(f"{host} no es un host local (localhost, *.localhost, *.test o loopback)")
try:
    direcciones = {info[4][0] for info in socket.getaddrinfo(host, partes.port or 80)}
except socket.gaierror:
    bloquear(f"{host} no resuelve")
ajenas = sorted(d for d in direcciones if not loopback(d))
if ajenas:
    bloquear(f"{host} resuelve a {', '.join(ajenas)}, fuera de esta máquina")
print(f"ENTORNO: local ({url})")
