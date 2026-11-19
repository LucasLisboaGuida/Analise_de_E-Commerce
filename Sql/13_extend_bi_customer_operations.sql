-- Projeto: Analise de E-Commerce | Camada analitica
-- 13: Extensao do modelo para paginas de Clientes/RFM e Operacoes.
-- Execute no banco "ecommerce" APOS Sql/12_create_bi_views.sql.
--
-- Nao altera as nove tabelas operacionais em public.
-- Acrescenta colunas ao FIM de bi.dim_customer (preserva as colunas
-- e os relacionamentos existentes) e cria tres novas views analiticas.
--
-- RFM: classificacao HISTORICA fixa em 17/11/2026;
-- considera apenas pedidos entregues, valor de produtos sem frete.
-- Nao interpreta "Em risco" como previsao de churn.
-- Pagamentos: tentativas / resultados; nao e medida de faturamento.
-- Estoque: posicao sintetica atual, NAO historico de movimentacoes.

BEGIN;

-- Pagina Clientes: um registro por cliente, com o RFM anexado.
CREATE OR REPLACE VIEW bi.dim_customer AS
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
    -- MANTER estas quatro colunas na mesma ordem do SQL 12!
    c.customer_id,
    c.full_name,
    c.customer_status,
    c.created_at::date AS customer_since,

    -- Colunas novas, anexadas para o Power BI:
    s.recencia_dias,
    s.frequencia_pedidos,
    s.valor_monetario,
    s.r AS r_score,
    s.f AS f_score,
    s.m AS m_score,
    s.segmento AS rfm_segment,
    CASE
        WHEN s.frequencia_pedidos = 0 THEN 'Nenhuma compra entregue'
        WHEN s.frequencia_pedidos = 1 THEN '1 compra'
        WHEN s.frequencia_pedidos = 2 THEN '2 compras'
        WHEN s.frequencia_pedidos = 3 THEN '3 compras'
        ELSE '4 ou mais compras'
    END AS frequency_band,
    CASE
        WHEN s.frequencia_pedidos = 0 THEN 0
        WHEN s.frequencia_pedidos = 1 THEN 1
        WHEN s.frequencia_pedidos = 2 THEN 2
        WHEN s.frequencia_pedidos = 3 THEN 3
        ELSE 4
    END AS frequency_band_order
FROM public.customers AS c
JOIN segmentados AS s
    ON s.customer_id = c.customer_id;

-- Pagina Operacoes: GRAO uma tentativa de pagamento.
CREATE OR REPLACE VIEW bi.fact_payments AS
SELECT
    p.payment_id,
    p.order_id,
    o.customer_id,
    o.order_date::date AS order_date_key,
    o.shipping_state AS state_code,
    p.payment_date,
    p.payment_method,
    p.payment_status,
    p.amount
FROM public.payments AS p
JOIN public.orders AS o
    ON o.order_id = p.order_id;

-- Pagina Operacoes: GRAO um registro de envio/entrega.
CREATE OR REPLACE VIEW bi.fact_shipments AS
SELECT
    s.shipment_id,
    s.order_id,
    o.customer_id,
    o.order_date::date AS order_date_key,
    o.shipping_state AS state_code,
    s.shipment_status,
    s.carrier,
    s.shipped_at,
    s.delivered_at,
    CASE
        WHEN s.shipped_at IS NOT NULL AND s.delivered_at IS NOT NULL
        THEN s.delivered_at::date - s.shipped_at::date
        ELSE NULL
    END AS transit_days
FROM public.shipments AS s
JOIN public.orders AS o
    ON o.order_id = s.order_id;

-- Pagina Operacoes: GRAO um produto no estoque atual (snapshot).
CREATE OR REPLACE VIEW bi.fact_inventory AS
SELECT
    i.inventory_id,
    i.product_id,
    i.quantity_on_hand,
    i.reorder_level,
    i.last_updated_at::date AS snapshot_date,
    (i.quantity_on_hand <= i.reorder_level) AS is_low_stock
FROM public.inventory AS i;

COMMIT;

-- TESTE 1: conferencias de quantidade.
SELECT 'dim_customer' AS objeto, COUNT(*) AS registros FROM bi.dim_customer
UNION ALL SELECT 'fact_payments', COUNT(*) FROM bi.fact_payments
UNION ALL SELECT 'fact_shipments', COUNT(*) FROM bi.fact_shipments
UNION ALL SELECT 'fact_inventory', COUNT(*) FROM bi.fact_inventory
ORDER BY objeto;

-- TESTE 2: mesmos valores usados na analise RFM anterior.
SELECT
    COUNT(*) AS clientes,
    COUNT(*) FILTER (WHERE frequencia_pedidos >= 1) AS clientes_com_compra,
    COUNT(*) FILTER (WHERE frequencia_pedidos >= 2) AS clientes_recorrentes,
    COUNT(*) FILTER (WHERE rfm_segment = 'Em risco') AS clientes_em_risco,
    COUNT(*) FILTER (WHERE rfm_segment = 'Campeoes') AS clientes_campeoes,
    COUNT(*) FILTER (WHERE rfm_segment = 'Sem compra entregue') AS sem_compra_entregue,
    ROUND(SUM(valor_monetario), 2) AS valor_historico_produtos
FROM bi.dim_customer;

-- TESTE 3: totais de status, sem somar valores de pagamento como receita.
SELECT payment_status, COUNT(*) AS tentativas
FROM bi.fact_payments
GROUP BY payment_status
ORDER BY tentativas DESC;
