#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/bootstrap.sh"

printf '=== MINI POS — Setup Admin awal ===\n'
if ! db_ping; then
    printf 'Koneksi database gagal. Periksa config/database.conf dan MySQL Client.\n' >&2
    exit 1
fi
auth_setup_admin
