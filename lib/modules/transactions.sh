#!/usr/bin/env bash
# Haliq — cash sales. Transactions are append-only; no edit/delete operation.
[[ "${_MINI_POS_TRANSACTIONS_LOADED:-0}" == "1" ]] && return 0
_MINI_POS_TRANSACTIONS_LOADED=1

transaction__error() { printf 'transactions: %s\n' "$1" >&2; }

transaction__build_cart_sql() {
    local pair id qty first=1 sql=''
    for pair in "$@"; do
        [[ "$pair" =~ ^([0-9]+):([0-9]+)$ ]] || { transaction__error "format item tidak valid: $pair (gunakan product_id:quantity)."; return 1; }
        id="${BASH_REMATCH[1]}"; qty="${BASH_REMATCH[2]}"
        id="$(validate_uint "$id" '18446744073709551615')" || return 1
        qty="$(validate_uint "$qty" '4294967295')" || return 1
        (( qty > 0 )) || { transaction__error 'quantity harus lebih besar dari 0.'; return 1; }
        if (( first )); then
            sql="SELECT ${id} AS product_id, ${qty} AS quantity"
            first=0
        else
            sql+=" UNION ALL SELECT ${id}, ${qty}"
        fi
    done
    (( first == 0 )) || { transaction__error 'keranjang minimal memiliki satu barang.'; return 1; }
    printf '%s' "$sql"
}

transaction_calculate_total() {
    (( $# >= 1 )) || { transaction__error 'penggunaan: transaction_calculate_total <product_id:quantity> [...]'; return 1; }
    local cart_sql sql result count
    cart_sql="$(transaction__build_cart_sql "$@")" || return 1
    count=$#
    sql="SELECT JSON_OBJECT(
      'total', COALESCE(SUM(p.price * cart.quantity),0),
      'items_found', COUNT(p.id),
      'items_requested', ${count}
    ) FROM products p JOIN (${cart_sql}) AS cart ON cart.product_id=p.id AND p.is_active=1;"
    result="$(db_query "$sql")" || { transaction__error 'gagal menghitung total dari database.'; return 2; }
    printf '%s\n' "$result"
}

# transaction_create USER_ID PAID PRODUCT_ID:QUANTITY [...]
# Example: transaction_create 1 20000 1:2 2:1
# One db_transaction call performs stock deduction, transaction header/details,
# SALE movements and result retrieval in the SAME MySQL connection.
transaction_create() {
    (( $# >= 3 )) || { transaction__error 'penggunaan: transaction_create <user_id> <paid> <product_id:quantity> [...]'; return 1; }
    local user_id paid invoice cart_sql item_count pair id qty duplicate_ids sql result
    user_id="$(validate_uint "$1" '18446744073709551615')" || { transaction__error 'user_id tidak valid.'; return 1; }
    paid="$(validate_uint "$2" '18446744073709551615')" || { transaction__error 'paid harus bilangan bulat Rupiah.'; return 1; }
    shift 2
    item_count=$#
    cart_sql="$(transaction__build_cart_sql "$@")" || return 1

    # A product may appear only once because transaction_details has a unique
    # (transaction_id, product_id) key. The caller should combine quantities.
    duplicate_ids=''
    local -A seen=()
    for pair in "$@"; do
        id="${pair%%:*}"
        [[ -z "${seen[$id]+x}" ]] || { transaction__error "product_id $id muncul lebih dari sekali; gabungkan quantity-nya."; return 1; }
        seen[$id]=1
    done

    invoice="INV-$(date +%Y%m%d-%H%M%S)-$$-${RANDOM}"
    local escaped_invoice
    escaped_invoice="$(db_escape "$invoice")" || return 2

    sql="CREATE TEMPORARY TABLE _mini_pos_assert (
      ok TINYINT NOT NULL,
      CONSTRAINT chk_mini_pos_assert CHECK (ok = 1)
    ) ENGINE=InnoDB;

    -- UPDATE locks matching product rows and decrements only active products
    -- with sufficient stock. ROW_COUNT must equal the number of cart lines.
    UPDATE products AS p
    INNER JOIN (${cart_sql}) AS cart ON cart.product_id = p.id
    SET p.stock = p.stock - cart.quantity
    WHERE p.is_active = 1 AND p.stock >= cart.quantity;

    INSERT INTO _mini_pos_assert (ok) VALUES (IF(ROW_COUNT() = ${item_count}, 1, 0));

    -- Product rows remain locked until COMMIT. The server computes the total;
    -- no price or total supplied by the browser is trusted.
    SET @mini_pos_total := (
      SELECT COALESCE(SUM(p.price * cart.quantity), 0)
      FROM products p
      INNER JOIN (${cart_sql}) AS cart ON cart.product_id = p.id
      WHERE p.is_active = 1
    );

    INSERT INTO _mini_pos_assert (ok) VALUES (IF(${paid} >= @mini_pos_total, 1, 0));

    INSERT INTO transactions (invoice_number, user_id, total, paid, change_amount)
    VALUES ('${escaped_invoice}', ${user_id}, @mini_pos_total, ${paid}, ${paid} - @mini_pos_total);

    SET @mini_pos_transaction_id := LAST_INSERT_ID();

    INSERT INTO transaction_details (
      transaction_id, product_id, product_code_snapshot,
      product_name_snapshot, unit_price, quantity, subtotal
    )
    SELECT @mini_pos_transaction_id, p.id, p.product_code,
           p.name, p.price, cart.quantity, p.price * cart.quantity
    FROM products p
    INNER JOIN (${cart_sql}) AS cart ON cart.product_id = p.id
    WHERE p.is_active = 1;

    INSERT INTO stock_movements (
      product_id, user_id, transaction_id, movement_type, quantity,
      stock_before, stock_after, notes
    )
    SELECT p.id, ${user_id}, @mini_pos_transaction_id, 'SALE', cart.quantity,
           p.stock + cart.quantity, p.stock, CONCAT('Penjualan ', '${escaped_invoice}')
    FROM products p
    INNER JOIN (${cart_sql}) AS cart ON cart.product_id = p.id
    WHERE p.is_active = 1;

    DROP TEMPORARY TABLE _mini_pos_assert;

    SELECT JSON_OBJECT(
      'id', t.id,
      'invoice_number', t.invoice_number,
      'total', t.total,
      'paid', t.paid,
      'change_amount', t.change_amount,
      'created_at', t.created_at,
      'items', COALESCE((
        SELECT JSON_ARRAYAGG(JSON_OBJECT(
          'product_id', d.product_id,
          'product_code', d.product_code_snapshot,
          'name', d.product_name_snapshot,
          'unit_price', d.unit_price,
          'quantity', d.quantity,
          'subtotal', d.subtotal
        )) FROM transaction_details d WHERE d.transaction_id = t.id
      ), JSON_ARRAY())
    )
    FROM transactions t WHERE t.id = @mini_pos_transaction_id;"

    result="$(db_transaction "$sql")" || {
        transaction__error 'transaksi gagal. Periksa stok, status barang, pembayaran, user_id, dan error SQL; perubahan dalam transaksi atomik seharusnya di-rollback.'
        return 2
    }
    [[ -n "$result" ]] || { transaction__error 'transaksi tersimpan tetapi respons detail kosong.'; return 2; }
    printf '%s\n' "$result"
}

transaction_get_detail() {
    (( $# == 1 )) || { transaction__error 'penggunaan: transaction_get_detail <transaction_id>'; return 1; }
    local id sql result
    id="$(validate_uint "$1" '18446744073709551615')" || { transaction__error 'transaction_id tidak valid.'; return 1; }
    sql="SELECT JSON_OBJECT(
      'id', t.id, 'invoice_number', t.invoice_number,
      'total', t.total, 'paid', t.paid, 'change_amount', t.change_amount,
      'created_at', t.created_at,
      'items', COALESCE((SELECT JSON_ARRAYAGG(JSON_OBJECT(
        'product_id', d.product_id, 'product_code', d.product_code_snapshot,
        'name', d.product_name_snapshot, 'unit_price', d.unit_price,
        'quantity', d.quantity, 'subtotal', d.subtotal
      )) FROM transaction_details d WHERE d.transaction_id=t.id), JSON_ARRAY())
    ) FROM transactions t WHERE t.id=${id} LIMIT 1;"
    result="$(db_query "$sql")" || { transaction__error 'gagal mengambil detail transaksi.'; return 2; }
    [[ -n "$result" ]] || { transaction__error 'transaksi tidak ditemukan.'; return 3; }
    printf '%s\n' "$result"
}
