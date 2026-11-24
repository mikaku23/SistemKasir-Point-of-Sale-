#!/usr/bin/env bash
[[ "${_MINI_POS_VALIDATION_LOADED:-0}" == "1" ]] && return 0
_MINI_POS_VALIDATION_LOADED=1

validate_uint() {
    local value="${1-}" maximum="${2:-18446744073709551615}"
    [[ "$value" =~ ^[0-9]+$ ]] || return 1
    while [[ ${#value} -gt 1 && ${value:0:1} == 0 ]]; do value="${value:1}"; done
    (( ${#value} < ${#maximum} )) && { printf '%s' "$value"; return 0; }
    (( ${#value} > ${#maximum} )) && return 1
    [[ "$value" == "$maximum" || ! "$value" > "$maximum" ]] || return 1
    printf '%s' "$value"
}

validate_text() {
    local label="${1-}" value="${2-}" max="${3:-255}"
    [[ -n "${value//[[:space:]]/}" ]] || { printf '%s wajib diisi.\n' "$label" >&2; return 1; }
    [[ ! "$value" =~ [[:cntrl:]] ]] || { printf '%s mengandung karakter kontrol.\n' "$label" >&2; return 1; }
    (( ${#value} <= max )) || { printf '%s maksimal %s karakter.\n' "$label" "$max" >&2; return 1; }
}
