-- Projeto: Analise de E-Commerce | Camada analitica para Power BI
-- 12: Esquema estrela com VIEWs no schema "bi".
--
-- IMPORTANTE
-- * Execute conectado ao banco "ecommerce".
-- * Nao altera, apaga ou recria as tabelas operacionais em "public".
-- * As views refletem os dados atuais do banco; nenhuma carga e duplicada.
-- * Nunca relacione diretamente fact_orders a fact_order_items no Power BI.
-- * Dimensoes filtram fatos (relacionamentos 1:* de direcao unica).

BEGIN;

CREATE SCHEMA IF NOT EXISTS bi;

-- DIMENSOES -------------------------------------------------------------

-- Uma linha por cliente.
CREATE OR REPLACE VIEW bi.dim_customer AS
SELECT
    c.customer_id,
    c.full_name,
    c.customer_status,
    c.created_at::date AS customer_since
FROM public.customers AS c;

-- Uma linha por produto. A categoria ja vem junto para simplificar
-- o esquema estrela (sem relacionamento adicional produto -> categoria).
CREATE OR REPLACE VIEW bi.dim_product AS
SELECT
    p.product_id,
    p.sku,
    p.product_name,
    c.category_name,
    p.current_price,
    p.is_active
FROM public.products AS p
JOIN public.categories AS c
    ON c.category_id = p.category_id;

-- Uma linha por estado registrado no endereco historico dos pedidos.
CREATE OR REPLACE VIEW bi.dim_state AS
SELECT DISTINCT
    o.shipping_state AS state_code
FROM public.orders AS o
WHERE o.shipping_state IS NOT NULL;

-- Uma linha por dia, do primeiro ao ultimo pedido disponivel.
-- Datas de pedidos, nao datas de entrega.
CREATE OR REPLACE VIEW bi.dim_date AS
SELECT
    calendario.dia::date AS date_key,
    EXTRACT(YEAR FROM calendario.dia)::integer AS year_num,
    EXTRACT(MONTH FROM calendario.dia)::integer AS month_num,
    EXTRACT(QUARTER FROM calendario.dia)::integer AS quarter_num,
    TO_CHAR(calendario.dia, 'YYYY-MM') AS year_month
FROM generate_series(
    (SELECT MIN(order_date)::date FROM public.orders),
    (SELECT MAX(order_date)::date FROM public.orders),
    INTERVAL '1 day'
) AS calendario(dia);

-- FATOS ----------------------------------------------------------------

-- GRAO: uma linha por pedido. Frete fica aqui para nao ser contado
-- varias vezes quando um pedido possui multiplos produtos.
CREATE OR REPLACE VIEW bi.fact_orders AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_date::date AS order_date_key,
    o.shipping_state AS state_code,
    o.order_status,
    o.shipping_cost,
    o.currency_code
FROM public.orders AS o;

-- GRAO: uma linha por item de pedido (order_item_id).
-- Os valores monetarios sao por linha; frete nao esta incluido.
CREATE OR REPLACE VIEW bi.fact_order_items AS
SELECT
    oi.order_item_id,
    oi.order_id,
    o.customer_id,
    oi.product_id,
    o.order_date::date AS order_date_key,
    o.shipping_state AS state_code,
    o.order_status,
    oi.quantity,
    oi.unit_price,
    oi.discount_amount,
    (oi.quantity * oi.unit_price)::numeric(14, 2) AS gross_product_value,
    (oi.quantity * oi.unit_price - oi.discount_amount)::numeric(14, 2)
        AS net_product_value
FROM public.order_items AS oi
JOIN public.orders AS o
    ON o.order_id = oi.order_id;

COMMIT;

-- VALIDACAO 1: conferir as seis views (nao espera valores nulos).
SELECT 'dim_customer' AS objeto, COUNT(*) AS registros FROM bi.dim_customer
UNION ALL SELECT 'dim_product', COUNT(*) FROM bi.dim_product
UNION ALL SELECT 'dim_state', COUNT(*) FROM bi.dim_state
UNION ALL SELECT 'dim_date', COUNT(*) FROM bi.dim_date
UNION ALL SELECT 'fact_orders', COUNT(*) FROM bi.fact_orders
UNION ALL SELECT 'fact_order_items', COUNT(*) FROM bi.fact_order_items
ORDER BY objeto;

-- VALIDACAO 2: valor vendido de produtos em pedidos entregues,
-- reproduz a definicao das consultas exploratorias (sem frete).
SELECT
    COUNT(DISTINCT order_id) AS pedidos_entregues,
    ROUND(SUM(net_product_value), 2) AS valor_vendido_produtos
FROM bi.fact_order_items
WHERE order_status = 'delivered';

-- Dica: no Power BI, importe apenas essas seis views do schema "bi".
-- Modelagem: veja Bi/README.md no repositorio.
