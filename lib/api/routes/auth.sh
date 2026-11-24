#!/usr/bin/env bash
api_route_auth_login() {
    local username password user_json user_id sid csrf secure=''
    username="$(jq -r '.username // empty' <<< "$API_JSON")"
    password="$(jq -r '.password // empty' <<< "$API_JSON")"
    if [[ -z "$username" || -z "$password" ]]; then api_set_error 422 'Username dan password wajib diisi.'; return; fi
    user_json="$(auth_verify "$username" "$password")" || { api_set_error 401 'Username atau password salah.'; unset password; return; }
    user_id="$(jq -r '.id' <<< "$user_json")"
    sid="$(session_create "$user_id" "$username")" || { api_set_error 500 'Gagal membuat session.'; unset password; return; }
    session_load "$sid" >/dev/null 2>&1 || { api_set_error 500 'Gagal memuat session baru.'; unset password; return; }
    csrf="$SESSION_CSRF_TOKEN"
    [[ "${HTTPS:-off}" == 'on' ]] && secure='; Secure'
    API_SET_COOKIE="MINIPOS_SESSION=${sid}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${MINI_POS_SESSION_TTL}${secure}"
    api_set_success 'Login berhasil.' "$(jq -cn --arg username "$username" --arg csrf "$csrf" '{username:$username,csrf_token:$csrf}')"
    unset password
}

api_route_auth_me() {
    api_set_success 'Session aktif.' "$(jq -cn --arg username "$SESSION_USERNAME" --arg csrf "$SESSION_CSRF_TOKEN" '{username:$username,csrf_token:$csrf}')"
}

api_route_auth_logout() {
    session_destroy "$API_SESSION_ID" || true
    local secure=''
    [[ "${HTTPS:-off}" == 'on' ]] && secure='; Secure'
    API_SET_COOKIE="MINIPOS_SESSION=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0${secure}"
    api_set_success 'Logout berhasil.' 'null'
}
