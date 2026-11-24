#!/usr/bin/env bash
api_route_dashboard_summary() {
    local data
    data="$(dashboard_summary)" || { api_set_error 500 'Gagal mengambil ringkasan dashboard.'; return; }
    api_set_success 'Ringkasan dashboard berhasil diambil.' "$data"
}
