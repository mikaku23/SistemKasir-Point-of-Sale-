#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/bootstrap.sh"
source "$ROOT/cli/login.sh"
source "$ROOT/cli/menu.sh"
source "$ROOT/cli/modules/products.sh"

# Optional transaction CLI is loaded only when its file exists.
if [[ -f "$ROOT/cli/modules/transactions.sh" ]]; then
    source "$ROOT/cli/modules/transactions.sh"
fi

command -v jq >/dev/null 2>&1 || { printf 'jq belum terpasang. Install jq terlebih dahulu.\n' >&2; exit 1; }
db_ping || { printf 'Database tidak dapat dihubungi. Periksa config/database.conf dan MySQL Client.\n' >&2; exit 1; }
cli_login || exit 1
cli_main_menu
