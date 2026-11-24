#!/usr/bin/env bash
# MINI POS - Products CLI interface (owner: Bahram)
# This file only handles terminal interaction. Business logic remains in
# lib/modules/products.sh and is shared by CLI and Web/API.

cli_products__render_array() {
    local json="${1:-[]}"
    local count
    if ! jq -e 'type == "array"' >/dev/null 2>&1 <<< "$json"; then
        printf 'Respons Products bukan JSON array yang valid.\n' >&2
        return 1
    fi
    count="$(jq 'length' <<< "$json")"
    if [[ "$count" == 0 ]]; then
        printf 'Tidak ada barang yang ditemukan.\n'
        return 0
    fi

    printf '\n%-6s %-12s %-30s %14s %8s %10s %10s\n' 'ID' 'KODE' 'NAMA BARANG' 'HARGA' 'STOK' 'MIN.STOK' 'STATUS'
    printf '%s\n' '---------------------------------------------------------------------------------------------------------------'
    while IFS=$'\t' read -r id code name price stock min_stock active; do
        local status='Aktif'
        [[ "$active" == 1 ]] || status='Nonaktif'
        printf '%-6s %-12.12s %-30.30s %14s %8s %10s %10s\n' \
            "$id" "$code" "$name" "Rp${price}" "$stock" "$min_stock" "$status"
    done < <(jq -r '.[] | [(.id|tostring), .product_code, .name, (.price|tostring), (.stock|tostring), (.min_stock|tostring), (.is_active|tostring)] | @tsv' <<< "$json")
    printf '\nTotal: %s barang\n' "$count"
}

cli_products__show_one() {
    local json="${1:-}"
    jq -e 'type == "object"' >/dev/null 2>&1 <<< "$json" || { printf 'Data barang tidak valid.\n' >&2; return 1; }
    jq -r '"ID           : \(.id)",
           "Kode Barang  : \(.product_code)",
           "Nama Barang  : \(.name)",
           "Harga        : Rp\(.price)",
           "Stok         : \(.stock)",
           "Stok Minimum : \(.min_stock)",
           "Status       : \(if .is_active == 1 then "Aktif" else "Nonaktif" end)",
           "Dibuat       : \(.created_at)"' <<< "$json"
}

cli_products__list() {
    local status="${1:-active}" search="${2-}" low_stock="${3:-0}" result
    if result="$(product_list "$status" "$search" "$low_stock")"; then
        cli_products__render_array "$result"
    else
        printf 'Gagal menampilkan barang.\n' >&2
        return 1
    fi
}

cli_products__create() {
    local code name price min_stock result
    printf '\n========== TAMBAH BARANG =========\n'
    read -r -p 'Kode barang       : ' code
    read -r -p 'Nama barang       : ' name
    read -r -p 'Harga (Rupiah)    : ' price
    read -r -p 'Stok minimum      : ' min_stock

    if result="$(product_create "$code" "$name" "$price" "$min_stock")"; then
        printf '\nBarang berhasil ditambahkan. Stok awal ditetapkan 0; penambahan stok dilakukan melalui modul Inventory.\n'
        cli_products__show_one "$result"
    else
        printf 'Tambah barang gagal.\n' >&2
        return 1
    fi
}

cli_products__search() {
    local term status result
    printf '\n========== CARI BARANG =========\n'
    read -r -p 'Kode/nama barang : ' term
    read -r -p 'Status [active/inactive/all, default all]: ' status
    status="${status:-all}"
    if result="$(product_find --search "$term" "$status")"; then
        cli_products__render_array "$result"
    else
        printf 'Pencarian gagal.\n' >&2
        return 1
    fi
}

cli_products__update() {
    local id current code name price min_stock input updated
    printf '\n========== UBAH DATA BARANG =========\n'
    read -r -p 'ID barang yang akan diubah: ' id
    if ! current="$(product_find --id "$id")"; then
        printf 'Barang tidak ditemukan atau ID tidak valid.\n' >&2
        return 1
    fi
    printf '\nData saat ini:\n'
    cli_products__show_one "$current"

    code="$(jq -r '.product_code' <<< "$current")"
    name="$(jq -r '.name' <<< "$current")"
    price="$(jq -r '.price' <<< "$current")"
    min_stock="$(jq -r '.min_stock' <<< "$current")"

    printf '\nTekan Enter jika nilai tidak ingin diubah. Stok tidak diedit di menu ini.\n'
    read -r -p "Kode barang [$code]: " input; [[ -n "$input" ]] && code="$input"
    read -r -p "Nama barang [$name]: " input; [[ -n "$input" ]] && name="$input"
    read -r -p "Harga [$price]: " input; [[ -n "$input" ]] && price="$input"
    read -r -p "Stok minimum [$min_stock]: " input; [[ -n "$input" ]] && min_stock="$input"

    if updated="$(product_update "$id" "$code" "$name" "$price" "$min_stock")"; then
        printf '\nData barang berhasil diperbarui.\n'
        cli_products__show_one "$updated"
    else
        printf 'Perubahan barang gagal.\n' >&2
        return 1
    fi
}

cli_products__delete() {
    local id current confirm result
    printf '\n========== NONAKTIFKAN BARANG =========\n'
    read -r -p 'ID barang yang akan dinonaktifkan: ' id
    if ! current="$(product_find --id "$id")"; then
        printf 'Barang tidak ditemukan atau ID tidak valid.\n' >&2
        return 1
    fi
    printf '\nBarang yang dipilih:\n'
    cli_products__show_one "$current"
    read -r -p 'Yakin menonaktifkan barang ini? [y/N]: ' confirm
    case "$confirm" in
        y|Y|yes|YES)
            if result="$(product_delete "$id")"; then
                printf '\nBarang berhasil dinonaktifkan (soft delete).\n'
                cli_products__show_one "$result"
            else
                printf 'Gagal menonaktifkan barang.\n' >&2
                return 1
            fi
            ;;
        *) printf 'Penghapusan dibatalkan.\n' ;;
    esac
}

cli_products_menu() {
    local choice
    while :; do
        printf '\n==============================================\n'
        printf '             MANAJEMEN BARANG\n'
        printf '==============================================\n'
        printf '[1] Lihat barang aktif\n'
        printf '[2] Tambah barang\n'
        printf '[3] Cari barang\n'
        printf '[4] Ubah data barang\n'
        printf '[5] Nonaktifkan barang (soft delete)\n'
        printf '[6] Lihat semua barang\n'
        printf '[7] Lihat barang stok menipis\n'
        printf '[0] Kembali ke menu utama\n'
        printf '==============================================\n'
        read -r -p 'Pilih menu Products: ' choice
        case "$choice" in
            1) cli_products__list active || true ;;
            2) cli_products__create || true ;;
            3) cli_products__search || true ;;
            4) cli_products__update || true ;;
            5) cli_products__delete || true ;;
            6) cli_products__list all || true ;;
            7) cli_products__list active '' 1 || true ;;
            0) return 0 ;;
            *) printf 'Pilihan tidak dikenal.\n' >&2 ;;
        esac
    done
}
