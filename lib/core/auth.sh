#!/usr/bin/env bash
[[ "${_MINI_POS_AUTH_LOADED:-0}" == "1" ]] && return 0
_MINI_POS_AUTH_LOADED=1

_auth_error() { printf 'auth: %s\n' "$1" >&2; }

_auth_hash_password() {
    local password="${1-}" salt
    command -v openssl >/dev/null 2>&1 || { _auth_error 'OpenSSL tidak ditemukan.'; return 1; }
    salt="$(openssl rand -hex 8)" || return 1
    printf '%s' "$password" | openssl passwd -6 -salt "$salt" -stdin
}

# auth_create_admin USERNAME PASSWORD; only the first and single Admin is allowed.
auth_create_admin() {
    (( $# == 2 )) || { _auth_error 'penggunaan: auth_create_admin USERNAME PASSWORD'; return 1; }
    local username="$1" password="$2" escaped_user hash escaped_hash count
    [[ "$username" =~ ^[A-Za-z0-9_.-]{3,50}$ ]] || { _auth_error 'username 3-50 karakter: huruf, angka, titik, garis bawah, atau strip.'; return 1; }
    (( ${#password} >= 10 )) || { _auth_error 'password minimal 10 karakter.'; return 1; }
    declare -F db_query >/dev/null 2>&1 && declare -F db_escape >/dev/null 2>&1 || { _auth_error 'database helper belum dimuat.'; return 1; }
    count="$(db_query 'SELECT COUNT(*) FROM users;')" || { _auth_error 'gagal memeriksa akun Admin.'; return 2; }
    [[ "$count" == '0' ]] || { _auth_error 'akun Admin sudah ada. Setup awal hanya boleh dijalankan sekali.'; return 3; }
    hash="$(_auth_hash_password "$password")" || { _auth_error 'gagal membuat password hash.'; return 2; }
    escaped_user="$(db_escape "$username")" || return 2
    escaped_hash="$(db_escape "$hash")" || return 2
    db_query "INSERT INTO users (username, password_hash, is_active) VALUES ('${escaped_user}', '${escaped_hash}', 1);" >/dev/null || { _auth_error 'gagal membuat akun Admin.'; return 2; }
    response_success 'Akun Admin berhasil dibuat.' "$(jq -cn --arg username "$username" '{username:$username}')"
}

# auth_setup_admin prompts without echo; passwords are not typed in shell history.
auth_setup_admin() {
    local username password confirm result rc
    read -r -p 'Username Admin: ' username
    read -r -s -p 'Password Admin (min. 10 karakter): ' password; printf '\n'
    read -r -s -p 'Ulangi Password: ' confirm; printf '\n'
    [[ "$password" == "$confirm" ]] || { _auth_error 'konfirmasi password tidak sama.'; unset password confirm; return 1; }
    if result="$(auth_create_admin "$username" "$password")"; then rc=0; else rc=$?; fi
    unset password confirm
    (( rc == 0 )) && printf '%s\n' "$result"
    return "$rc"
}

# auth_verify USERNAME PASSWORD -> JSON {id,username}; no password/hash is returned.
auth_verify() {
    (( $# == 2 )) || return 1
    local username="$1" password="$2" escaped_user row user_id db_username stored_hash algo salt digest candidate
    [[ "$username" =~ ^[A-Za-z0-9_.-]{3,50}$ ]] || return 1
    escaped_user="$(db_escape "$username")" || return 2
    row="$(db_query "SELECT id, username, password_hash FROM users WHERE username='${escaped_user}' AND is_active=1 LIMIT 1;")" || return 2
    [[ -n "$row" ]] || return 1
    IFS=$'\t' read -r user_id db_username stored_hash <<< "$row"
    [[ "$user_id" =~ ^[0-9]+$ && "$stored_hash" == '$6$'* ]] || return 1
    IFS='$' read -r _ algo salt digest <<< "$stored_hash"
    [[ "$algo" == '6' && -n "$salt" ]] || return 1
    candidate="$(printf '%s' "$password" | openssl passwd -6 -salt "$salt" -stdin 2>/dev/null)" || return 2
    [[ "$candidate" == "$stored_hash" ]] || return 1
    jq -cn --arg id "$user_id" --arg username "$db_username" '{id:($id|tonumber),username:$username}'
}
