#!/usr/bin/env bash
# Shared MySQL/MariaDB client adapter for Linux and Git Bash on Windows.
#
# Public contract:
#   db_query "SQL"          -> one or more raw result rows, no column headings
#   db_escape "value"       -> escaped contents for a single-quoted SQL literal
#   db_transaction "SQL"    -> executes body in one connection and commits
#   db_ping                 -> checks the configured database connection
#
# Required local file: config/database.conf (MySQL option-file format [client]).
[[ "${_MINI_POS_DB_LOADED:-0}" == "1" ]] && return 0
_MINI_POS_DB_LOADED=1

if ! declare -F mini_pos_require_file >/dev/null 2>&1; then
    # shellcheck source=lib/core/config.sh
    source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/config.sh"
fi

DB_CLIENT="${MINI_POS_DB_CLIENT:-}"

_db_error() {
    printf 'database: %s\n' "$1" >&2
}

_db_resolve_client() {
    if [[ -n "${DB_CLIENT:-}" ]]; then
        command -v "$DB_CLIENT" >/dev/null 2>&1 || {
            _db_error "MySQL client '${DB_CLIENT}' tidak ditemukan di PATH."
            return 1
        }
        return 0
    fi

    if command -v mysql >/dev/null 2>&1; then
        DB_CLIENT="mysql"
    elif command -v mariadb >/dev/null 2>&1; then
        DB_CLIENT="mariadb"
    else
        _db_error 'MySQL/MariaDB client tidak ditemukan. Windows: tambahkan Laragon bin/mysql ke PATH; Ubuntu: install mysql-client atau mariadb-client.'
        return 1
    fi
}

_db_defaults_file_arg() {
    local file="${MINI_POS_DB_CONFIG:-}"

    if [[ -z "$file" || ! -f "$file" || ! -r "$file" ]]; then
        _db_error "config database tidak ditemukan/dapat dibaca: ${file:-<belum ditentukan>}. Salin config/database.conf.example menjadi config/database.conf."
        return 1
    fi

    # In Git Bash, mysql.exe needs a native Windows path to its option file.
    if command -v cygpath >/dev/null 2>&1; then
        file="$(cygpath -w "$file")" || {
            _db_error 'gagal mengubah path database.conf ke format Windows.'
            return 1
        }
    fi

    # --defaults-extra-file must be the first MySQL client option.
    printf '%s' "--defaults-extra-file=$file"
}

_db_run() {
    local sql="${1-}"
    local defaults_arg

    _db_resolve_client || return 2
    defaults_arg="$(_db_defaults_file_arg)" || return 2

    # Do not use --force. A SQL error must stop the batch; for db_transaction,
    # the client connection then closes and InnoDB rolls back uncommitted work.
    printf '%s\n' "$sql" |
        "$DB_CLIENT" "$defaults_arg" \
            --batch \
            --skip-column-names \
            --raw \
            --default-character-set=utf8mb4 \
            --connect-timeout=8
}

db_query() {
    (( $# == 1 )) || {
        _db_error 'penggunaan: db_query "SQL"'
        return 1
    }
    _db_run "$1"
}

# Escape a value inserted inside a single-quoted MySQL/MariaDB string literal.
# Keep text validation at each module boundary; Bash variables cannot hold NUL.
# This follows MySQL's default backslash-escape mode. Do not enable
# NO_BACKSLASH_ESCAPES for the application DB session.
db_escape() {
    (( $# == 1 )) || {
        _db_error 'penggunaan: db_escape VALUE'
        return 1
    }

    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\'/\\\'}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    value="${value//$'\032'/\\Z}"
    printf '%s' "$value"
}

# Execute the full SQL body in ONE client process / ONE server session.
# The body must contain DML/temporary-table statements only (no implicit-commit
# DDL such as CREATE TABLE, ALTER TABLE, DROP TABLE).
db_transaction() {
    (( $# == 1 )) || {
        _db_error 'penggunaan: db_transaction "SQL_BODY"'
        return 1
    }

    local script
    script=$'START TRANSACTION;\n'
    script+="$1"
    script+=$'\nCOMMIT;'
    _db_run "$script"
}

db_ping() {
    local result
    result="$(db_query 'SELECT 1;')" || return 1
    [[ "$result" == '1' ]]
}
