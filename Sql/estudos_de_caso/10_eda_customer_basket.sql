-- Projeto: Analise de E-Commerce | EDA de Clientes
-- 10: Analise das compras de eletronicos de uma cliente ficticia
--
-- Hipotese: compras de multiplas unidades podem sinalizar compra para
-- revenda, presente, uso empresarial, etc. Nao sao prova de revenda.
-- Foco: cliente 1853, pedidos entregues, categorias Celulares e TVs.
-- Produtos e clientes sao sinteticos.
--
-- Quantidade por item e valor liquido (desconto aplicado), sem frete.

SELECT
    o.order_id,
    o.order_date::date AS data_pedido,
    c.category_name AS categoria,
    p.product_name AS produto,
    oi.quantity AS unidades,
    oi.unit_price AS preco_unitario,
    oi.discount_amount AS desconto_item,
    ROUND(
        oi.quantity * oi.unit_price - oi.discount_amount,
        2
    ) AS total_item
FROM public.orders AS o
JOIN public.order_items AS oi
    ON oi.order_id = o.order_id
JOIN public.products AS p
    ON p.product_id = oi.product_id
JOIN public.categories AS c
    ON c.category_id = p.category_id
WHERE o.customer_id = 1853
  AND o.order_status = 'delivered'
  AND c.category_name IN ('Celulares', 'TVs')
ORDER BY o.order_date, o.order_id, oi.quantity DESC;
