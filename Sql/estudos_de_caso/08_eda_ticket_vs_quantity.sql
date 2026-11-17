-- Projeto: Analise de E-Commerce | EDA de Clientes
-- 08: Ticket medio x quantidade x preco medio por unidade
--
-- Objetivo: comparar Paula e Carolina, clientes sinteticas do RFM.
-- Usamos somente pedidos entregues e somente produtos (sem frete).
-- Os descontos ja sao subtraidos no valor liquido dos itens.
--
-- INTERPRETACAO:
-- * ticket_medio = total de produtos / numero de pedidos entregues
-- * unidades_por_pedido = quantidade de unidades / numero de pedidos entregues
-- * preco_medio_por_unidade = total de produtos / unidades compradas
-- Assim podemos distinguir "gastar mais por pedido" de "comprar itens mais caros".

SELECT
    c.full_name AS cliente,
    COUNT(DISTINCT o.order_id) AS pedidos_entregues,
    SUM(oi.quantity) AS unidades_compradas,
    ROUND(
        SUM(oi.quantity * oi.unit_price - oi.discount_amount)
        / NULLIF(COUNT(DISTINCT o.order_id), 0), 2
    ) AS ticket_medio_produtos,
    ROUND(
        SUM(oi.quantity)::numeric
        / NULLIF(COUNT(DISTINCT o.order_id), 0), 2
    ) AS unidades_por_pedido,
    ROUND(
        SUM(oi.quantity * oi.unit_price - oi.discount_amount)
        / NULLIF(SUM(oi.quantity), 0), 2
    ) AS preco_medio_liquido_por_unidade
FROM public.customers AS c
JOIN public.orders AS o
    ON o.customer_id = c.customer_id
    AND o.order_status = 'delivered'
JOIN public.order_items AS oi
    ON oi.order_id = o.order_id
WHERE c.customer_id IN (1853, 3986)
GROUP BY c.customer_id, c.full_name
ORDER BY ticket_medio_produtos DESC;
