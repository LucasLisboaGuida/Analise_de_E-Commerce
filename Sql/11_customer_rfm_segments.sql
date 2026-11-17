-- Projeto: Analise de E-Commerce | Segmentacao RFM
-- 11: Classificar os 5.000 clientes por Recencia, Frequencia e Valor.
-- Consulta somente de leitura.
--
-- Data de referencia fixa: 2026-11-17 (resultado reproduzivel).
-- R: dias desde a ultima COMPRA ENTREGUE (data do pedido, nao entrega).
-- F: numero de pedidos ENTREGUES (nao numero de itens).
-- M: valor total dos produtos de pedidos ENTREGUES, com descontos, sem frete.
-- Clientes sem compras entregues ficam em grupo separado (sem recencia).
-- O M recebe pontuacao por quintis apenas entre compradores.
-- R e F usam cortes definidos para este estudo, NAO regras universais.
--
-- Regras R:
-- <=30 dias = 5, <=90 = 4, <=180 = 3, <=365 = 2, >365 = 1
-- Regras F:
-- >=7 pedidos = 5, >=5 = 4, >=3 = 3, 2 = 2, 1 = 1
-- Regras M: NTILE(5) do valor monetario entre quem tem compra entregue,
-- de menor (1) para maior (5), com desempate por customer_id.
--
-- Os segmentos sao mutuamente exclusivos; a ordem de classificacao importa.

WITH metricas AS (
    SELECT
        c.customer_id,
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
    GROUP BY c.customer_id
),
pontuacoes AS (
    SELECT
        *,
        CASE
            WHEN frequencia_pedidos = 0 THEN 0
            WHEN recencia_dias <= 30 THEN 5
            WHEN recencia_dias <= 90 THEN 4
            WHEN recencia_dias <= 180 THEN 3
            WHEN recencia_dias <= 365 THEN 2
            ELSE 1
        END AS r,
        CASE
            WHEN frequencia_pedidos >= 7 THEN 5
            WHEN frequencia_pedidos >= 5 THEN 4
            WHEN frequencia_pedidos >= 3 THEN 3
            WHEN frequencia_pedidos = 2 THEN 2
            WHEN frequencia_pedidos = 1 THEN 1
            ELSE 0
        END AS f,
        CASE
            WHEN frequencia_pedidos = 0 THEN 0
            ELSE NTILE(5) OVER (
                PARTITION BY (frequencia_pedidos = 0)
                ORDER BY valor_monetario, customer_id
            )
        END AS m
    FROM metricas
),
segmentados AS (
    SELECT
        *,
        CASE
            WHEN frequencia_pedidos = 0 THEN 'Sem compra entregue'
            WHEN r >= 4 AND f >= 4 AND m >= 4 THEN 'Campeoes'
            WHEN f >= 4 AND r >= 3 THEN 'Fieis'
            WHEN m >= 4 AND r >= 3 THEN 'Alto valor'
            WHEN r <= 2 AND (f >= 4 OR m >= 4) THEN 'Em risco'
            WHEN r >= 4 AND f = 1 THEN 'Compra unica recente'
            WHEN r >= 3 THEN 'Regulares'
            ELSE 'Baixa atividade'
        END AS segmento
    FROM pontuacoes
)
SELECT
    segmento,
    COUNT(*) AS clientes,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)
        AS percentual_clientes,
    ROUND(SUM(valor_monetario), 2) AS valor_vendido_produtos,
    ROUND(
        100.0 * SUM(valor_monetario)
        / NULLIF(SUM(SUM(valor_monetario)) OVER (), 0),
        2
    ) AS participacao_vendas_pct
FROM segmentados
GROUP BY segmento
ORDER BY clientes DESC, segmento;

-- O esperado para o dataset gerado: soma de 'clientes' = 5.000.
-- 'Sem compra entregue' deve somar 951 para a semente padrao.
-- Segmentos sinalizam padroes DESCRITIVOS, nao comprovam fidelidade,
-- intencao de revenda ou risco real de evasao.
