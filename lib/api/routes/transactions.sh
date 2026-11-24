#!/usr/bin/env bash
api_route_transactions_create() {
    local paid result rc product_id quantity
    local -a items=()
    paid="$(jq -r '.paid // empty' <<< "$API_JSON")"
    [[ "$paid" =~ ^[0-9]+$ ]] || { api_set_error 422 'Pembayaran harus berupa bilangan Rupiah bulat.'; return; }
    if ! jq -e '.items | type == "array" and length > 0' >/dev/null <<< "$API_JSON"; then
        api_set_error 422 'Keranjang wajib berisi minimal satu barang.'; return
    fi
    while IFS=$'\t' read -r product_id quantity; do
        [[ "$product_id" =~ ^[0-9]+$ && "$quantity" =~ ^[0-9]+$ ]] || { api_set_error 422 'Format item transaksi tidak valid.'; return; }
        items+=("${product_id}:${quantity}")
    done < <(jq -r '.items[] | [.product_id,.quantity] | @tsv' <<< "$API_JSON")
    result="$(transaction_create "$SESSION_USER_ID" "$paid" "${items[@]}")"; rc=$?
    if (( rc != 0 )); then api_set_error 422 'Transaksi gagal. Periksa barang, stok, pembayaran, atau relasi Admin.'; return; fi
    api_set_success 'Transaksi berhasil disimpan.' "$result"
}
