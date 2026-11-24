# MINI POS Database

Database name: `mini_pos`. Engine: InnoDB. Character set: `utf8mb4`.

## Tables

| Table | Purpose | Owner |
|---|---|---|
| `users` | Single Admin account | Haliq |
| `products` | Product master, price and current stock | Bahram (master fields); Rafis/Haliq change stock |
| `transactions` | Cash-sale header | Haliq |
| `transaction_details` | Product and price snapshots per sale | Haliq |
| `stock_movements` | Audit trail of stock changes | Rafis/Haliq |

`products.stock` is initialized to zero when Products creates a product. Inventory receipts/adjustments and successful sales are responsible for stock changes.

`transaction_details` preserves `product_code_snapshot`, `product_name_snapshot`, and `unit_price` so historical sales do not change when the product master is edited.

Transactions are append-only. Do not add edit/delete operations for historical completed sales.

## App database privileges

The application user requires:
- `SELECT`, `INSERT`, `UPDATE` on `mini_pos.*`;
- `CREATE TEMPORARY TABLES` for the transaction implementation which uses a temporary assertion table.

Database schema changes must be coordinated by Haliq and committed to `database/schema.sql`. Re-importing a `CREATE TABLE IF NOT EXISTS` schema does not alter tables that already exist; use a reviewed migration/ALTER script when schema changes are needed.

## Compatibility

The schema includes enforced CHECK constraints and is intended for MySQL 8.0.16+ or a compatible MariaDB version. The FK from `stock_movements.transaction_id` uses `ON UPDATE RESTRICT` because this column is also referenced by a CHECK constraint in MariaDB.
