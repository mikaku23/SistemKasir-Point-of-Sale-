#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The smoke test must work when launched from any current working directory.
source "$ROOT/lib/bootstrap.sh"

required_functions=(
    product_create product_list product_find product_update product_delete
    transaction_create transaction_calculate_total dashboard_summary
    db_query db_escape db_transaction db_ping
)

for fn in "${required_functions[@]}"; do
    if ! declare -F "$fn" >/dev/null 2>&1; then
        printf 'FAIL: fungsi %s belum dimuat.\n' "$fn" >&2
        exit 1
    fi
done

source "$ROOT/cli/modules/products.sh"
declare -F cli_products_menu >/dev/null 2>&1 || {
    printf 'FAIL: cli_products_menu belum dimuat.\n' >&2
    exit 1
}

printf 'PASS: bootstrap memuat core, Products, Transactions, Dashboard, dan Products CLI.\n'
