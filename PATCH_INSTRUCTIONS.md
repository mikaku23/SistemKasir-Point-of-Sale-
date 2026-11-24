# Petunjuk menerapkan MINI POS Repository Repair

1. Buat backup folder repository yang sedang dikerjakan.
2. Download ZIP ini.
3. Ekstrak isi ZIP langsung ke root repository `SistemKasir-Point-of-Sale-` (merge/replace file yang diminta).
4. **Jangan menghapus atau mengganti folder `.git`** milik clone kamu.
5. **Jangan mengganti `config/database.conf` lokal**. File tersebut sengaja tidak ada di ZIP.
6. Buka terminal Git Bash (Windows) atau Bash (Ubuntu), bukan PowerShell.
7. Jalankan:
   ```bash
   bash tests/smoke.sh
   bash tests/bootstrap_smoke.sh
   ```
8. Pastikan Laragon/MariaDB aktif dan koneksi lokal benar:
   ```bash
   mysql --defaults-extra-file="$(cygpath -w "$PWD/config/database.conf")" \
     -e "SELECT DATABASE(), CURRENT_USER();"
   ```
   Di Ubuntu, bila `cygpath` tidak tersedia, gunakan path Linux:
   ```bash
   mysql --defaults-extra-file="$PWD/config/database.conf" \
     -e "SELECT DATABASE(), CURRENT_USER();"
   ```
9. Jalankan integrasi Products:
   ```bash
   bash tests/manual_products_crud.sh
   ```
10. Periksa perubahan:
    ```bash
    git status
    git diff --stat
    ```
11. Commit ke branch kerja, bukan langsung ke `main`. Setelah diuji, buat Pull Request.

ZIP ini tidak berisi folder `.git`, database credentials, atau data database lokal.
