#!/usr/bin/env bash
# Load MINI POS shared core first, then all available business modules.
# This file must be sourced, not executed: source lib/bootstrap.sh
[[ "${_MINI_POS_BOOTSTRAP_LOADED:-0}" == "1" ]] && return 0

# Define MINI_POS_ROOT BEFORE referencing it. The :- fallback also works when
# callers use `set -u` (nounset), including tests/manual_products_crud.sh.
if [[ -z "${MINI_POS_ROOT:-}" ]]; then
    MINI_POS_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Core load order matters: config -> validation/response -> database -> auth/session.
for _mini_pos_file in \
    "$MINI_POS_ROOT/lib/core/config.sh" \
    "$MINI_POS_ROOT/lib/core/validation.sh" \
    "$MINI_POS_ROOT/lib/core/response.sh" \
    "$MINI_POS_ROOT/lib/core/db.sh" \
    "$MINI_POS_ROOT/lib/core/auth.sh" \
    "$MINI_POS_ROOT/lib/core/session.sh"; do

    if [[ ! -f "$_mini_pos_file" ]]; then
        printf 'bootstrap: file core tidak ditemukan: %s\n' "$_mini_pos_file" >&2
        unset _mini_pos_file
        return 1
    fi

    # shellcheck source=/dev/null
    source "$_mini_pos_file" || {
        printf 'bootstrap: gagal memuat: %s\n' "$_mini_pos_file" >&2
        unset _mini_pos_file
        return 1
    }
done

# Load available modules in a deterministic order. Empty scaffold files are
# skipped so a teammate can implement their module independently.
for _mini_pos_module in products inventory transactions history reports dashboard; do
    _mini_pos_file="$MINI_POS_ROOT/lib/modules/${_mini_pos_module}.sh"
    if [[ -f "$_mini_pos_file" && -s "$_mini_pos_file" ]]; then
        # shellcheck source=/dev/null
        source "$_mini_pos_file" || {
            printf 'bootstrap: gagal memuat modul %s\n' "$_mini_pos_module" >&2
            unset _mini_pos_file _mini_pos_module
            return 1
        }
    fi
done

unset _mini_pos_file _mini_pos_module
_MINI_POS_BOOTSTRAP_LOADED=1
