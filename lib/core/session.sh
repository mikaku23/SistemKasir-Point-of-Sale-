#!/usr/bin/env bash
[[ "${_MINI_POS_SESSION_LOADED:-0}" == "1" ]] && return 0
_MINI_POS_SESSION_LOADED=1

SESSION_USER_ID=''
SESSION_USERNAME=''
SESSION_CSRF_TOKEN=''
SESSION_EXPIRES_AT=''

session__ensure_dir() {
    mkdir -p "$MINI_POS_SESSION_DIR" || return 1
    chmod 700 "$MINI_POS_SESSION_DIR" 2>/dev/null || true
}

session_create() {
    (( $# == 2 )) || return 1
    local user_id="$1" username="$2" sid csrf now expires file
    [[ "$user_id" =~ ^[0-9]+$ && "$username" =~ ^[A-Za-z0-9_.-]{3,50}$ ]] || return 1
    command -v openssl >/dev/null 2>&1 || return 1
    session__ensure_dir || return 1
    sid="$(openssl rand -hex 32)" || return 1
    csrf="$(openssl rand -hex 32)" || return 1
    now="$(date +%s)" || return 1
    expires=$((now + MINI_POS_SESSION_TTL))
    file="${MINI_POS_SESSION_DIR}/${sid}.session"
    (umask 077; printf 'user_id=%s\nusername=%s\ncsrf_token=%s\nexpires_at=%s\n' "$user_id" "$username" "$csrf" "$expires" > "$file") || return 1
    printf '%s' "$sid"
}

session_load() {
    local sid="${1-}" file key value
    [[ "$sid" =~ ^[a-f0-9]{64}$ ]] || return 1
    file="${MINI_POS_SESSION_DIR}/${sid}.session"
    [[ -f "$file" && -r "$file" ]] || return 1
    SESSION_USER_ID=''; SESSION_USERNAME=''; SESSION_CSRF_TOKEN=''; SESSION_EXPIRES_AT=''
    while IFS='=' read -r key value; do
        case "$key" in
            user_id) SESSION_USER_ID="$value" ;;
            username) SESSION_USERNAME="$value" ;;
            csrf_token) SESSION_CSRF_TOKEN="$value" ;;
            expires_at) SESSION_EXPIRES_AT="$value" ;;
        esac
    done < "$file"
    [[ "$SESSION_USER_ID" =~ ^[0-9]+$ && "$SESSION_USERNAME" =~ ^[A-Za-z0-9_.-]{3,50}$ && "$SESSION_CSRF_TOKEN" =~ ^[a-f0-9]{64}$ && "$SESSION_EXPIRES_AT" =~ ^[0-9]+$ ]] || return 1
    if (( SESSION_EXPIRES_AT < $(date +%s) )); then
        rm -f "$file"
        return 1
    fi
}

session_destroy() {
    local sid="${1-}"
    [[ "$sid" =~ ^[a-f0-9]{64}$ ]] || return 1
    rm -f -- "${MINI_POS_SESSION_DIR}/${sid}.session"
}
