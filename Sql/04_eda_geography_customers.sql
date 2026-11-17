-- Projeto: Análise de E-Commerce | EDA
-- 04: Distribuição geográfica e recorrência de clientes
-- Todas as consultas são somente de leitura.
-- Pedidos considerados: apenas 'delivered'.
-- Vendas = valor dos produtos após descontos, sem frete.

-- Análise 1: Vendas por estado de entrega no momento da compra.
WITH vendas AS (
    SELECT
        o.order_id,
        o.shipping_state AS estado,
        SUM(oi.quantity * oi.unit_price - oi.discount_amount) AS valor_pedido
    FROM public.orders AS o
    JOIN public.order_items AS oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.order_id, o.shipping_state
)
SELECT
    estado,
    COUNT(*) AS pedidos_entregues,
    ROUND(SUM(valor_pedido), 2) AS valor_vendido,
    ROUND(AVG(valor_pedido), 2) AS ticket_medio
FROM vendas
GROUP BY estado
ORDER BY valor_vendido DESC;

-- Análise 2: Quantos clientes compraram e quantos voltaram?
-- Recorrente = cliente com pelo menos dois pedidos ENTREGUES.
-- Denominador da taxa = clientes com pelo menos um pedido entregue,
-- não todos os cadastrados.
WITH pedidos_por_cliente AS (
    SELECT
        c.customer_id,
        COUNT(o.order_id) FILTER (WHERE o.order_status = 'delivered') AS pedidos_entregues
    FROM public.customers AS c
    LEFT JOIN public.orders AS o ON o.customer_id = c.customer_id
    GROUP BY c.customer_id
)
SELECT
    COUNT(*) AS clientes_cadastrados,
    COUNT(*) FILTER (WHERE pedidos_entregues >= 1) AS clientes_com_compra_entregue,
    COUNT(*) FILTER (WHERE pedidos_entregues >= 2) AS clientes_recorrentes,
    COUNT(*) FILTER (WHERE pedidos_entregues = 0) AS clientes_sem_compra_entregue,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE pedidos_entregues >= 2)
        / NULLIF(COUNT(*) FILTER (WHERE pedidos_entregues >= 1), 0),
        2
    ) AS taxa_recorrencia_pct
FROM pedidos_por_cliente;

-- Nota: Os dados são sintéticos e a escolha de clientes/localidades
-- tem probabilidades definidas no gerador. Não representam o mercado real.
