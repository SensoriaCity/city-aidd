#!/usr/bin/env bash
# Prueba de plugins/city/scripts/dependency-guard.sh (S2-04, paso 4): cada caso de la
# fila "Agentes" de ADR-0026 y de su enmienda del 2026-10-02, con el JSON de PreToolUse por la entrada
# estándar, y la invocación de settings.json (`… || exit 2`) con el JSON roto
# o el hook ausente. Bash 3.2 o posterior y jq.
# Uso: bash plugins/city/scripts/dependency-guard.test.sh
# Los comandos van entre comillas simples a propósito: son texto para el hook.
# shellcheck disable=SC2016
set -euo pipefail

dir="${BASH_SOURCE[0]%/*}"
if [[ "$dir" == "${BASH_SOURCE[0]}" ]]; then dir="."; fi
hook="$(cd "$dir" && pwd)/dependency-guard.sh"

checks=0
failures=0

# decision <comando de Bash>: deny, ask o nada, según el hook.
decision() {
  local out
  out="$(jq -n --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}' | bash "$hook")" || { echo "salida $?"; return 0; }
  if [[ -z "$out" ]]; then echo nada; return 0; fi
  # Un deny sin el motivo de la enmienda (Belmar corre la línea) no cuenta.
  printf '%s' "$out" | jq -r '.hookSpecificOutput | if .permissionDecision == "deny" and (.permissionDecisionReason | contains("Belmar") | not) then "deny sin Belmar" else .permissionDecision end'
}

# expect <esperado> <comando>
expect() {
  local got name
  checks=$((checks + 1))
  got="$(decision "$2")"
  name="${2//$'\n'/ ⏎ }"
  if [[ "$got" == "$1" ]]; then
    printf 'ok     %-5s %s\n' "$1" "$name"
  else
    failures=$((failures + 1))
    printf 'FALLA  %-5s %s (obtuvo %s)\n' "$1" "$name" "$got"
  fi
}

# Los cinco de deny, y sus alias e indirecciones.
expect deny 'npx shadcn add button'
expect deny 'pnpx create-vite'
expect deny 'pnpm dlx shadcn@latest add button'
expect deny 'npm install left-pad'
expect deny 'npm exec cowsay'
expect deny 'npm i left-pad'
expect deny 'npm ci'
expect deny 'yarn dlx cowsay'
expect deny 'bunx cowsay'
expect deny 'corepack pnpm -C web dlx shadcn add button'
expect deny 'cd web && npx vitest'
expect deny "sh -c 'npx cowsay'"
expect deny 'eval "npm install x"'
expect deny 'echo $(npx cowsay)'
expect deny 'docker compose exec app npx cowsay'
expect deny 'FOO=1 /usr/local/bin/npx cowsay'
expect deny 'npm create vite'
expect deny 'npm init vite'
expect deny 'pnpm create vite'
expect deny 'yarn create vite'
expect deny 'corepack pnpm@9 dlx cowsay'
expect deny 'corepack npm@10 install left-pad'
expect deny $'npm \\\ninstall left-pad'
expect deny 'NPX cowsay'
expect deny '\npx cowsay'
expect deny "n''px cowsay"
expect deny 'env -u FOO npx cowsay'
expect deny 'command -p npx cowsay'
expect deny 'nice -n 10 npx cowsay'
expect deny 'timeout -s KILL 5 npx cowsay'
expect deny 'xargs -n 1 npx'
expect deny 'sudo -u root npx cowsay'
expect deny 'docker run --rm node:24 npx cowsay'
expect deny 'gh pr create --body "corre `npx cowsay`"'
expect deny $'bash <<\'EOF\'\nnpx cowsay\nEOF'
# Lo que el tokenizador no debe dejar como texto (segunda revisión de #107).
expect deny $'echo hola # it\'s\nnpx cowsay'
expect deny $'cat <<< x\nnpx cowsay'
expect deny $'echo \'<<EOF\'\nnpx cowsay'
expect deny $'echo $((1<<2))\nnpx cowsay'
expect deny $'echo "$(echo \')\'; npx cowsay)"'
expect deny $'cat <<X | "bash"\nnpx cowsay\nX'
expect deny $'cat <<X | BASH\nnpx cowsay\nX'
expect deny $'source /dev/stdin <<X\nnpx cowsay\nX'
expect deny '/usr/bin/env npx cowsay'
expect deny '/usr/bin/time npx cowsay'
expect deny 'ENV npx cowsay'
expect deny 'SUDO npx cowsay'
expect deny '=npx cowsay'
expect deny 'noglob npx cowsay'
expect deny 'nocorrect npx cowsay'
expect deny 'repeat 1 npx cowsay'
expect deny 'caffeinate -i npx cowsay'
expect deny 'arch -arm64 npx cowsay'
expect deny 'script -q /dev/null npx cowsay'
expect deny 'find . -name x -exec npx cowsay {} ;'
expect deny 'builtin command npx cowsay'
expect deny "tcsh -c 'npx cowsay'"
expect deny 'docker run --entrypoint npx node:24 cowsay'
expect deny 'docker run --hostname h node:24 npx cowsay'
expect deny 'npm --before 2020-01-01 install left-pad'
# Tercera revisión de #107: heredocs que desincronizaban o se expandían.
expect deny $'cat <<\'EOF\' | gh pr comment 107 --body-file -\nIt\'s done\nEOF\nnpx cowsay # it\'s'
expect deny $'php <<\'EOF\'\n<?php // don\'t\nEOF\nnpm install left-pad # that\'s it'
expect deny $'cat <<EOF > /tmp/x.md\n$(npm install left-pad)\nEOF'
expect deny $'gh pr comment 107 --body-file - <<EOF\nUsa `npx cowsay`\nEOF'
expect deny $'echo $\'don\\\'t\' && npx cowsay # it\'s'
expect deny 'docker run --rm --pids-limit 100 node:22 npx cowsay'
expect deny 'docker run --sysctl k=v node:22 npm install'
# Verificación de la tercera: heredocs a un shell detrás de un envoltorio.
expect deny $'docker run -i --rm node:22 bash <<\'EOF\'\nnpx cowsay\nEOF'
expect deny $'cat <<\'EOF\' | docker run -i --rm node:22 bash\nnpx cowsay\nEOF'
expect deny $'sudo bash <<\'EOF\'\nnpx cowsay\nEOF'
expect deny $'timeout 60 bash <<\'EOF\'\nnpx cowsay\nEOF'
expect deny $'cat <<\'EOF\' | env -i bash\nnpx cowsay\nEOF'
expect deny $'cat <<\'EOF\' | tr a a | bash\nnpx cowsay\nEOF'
expect deny $'echo x | cat <<\'EOF\' | sh\nnpx cowsay\nEOF'
expect deny $'cat <<\'EOF\' | gh api x | bash\nnpx cowsay\nEOF'
expect deny $'bash -c $\'echo x\\nnpx cowsay\''

# Lo que cambia dependencias o escribe un lockfile, de ask a deny (ADR-0026,
# enmienda del 2026-10-02), con alias, -C web, corepack pnpm, sh -c, eval,
# $(…) y docker compose exec o run. Cada deny lleva "Belmar" en el motivo.
expect deny 'pnpm add zod'
expect deny 'corepack pnpm -C web add zod'
expect deny 'pnpm --filter @city/ui add -D zod'
expect deny 'pnpm up'
expect deny 'pnpm remove zod'
expect deny 'pnpm install'
expect deny 'yarn add zod'
expect deny 'bun add zod'
expect deny 'npm update'
expect deny 'composer require laravel/fortify:^1.40.0'
expect deny 'composer req laravel/fortify'
expect deny 'composer -d api update'
expect deny 'composer remove laravel/pail'
expect deny 'corepack pnpm -C web exec shadcn add button'
expect deny "bash -c 'cd web && pnpm add zod'"
expect deny 'eval "composer require x/y"'
expect deny 'x=$(pnpm add zod)'
expect deny 'docker compose exec app composer require x/y'
expect deny 'cp /tmp/x pnpm-lock.yaml'
expect deny 'corepack pnpm -C web shadcn add button'
expect deny 'pnpm --filter @city/ui shadcn add button'
expect deny 'pnpm -C web exec shadcn@latest add button'
expect deny 'pnpm --reporter silent add zod'
expect deny 'npm --loglevel silent update'
expect deny 'corepack pnpm -C web audit --fix'
expect deny 'pnpm approve-builds'
expect deny 'corepack use pnpm@12'
expect deny 'yarn'
expect deny '"$HOME/Library/Application Support/Herd/bin/composer" require x/y'
expect deny $'git commit -F - <<EOF\nfix: usa `pnpm add zod`\nEOF'
expect deny 'php composer.phar require x/y'
expect deny 'pnpm dedupe'
expect deny 'pnpm link ../x'
expect deny 'pnpm import'
expect deny 'pnpm patch zod'
expect deny 'pnpm patch-commit /tmp/x'
expect deny 'pnpm global add zod'
expect deny 'pnpm rebuild'
expect deny 'yarn upgrade'
expect deny 'bun update'
expect deny 'npm uninstall zod'
expect deny 'npm dedupe'
expect deny 'npm audit fix'
expect deny 'composer global require x/y'
expect deny 'composer create-project laravel/laravel x'
expect deny 'composer bump'
expect deny 'composer reinstall x/y'
expect deny 'corepack up'
expect deny 'docker compose run --rm app composer update'
expect deny 'docker compose exec -T app pnpm add zod'
expect deny "sh -c 'corepack pnpm -C web install'"
expect deny 'echo x > web/pnpm-lock.yaml'
expect deny "sed -i '' 's/a/b/' api/composer.lock"
expect deny 'tee package-lock.json'
expect deny 'mv /tmp/x yarn.lock'
# Revisión de seguridad de #134: alias, prefijos y caminos de accidente.
expect deny 'php artisan install:api'
expect deny 'php artisan --no-interaction install:broadcasting'
expect deny 'docker compose exec app php artisan install:api'
expect deny 'herd php artisan install:api'
expect deny './artisan install:broadcasting'
expect deny 'pnpm audit --fix=update'
expect deny 'corepack pnpm -C web audit --fix=override'
expect deny 'pnpm audit --interactive'
expect deny 'pnpm audit -i'
expect deny 'composer r x/y'
expect deny 'composer -d api r x/y'
expect deny 'composer upg'
expect deny 'composer rei x/y'
expect deny 'composer bu'
expect deny 'composer gl require x/y'
expect deny 'composer cr laravel/laravel x'
expect deny 'herd composer require x/y'
expect deny 'pnpm install-test'
expect deny 'pnpm it'
expect deny 'pnpm self-update 12.0.0'
expect deny 'pnpm recursive add zod'
expect deny 'pnpm m add zod'
expect deny 'mv api/composer.lock api/composer.lock.bak'
expect deny 'find api -name composer.lock -delete'
expect deny 'docker run --rm -v "$PWD/api:/app" composer:2 require x/y'
expect deny 'docker run --rm composer/composer:2.10 update'
expect deny 'patch -p1 < x.diff'
expect deny 'pnpm exec shadcn init'
expect deny 'npm rebuild'
expect deny 'npm rb'
expect deny 'awk -i inplace 1 web/pnpm-lock.yaml'
expect deny 'yq -i .x web/pnpm-lock.yaml'
expect ask 'php artisan migrate --force'
expect nada 'composer validate --strict'
expect nada 'composer install --no-scripts'
expect nada 'composer dump-autoload'
expect nada 'composer show'
expect nada 'find api -name composer.lock'
expect nada 'git mv docs/a.md docs/b.md'
# Revisión del revisor de #134: alias, opciones con valor y carpetas.
expect deny 'pnpm rb'
expect deny 'bun a zod'
expect deny 'pnpm multi update'
expect deny 'composer g require x/y'
expect deny 'composer glob require x/y'
expect deny 'composer create x/y'
expect deny 'composer reins x/y'
expect deny 'composer uni x/y'
expect deny 'composer uninst x/y'
expect deny 'cp ../x/web/pnpm-lock.yaml web/'
expect deny 'mv /tmp/composer.lock api/'
expect deny 'cp /tmp/pnpm-lock.yaml .'
expect deny 'pnpm --filter-prod @city/ui add zod'
expect deny 'pnpm --workspace-concurrency 1 add zod'
expect deny 'pnpm --depth 0 update'
expect deny 'pnpm install --frozen-lockfile zod'
expect deny 'docker compose run --rm --entrypoint composer app require x/y'
expect deny 'patch web/pnpm-lock.yaml x.diff'
expect deny 'bun pm trust zod'
expect deny 'pnpm patch-remove zod'
expect deny 'echo x > web/pnpm-lock.y*ml'
expect deny 'watch pnpm add zod'
expect deny 'wget https://example.invalid/pnpm-lock.yaml'
expect nada 'patch --dry-run -p1 x.diff'
expect nada 'yarn --version'
expect nada 'yarn -v'
expect nada 'curl -sS https://example.invalid/pnpm-lock.yaml'
expect nada 'git am --abort'
expect nada 'cp web/pnpm-lock.yaml /tmp/lock.bak'
expect nada 'corepack pnpm -C web exec vitest run'
expect nada 'git apply --check x.patch'
expect nada 'git apply --stat x.patch'
expect nada 'git am --show-current-patch'

# Lo de ask, también con alias, -C web, corepack pnpm, sh -c, eval, $(…) y
# docker compose exec o run.
expect ask 'php artisan tinker'
expect ask 'php artisan migrate'
expect ask '"$HOME/Library/Application Support/Herd/bin/php84" artisan migrate'
expect ask "sed -i '' 's/1.0/2.0/' web/package.json"
expect ask 'echo {} > api/composer.json'
expect ask 'pnpm config set registry https://example.invalid/'
expect ask 'npm pkg set scripts.x=y'
expect ask 'composer config allow-plugins.x/y true'
expect ask 'php -d memory_limit=-1 artisan migrate'
expect ask 'PHP artisan migrate'
expect ask "sed -i '' 's/a/b/' .claude/settings.json"
expect ask 'echo "exit 0" > .claude/hooks/dependency-guard.sh'
expect ask 'cp /tmp/x .github/workflows/ci.yml'
expect ask 'rm -rf .semgrep'
expect ask 'echo x >> web/package.json'
expect ask 'echo {} > "api/composer.json"'
expect ask 'printf x >| web/package.json'
expect ask 'jq . x 2>/dev/null > web/package.json'
expect ask 'jq . x | sponge web/package.json'
expect ask 'corepack pnpm -C web exec playwright test --output=../.claude'
expect ask "sed -Ei '' 's/a/b/' .claude/settings.json"
expect ask "perl -0pi -e 's/a/b/' .claude/settings.json"
expect ask "sed -i '' 's/a/b/' .c[l]aude/settings.json"
expect ask 'rm {.claude,x}/settings.json'
expect ask 'vendor/bin/pest --log-junit=.claude/settings.json'
expect ask "echo 'sin cerrar"
expect ask 'echo "$(ls'
expect ask "$(printf 'corepack %.0s' $(seq 300)) true"
# Lo que no se revisa antes del timeout de settings.json pregunta.
expect ask "$(printf 'echo a;%.0s' $(seq 1001))"
expect ask "echo $(printf '%070000d' 0)"

# docker, git, curl y bin/city nunca deciden por sí mismos: solo el gestor
# que corran. goal.sh baja la instalación con `docker compose down -v`.
expect nada 'docker compose down -v'
expect nada 'docker compose --profile onprem down -v'
expect nada 'docker compose up -d'
expect nada 'docker compose config'
expect nada 'docker compose exec -T app sh'
expect nada 'docker exec -it city-app-1 sh'
expect nada 'docker --context remoto compose up -d'
expect nada 'bin/city install --output=.claude/settings.json'
expect nada 'curl -O https://example.invalid/pnpm-lock.yaml'
expect nada 'curl -o .claude/hooks/dependency-guard.sh https://example.invalid/x'
expect nada 'git apply x.patch'
expect nada 'git restore api/composer.lock'
expect nada 'git checkout -b x 9eb514d'
expect nada 'git diff --output .claude/settings.json'
expect deny 'docker compose --profile onprem exec app pnpm add zod'

# Lo que sigue a las reglas de settings.json sin pasar por el hook.
expect nada 'corepack pnpm -C web install --frozen-lockfile'
expect nada 'corepack pnpm -C web lint'
expect nada 'corepack pnpm -C web audit --audit-level high'
expect nada 'corepack pnpm -C web exec playwright test'
expect nada 'docker compose ps'
expect nada 'docker compose logs app'
expect nada 'docker compose -f docker-compose.yml config --quiet'
expect nada 'docker compose config --services'
expect nada 'vendor/bin/pest --ci'
expect nada 'composer audit'
expect nada 'composer validate --strict'
expect nada 'bin/city smoke'
expect nada 'git commit -m "npx y npm install quedan en deny"'
expect nada 'cat web/package.json'
expect nada 'jq .version web/package.json'
expect nada 'grep -n npx docs/adr/ADR-0026-cadena-de-suministro.md'
expect nada $'git commit -F - <<\'EOF\'\nfeat: rechaza npx; npm install pregunta\nEOF'
expect nada $'git commit -m "$(cat <<\'EOF\'\nRechaza npx y npm install | pnpm dlx\nEOF\n)"'
expect nada "grep -rn 'npx\\|pnpx' docs"
expect nada "rg 'npx|pnpm dlx' docs"
expect nada 'sed -n 1,40p web/package.json'
expect nada 'cp web/pnpm-lock.yaml /tmp/x'
expect nada 'composer config --list'
expect nada 'git checkout -b feat/2026-10-01-x'
expect nada 'git checkout -b feat/x origin/main'
expect nada $'cat <<\'EOF\' | gh pr comment 107 --body-file -\nBelmar\'s PR\nEOF'
expect nada $'node <<\'EOF\'\n// it\'s\nEOF'
expect nada $'git commit -F - <<EOF\nfix: rechaza npx en $HOME\nEOF'
expect nada 'command -v npx'
expect nada 'git restore --staged .claude/settings.json'
expect nada $'cat <<\'EOF\' | gh pr comment 1 --body-file -; bash bin/city.test.sh\nnpx y npm install, en texto\nEOF'
expect nada $'cat <<A || bash bin/city.test.sh\nnpx en texto\nA'
expect nada $'/bin/bash <<\'EOF\'\ncorepack pnpm -C web lint\nvendor/bin/pest --ci\nEOF'
expect nada $'git commit -m "$(cat <<\'EOF\'\nfix: it\'s done (yes) y npx queda en deny\nEOF\n)"'
expect nada $'gh pr create --body-file - <<\'EOF\'\nRechaza `npx` y $(npm install)\nEOF'
expect nada 'echo hola # npx cowsay'
expect nada 'echo $((2 + 3))'
expect nada 'docker run --rm -v "$PWD:/w:ro" -w /w ubuntu:24.04 bash bin/city.test.sh'
expect nada 'corepack pnpm -C web lint && corepack pnpm -C web test'

# Edit, Write, MultiEdit y NotebookEdit: el hook rechaza un lockfile; lo
# demás va por settings.json.
# tool <esperado> <herramienta> <campo> <ruta>
tool() {
  local got
  checks=$((checks + 1))
  got="$(jq -n --arg t "$2" --arg f "$3" --arg p "$4" '{tool_name: $t, tool_input: {($f): $p}}' | bash "$hook" |
    jq -r 'if .hookSpecificOutput.permissionDecisionReason | contains("Belmar") then .hookSpecificOutput.permissionDecision else "sin Belmar" end')"
  [[ -n "$got" ]] || got=nada
  if [[ "$got" == "$1" ]]; then printf 'ok     %-5s %s %s\n' "$1" "$2" "$4"; else
    failures=$((failures + 1)); printf 'FALLA  %-5s %s %s (obtuvo %s)\n' "$1" "$2" "$4" "$got"; fi
}
tool deny Edit file_path web/pnpm-lock.yaml
tool deny Write file_path /Users/x/city/api/composer.lock
tool deny MultiEdit file_path package-lock.json
tool deny Edit file_path web/YARN.LOCK
tool deny NotebookEdit notebook_path x/bun.lock
tool deny Write file_path bun.lockb
tool nada Edit file_path web/package.json
tool nada Write file_path docs/pnpm-lock.yaml.md
tool nada Read file_path web/pnpm-lock.yaml

# Falla cerrado, como lo invoca settings.json.
# fails_closed <nombre> <entrada> <ruta del hook>
fails_closed() {
  local code=0
  checks=$((checks + 1))
  printf '%s' "$2" | bash -c "bash \"\$1\" || exit 2" _ "$3" >/dev/null 2>&1 || code=$?
  if [[ "$code" == 2 ]]; then
    printf 'ok     sale 2 %s\n' "$1"
  else
    failures=$((failures + 1))
    printf 'FALLA  sale 2 %s (salió %s)\n' "$1" "$code"
  fi
}
fails_closed 'con el JSON roto' '{"tool_name": "Bash", "tool_input": {' "$hook"
fails_closed 'sin tool_input.command' '{"tool_name": "Bash"}' "$hook"
fails_closed 'con el hook ausente' '{"tool_name":"Bash","tool_input":{"command":"npx x"}}' "$hook.no-existe"

printf '\n%s de %s casos en verde (bash %s, %s)\n' "$((checks - failures))" "$checks" "$BASH_VERSION" "$(jq --version)"
(( failures == 0 ))
