-- Projeto: Análise de E-Commerce | EDA
-- 05: Frequência de compra dos clientes
-- Contamos apenas pedidos entregues para manter a definição da análise anterior.
-- Clientes sem pedidos entregues continuam na análise (0 pedidos).
-- Dados sintéticos: não interpretar como taxa real de retenção.

WITH pedidos_por_cliente AS (
    SELECT
        c.customer_id,
        COUNT(o.order_id) FILTER (
            WHERE o.order_status = 'delivered'
        ) AS pedidos_entregues
    FROM public.customers AS c
    LEFT JOIN public.orders AS o
        ON o.customer_id = c.customer_id
    GROUP BY c.customer_id
),
faixas AS (
    SELECT
        CASE
            WHEN pedidos_entregues = 0 THEN 'Nenhuma compra entregue'
            WHEN pedidos_entregues = 1 THEN '1 compra'
            WHEN pedidos_entregues = 2 THEN '2 compras'
            WHEN pedidos_entregues = 3 THEN '3 compras'
            ELSE '4 ou mais compras'
        END AS faixa_compras,
        CASE
            WHEN pedidos_entregues = 0 THEN 0
            WHEN pedidos_entregues = 1 THEN 1
            WHEN pedidos_entregues = 2 THEN 2
            WHEN pedidos_entregues = 3 THEN 3
            ELSE 4
        END AS ordem
    FROM pedidos_por_cliente
)
SELECT
    faixa_compras,
    COUNT(*) AS clientes,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS percentual_clientes
FROM faixas
GROUP BY faixa_compras, ordem
ORDER BY ordem;
