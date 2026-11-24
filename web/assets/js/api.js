/* Shared MINI POS API client. Business logic stays in Bash. */
(() => {
  let csrfToken = null;
  async function apiRequest(action, options = {}) {
    const method = (options.method || 'GET').toUpperCase();
    const headers = { Accept: 'application/json' };
    const init = { method, credentials: 'same-origin', headers };
    if (options.body !== undefined) { headers['Content-Type'] = 'application/json'; init.body = JSON.stringify(options.body); }
    if (method === 'POST' && options.csrf !== false && csrfToken) headers['X-CSRF-Token'] = csrfToken;
    const response = await fetch(`/cgi-bin/api.cgi?action=${encodeURIComponent(action)}`, init);
    let payload;
    try { payload = await response.json(); } catch { throw new Error(`Respons server tidak valid (${response.status}).`); }
    if (payload?.data?.csrf_token) csrfToken = payload.data.csrf_token;
    if (!response.ok || !payload.ok) {
      if (response.status === 401 && !location.pathname.endsWith('/login.html')) location.href = '/login.html';
      throw new Error(payload.message || 'Permintaan gagal.');
    }
    return payload;
  }
  window.MINIPOS_API = { apiRequest };
})();
