#!/usr/bin/env bash
cli_main_menu() {
    local choice
    while :; do
        printf '\n====================================\n'
        printf '             MINI POS\n'
        printf '====================================\n'
        printf 'Admin: %s\n' "${CLI_USERNAME:-Admin}"
        printf '[1] Manajemen Barang\n'
        printf '[2] Pengelolaan Stok\n'
        printf '[3] Transaksi Penjualan\n'
        printf '[4] Riwayat Transaksi\n'
        printf '[5] Laporan Penjualan\n'
        printf '[0] Logout\n'
        printf '====================================\n'
        read -r -p 'Pilih menu: ' choice
        case "$choice" in
            1)
                if declare -F cli_products_menu >/dev/null 2>&1; then
                    cli_products_menu
                else
                    printf 'CLI Products belum dimuat. Periksa cli/modules/products.sh.\n' >&2
                fi
                ;;
            2) printf 'Modul Inventory dikerjakan Rafis dan belum dimuat.\n' ;;
            3)
                if declare -F cli_transactions_menu >/dev/null 2>&1; then cli_transactions_menu; else printf 'CLI Transactions belum dimuat.\n' >&2; fi
                ;;
            4) printf 'Modul History dikerjakan Hasan dan belum dimuat.\n' ;;
            5) printf 'Modul Reports dikerjakan Haikal dan belum dimuat.\n' ;;
            0) printf 'Logout berhasil.\n'; return 0 ;;
            *) printf 'Pilihan tidak dikenal.\n' >&2 ;;
        esac
    done
}
