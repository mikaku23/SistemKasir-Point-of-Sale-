#!/usr/bin/env bash
# Apache CGI entry point. Deploy on Linux/Ubuntu with Apache mod_cgi enabled.
set -o pipefail

APP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

cgi_fatal() {
    printf 'Status: 500 Internal Server Error\r\n'
    printf 'Content-Type: application/json; charset=utf-8\r\n'
    printf 'Cache-Control: no-store\r\n\r\n'
    printf '{"ok":false,"message":"%s","data":null}' "$1"
    exit 1
}

source "$APP_ROOT/lib/bootstrap.sh" || cgi_fatal 'Bootstrap gagal.'

# Load all non-empty route files. Each module owner implements the functions
# declared in its route file; shared dispatch remains in lib/api/router.sh.
for route_file in "$APP_ROOT"/lib/api/routes/*.sh; do
    [[ -f "$route_file" && -s "$route_file" ]] || continue
    source "$route_file" || cgi_fatal 'Gagal memuat API route.'
done
unset route_file

source "$APP_ROOT/lib/api/router.sh" || cgi_fatal 'API router gagal dimuat.'
api_main
