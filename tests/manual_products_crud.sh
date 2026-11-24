#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/bootstrap.sh"

for fn in product_create product_list product_find product_update product_delete; do
    declare -F "$fn" >/dev/null || { printf 'Fungsi %s belum tersedia.\n' "$fn" >&2; exit 1; }
done
command -v jq >/dev/null 2>&1 || { printf 'jq belum terpasang.\n' >&2; exit 1; }
db_ping || { printf 'Koneksi database gagal. Periksa config/database.conf.\n' >&2; exit 1; }

code="TEST-$(date +%Y%m%d%H%M%S)-$$"
name="Produk Uji O'Reilly"
printf '1) CREATE %s\n' "$code"
created="$(product_create "$code" "$name" 7500 3)"
id="$(jq -r '.id' <<< "$created")"
[[ "$id" =~ ^[0-9]+$ ]] || { printf 'ID hasil create tidak valid: %s\n' "$created" >&2; exit 1; }
printf '%s\n' "$created" | jq .

printf '\n2) DUPLICATE CODE MUST BE REJECTED\n'
if product_create "$code" 'Nama Duplikat' 1000 1 >/dev/null 2>&1; then
    printf 'FAIL: kode barang duplikat diterima.\n' >&2
    exit 1
else
    duplicate_rc=$?
    [[ "$duplicate_rc" == 4 ]] || { printf 'FAIL: expected return code 4, got %s.\n' "$duplicate_rc" >&2; exit 1; }
    printf 'PASS: kode barang duplikat ditolak.\n'
fi

printf '\n3) READ BY ID %s\n' "$id"
found="$(product_find --id "$id")"
[[ "$(jq -r '.name' <<< "$found")" == "$name" ]]
printf '%s\n' "$found" | jq .

printf '\n4) SEARCH\n'
searched="$(product_find --search "$code" all)"
jq -e --arg code "$code" 'any(.[]; .product_code == $code)' >/dev/null <<< "$searched"
printf '%s\n' "$searched" | jq .

printf '\n5) UPDATE\n'
updated="$(product_update "$id" "$code" 'Produk Uji Updated' 8000 4)"
[[ "$(jq -r '.price' <<< "$updated")" == 8000 ]]
printf '%s\n' "$updated" | jq .

printf '\n6) SOFT DELETE\n'
deleted="$(product_delete "$id")"
[[ "$(jq -r '.is_active' <<< "$deleted")" == 0 ]]
printf '%s\n' "$deleted" | jq .

printf '\n7) VERIFY INACTIVE LIST\n'
list="$(product_list inactive "$code")"
jq -e --arg code "$code" 'any(.[]; .product_code == $code and .is_active == 0)' >/dev/null <<< "$list"
printf 'PASS: Products CRUD (create/read/search/update/soft-delete + duplicate validation) berhasil. Record uji dibiarkan nonaktif.\n'
