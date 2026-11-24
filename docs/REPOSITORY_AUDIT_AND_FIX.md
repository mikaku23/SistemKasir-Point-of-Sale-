# Audit Repository dan Perbaikan Fondasi MINI POS

## Temuan dari ZIP repository yang diunggah

ZIP repository yang diaudit berisi metadata `.git` dan 130 entri file/direktori. Pada working tree yang diunggah:

- `lib/bootstrap.sh` berukuran **0 byte**.
- `lib/core/config.sh`, `db.sh`, `validation.sh`, `response.sh`, `auth.sh`, dan `session.sh` berukuran **0 byte**.
- `lib/modules/products.sh` dan file CLI Products berukuran **0 byte**.
- `bin/pos.sh`, `bin/setup.sh`, `cli/login.sh`, `cli/menu.sh`, serta `tests` belum berisi implementasi.
- `database/schema.sql`, `database/seed.sql`, `config/database.conf.example`, `.gitignore`, dan `README.md` adalah beberapa file yang sudah memiliki isi.

Karena itu `product_create` tidak ditemukan: file implementasi belum dimuat oleh bootstrap, dan file bootstrap yang berasal dari scaffold GitHub masih kosong. Pesan `MINI_POS_ROOT: unbound variable` menunjukkan versi bootstrap lokal yang sempat dicoba juga merujuk variabel root sebelum didefinisikan. Patch ini menetapkan `MINI_POS_ROOT` terlebih dahulu dan memakai ekspansi aman untuk `set -u`.

## Apa yang diperbaiki dalam patch

1. `lib/bootstrap.sh` memuat `config.sh` terlebih dahulu, lalu helper core, lalu modul yang sudah benar-benar diimplementasikan.
2. `lib/core/db.sh` menyediakan kontrak yang dipakai Products: `db_query`, `db_escape`, `db_ping`, dan `db_transaction`.
3. Path `config/database.conf` dikonversi dengan `cygpath -w` di Git Bash agar `mysql.exe` Laragon dapat membacanya.
4. `db_transaction` menjalankan seluruh SQL body dalam satu proses client / satu sesi server; tidak menggunakan `--force`.
5. Products CRUD dan CLI Bahram disertakan sebagai implementasi yang bisa diuji.
6. Entry point `bin/setup.sh` dan `bin/pos.sh` serta CLI login/menu disediakan.
7. File modul anggota yang belum diimplementasikan diberi komentar TODO, bukan file kosong, agar kepemilikan dan statusnya jelas.
8. README menjelaskan perbedaan Windows Git Bash + Laragon dan Ubuntu + Apache CGI.
9. `.git` tidak disertakan dalam patch. Jangan pernah menimpa folder `.git` saat menerapkan patch.

## Perbedaan penting antara file template dan file implementasi

File yang dibuat dengan `touch` hanya merupakan placeholder 0 byte. Git dapat melacak file kosong, tetapi keberadaan file tidak berarti fungsinya telah diimplementasikan.

Setelah patch diekstrak ke root repository, periksa:
```bash
wc -c lib/bootstrap.sh lib/core/db.sh lib/modules/products.sh cli/modules/products.sh
```
Semua file implementasi di atas harus memiliki ukuran lebih dari nol.

## Status yang belum boleh diklaim selesai

Patch tidak mengimplementasikan penuh:
- Products Web API dan halaman Products GUI;
- Inventory CRUD/CLI/Web oleh Rafis;
- History oleh Hasan;
- Reports oleh Haikal;
- keseluruhan deployment Apache CGI pada Windows.

Apache CGI berbasis Bash harus dijalankan di Linux/Ubuntu atau environment Linux yang sesuai. Git Bash adalah shell untuk development/CLI Windows, bukan server CGI Linux.

## Urutan sesudah patch

1. Pastikan `config/database.conf` lokal ada dan tidak di-commit.
2. Jalankan `bash tests/bootstrap_smoke.sh`.
3. Jalankan `db_ping`.
4. Jalankan `bash tests/manual_products_crud.sh`.
5. Uji menu Products melalui `bash bin/pos.sh`.
6. Tinjau `git diff`, commit patch, dan push ke branch kerja sebelum membuat Pull Request.
