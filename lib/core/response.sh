#!/usr/bin/env bash
[[ "${_MINI_POS_RESPONSE_LOADED:-0}" == "1" ]] && return 0
_MINI_POS_RESPONSE_LOADED=1

response_success() {
    local message="${1:-Berhasil}" data="${2:-null}"
    command -v jq >/dev/null 2>&1 || { printf '{"ok":true,"message":"%s","data":null}' "$message"; return; }
    jq -cn --arg message "$message" --argjson data "$data" '{ok:true,message:$message,data:$data}'
}

response_error() {
    local message="${1:-Terjadi kesalahan}" data="${2:-null}"
    command -v jq >/dev/null 2>&1 || { printf '{"ok":false,"message":"%s","data":null}' "$message"; return; }
    jq -cn --arg message "$message" --argjson data "$data" '{ok:false,message:$message,data:$data}'
}
