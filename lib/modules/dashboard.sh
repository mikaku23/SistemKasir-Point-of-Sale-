#!/usr/bin/env bash
# Haliq — dashboard summary. Read-only; all metrics are computed by MariaDB.
[[ "${_MINI_POS_DASHBOARD_LOADED:-0}" == "1" ]] && return 0
_MINI_POS_DASHBOARD_LOADED=1

dashboard_summary() {
    local sql result
    declare -F db_query >/dev/null 2>&1 || { printf 'dashboard: db_query() belum tersedia.\n' >&2; return 1; }
    sql="SELECT JSON_OBJECT(
      'active_products', (SELECT COUNT(*) FROM products WHERE is_active=1),
      'transactions_today', (SELECT COUNT(*) FROM transactions WHERE DATE(created_at)=CURRENT_DATE()),
      'sales_today', (SELECT COALESCE(SUM(total),0) FROM transactions WHERE DATE(created_at)=CURRENT_DATE()),
      'low_stock_products', (SELECT COUNT(*) FROM products WHERE is_active=1 AND stock <= min_stock),
      'generated_at', DATE_FORMAT(NOW(), '%Y-%m-%d %H:%i:%s')
    );"
    result="$(db_query "$sql")" || { printf 'dashboard: gagal mengambil ringkasan.\n' >&2; return 2; }
    [[ -n "$result" ]] || { printf 'dashboard: respons database kosong.\n' >&2; return 2; }
    printf '%s\n' "$result"
}
