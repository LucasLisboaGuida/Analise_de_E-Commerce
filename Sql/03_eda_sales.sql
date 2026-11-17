-- Projeto: Analise de E-Commerce
-- Etapa 5: analise exploratoria de vendas
-- Pergunta 1: Qual o valor vendido dos pedidos entregues em cada mes?
--
-- Definicao:
--   * inclui somente pedidos com order_status = 'delivered'
--   * agrupa pelo mes da COMPRA (orders.order_date), nao da entrega
--   * considera produtos apos descontos; NAO inclui frete
--   * exclui pedidos cancelados, devolvidos e ainda nao entregues
--   * nao representa faturamento contabil ou recebimento de caixa

WITH totais_por_pedido AS (
    SELECT
        o.order_id,
        o.order_date,
        SUM(oi.quantity * oi.unit_price - oi.discount_amount) AS valor_produtos
    FROM public.orders AS o
    JOIN public.order_items AS oi
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.order_id, o.order_date
)
SELECT
    TO_CHAR(DATE_TRUNC('month', order_date), 'YYYY-MM') AS mes,
    COUNT(*) AS pedidos_entregues,
    ROUND(SUM(valor_produtos), 2) AS valor_vendido_produtos,
    ROUND(AVG(valor_produtos), 2) AS ticket_medio_produtos
FROM totais_por_pedido
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY DATE_TRUNC('month', order_date);
