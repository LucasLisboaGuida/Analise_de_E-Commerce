-- Projeto: Analise de E-Commerce | EDA de Clientes
-- 07: RFM basico (Recencia, Frequencia e Valor Monetario)
--
-- Pergunta: quem sao os 10 clientes com maior valor acumulado
-- em produtos de pedidos entregues?
--
-- R = dias desde o pedido entregue mais recente ate 2026-11-17
-- F = numero de pedidos entregues (COUNT DISTINCT evita inflar a frequencia)
-- M = soma de produtos dos pedidos entregues, apos descontos, sem frete
--
-- A data de referencia e fixa para que o relatorio seja reproduzivel.
-- Isto calcula metricas RFM; a pontuacao/segmentacao ficara para outra etapa.
-- Os dados e nomes sao ficticios. Consulta somente de leitura.

WITH rfm_base AS (
    SELECT
        c.customer_id,
        c.full_name,
        DATE '2026-11-17' - MAX(o.order_date)::date AS recencia_dias,
        COUNT(DISTINCT o.order_id) AS frequencia_pedidos,
        COALESCE(
            SUM(oi.quantity * oi.unit_price - oi.discount_amount),
            0
        ) AS valor_monetario
    FROM public.customers AS c
    LEFT JOIN public.orders AS o
        ON o.customer_id = c.customer_id
       AND o.order_status = 'delivered'
    LEFT JOIN public.order_items AS oi
        ON oi.order_id = o.order_id
    GROUP BY c.customer_id, c.full_name
)
SELECT
    customer_id,
    full_name,
    recencia_dias,
    frequencia_pedidos,
    ROUND(valor_monetario, 2) AS valor_total_produtos
FROM rfm_base
WHERE frequencia_pedidos > 0
ORDER BY valor_monetario DESC, frequencia_pedidos DESC, customer_id
LIMIT 10;
