-- Projeto: Analise de E-Commerce | EDA de Clientes
-- 09: Quais categorias concentram o gasto dos dois clientes analisados?
-- Compara os 3 principais grupos de produtos por cliente.
-- Somente pedidos entregues, descontos aplicados, sem frete.
--
-- Dados sinteticos, com categorias e precos definidos pelo gerador.
-- A classificacao mostra compras observadas, nao preferencias permanentes.

WITH categorias_clientes AS (
    SELECT
        c.customer_id,
        c.full_name AS cliente,
        cat.category_name AS categoria,
        COUNT(DISTINCT o.order_id) AS pedidos_com_categoria,
        SUM(oi.quantity) AS unidades,
        SUM(oi.quantity * oi.unit_price - oi.discount_amount) AS valor_vendido
    FROM public.customers AS c
    JOIN public.orders AS o
        ON o.customer_id = c.customer_id
       AND o.order_status = 'delivered'
    JOIN public.order_items AS oi
        ON oi.order_id = o.order_id
    JOIN public.products AS p
        ON p.product_id = oi.product_id
    JOIN public.categories AS cat
        ON cat.category_id = p.category_id
    WHERE c.customer_id IN (1853, 3986)
    GROUP BY c.customer_id, c.full_name, cat.category_name
),
ranking AS (
    SELECT
        cliente,
        categoria,
        pedidos_com_categoria,
        unidades,
        ROUND(valor_vendido, 2) AS valor_vendido,
        ROUND(valor_vendido / NULLIF(unidades, 0), 2)
            AS preco_medio_liquido_unidade,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY valor_vendido DESC, categoria
        ) AS posicao
    FROM categorias_clientes
)
SELECT
    cliente,
    posicao,
    categoria,
    pedidos_com_categoria,
    unidades,
    valor_vendido,
    preco_medio_liquido_unidade
FROM ranking
WHERE posicao <= 3
ORDER BY cliente, posicao;
