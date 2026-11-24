#!/usr/bin/env bash
[[ "${_MINI_POS_API_ROUTER_LOADED:-0}" == "1" ]] && return 0
_MINI_POS_API_ROUTER_LOADED=1
API_STATUS=200
API_BODY='{"ok":false,"message":"Request belum diproses.","data":null}'
API_SET_COOKIE=''
API_JSON='{}'
API_ACTION=''
API_METHOD=''
API_SESSION_ID=''

api_set_success() { API_STATUS=200; API_BODY="$(response_success "$1" "${2:-null}")"; }
api_set_error() { API_STATUS="${1:-400}"; API_BODY="$(response_error "${2:-Request gagal.}" "${3:-null}")"; }

api_url_decode() {
    # Decode exactly once, byte by byte, to avoid double-decoding sequences
    # such as %2526 into an ampersand.
    local input="${1-}" output='' char hex
    input="${input//+/ }"
    while [[ -n "$input" ]]; do
        if [[ "${input:0:1}" == '%' && "${input:1:2}" =~ ^[0-9A-Fa-f]{2}$ ]]; then
            hex="${input:1:2}"
            [[ "$hex" != '00' ]] || return 1
            printf -v char '%b' "\\x${hex}"
            output+="$char"
            input="${input:3}"
        else
            output+="${input:0:1}"
            input="${input:1}"
        fi
    done
    printf '%s' "$output"
}

api_query_param() {
    local wanted="${1-}" pair key value
    local -a parts=()
    IFS='&' read -r -a parts <<< "${QUERY_STRING:-}"
    for pair in "${parts[@]}"; do
        key="${pair%%=*}"; value="${pair#*=}"
        if [[ "$(api_url_decode "$key")" == "$wanted" ]]; then api_url_decode "$value"; return 0; fi
    done
    return 1
}

api_read_body() {
    local length="${CONTENT_LENGTH:-0}"
    [[ "$length" =~ ^[0-9]+$ && ${#length} -le 5 ]] || { api_set_error 400 'Content-Length tidak valid.'; return 1; }
    (( length <= MINI_POS_MAX_REQUEST_BYTES )) || { api_set_error 413 'Ukuran request terlalu besar.'; return 1; }
    if (( length == 0 )); then API_JSON='{}'; return 0; fi
    API_JSON="$(head -c "$length")" || { api_set_error 400 'Gagal membaca body request.'; return 1; }
    jq -e 'type == "object"' >/dev/null 2>&1 <<< "$API_JSON" || { api_set_error 400 'Body harus berupa JSON object yang valid.'; return 1; }
}

api_cookie_session_id() {
    local part name value
    local -a cookies=()
    IFS=';' read -r -a cookies <<< "${HTTP_COOKIE:-}"
    for part in "${cookies[@]}"; do
        part="${part#"${part%%[![:space:]]*}"}"
        name="${part%%=*}"; value="${part#*=}"
        if [[ "$name" == 'MINIPOS_SESSION' ]]; then printf '%s' "$value"; return 0; fi
    done
    return 1
}

api_require_session() {
    API_SESSION_ID="$(api_cookie_session_id)" || { api_set_error 401 'Silakan login terlebih dahulu.'; return 1; }
    session_load "$API_SESSION_ID" || { api_set_error 401 'Session tidak valid atau sudah kedaluwarsa.'; return 1; }
}
api_require_csrf() {
    [[ -n "${HTTP_X_CSRF_TOKEN:-}" && "$HTTP_X_CSRF_TOKEN" == "$SESSION_CSRF_TOKEN" ]] || { api_set_error 403 'CSRF token tidak valid.'; return 1; }
}

api_emit() {
    local reason='OK'
    case "$API_STATUS" in
        200) reason='OK' ;; 400) reason='Bad Request' ;; 401) reason='Unauthorized' ;;
        403) reason='Forbidden' ;; 404) reason='Not Found' ;; 405) reason='Method Not Allowed' ;;
        413) reason='Payload Too Large' ;; 415) reason='Unsupported Media Type' ;;
        422) reason='Unprocessable Entity' ;; 500) reason='Internal Server Error' ;; *) reason='Error' ;;
    esac
    printf 'Status: %s %s\r\n' "$API_STATUS" "$reason"
    printf 'Content-Type: application/json; charset=utf-8\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n'
    [[ -n "$API_SET_COOKIE" ]] && printf 'Set-Cookie: %s\r\n' "$API_SET_COOKIE"
    printf '\r\n%s' "$API_BODY"
}

api_main() {
    API_METHOD="${REQUEST_METHOD:-GET}"
    API_ACTION="$(api_query_param action 2>/dev/null || true)"
    if [[ "$API_METHOD" != 'GET' && "$API_METHOD" != 'POST' ]]; then api_set_error 405 'HTTP method tidak didukung.'; api_emit; return; fi
    if [[ "$API_METHOD" == 'POST' ]]; then
        [[ "${CONTENT_TYPE:-}" == application/json* ]] || { api_set_error 415 'Content-Type harus application/json.'; api_emit; return; }
        api_read_body || { api_emit; return; }
    fi
    case "$API_ACTION" in
        auth.login)
            [[ "$API_METHOD" == 'POST' ]] || { api_set_error 405 'auth.login harus POST.'; api_emit; return; }
            api_route_auth_login ;;
        auth.me)
            [[ "$API_METHOD" == 'GET' ]] || { api_set_error 405 'auth.me harus GET.'; api_emit; return; }
            if api_require_session; then api_route_auth_me; fi ;;
        auth.logout)
            [[ "$API_METHOD" == 'POST' ]] || { api_set_error 405 'auth.logout harus POST.'; api_emit; return; }
            if api_require_session && api_require_csrf; then api_route_auth_logout; fi ;;
        dashboard.summary)
            [[ "$API_METHOD" == 'GET' ]] || { api_set_error 405 'dashboard.summary harus GET.'; api_emit; return; }
            if api_require_session; then api_route_dashboard_summary; fi ;;
        transactions.create)
            [[ "$API_METHOD" == 'POST' ]] || { api_set_error 405 'transactions.create harus POST.'; api_emit; return; }
            if api_require_session && api_require_csrf; then api_route_transactions_create; fi ;;
        '') api_set_error 400 'Parameter action wajib diisi.' ;;
        *) api_set_error 404 'Action API tidak ditemukan.' ;;
    esac
    api_emit
}
