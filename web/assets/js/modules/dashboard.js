document.addEventListener('DOMContentLoaded', async () => {
  if (document.body.dataset.page !== 'dashboard') return;
  const money = value => new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(Number(value || 0));
  try {
    const { data } = await window.MINIPOS_API.apiRequest('dashboard.summary');
    document.querySelector('[data-metric="active-products"]').textContent = data.active_products;
    document.querySelector('[data-metric="transactions-today"]').textContent = data.transactions_today;
    document.querySelector('[data-metric="sales-today"]').textContent = money(data.sales_today);
    document.querySelector('[data-metric="low-stock"]').textContent = data.low_stock_products;
    document.querySelector('[data-generated-at]').textContent = `Diperbarui: ${data.generated_at}`;
  } catch (error) { document.querySelector('[data-dashboard-error]').textContent = error.message; }
});
