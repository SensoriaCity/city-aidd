#!/usr/bin/env python3
"""Números del piloto AIDD Lite directo desde GitHub, sin esperar al dashboard de aidd-metrics.

Uso (desde cualquier carpeta, con gh autenticado):

  gh pr list --repo SensoriaCity/city --state merged --limit 1000 \
    --search "merged:>=2026-10-06" \
    --json number,title,author,headRefName,baseRefName,labels,createdAt,mergedAt,additions,deletions,changedFiles,files,reviews,commits \
    | python3 scripts/numeros.py [--autores usuario1,usuario2]

Clasifica cada PR con una versión simplificada del ADR-008 de aidd-metrics
(hotfix > experimento > proceso > bmad > liviano > clasico) y reporta, por flujo, solo PRs mergeados a main:
  n · tamaño p50/p85 (inserciones + borrados, sin lockfiles, vendor, public/build, specs de docs/apps/*/lite ni ADRs de docs/adrs)
  · lead time p50/p85 (primer commit → merge, en horas) · % sin revisión humana
  · primera revisión humana p50 (horas desde la apertura)
  · % de aprobaciones rápidas: PRs de 50 líneas o más cuya primera aprobación humana llegó sin comentarios
    a más de 500 líneas por hora, contando desde la apertura del PR o el último commit anterior a ella.
    500 líneas por hora es el techo de inspección efectiva del estudio de SmartBear en Cisco. Es una señal
    para conversar en la retro, no un veredicto: alguien pudo leer el diff antes del último commit.
Para BMAD, los PRs a main son los hito → main: su primer commit incluye el de las tareas.
Las revisiones del propio autor y de bots no cuentan como revisión humana. gh trae como máximo 100 archivos
por PR: en PRs más grandes el tamaño usa el total del PR, lockfiles incluidos, y se cuenta en la nota final.
--autores filtra por autor del PR, para ver una squad.
Son cifras de control semanal. La comparación oficial la hace aidd-metrics con las reglas completas.
"""
import argparse
import json
import re
import sys
from datetime import datetime

MIN_N = 5  # min_sample_size de aidd-metrics
LINEAS_POR_HORA = 500
TAM_MIN_RAPIDA = 50
EXCLUIR = re.compile(r"(^|/)(composer\.lock|package-lock\.json|yarn\.lock)$|^vendor/|^public/build/|^docs/apps/[^/]+/lite/|^docs/adrs?/")
PROCESO = ("_bmad/", ".claude/", "docs/", ".github/")
BMAD_RAMA = re.compile(r"^(hito|tarea)/.*-H\d+")
BMAD_TITULO = re.compile(r"(?i)\b(story|historia)\s+\d+\.\d+")
BMAD_DOCS = re.compile(r"^docs/apps/[^/]+/.*(stor(y|ies)|epic|prd|tech-plan|sprint-status)")
BOTS = {"coderabbitai", "claude", "copilot", "github-actions"}


def ts(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00")) if s else None


def es_bot(login):
    login = (login or "").lower()
    return login.endswith("[bot]") or login in BOTS


def flujo(pr):
    rama = pr.get("headRefName", "")
    rutas = [f["path"] for f in pr.get("files") or []]
    labels = {lab["name"] for lab in pr.get("labels") or []}
    if rama.startswith("hotfix/") or "/hotfix/" in rama:
        return "hotfix"
    if "experiment" in labels:
        return "experimento"
    if rutas and all(r.startswith(PROCESO) for r in rutas):
        return "proceso"
    if (BMAD_RAMA.match(rama) or rama.startswith("hito/") or BMAD_TITULO.search(pr.get("title", ""))
            or any(BMAD_DOCS.match(r) for r in rutas)):
        return "bmad"
    if rama.startswith("lite/") or "aidd-lite" in labels:
        return "liviano"
    return "clasico"


def percentil(valores, p):
    v = sorted(valores)
    if not v:
        return None
    k = (len(v) - 1) * p
    i = int(k)
    return v[i] if i + 1 >= len(v) else v[i] + (v[i + 1] - v[i]) * (k - i)


def fmt(x, dec=0):
    return "sin datos" if x is None else f"{x:.{dec}f}"


def autor(pr):
    return ((pr.get("author") or {}).get("login") or "").lower()


def revisiones_humanas(pr):
    return sorted((r for r in pr.get("reviews") or []
                   if r.get("submittedAt") and not es_bot((r.get("author") or {}).get("login"))
                   and ((r.get("author") or {}).get("login") or "").lower() != autor(pr)),
                  key=lambda r: r["submittedAt"])


def tamano(pr):
    archivos = pr.get("files") or []
    if pr.get("changedFiles") and pr["changedFiles"] > len(archivos):
        return (pr.get("additions") or 0) + (pr.get("deletions") or 0), True
    return sum(f["additions"] + f["deletions"] for f in archivos if not EXCLUIR.search(f["path"])), False


def aprobacion_rapida(pr, tam):
    humanas = revisiones_humanas(pr)
    aprob = next((r for r in humanas if r.get("state") == "APPROVED"), None)
    if aprob is None or tam < TAM_MIN_RAPIDA:
        return None
    if (aprob.get("body") or "").strip() or any(r is not aprob and r["submittedAt"] <= aprob["submittedAt"]
                                               for r in humanas):
        return False
    momento = ts(aprob["submittedAt"])
    previos = [ts(c.get("committedDate") or c.get("authoredDate")) for c in pr.get("commits") or []]
    previos = [f for f in previos if f and f <= momento]
    desde = max([ts(pr["createdAt"])] + previos)
    horas = max((momento - desde).total_seconds() / 3600, 1 / 60)
    return tam / horas > LINEAS_POR_HORA


def main():
    args = argparse.ArgumentParser(description="Números del piloto AIDD Lite desde gh pr list --json.")
    args.add_argument("--autores", default="", help="logins separados por coma; filtra por autor del PR")
    autores = {a.strip().lower() for a in args.parse_args().autores.split(",") if a.strip()}
    prs = json.load(sys.stdin)
    grupos = {}
    truncados = 0
    for pr in prs:
        if not pr.get("mergedAt") or pr.get("baseRefName") != "main":
            continue
        if autores and autor(pr) not in autores:
            continue
        g = grupos.setdefault(flujo(pr), {"tam": [], "lead": [], "sin_rev": 0, "rev1": [], "n": 0,
                                           "rapidas": 0, "con_aprob": 0})
        g["n"] += 1
        tam, truncado = tamano(pr)
        truncados += int(truncado)
        g["tam"].append(tam)
        rapida = aprobacion_rapida(pr, tam)
        if rapida is not None:
            g["con_aprob"] += 1
            g["rapidas"] += int(rapida)
        fechas = [ts(c.get("authoredDate") or c.get("committedDate")) for c in pr.get("commits") or []]
        fechas = [f for f in fechas if f]
        if fechas:
            g["lead"].append((ts(pr["mergedAt"]) - min(fechas)).total_seconds() / 3600)
        humanas = [ts(r["submittedAt"]) for r in revisiones_humanas(pr)]
        if humanas:
            g["rev1"].append((humanas[0] - ts(pr["createdAt"])).total_seconds() / 3600)
        else:
            g["sin_rev"] += 1

    print("| Flujo | n | Tamaño p50 | Tamaño p85 | Lead time p50 h | Lead time p85 h | % sin revisión humana "
          "| 1.ª revisión p50 h | % aprobación rápida |")
    print("|---|---|---|---|---|---|---|---|---|")
    for nombre in ("liviano", "bmad", "clasico", "hotfix", "experimento", "proceso"):
        g = grupos.get(nombre)
        if not g:
            continue
        aviso = " (muestra pequeña)" if g["n"] < MIN_N else ""
        print(f"| {nombre}{aviso} | {g['n']} | {fmt(percentil(g['tam'], .5))} | {fmt(percentil(g['tam'], .85))} "
              f"| {fmt(percentil(g['lead'], .5))} | {fmt(percentil(g['lead'], .85))} "
              f"| {fmt(100 * g['sin_rev'] / g['n'])}% | {fmt(percentil(g['rev1'], .5), 1)} "
              f"| {fmt(100 * g['rapidas'] / g['con_aprob']) + '%' if g['con_aprob'] else 'sin datos'} ({g['con_aprob']}) |")

    if truncados:
        print(f"\nNota: {truncados} PR(s) con más de 100 archivos; su tamaño usa el total del PR, lockfiles incluidos.")


if __name__ == "__main__":
    main()
