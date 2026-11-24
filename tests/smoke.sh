#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

shopt -s nullglob
files=(
    bin/*.sh cli/*.sh cli/modules/*.sh
    lib/*.sh lib/core/*.sh lib/modules/*.sh lib/api/*.sh lib/api/routes/*.sh
    cgi-bin/*.cgi tests/*.sh tests/modules/*.sh
)
for file in "${files[@]}"; do
    [[ -s "$file" ]] || continue
    bash -n "$file"
done

bash tests/bootstrap_smoke.sh
printf 'PASS: pemeriksaan sintaks Bash selesai.\n'
