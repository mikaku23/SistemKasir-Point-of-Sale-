# Team Tasks — MINI POS

| Member | Module | Technical name | Primary files |
|---|---|---|---|
| Haliq | Core, Auth, Transactions, Dashboard, shared UI/integration | `core`, `auth`, `transactions`, `dashboard` | `lib/core/`, `lib/bootstrap.sh`, `lib/modules/transactions.sh`, `lib/modules/dashboard.sh`, shared `bin/`, `cli/`, `web/`, API |
| Bahram | Manajemen Barang | `products` | `lib/modules/products.sh`, `cli/modules/products.sh`, `lib/api/routes/products.sh`, `web/pages/products.html`, `web/assets/js/modules/products.js` |
| Rafis | Pengelolaan Stok | `inventory` | `lib/modules/inventory.sh`, `cli/modules/inventory.sh`, `lib/api/routes/inventory.sh`, `web/pages/inventory.html`, `web/assets/js/modules/inventory.js` |
| Hasan | Riwayat Transaksi | `history` | `lib/modules/history.sh`, `cli/modules/history.sh`, `lib/api/routes/history.sh`, `web/pages/history.html`, `web/assets/js/modules/history.js` |
| Haikal | Laporan Penjualan | `reports` | `lib/modules/reports.sh`, `cli/modules/reports.sh`, `lib/api/routes/reports.sh`, `web/pages/reports.html`, `web/assets/js/modules/reports.js` |

## File ownership rules

- Haliq coordinates `lib/core/db.sh`, `lib/bootstrap.sh`, database schema, authentication, shared API routing, shared CSS and shared JavaScript.
- Each member owns the files for their module.
- Request changes to shared files through an Issue or team discussion; do not silently overwrite another member's work.
- All modules use the same MySQL schema and the same database helper contract.
- Every module must support the CLI and Web GUI by the end of the project, even if a member starts with CLI/business logic first.
- Changes are integrated through Pull Requests to `main`.
