#!/usr/bin/env bash
# MINI POS shared configuration. This file is safe to source repeatedly.
[[ "${_MINI_POS_CONFIG_LOADED:-0}" == "1" ]] && return 0
_MINI_POS_CONFIG_LOADED=1

# Resolve the project root from this file, not from the caller's current directory.
# lib/core/config.sh -> project root is two directories above this file.
if [[ -z "${MINI_POS_ROOT:-}" ]]; then
    MINI_POS_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

MINI_POS_DB_CONFIG="${MINI_POS_DB_CONFIG:-${MINI_POS_ROOT}/config/database.conf}"
MINI_POS_SESSION_DIR="${MINI_POS_SESSION_DIR:-${MINI_POS_ROOT}/storage/sessions}"
MINI_POS_SESSION_TTL="${MINI_POS_SESSION_TTL:-28800}"
MINI_POS_MAX_REQUEST_BYTES="${MINI_POS_MAX_REQUEST_BYTES:-65536}"

mini_pos_require_file() {
    local path="${1-}"
    [[ -f "$path" && -r "$path" ]]
}
