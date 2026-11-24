# MINI POS Architecture

## One application, two interfaces, one Bash business layer

```text
CLI (Bash) -------------------------------+
                                          |
Web Browser -> Apache CGI -> API routes --+--> lib/modules/*.sh --> lib/core/db.sh --> MySQL/MariaDB
```

- CLI menus call business functions directly.
- Web API routes validate/translate HTTP input and call the same business functions.
- Business modules must not duplicate connection code. Use `db_query`, `db_escape`, and `db_transaction`.
- JavaScript handles rendering and form interaction only.
- `config/database.conf` is local and must not be committed.

## Directory ownership

- `bin/`, `lib/core/`, `lib/bootstrap.sh`, `cgi-bin/`, shared API/router and shared Web shell: Haliq.
- `lib/modules/products.sh`, `cli/modules/products.sh`, Products API/page: Bahram.
- Inventory equivalents: Rafis.
- Transactions: Haliq.
- History equivalents: Hasan.
- Reports equivalents: Haikal.

## Shared function contract

- `db_query SQL`
- `db_escape VALUE`
- `db_transaction SQL_BODY`
- `db_ping`

Modules should expose stable functions:
- `product_create`, `product_list`, `product_find`, `product_update`, `product_delete`
- `inventory_add`, `inventory_issue`, `inventory_adjust`, `inventory_list`
- `transaction_calculate_total`, `transaction_create`, `transaction_get_detail`
- `history_list`, `history_detail`
- `report_daily`
- `dashboard_summary`

Business functions print data (normally JSON) to stdout and send diagnostics to stderr. CLI and API format the result; business modules do not print menus or HTTP headers.
