# MINI POS — Point of Sale Management System

Aplikasi kasir skala menengah dengan dua antarmuka (CLI dan Web GUI), satu backend Bash,
Apache CGI sebagai adapter HTTP, dan satu database MySQL/MariaDB.

## Arsitektur yang wajib dipertahankan

- **Backend/logika bisnis:** Bash Shell Script.
- **CLI:** Bash Terminal (Linux Bash atau Git Bash untuk pengembangan CLI di Windows).
- **Web GUI:** HTML, CSS, JavaScript.
- **Web API adapter:** Apache CGI (`cgi-bin/api.cgi`) pada lingkungan Linux.
- **Database:** MySQL 8.0.16+ atau MariaDB yang kompatibel dengan `database/schema.sql`.
- **Database client:** `mysql` atau `mariadb`.
- **Akun aplikasi:** satu Admin; akun database `mini_pos_app` terpisah dari akun Admin aplikasi.

CLI dan Web harus memanggil fungsi bisnis Bash yang sama. JavaScript hanya menangani tampilan dan interaksi,
bukan menghitung atau menyimpan logika penjualan.

## Anggota dan kepemilikan modul

| Anggota | Modul teknis | Tanggung jawab |
|---|---|---|
| Haliq | `core`, `auth`, `transactions`, `dashboard` | Fondasi, transaksi, login, dashboard, UI bersama, integrasi |
| Bahram | `products` | Master barang / CRUD Products |
| Rafis | `inventory` | Stok masuk, stok keluar, penyesuaian, audit stok |
| Hasan | `history` | Riwayat dan detail transaksi |
| Haikal | `reports` | Rekap penjualan dan laporan |

Nama teknis dan nama file memakai bahasa Inggris `snake_case`: `products`, `inventory`,
`transactions`, `history`, `reports`, `dashboard`, `auth`.

## Prasyarat

### Windows 11 (anggota yang memakai Laragon)

1. Install Git for Windows dan pilih **Git Bash** sebagai terminal VS Code.
2. Jalankan Laragon, lalu Start All atau pastikan MySQL/MariaDB aktif.
3. Tambahkan folder `C:\laragon\bin\mysql\<versi>\bin` ke PATH agar `mysql --version` bekerja di Git Bash.
4. Sediakan `jq.exe` di PATH (misalnya `C:\Tools\jq\jq.exe`).
5. Pastikan `openssl` tersedia di Git Bash.
6. Gunakan Git Bash untuk perintah Bash (`source`, `bash`, `declare -F`, dan fungsi CLI).

**Catatan:** PowerShell bukan Bash. `source` dan fungsi Bash harus dijalankan di Git Bash. Git Bash mendukung pengembangan/pengujian CLI, tetapi bukan pengganti Linux penuh untuk menjalankan Apache CGI.

### Ubuntu Linux (Haliq / integrasi CGI)

Contoh dependensi:
```bash
sudo apt update
sudo apt install bash mysql-client jq openssl apache2
```
Gunakan MariaDB Client bila server yang dipakai MariaDB.

## Setup database lokal

1. Buat database dan tabel dengan mengimpor `database/schema.sql` melalui phpMyAdmin (akun administrator lokal), atau:
   ```bash
   mysql -u root -p < database/schema.sql
   ```
2. Masukkan data contoh:
   ```bash
   mysql -u root -p < database/seed.sql
   ```
3. Buat akun database khusus aplikasi (jalankan melalui phpMyAdmin SQL atau MySQL administrator):
   ```sql
   CREATE USER IF NOT EXISTS 'mini_pos_app'@'localhost' IDENTIFIED BY 'GANTI_PASSWORD';
   GRANT SELECT, INSERT, UPDATE, CREATE TEMPORARY TABLES
   ON mini_pos.* TO 'mini_pos_app'@'localhost';
   FLUSH PRIVILEGES;
   ```
   Untuk koneksi TCP ke `127.0.0.1`, buat akun host `'mini_pos_app'@'127.0.0.1'` dan berikan grant yang sama.
4. Salin contoh konfigurasi:
   ```bash
   cp config/database.conf.example config/database.conf
   ```
5. Isi `config/database.conf` sesuai host, port, username, dan password lokal:
   ```ini
   [client]
   host=localhost
   port=3306
   user=mini_pos_app
   password=PASSWORD_LOKAL
   database=mini_pos
   default-character-set=utf8mb4
   ```
   Untuk Windows + Laragon, `host=127.0.0.1` umumnya sesuai dengan koneksi TCP yang dipakai.
6. Jangan commit `config/database.conf`. File ini sudah dikecualikan oleh `.gitignore`.

Uji:
```bash
mysql --defaults-extra-file="$PWD/config/database.conf" \
  -e "SELECT DATABASE(), CURRENT_USER();"
```
Di Git Bash, `lib/core/db.sh` mengubah path konfigurasi menggunakan `cygpath` untuk `mysql.exe`.

## Setup aplikasi dan uji CLI

Jalankan semua perintah berikut dari **Git Bash** (Windows) atau Bash (Linux).

Periksa dependensi:
```bash
bash --version
mysql --version
jq --version
openssl version
```

Periksa sintaks:
```bash
bash -n lib/bootstrap.sh
bash -n lib/core/db.sh
bash -n lib/modules/products.sh
bash -n cli/modules/products.sh
bash -n tests/manual_products_crud.sh
```

Uji bootstrap:
```bash
bash tests/bootstrap_smoke.sh
```

Uji koneksi:
```bash
source lib/bootstrap.sh
db_ping && echo "DATABASE CONNECTED"
```

Uji Products CRUD terhadap database lokal:
```bash
bash tests/manual_products_crud.sh
```

Setup akun Admin satu kali:
```bash
bash bin/setup.sh
```

Jalankan aplikasi CLI:
```bash
bash bin/pos.sh
```

Pilih menu **1 — Manajemen Barang**. Barang baru selalu dimulai dengan stok `0`; perubahan stok dilakukan melalui modul Inventory. Hapus barang adalah soft delete (`is_active=0`).

## File konfigurasi dan keamanan

- `config/database.conf.example` adalah template, bukan konfigurasi aktif.
- Buat `config/database.conf` secara lokal.
- Jangan simpan password DB atau password Admin di Git.
- Gunakan akun DB `mini_pos_app`, bukan `root`, untuk menjalankan aplikasi.
- Akun aplikasi memerlukan `SELECT`, `INSERT`, `UPDATE`, dan `CREATE TEMPORARY TABLES` untuk implementasi transaksi.
- Jangan memasukkan `--force` ke pemanggilan MySQL pada `db_transaction`; SQL error harus menghentikan batch agar transaksi dapat rollback.

## Status implementasi

Saat patch fondasi diterapkan:
- Core database, auth CLI, transactions CLI, dashboard query, dan Products CRUD + CLI tersedia.
- Products API/Web GUI, Inventory, History, Reports, dan halaman Web modul terkait tetap menjadi tugas pemilik modul masing-masing.
- Apache CGI berjalan pada lingkungan Linux yang dikonfigurasi; Git Bash di Windows dipakai untuk pengembangan dan tes CLI.
