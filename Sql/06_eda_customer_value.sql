-- Projeto: Analise de E-Commerce | Analise exploratoria
-- 06: Frequencia de compras x valor vendido por grupo de clientes
--
-- Pergunta: clientes com 4 ou mais compras entregues respondem
-- por qual parcela do valor total vendido?
--
-- Definicoes:
--   * Conta somente pedidos com status 'delivered'.
--   * Valor vendido: itens * preco historico - desconto, SEM frete.
--   * Clientes sem pedidos entregues permanecem na analise com valor zero.
--   * Percentuais usam como base o valor de TODOS os pedidos entregues.
--   * Dados sinteticos; nao sao indicadores reais de mercado.
--
-- Consulta somente de leitura.

WITH metricas_cliente AS (
    SELECT
        c.customer_id,
        COUNT(DISTINCT o.order_id) AS pedidos_entregues,
        COALESCE(
            SUM(oi.quantity * oi.unit_price - oi.discount_amount),
            0
        ) AS valor_vendido_cliente
    FROM public.customers AS c
    LEFT JOIN public.orders AS o
        ON o.customer_id = c.customer_id
       AND o.order_status = 'delivered'
    LEFT JOIN public.order_items AS oi
        ON oi.order_id = o.order_id
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
        END AS ordem,
        valor_vendido_cliente
    FROM metricas_cliente
)
SELECT
    faixa_compras,
    COUNT(*) AS clientes,
    ROUND(SUM(valor_vendido_cliente), 2) AS valor_vendido_produtos,
    ROUND(
        100.0 * SUM(valor_vendido_cliente)
        / NULLIF(SUM(SUM(valor_vendido_cliente)) OVER (), 0),
        2
    ) AS participacao_vendas_pct,
    ROUND(AVG(valor_vendido_cliente), 2) AS valor_medio_por_cliente
FROM faixas
GROUP BY faixa_compras, ordem
ORDER BY ordem;
