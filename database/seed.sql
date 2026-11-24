-- MINI POS development seed data.
-- No default Admin credentials are inserted here.
-- Use INSERT IGNORE so re-running this file does not overwrite existing test data.

USE mini_pos;

INSERT IGNORE INTO products (product_code, name, price, stock, min_stock, is_active)
VALUES
    ('BRG001', 'Indomie Goreng', 3500, 0, 5, 1),
    ('BRG002', 'Air Mineral 600ml', 4000, 0, 5, 1),
    ('BRG003', 'Roti Cokelat', 5000, 0, 3, 1),
    ('BRG004', 'Kopi Sachet', 2000, 0, 5, 1),
    ('BRG005', 'Susu UHT 250ml', 6000, 0, 3, 1);
