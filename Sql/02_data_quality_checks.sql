-- Project: E-commerce Data Platform
-- Version: 1.0
-- Purpose: Data quality checks after loading the synthetic dataset.
-- All queries are read-only. They do not modify the database.
-- Run against the ecommerce database after 03_import_data.py.
--
-- Query 1: Row counts (baseline for auditing the load)
SELECT 'customers' AS tabela, COUNT(*) AS registros FROM public.customers
UNION ALL SELECT 'addresses', COUNT(*) FROM public.addresses
UNION ALL SELECT 'categories', COUNT(*) FROM public.categories
UNION ALL SELECT 'products', COUNT(*) FROM public.products
UNION ALL SELECT 'orders', COUNT(*) FROM public.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM public.order_items
UNION ALL SELECT 'payments', COUNT(*) FROM public.payments
UNION ALL SELECT 'shipments', COUNT(*) FROM public.shipments
UNION ALL SELECT 'inventory', COUNT(*) FROM public.inventory
ORDER BY tabela;

-- Query 2: Business-level quality checks.
-- Expected outcome for the generated dataset: zero problems in every row.
-- Referential integrity is additionally enforced by PostgreSQL foreign keys.
WITH totais_pedidos AS (
    SELECT
        o.order_id,
        o.shipping_cost
            + COALESCE(
                SUM(oi.quantity * oi.unit_price - oi.discount_amount),
                0
            ) AS total_pedido
    FROM public.orders AS o
    LEFT JOIN public.order_items AS oi
        ON oi.order_id = o.order_id
    GROUP BY o.order_id, o.shipping_cost
)
SELECT
    'Pedidos sem itens' AS verificacao,
    COUNT(*) AS problemas
FROM public.orders AS o
WHERE NOT EXISTS (
    SELECT 1 FROM public.order_items AS oi
    WHERE oi.order_id = o.order_id
)

UNION ALL

SELECT
    'Pedidos sem pagamento',
    COUNT(*)
FROM public.orders AS o
WHERE NOT EXISTS (
    SELECT 1 FROM public.payments AS p
    WHERE p.order_id = o.order_id
)

UNION ALL

SELECT
    'Pedidos anteriores ao cadastro do cliente',
    COUNT(*)
FROM public.orders AS o
JOIN public.customers AS c ON c.customer_id = o.customer_id
WHERE o.order_date < c.created_at

UNION ALL

SELECT
    'Pagamentos com valor divergente do pedido',
    COUNT(*)
FROM public.payments AS p
JOIN totais_pedidos AS t ON t.order_id = p.order_id
WHERE p.amount <> t.total_pedido

UNION ALL

SELECT
    'Pedidos entregues sem entrega registrada',
    COUNT(*)
FROM public.orders AS o
WHERE o.order_status = 'delivered'
  AND NOT EXISTS (
      SELECT 1
      FROM public.shipments AS s
      WHERE s.order_id = o.order_id
        AND s.shipment_status = 'delivered'
        AND s.delivered_at IS NOT NULL
  )

UNION ALL

SELECT
    'Envios anteriores a data do pedido',
    COUNT(*)
FROM public.shipments AS s
JOIN public.orders AS o ON o.order_id = s.order_id
WHERE s.shipped_at < o.order_date

UNION ALL

SELECT
    'Produtos sem registro de estoque',
    COUNT(*)
FROM public.products AS p
WHERE NOT EXISTS (
    SELECT 1 FROM public.inventory AS i
    WHERE i.product_id = p.product_id
)

UNION ALL

SELECT
    'Clientes com mais de um endereco padrao',
    COUNT(*)
FROM (
    SELECT a.customer_id
    FROM public.addresses AS a
    GROUP BY a.customer_id
    HAVING COUNT(*) FILTER (WHERE a.is_default) > 1
) AS duplicados

ORDER BY verificacao;

-- Note:
-- These checks cover selected business rules, not every possible issue.
-- The payment amount comparison is PER payment attempt, because an order
-- may have failed attempts and refunds. Do not sum all payment attempts
-- together to calculate revenue.
