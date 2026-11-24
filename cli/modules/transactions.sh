#!/usr/bin/env bash
cli_transactions_menu() {
    local add_more product_id quantity paid result rc
    local -a cart=()
    printf '\n========== TRANSAKSI PENJUALAN ==========\n'
    if declare -F product_list >/dev/null 2>&1; then
        printf 'Produk aktif (JSON):\n'
        product_list active | jq -r '.[] | "ID: \(.id) | \(.product_code) | \(.name) | Rp\(.price) | Stok: \(.stock)"'
    else
        printf 'Modul Products belum tersedia; masukkan ID produk dari database.\n'
    fi
    while :; do
        read -r -p 'ID produk (kosong untuk selesai): ' product_id
        [[ -n "$product_id" ]] || break
        read -r -p 'Jumlah: ' quantity
        [[ "$product_id" =~ ^[0-9]+$ && "$quantity" =~ ^[0-9]+$ && "$quantity" -gt 0 ]] || { printf 'ID/jumlah tidak valid.\n' >&2; continue; }
        cart+=("${product_id}:${quantity}")
    done
    (( ${#cart[@]} > 0 )) || { printf 'Keranjang kosong.\n'; return 0; }
    read -r -p 'Uang pembayaran (Rupiah): ' paid
    if result="$(transaction_create "$CLI_USER_ID" "$paid" "${cart[@]}")"; then rc=0; else rc=$?; fi
    if (( rc == 0 )); then
        printf '%s\n' "$result" | jq .
    else
        printf 'Transaksi tidak berhasil.\n' >&2
        return "$rc"
    fi
}
