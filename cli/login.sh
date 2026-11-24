#!/usr/bin/env bash
cli_login() {
    local username password result rc
    local attempt
    for attempt in 1 2 3; do
        read -r -p 'Username Admin: ' username
        read -r -s -p 'Password Admin: ' password; printf '\n'
        if result="$(auth_verify "$username" "$password")"; then rc=0; else rc=$?; fi
        unset password
        if (( rc == 0 )); then
            CLI_USER_ID="$(jq -r '.id' <<< "$result")"
            CLI_USERNAME="$(jq -r '.username' <<< "$result")"
            printf 'Login berhasil. Selamat datang, %s.\n' "$CLI_USERNAME"
            return 0
        fi
        printf 'Login gagal. Percobaan %s dari 3.\n' "$attempt" >&2
    done
    return 1
}
