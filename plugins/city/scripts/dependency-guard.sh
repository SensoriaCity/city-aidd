#!/usr/bin/env bash
# Hook PreToolUse (ADR-0026, fila "Agentes" y enmienda del 2026-10-02):
# aplica el deny y el ask de .claude/settings.json donde las reglas por
# prefijo no llegan. Rechaza, con el motivo de que la línea la corre Belmar
# al teclado, la que nombra el plan: npx, pnpx, bunx, `dlx`, `create`, `npm
# install`, `npm exec` e `npm init` de un paquete, todo comando que agregue,
# actualice o quite dependencias (`add`, `update`, `remove`, `install` sin
# `--frozen-lockfile`, `shadcn add`, `composer require`…) y escribir un
# lockfile, desde Bash o con Edit, Write, MultiEdit y NotebookEdit. Pregunta
# antes de cambiar la configuración de un gestor, de escribir un manifiesto o
# un archivo de la política (también `.claude/` y `.github/workflows/`) y de
# `php artisan` fuera de `allow`; en modo auto, `ask` no pregunta (#124).
# `docker`, `git`, `curl` y `bin/city` nunca deciden por sí mismos: solo se
# revisa el gestor que corran. Mira dentro de envoltorios (`corepack`, `sudo`,
# `env`…), `-C web`, `sh -c`, `eval`, `$(…)`, backticks y `docker exec` o
# `run` y `docker compose exec` o `run`; el texto
# entre comillas simples, un comentario y el cuerpo de un heredoc que va a
# `cat`, `git` o `gh` son solo texto. Lo que no alcanza a leer (una comilla
# sin cerrar, un comando enorme) pregunta. No ve un script en disco, una
# variable ni `node -e`: es un freno para accidentes, y la frontera es CI con
# el lockfile congelado. Bash 3.2 o posterior, awk y jq. settings.json lo
# invoca con `|| exit 2`: un error o el archivo ausente bloquean (falla
# cerrado). Lee el JSON de la entrada estándar.
set -euo pipefail
# APFS no distingue NPX de npx: comandos, subcomandos y rutas, sin mayúsculas.
shopt -s nocasematch

command -v jq >/dev/null 2>&1 || { echo "dependency-guard: falta jq" >&2; exit 2; }
input="$(cat)"
tool="$(printf '%s' "$input" | jq -er 'if type == "object" then .tool_name else error end')" ||
  { echo "dependency-guard: JSON inválido" >&2; exit 2; }
lockfiles='^(pnpm-lock\.yaml|composer\.lock|package-lock\.json|yarn\.lock|bun\.lockb?)$'
belmar="La línea la corre Belmar al teclado, la que nombra el plan (ADR-0026, enmienda del 2026-10-02)."
case "$tool" in
  Bash) ;;
  Edit|Write|MultiEdit|NotebookEdit)
    # De estas solo se rechaza un lockfile; lo demás va por settings.json.
    path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')"
    if [[ "${path##*/}" =~ $lockfiles ]]; then
      jq -n --arg r "dependency-guard: $tool escribe ${path##*/}, un lockfile. $belmar" \
        '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
    fi
    exit 0 ;;
  *) exit 0 ;;
esac
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
command="$(printf '%s' "$input" | jq -er '.tool_input.command | strings')" ||
  { echo "dependency-guard: sin tool_input.command" >&2; exit 2; }

level=0 # 0 nada, 1 ask, 2 deny
reason=""
flag() { # flag <1|2> <razón>
  if (( $1 > level )); then level=$1; reason="$2"; fi
}

decide() {
  case "$level" in
    0) exit 0 ;;
    1) decision=ask ;;
    *) decision=deny; reason="$reason. $belmar" ;;
  esac
  jq -n --arg d "$decision" --arg r "dependency-guard: $reason" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
  exit 0
}

# Uno enorme no se revisa antes del timeout de settings.json: pregunta.
if (( ${#command} > 65536 )); then flag 1 "comando de más de 64 KiB"; decide; fi

# Partir en comandos simples, en una sola pasada que sigue a bash: comillas,
# `\`, comentarios, heredocs y `$((…))`. Una línea por comando, con las
# palabras separadas por \037 (un salto de línea dentro de una palabra va como
# \036). `$(…)` y los backticks, también entre comillas dobles, salen como
# comandos aparte. El cuerpo de un heredoc es texto, salvo que una palabra
# del comando que lo recibe, o de la tubería que sigue, sea un shell (`sudo
# bash`, `docker run … bash`, `| tr | sh`): entonces sale como una línea
# `\002cuerpo` que se revisa sola. Sin comillas en el delimitador, bash expande sus `$(…)` y
# backticks: se revisan aunque vaya a `cat` o a `git`. Una redirección de
# salida queda como la palabra `>destino`. Si algo queda abierto al final,
# imprime la línea `\001abierto`.
tokenize() {
  printf '%s\n' "$1" | awk '
function flush(   w, b) {
  if (inw) {
    w = word; gsub(/\n/, "\036", w)
    if (pre == "") { b = tolower(w); sub(/.*\//, "", b); sub(/^=/, "", b); if (b ~ /^(sh|bash|zsh|dash|ksh|csh|tcsh|fish|eval|xargs|source|\.)$/) segshell = 1 }
    seg = seg (seg == "" ? "" : "\037") pre w; pre = ""
  }
  word = ""; inw = 0
}
function emit(   k) {
  flush()
  if (seg != "") print seg
  # Un heredoc va a este comando si se declaró aquí o le llega por tubería.
  for (k = 1; k <= nh; k++) if (segshell && (hseg[k] == segid || hpipe[k] == 1)) hshell[k] = 1
  seg = ""; segshell = 0; segid = ++ids
}
function save() { sp++; st_seg[sp] = seg; st_word[sp] = word; st_pre[sp] = pre; st_inw[sp] = inw; st_sh[sp] = segshell; st_id[sp] = segid; seg = ""; word = ""; pre = ""; inw = 0; segshell = 0; segid = ++ids }
function restore() { seg = st_seg[sp]; word = st_word[sp]; pre = st_pre[sp]; inw = st_inw[sp]; segshell = st_sh[sp]; segid = st_id[sp]; sp-- }
function subst(kind) { save(); seq(kind); emit(); restore() }
function heredocs(   k, line, nl, t, body, sS, sN, sP) {
  # Los heredocs pendientes empiezan en la línea que sigue: cada cuerpo se
  # consume hasta su delimitador.
  for (k = 1; k <= nh; k++) {
    body = ""
    for (;;) {
      if (P > N) { open = 1; break }
      nl = index(substr(S, P), "\n"); if (nl == 0) nl = N - P + 2
      line = substr(S, P, nl - 1); t = line
      if (hstrip[k]) sub(/^\t+/, "", t)
      P += nl
      if (t == hdelim[k]) break
      body = body line "\n"
    }
    if (hshell[k]) { gsub(/\n/, "\036", body); print "\002" body }
    else if (!hquoted[k]) { sS = S; sN = N; sP = P; S = body; N = length(S); P = 1; expand(); S = sS; N = sN; P = sP }
  }
  nh = 0
}
function expand(   c) {
  # Lo que bash expande en un heredoc sin comillas: $(…), backticks y $((…)).
  while (P <= N) {
    c = substr(S, P, 1)
    if (c == "\\") { P += 2; continue }
    if (c == "`") { P++; subst("bt"); continue }
    if (substr(S, P, 3) == "$((") { P = arith(P + 1); continue }
    if (c == "$" && substr(S, P + 1, 1) == "(") { P += 2; subst("sub"); continue }
    P++
  }
}
function arith(p,   d, c) {
  # $(( … )): aritmética, no un comando.
  for (d = 0; p <= N; p++) { c = substr(S, p, 1); if (c == "(") d++; else if (c == ")" && --d == 0) return p + 1 }
  open = 1; return N + 1
}
function seq(kind,   c, j, d) {
  while (P <= N) {
    c = substr(S, P, 1)
    if (kind == "sub" && c == ")") { P++; return }
    if (kind == "bt" && c == "`") { P++; return }
    if (c == "\\") { P++; if (P <= N && substr(S, P, 1) != "\n") { word = word substr(S, P, 1); inw = 1 } P++; continue }
    if (c == "$" && substr(S, P + 1, 1) == "\047") {
      # $'…': comillas con escapes de barra.
      P += 2; inw = 1
      while (P <= N && substr(S, P, 1) != "\047") {
        if (substr(S, P, 1) == "\\") { P++; c = substr(S, P, 1); if (c == "n") c = "\n"; else if (c == "t") c = "\t"; word = word c; P++; continue }
        word = word substr(S, P, 1); P++
      }
      if (P > N) { open = 1; return }
      P++; continue
    }
    if (c == "\047") {
      j = index(substr(S, P + 1), "\047")
      if (j == 0) { open = 1; P = N + 1; return }
      word = word substr(S, P + 1, j - 1); inw = 1; P += j + 1; continue
    }
    if (c == "\"") {
      inw = 1; P++
      while (P <= N) {
        c = substr(S, P, 1)
        if (c == "\"") break
        if (c == "\\") { P++; word = word substr(S, P, 1); P++; continue }
        if (c == "`") { P++; subst("bt"); continue }
        if (substr(S, P, 3) == "$((") { P = arith(P + 1); continue }
        if (c == "$" && substr(S, P + 1, 1) == "(") { P += 2; subst("sub"); continue }
        word = word c; P++
      }
      if (P > N) { open = 1; return }
      P++; continue
    }
    if (substr(S, P, 3) == "$((") { inw = 1; P = arith(P + 1); continue }
    if (c == "$" && substr(S, P + 1, 1) == "(") { P += 2; subst("sub"); continue }
    if (c == "`") { P++; subst("bt"); continue }
    if (c == "#" && !inw) { while (P <= N && substr(S, P, 1) != "\n") P++; continue }
    if (c == " " || c == "\t") { flush(); P++; continue }
    if (c == "\n") { emit(); for (j = 1; j <= nh; j++) if (hpipe[j] == 1) hpipe[j] = 2; P++; if (nh) heredocs(); continue }
    if (c == ";" || c == "&" || c == "|" || c == "(" || c == ")") {
      if (c == "&" && substr(S, P + 1, 1) == ">") { flush(); pre = ">"; P += 2; while (substr(S, P, 1) == ">") P++; continue }
      d = segid; emit()
      if (c == "|" && substr(S, P + 1, 1) != "|") {
        # Una tubería lleva los heredocs de este comando a los siguientes.
        for (j = 1; j <= nh; j++) if (hseg[j] == d || hpipe[j] == 1) hpipe[j] = 1
        P++; if (substr(S, P, 1) == "&") P++
        continue
      }
      for (j = 1; j <= nh; j++) if (hpipe[j] == 1) hpipe[j] = 2
      P++; if (substr(S, P, 1) == c) P++
      continue
    }
    if (c == ">") { if (inw && word !~ /^[0-9]+$/) flush(); word = ""; inw = 0; pre = ">"; P++; while (substr(S, P, 1) ~ /[>|&]/) P++; continue }
    if (c == "<") {
      if (inw && word !~ /^[0-9]+$/) flush(); word = ""; inw = 0
      if (substr(S, P, 3) == "<<<") { pre = "<"; P += 3; continue }
      if (substr(S, P, 2) == "<<") {
        P += 2; d = ""; nh++
        hstrip[nh] = 0; hquoted[nh] = 0; hpipe[nh] = 0; hshell[nh] = 0; hseg[nh] = segid
        if (substr(S, P, 1) == "-") { hstrip[nh] = 1; P++ }
        while (substr(S, P, 1) ~ /[ \t]/) P++
        while (P <= N && substr(S, P, 1) !~ /[ \t\n;&|<>()]/) { c = substr(S, P, 1); if (c == "\047" || c == "\"" || c == "\\") hquoted[nh] = 1; else d = d c; P++ }
        hdelim[nh] = d
        continue
      }
      pre = "<"; P++; continue
    }
    word = word c; inw = 1; P++
  }
  if (kind != "") open = 1
}
{ S = S $0 "\n" }
END {
  N = length(S); P = 1; open = 0; nh = 0; sp = 0
  seg = ""; word = ""; pre = ""; inw = 0; segshell = 0; ids = 1; segid = 1
  seq(""); emit()
  if (nh) heredocs()
  if (open) print "\001abierto"
}'
}

manifests='^(package\.json|composer\.json|composer\.lock|composer\.phar|auth\.json|pnpm-lock\.yaml|pnpm-workspace\.yaml|\.npmrc|\.yarnrc\.yml|bunfig\.toml|\.pnpmfile\..*|\.trivyignore\.yaml|dependabot\.yml|dockerfile|\.semgrepignore)$'
policy_dirs='(^|/)(\.claude|\.github/workflows|\.github/scripts|\.semgrep)(/|$)'
globbed='[][{}*?]'
loose='(claude|github|semgrep|package|composer|lock|npmrc|pnpm|docker|trivy|dependabot)'
calls=0

protected() { # protected <ruta>: un manifiesto, un lockfile o la política
  [[ "${1##*/}" =~ $manifests || "$1" =~ $policy_dirs ]] && return 0
  # Con globs o llaves no se sabe qué archivo es: si se parece, cuenta.
  local bare="${1//[][{\}*?]/}"
  [[ "$1" =~ $globbed && "$bare" =~ $loose ]]
}

lockfile() { [[ "${1##*/}" =~ $lockfiles ]]; }

writes() { # writes <ruta>
  if lockfile "$1"; then flag 2 "escribe ${1}, un lockfile"; return 0; fi
  local bare="${1//[][{\}*?]/}"
  if [[ "$1" =~ $globbed && "$bare" =~ lock ]]; then flag 2 "escribe ${1}, que puede ser un lockfile"; return 0; fi
  protected "$1" && flag 1 "escribe ${1}: un manifiesto, un lockfile o la configuración de dependencias"
  return 0
}

# check_string <texto>: analiza un texto como una línea de shell.
check_string() {
  local line text="${1//$'\036'/$'\n'}" tokens
  local -a words
  if (( SECONDS > 10 )); then flag 1 "comando demasiado anidado para revisarlo"; return 0; fi
  tokens="$(tokenize "$text")"
  # Más de 1000 comandos simples no se revisan a tiempo: pregunta.
  if (( $(printf '%s\n' "$tokens" | wc -l) > 1000 )); then flag 1 "más de 1000 comandos en uno"; return 0; fi
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    if [[ "$line" == $'\001abierto' ]]; then flag 1 "comillas, \$( o un heredoc sin cerrar"; continue; fi
    if [[ "$line" == $'\002'* ]]; then check_string "${line#?}"; continue; fi
    IFS=$'\037' read -r -a words <<< "$line"
    check "${words[@]}"
  done <<< "$tokens"
}

# artisan <argumentos>: fuera de allow pregunta; install:api e
# install:broadcasting bajan paquetes de Composer y de npm (ADR-0026).
artisan() {
  local w
  for w in "$@"; do
    [[ "$w" == -* ]] && continue
    [[ "$w" == install:* ]] && { flag 2 "php artisan $w instala paquetes"; return 0; }
    break
  done
  flag 1 "php artisan está fuera de allow"
}

# check <palabras…>: un comando simple, sin comillas.
check() {
  local w prev="" last="" sub="" cmd args=() optw=()
  calls=$((calls + 1))
  # Anidado sin fin (corepack corepack …), o sin tiempo: pregunta.
  if (( calls > 200 || SECONDS > 10 )); then flag 1 "comando demasiado anidado para revisarlo"; return 0; fi
  # Destinos de redirección aparte, y una ruta protegida en --opción=ruta o
  # tras -o, --output u -O (git log --output, pest --log-junit, curl -o).
  for w in "$@"; do
    case "$w" in
      ">"*) writes "${w#>}" ;;
      "<"*|"") ;;
      *)
        [[ "$w" == --*=* ]] && optw[${#optw[@]}]="${w#*=}"
        [[ "$prev" == -o || "$prev" == --output || "$prev" == -O || "$prev" == --log-junit ]] && optw[${#optw[@]}]="$w"
        args[${#args[@]}]="$w" ;;
    esac
    prev="$w"
  done
  (( ${#args[@]} > 0 )) || return 0
  set -- "${args[@]}"

  # Asignaciones y envoltorios delante del comando, con sus opciones.
  while (( $# > 0 )); do
    w="${1##*/}"
    w="${w#=}" # =npx en zsh
    case "$w" in
      [A-Za-z_]*=*|nohup|then|do|else|if|while|until|"!"|"{"|"}"|noglob|nocorrect|builtin|coproc|herd) shift ;;
      command|time|caffeinate)
        [[ "$w" == command && ( "${2:-}" == -v || "${2:-}" == -V ) ]] && return 0
        shift
        while (( $# > 0 )) && [[ "$1" == -* ]]; do shift; done ;;
      arch)
        shift
        while (( $# > 0 )) && [[ "$1" == -* ]]; do [[ "$1" == -e || "$1" == -d ]] && shift; (( $# > 0 )) && shift; done ;;
      repeat) shift; (( $# > 0 )) && shift ;;
      script)
        shift
        while (( $# > 0 )) && [[ "$1" == -* ]]; do [[ "$1" == -t || "$1" == -T ]] && shift; (( $# > 0 )) && shift; done
        (( $# > 0 )) && shift ;;
      exec|sudo|nice|xargs|stdbuf|timeout|watch)
        shift
        while (( $# > 0 )) && [[ "$1" == -* ]]; do
          case "$1" in -a|-u|-g|-h|-n|-s|-k|-d|-I|-L|-P|-E|-C) shift ;; esac
          (( $# > 0 )) && shift
        done
        [[ "$w" == timeout ]] && (( $# > 0 )) && shift ;;
      env)
        shift
        while (( $# > 0 )) && [[ "$1" == -* || "$1" == *=* ]]; do
          case "$1" in
            -S|--split-string) shift; (( $# > 0 )) && { check_string "$1"; return 0; } ;;
            -u|-C|--unset|--chdir) shift ;;
          esac
          (( $# > 0 )) && shift
        done ;;
      *) break ;;
    esac
  done
  (( $# > 0 )) || return 0
  cmd="${1##*/}"
  cmd="${cmd#=}"
  cmd="${cmd%%@*}"
  cmd="${cmd%%:*}" # composer:2 en docker run
  shift
  # docker, git, curl y bin/city no son gestores: sus opciones no cuentan.
  case "$cmd" in
    docker|docker-compose|git|curl|city) ;;
    *) if (( ${#optw[@]} > 0 )); then for w in "${optw[@]}"; do writes "$w"; done; fi ;;
  esac

  # Escribir un manifiesto, un lockfile o la política por fuera de Edit.
  case "$cmd" in
    tee|rm|truncate|unlink|touch|sponge|chmod)
      for w in "$@"; do [[ "$w" == -* ]] || writes "$w"; done ;;
    cp|mv|install|ln|rsync)
      for w in "$@"; do
        [[ "$w" == -* ]] && continue
        last="$w"
        # Mover un lockfile lo saca: composer install sin él escribe otro.
        [[ "$cmd" == mv ]] && lockfile "$w" && flag 2 "mv saca ${w}, un lockfile"
      done
      [[ -z "$last" ]] || writes "$last"
      # A una carpeta (web/, ., ..), el archivo conserva su nombre.
      if [[ -n "$last" && ( "$last" == */ || "$last" == . || "$last" == .. || -d "${cwd:-.}/$last" || -d "$last" ) ]]; then
        for w in "$@"; do [[ "$w" == -* || "$w" == "$last" ]] || writes "${last%/}/${w##*/}"; done
      fi ;;
    awk|gawk|yq)
      for w in "$@"; do [[ "$w" == -i || "$w" == inplace ]] && last=1; done
      if [[ -n "$last" ]]; then for w in "$@"; do [[ "$w" == -* ]] || writes "$w"; done; fi ;;
    patch)
      for w in "$@"; do [[ "$w" == --dry-run ]] && return 0; done
      flag 2 "patch escribe archivos que el parche decide, también un lockfile" ;;
    sed|perl)
      for w in "$@"; do [[ "$w" =~ ^-[a-z0-9]*i || "$w" == --in-place* ]] && last=1; done
      if [[ -n "$last" ]]; then for w in "$@"; do [[ "$w" == -* ]] || writes "$w"; done; fi ;;
    dd)
      for w in "$@"; do [[ "$w" == of=* ]] && writes "${w#of=}"; done ;;
    tar|unzip|wget)
      for w in "$@"; do
        if lockfile "$w"; then flag 2 "$cmd puede escribir ${w}, un lockfile"; else protected "$w" && flag 1 "$cmd puede escribir ${w}"; fi
      done ;;
  esac

  case "$cmd" in
    sh|bash|zsh|dash|ksh|csh|tcsh|fish)
      while (( $# > 0 )); do
        if [[ "$1" == -*c* && "$1" != --* ]]; then shift; (( $# > 0 )) && check_string "$1"; return 0; fi
        shift
      done ;;
    eval) check_string "$*" ;;
    find)
      for w in "$@"; do lockfile "$w" && last=1; done
      if [[ -n "$last" ]]; then for w in "$@"; do [[ "$w" == -delete ]] && flag 2 "find borra un lockfile"; done; fi
      while (( $# > 0 )); do
        if [[ "$1" == -exec || "$1" == -execdir || "$1" == -ok || "$1" == -okdir ]]; then
          shift; args=()
          while (( $# > 0 )) && [[ "$1" != ";" && "$1" != + ]]; do args[${#args[@]}]="$1"; shift; done
          (( ${#args[@]} > 0 )) && check "${args[@]}"
        fi
        (( $# > 0 )) && shift
      done ;;
    corepack)
      case "${1:-}" in
        use|up) flag 2 "corepack $1 cambia packageManager en package.json" ;;
        *) check "$@" ;;
      esac ;;
    npx|pnpx|bunx) flag 2 "$cmd ejecuta un paquete sin el lockfile (ADR-0026)" ;;
    npm)
      # El subcomando es la primera palabra que npm conoce: una opción con
      # valor que no está en la lista no lo esconde.
      for w in "$@"; do
        [[ "$w" == -* ]] && continue
        if [[ "$w" =~ ^(install|i|in|ins|inst|insta|instal|isnt|isnta|isntal|isntall|add|ci|clean-install|ic|install-clean|isntall-clean|it|install-test|cit|install-ci-test|exec|x|create|init|innit|update|up|upgrade|udpate|uninstall|unlink|remove|rm|r|un|link|ln|dedupe|ddp|rebuild|rb|pkg|config|c|set|audit|run|run-script|test|t|ls|list|view|info|outdated|why|explain|help|version)$ ]]; then sub="$w"; break; fi
      done
      while (( $# > 0 )) && [[ "$1" != "$sub" ]]; do shift; done
      (( $# > 0 )) && shift
      case "$sub" in
        install|i|in|ins|inst|insta|instal|isnt|isnta|isntal|isntall|add|ci|clean-install|ic|install-clean|isntall-clean|it|install-test|cit|install-ci-test)
          flag 2 "npm $sub instala sin la política de pnpm (ADR-0026)" ;;
        exec|x|create) flag 2 "npm $sub ejecuta un paquete sin el lockfile (ADR-0026)" ;;
        init|innit)
          for w in "$@"; do
            if [[ "$w" != -* ]]; then flag 2 "npm $sub $w ejecuta un paquete sin el lockfile (ADR-0026)"; return 0; fi
          done
          flag 1 "npm $sub escribe package.json" ;;
        update|up|upgrade|udpate|uninstall|unlink|remove|rm|r|un|link|ln|dedupe|ddp)
          flag 2 "npm $sub cambia dependencias" ;;
        rebuild|rb) flag 2 "npm $sub corre scripts de dependencias sin la política de pnpm" ;;
        pkg|config|c|set)
          case "${1:-}" in set|delete|fix|edit) flag 1 "npm $sub $1 cambia la configuración o un manifiesto" ;; esac ;;
        audit) for w in "$@"; do [[ "$w" == fix ]] && flag 2 "npm audit fix cambia dependencias"; done ;;
      esac ;;
    pnpm|yarn|bun)
      local frozen=0 fix=0 info=0
      for w in "$@"; do
        [[ "$w" == -v || "$w" == --version || "$w" == -h || "$w" == --help ]] && info=1
        [[ "$w" == --frozen-lockfile ]] && frozen=1
        # --fix, --fix=update|override y --interactive aplican el arreglo.
        [[ "$w" == --fix || "$w" == --fix=* || "$w" == fix || "$w" == -i || "$w" == --interactive ]] && fix=1
      done
      # El subcomando es la primera palabra que el gestor conoce: una opción
      # con valor fuera de la lista (--filter-prod x, --depth 0) no lo esconde.
      for w in "$@"; do
        [[ "$w" == -* ]] && continue
        if [[ "$w" =~ ^(add|a|update|up|upgrade|remove|rm|uninstall|un|link|ln|unlink|import|patch|patch-commit|patch-remove|dedupe|global|approve-builds|rebuild|rb|self-update|recursive|multi|m|install|i|install-test|it|audit|config|c|pkg|set|exec|run|test|lint|build|ls|list|why|outdated|licenses|store|view|info|help|dlx|x|create|pm)$ ]]; then sub="$w"; break; fi
      done
      if [[ -n "$sub" ]]; then
        while (( $# > 0 )) && [[ "$1" != "$sub" ]]; do shift; done
        (( $# > 0 )) && shift
      else
        while (( $# > 0 )); do
          case "$1" in
            -C|--dir|--filter|-F|--prefix|--cwd|--workspace-dir|--reporter|--loglevel|--registry|--store-dir|--config|--modules-dir|--lockfile-dir) shift ;;
            -*) ;;
            *) sub="$1"; shift; break ;;
          esac
          (( $# > 0 )) && shift
        done
      fi
      case "$sub" in
        "") [[ "$cmd" == yarn && "$info" == 0 ]] && flag 2 "yarn sin subcomando instala y puede cambiar el lockfile" ;;
        dlx|x|create) flag 2 "$cmd $sub ejecuta un paquete sin el lockfile (ADR-0026)" ;;
        add|a|update|up|upgrade|remove|rm|uninstall|un|link|ln|unlink|import|patch|patch-commit|patch-remove|dedupe|global|approve-builds|rebuild|rb|self-update)
          flag 2 "$cmd $sub cambia dependencias o lo que pueden ejecutar" ;;
        # pnpm recursive add y pnpm m add: el subcomando real va después.
        recursive|multi|m) check "$cmd" "$@" ;;
        install|i|install-test|it)
          # Con un paquete, install es add (pnpm 11), con o sin --frozen-lockfile.
          for w in "$@"; do [[ "$w" == -* ]] || { flag 2 "$cmd $sub $w agrega una dependencia"; return 0; }; done
          (( frozen )) || flag 2 "$cmd $sub sin --frozen-lockfile puede cambiar el lockfile" ;;
        pm) [[ "${1:-}" == trust ]] && flag 2 "$cmd pm trust corre scripts de dependencias" ;;
        audit) (( fix == 0 )) || flag 2 "$cmd audit --fix escribe overrides" ;;
        config|c|pkg|set)
          case "${1:-}" in set|delete|edit) flag 1 "$cmd $sub $1 cambia la configuración o un manifiesto" ;; esac ;;
        exec)
          [[ "${1:-}" == -- ]] && shift
          check "$@" ;;
        run|test|lint|build|ls|list|why|outdated|licenses|store|view|info|help|-v|--version) ;;
        # Un subcomando que no es de pnpm ejecuta el binario local del mismo nombre.
        *) check "$sub" "$@" ;;
      esac ;;
    shadcn)
      # init y migrate también corren un add del gestor por dentro.
      for w in "$@"; do [[ "$w" == add || "$w" == init || "$w" == migrate ]] && flag 2 "shadcn $w instala dependencias"; done ;;
    playwright)
      # Limpia su carpeta de salida al empezar.
      for w in "$@"; do
        [[ "$w" == -o || "$w" == --output* || "$w" == -c || "$w" == --config* ]] && flag 1 "playwright con otra salida o configuración"
      done ;;
    composer)
      while (( $# > 0 )); do
        case "$1" in -d|--working-dir) shift ;; -*) ;; *) sub="$1"; shift; break ;; esac
        (( $# > 0 )) && shift
      done
      # Composer acepta alias (r, u, rm) y cualquier prefijo sin ambigüedad
      # (upg, rei, cr): un prefijo de estos se rechaza, también uno ambiguo.
      local t
      for t in require update upgrade remove uninstall reinstall bump global create-project; do
        [[ -n "$sub" && "$t" == "$sub"* ]] && { flag 2 "composer $sub cambia dependencias"; return 0; }
      done
      [[ "$sub" == r || "$sub" == rm ]] && { flag 2 "composer $sub cambia dependencias"; return 0; }
      if [[ "$sub" =~ ^(conf|confi|config)$ ]]; then
        for w in "$@"; do [[ "$w" == -l || "$w" == --list ]] && return 0; done
        flag 1 "composer config cambia composer.json"
      fi ;;
    docker|docker-compose)
      if [[ "$cmd" == docker ]]; then
        while (( $# > 0 )) && [[ "$1" == -* ]]; do
          case "$1" in -c|--context|-H|--host|--config|-l|--log-level) shift ;; esac
          (( $# > 0 )) && shift
        done
        [[ "${1:-}" == container ]] && shift
        # docker no decide: solo se revisa lo que corre en el contenedor.
        case "${1:-}" in
          exec)
            shift
            while (( $# > 0 )) && [[ "$1" == -* ]]; do
              case "$1" in -e|--env|-u|--user|-w|--workdir|--env-file) shift ;; esac
              (( $# > 0 )) && shift
            done
            (( $# > 0 )) && shift
            check "$@"; return 0 ;;
          run)
            # También --entrypoint.
            shift
            local entry=""
            while (( $# > 0 )) && [[ "$1" == -* ]]; do
              case "$1" in
                --entrypoint) shift; entry="${1:-}" ;;
                --entrypoint=*) entry="${1#*=}" ;;
                -e|--env|-u|--user|-w|--workdir|-v|--volume|--name|-p|--publish|--network|--platform|--mount|-l|--label|--env-file|--cap-drop|--cap-add|--security-opt|--tmpfs|-m|--memory|--cpus|--userns|--pull|-h|--hostname|--add-host|--dns|--device|--gpus|--ipc|--pid|--restart|--runtime|--shm-size|--stop-signal|--ulimit|--log-driver|--log-opt|--health-cmd|--cidfile|--group-add|--expose|--link|--memory-swap|--uts|--volumes-from|--isolation|--cgroupns) shift ;;
              esac
              (( $# > 0 )) && shift
            done
            [[ -z "$entry" ]] || { (( $# > 0 )) && shift; check "$entry" "$@"; return 0; }
            # Una opción con valor fuera de la lista correría la imagen un
            # lugar: se revisa desde cada palabra (la imagen lleva : o /).
            while (( $# > 0 )); do [[ "$1" == -* ]] || check "$@"; shift; done
            return 0 ;;
          compose) shift ;;
          *) return 0 ;;
        esac
      fi
      while (( $# > 0 )) && [[ "$1" == -* ]]; do
        case "$1" in
          -f|--file|-p|--project-name|--profile|--env-file|--project-directory|--ansi|--progress|--parallel) shift ;;
        esac
        (( $# > 0 )) && shift
      done
      sub="${1:-}"
      (( $# > 0 )) && shift
      case "$sub" in
        exec|run)
          local centry=""
          while (( $# > 0 )) && [[ "$1" == -* ]]; do
            case "$1" in
              --entrypoint) shift; centry="${1:-}" ;;
              --entrypoint=*) centry="${1#*=}" ;;
              -e|--env|-u|--user|-w|--workdir|--name|-v|--volume|-p|--publish|-l|--label) shift ;;
            esac
            (( $# > 0 )) && shift
          done
          (( $# > 0 )) && shift # el servicio
          if [[ -n "$centry" ]]; then check "$centry" "$@"; else check "$@"; fi ;;
      esac ;;
    artisan) artisan "$@" ;;
    php*)
      for w in "$@"; do
        if [[ "${w##*/}" == artisan ]]; then
          while (( $# > 0 )) && [[ "${1##*/}" != artisan ]]; do shift; done
          shift; artisan "$@"; return 0
        fi
        if [[ "${w##*/}" == composer* ]]; then
          while (( $# > 0 )) && [[ "${1##*/}" != composer* ]]; do shift; done
          shift; check composer "$@"; return 0
        fi
      done ;;
  esac
  return 0
}

check_string "$command"
decide
