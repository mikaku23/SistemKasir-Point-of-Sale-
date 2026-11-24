document.addEventListener('DOMContentLoaded', () => {
  if (document.body.dataset.page !== 'transactions') return;
  const form = document.querySelector('#transaction-form'), list = document.querySelector('#transaction-items');
  const message = document.querySelector('#transaction-message');
  const addRow = () => {
    const row = document.createElement('div'); row.className = 'cart-row';
    row.innerHTML = '<label>ID Barang<input name="product_id" type="number" min="1" required></label><label>Jumlah<input name="quantity" type="number" min="1" required></label><button class="button button-quiet remove-row" type="button">Hapus</button>';
    row.querySelector('.remove-row').addEventListener('click', () => row.remove()); list.append(row);
  };
  document.querySelector('#add-item').addEventListener('click', addRow); addRow();
  form.addEventListener('submit', async event => {
    event.preventDefault(); message.textContent = 'Memproses transaksi...';
    const items = [...list.querySelectorAll('.cart-row')].map(row => ({ product_id: Number(row.querySelector('[name="product_id"]').value), quantity: Number(row.querySelector('[name="quantity"]').value) }));
    const paid = Number(form.querySelector('[name="paid"]').value);
    try {
      const { data } = await window.MINIPOS_API.apiRequest('transactions.create', { method: 'POST', body: { paid, items } });
      message.textContent = `Berhasil ${data.invoice_number}. Total Rp${data.total}; kembalian Rp${data.change_amount}.`;
      form.reset(); list.innerHTML = ''; addRow();
    } catch (error) { message.textContent = error.message; }
  });
});
