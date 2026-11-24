#!/usr/bin/env bash
# MINI POS - Products business logic
# Owner: Bahram
# Requires lib/core/db.sh to be loaded first (db_query and db_escape).
# Contract: functions return JSON data on stdout; diagnostics go to stderr.

[[ "${_MINI_POS_PRODUCTS_LOADED:-0}" == "1" ]] && return 0
_MINI_POS_PRODUCTS_LOADED=1

product__error() { printf 'products: %s\n' "$1" >&2; }

product__require_db() {
    declare -F db_query >/dev/null 2>&1 || { product__error 'db_query() belum tersedia. Muat lib/bootstrap.sh terlebih dahulu.'; return 1; }
    declare -F db_escape >/dev/null 2>&1 || { product__error 'db_escape() belum tersedia di lib/core/db.sh.'; return 1; }
}

# Validate and normalize unsigned decimal numbers without Bash integer overflow.
product__normalize_uint() {
    local value="${1-}" maximum="${2-18446744073709551615}"
    [[ "$value" =~ ^[0-9]+$ ]] || return 1
    while [[ ${#value} -gt 1 && ${value:0:1} == '0' ]]; do value="${value:1}"; done
    (( ${#value} <= ${#maximum} )) || return 1
    if (( ${#value} == ${#maximum} )) && [[ "$value" > "$maximum" ]]; then return 1; fi
    printf '%s' "$value"
}

product__validate_text() {
    local label="${1-}" value="${2-}" maximum="${3-120}"
    [[ -n "${value//[[:space:]]/}" ]] || { product__error "$label wajib diisi."; return 1; }
    [[ ! "$value" =~ [[:cntrl:]] ]] || { product__error "$label tidak boleh mengandung karakter kontrol/baris baru."; return 1; }
    (( ${#value} <= maximum )) || { product__error "$label maksimal $maximum karakter."; return 1; }
}

product__query_scalar() {
    local output
    output="$(db_query "$1")" || return 2
    output="${output//$'\r'/}"
    output="${output//$'\n'/}"
    output="${output//[[:space:]]/}"
    printf '%s' "$output"
}

product__select_by_id() {
    local product_id="$1" result
    result="$(db_query "SELECT JSON_OBJECT(
        'id', id, 'product_code', product_code, 'name', name,
        'price', price, 'stock', stock, 'min_stock', min_stock,
        'is_active', is_active, 'created_at', created_at, 'updated_at', updated_at
    ) FROM products WHERE id = ${product_id} LIMIT 1;")" || { product__error 'gagal mengambil data barang.'; return 2; }
    [[ -n "$result" ]] || { product__error "barang dengan ID ${product_id} tidak ditemukan."; return 3; }
    printf '%s\n' "$result"
}

# product_create PRODUCT_CODE NAME PRICE MIN_STOCK; stock starts at zero.
product_create() {
    (( $# == 4 )) || { product__error 'penggunaan: product_create <product_code> <name> <price> <min_stock>'; return 1; }
    local product_code="$1" name="$2" price min_stock escaped_code escaped_name duplicate result
    product__validate_text 'product_code' "$product_code" 40 || return 1
    product__validate_text 'name' "$name" 120 || return 1
    price="$(product__normalize_uint "$3" '18446744073709551615')" || { product__error 'price harus bilangan bulat Rupiah yang valid.'; return 1; }
    min_stock="$(product__normalize_uint "$4" '4294967295')" || { product__error 'min_stock harus bilangan bulat yang valid.'; return 1; }
    product__require_db || return 1
    escaped_code="$(db_escape "$product_code")" || { product__error 'gagal mengamankan product_code.'; return 1; }
    escaped_name="$(db_escape "$name")" || { product__error 'gagal mengamankan name.'; return 1; }
    duplicate="$(product__query_scalar "SELECT EXISTS(SELECT 1 FROM products WHERE product_code='${escaped_code}');")" || { product__error 'gagal memeriksa kode barang.'; return 2; }
    if [[ "$duplicate" == 1 ]]; then
        product__error "kode barang '${product_code}' sudah digunakan."
        return 4
    fi
    [[ "$duplicate" == 0 ]] || { product__error 'hasil pemeriksaan duplikasi tidak valid.'; return 2; }
    db_query "INSERT INTO products (product_code,name,price,stock,min_stock,is_active) VALUES ('${escaped_code}','${escaped_name}',${price},0,${min_stock},1);" >/dev/null || { product__error 'gagal menambahkan barang ke database.'; return 2; }
    result="$(db_query "SELECT JSON_OBJECT('id',id,'product_code',product_code,'name',name,'price',price,'stock',stock,'min_stock',min_stock,'is_active',is_active,'created_at',created_at,'updated_at',updated_at) FROM products WHERE product_code='${escaped_code}' LIMIT 1;")" || { product__error 'barang tersimpan tetapi gagal dibaca kembali.'; return 2; }
    [[ -n "$result" ]] || { product__error 'barang tidak ditemukan setelah penyimpanan.'; return 2; }
    printf '%s\n' "$result"
}

# product_list [active|inactive|all] [search] [low_stock:0|1]
product_list() {
    (( $# <= 3 )) || { product__error 'penggunaan: product_list [active|inactive|all] [search] [low_stock:0|1]'; return 1; }
    local status="${1:-active}" search="${2-}" low_stock="${3:-0}" status_sql='' search_sql='' low_sql='' escaped result
    case "$status" in active) status_sql=' AND is_active=1';; inactive) status_sql=' AND is_active=0';; all) ;; *) product__error 'status harus active, inactive, atau all.'; return 1;; esac
    case "$low_stock" in 0) ;; 1) low_sql=' AND stock <= min_stock';; *) product__error 'low_stock hanya boleh 0 atau 1.'; return 1;; esac
    [[ -z "$search" ]] || product__validate_text 'search' "$search" 120 || return 1
    product__require_db || return 1
    if [[ -n "$search" ]]; then
        escaped="$(db_escape "$search")" || { product__error 'gagal mengamankan kata pencarian.'; return 1; }
        search_sql=" AND (LOCATE('${escaped}',product_code)>0 OR LOCATE('${escaped}',name)>0)"
    fi
    result="$(db_query "SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT('id',id,'product_code',product_code,'name',name,'price',price,'stock',stock,'min_stock',min_stock,'is_active',is_active,'created_at',created_at,'updated_at',updated_at)),JSON_ARRAY()) FROM products WHERE 1=1${status_sql}${search_sql}${low_sql};")" || { product__error 'gagal mengambil daftar barang.'; return 2; }
    printf '%s\n' "${result:-[]}"
}

# product_find --id ID | --search TERM [active|inactive|all] | TERM
product_find() {
    local mode value status='all' status_sql='' escaped result product_id
    if (( $# == 1 )); then mode='--search'; value="$1"
    elif (( $# == 2 )) && [[ "$1" == '--id' ]]; then mode='--id'; value="$2"
    elif (( $# == 2 )) && [[ "$1" == '--search' ]]; then mode='--search'; value="$2"
    elif (( $# == 3 )) && [[ "$1" == '--search' ]]; then mode='--search'; value="$2"; status="$3"
    else product__error 'penggunaan: product_find --id <id> | --search <term> [active|inactive|all]'; return 1
    fi
    product__require_db || return 1
    if [[ "$mode" == '--id' ]]; then
        product_id="$(product__normalize_uint "$value" '18446744073709551615')" || { product__error 'ID barang tidak valid.'; return 1; }
        product__select_by_id "$product_id"; return $?
    fi
    product__validate_text 'search' "$value" 120 || return 1
    case "$status" in active) status_sql=' AND is_active=1';; inactive) status_sql=' AND is_active=0';; all) ;; *) product__error 'status harus active, inactive, atau all.'; return 1;; esac
    escaped="$(db_escape "$value")" || { product__error 'gagal mengamankan kata pencarian.'; return 1; }
    result="$(db_query "SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT('id',id,'product_code',product_code,'name',name,'price',price,'stock',stock,'min_stock',min_stock,'is_active',is_active,'created_at',created_at,'updated_at',updated_at)),JSON_ARRAY()) FROM products WHERE (LOCATE('${escaped}',product_code)>0 OR LOCATE('${escaped}',name)>0)${status_sql};")" || { product__error 'gagal mencari barang.'; return 2; }
    printf '%s\n' "${result:-[]}"
}

# product_update ID PRODUCT_CODE NAME PRICE MIN_STOCK; stock is managed by Inventory.
product_update() {
    (( $# == 5 )) || { product__error 'penggunaan: product_update <id> <product_code> <name> <price> <min_stock>'; return 1; }
    local product_id code="$2" name="$3" price min_stock escaped_code escaped_name duplicate current
    product_id="$(product__normalize_uint "$1" '18446744073709551615')" || { product__error 'ID barang tidak valid.'; return 1; }
    product__validate_text 'product_code' "$code" 40 || return 1
    product__validate_text 'name' "$name" 120 || return 1
    price="$(product__normalize_uint "$4" '18446744073709551615')" || { product__error 'price harus bilangan bulat Rupiah yang valid.'; return 1; }
    min_stock="$(product__normalize_uint "$5" '4294967295')" || { product__error 'min_stock harus bilangan bulat yang valid.'; return 1; }
    product__require_db || return 1
    current="$(product__select_by_id "$product_id")" || return $?
    escaped_code="$(db_escape "$code")" || { product__error 'gagal mengamankan product_code.'; return 1; }
    escaped_name="$(db_escape "$name")" || { product__error 'gagal mengamankan name.'; return 1; }
    duplicate="$(product__query_scalar "SELECT EXISTS(SELECT 1 FROM products WHERE product_code='${escaped_code}' AND id<>${product_id});")" || { product__error 'gagal memeriksa kode barang.'; return 2; }
    if [[ "$duplicate" == 1 ]]; then
        product__error "kode barang '${code}' sudah digunakan barang lain."
        return 4
    fi
    [[ "$duplicate" == 0 ]] || { product__error 'hasil pemeriksaan duplikasi tidak valid.'; return 2; }
    db_query "UPDATE products SET product_code='${escaped_code}',name='${escaped_name}',price=${price},min_stock=${min_stock} WHERE id=${product_id};" >/dev/null || { product__error 'gagal memperbarui barang.'; return 2; }
    product__select_by_id "$product_id"
}

# Soft delete only; never physically DELETE historical products.
product_delete() {
    (( $# == 1 )) || { product__error 'penggunaan: product_delete <id>'; return 1; }
    local product_id current
    product_id="$(product__normalize_uint "$1" '18446744073709551615')" || { product__error 'ID barang tidak valid.'; return 1; }
    product__require_db || return 1
    current="$(product__select_by_id "$product_id")" || return $?
    db_query "UPDATE products SET is_active=0 WHERE id=${product_id};" >/dev/null || { product__error 'gagal menonaktifkan barang.'; return 2; }
    product__select_by_id "$product_id"
}
