document.addEventListener('DOMContentLoaded', async () => {
  if (document.body.dataset.page === 'login') return;
  try {
    const result = await window.MINIPOS_API.apiRequest('auth.me');
    const name = document.querySelector('[data-admin-name]');
    if (name) name.textContent = result.data.username;
  } catch { location.href = '/login.html'; return; }
  const logout = document.querySelector('[data-logout]');
  if (logout) logout.addEventListener('click', async () => {
    try { await window.MINIPOS_API.apiRequest('auth.logout', { method: 'POST', body: {} }); }
    finally { location.href = '/login.html'; }
  });
});
