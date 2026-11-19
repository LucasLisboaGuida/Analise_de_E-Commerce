# Power BI — Páginas 2 e 3

## Preparação

Execute Sql/13_extend_bi_customer_operations.sql no banco ecommerce, após o script 12. Ele mantém as views atuais, acrescenta atributos RFM à dimensão de clientes e cria três novas views: fact_payments, fact_shipments e fact_inventory.

No Power BI Desktop, abra o PBIX existente e atualize a consulta bi dim_customer (se necessário, em Transformar dados, confira se uma etapa de escolha de colunas impede a entrada das novas colunas). Depois use Obter dados > PostgreSQL > Importar para carregar somente as três novas views. Clique em Atualizar.

## Novos relacionamentos

Todas as conexões são 1 para muitos, filtro único da dimensão para o fato, e ativas:

| Dimensão | Fato |
| --- | --- |
| dim_customer.customer_id | fact_payments.customer_id |
| dim_customer.customer_id | fact_shipments.customer_id |
| dim_date.date_key | fact_payments.order_date_key |
| dim_date.date_key | fact_shipments.order_date_key |
| dim_state.state_code | fact_payments.state_code |
| dim_state.state_code | fact_shipments.state_code |
| dim_product.product_id | fact_inventory.product_id |

Não conecte fatos diretamente. Estoque é um retrato atual e não tem relação com as dimensões de estado e data.

## Página 2 — Clientes e RFM

Crie as medidas DAX abaixo individualmente (ajuste nomes das tabelas se o Power BI os exibir de outra forma):

~~~dax
Clientes Cadastrados =
DISTINCTCOUNT('bi dim_customer'[customer_id])
~~~

~~~dax
Clientes Recorrentes Histórico =
CALCULATE(
    DISTINCTCOUNT('bi dim_customer'[customer_id]),
    'bi dim_customer'[frequencia_pedidos] >= 2
)
~~~

~~~dax
Taxa Recorrência Histórico =
DIVIDE(
    [Clientes Recorrentes Histórico],
    CALCULATE(
        DISTINCTCOUNT('bi dim_customer'[customer_id]),
        'bi dim_customer'[frequencia_pedidos] >= 1
    )
)
~~~

~~~dax
Clientes Em Risco =
CALCULATE(
    DISTINCTCOUNT('bi dim_customer'[customer_id]),
    'bi dim_customer'[rfm_segment] = "Em risco"
)
~~~

~~~dax
Valor Histórico RFM =
SUM('bi dim_customer'[valor_monetario])
~~~

Layout: quatro cartões (5.000 cadastrados; 3.164 recorrentes; 78,14% taxa; 670 em risco), barras de clientes por rfm_segment, barras de valor histórico por rfm_segment e barras de clientes por frequency_band. Ordene frequency_band usando frequency_band_order.

ATENÇÃO: O RFM é um retrato histórico calculado com data de referência de 17/11/2026. Não o apresente como recalculável por filtros de datas. A análise não prevê churn real.

## Página 3 — Operações e logística

~~~dax
Pedidos Totais =
DISTINCTCOUNT('bi fact_orders'[order_id])
~~~

~~~dax
Pedidos Cancelados =
CALCULATE(
    [Pedidos Totais],
    'bi fact_orders'[order_status] = "cancelled"
)
~~~

~~~dax
Taxa Cancelamento =
DIVIDE([Pedidos Cancelados], [Pedidos Totais])
~~~

~~~dax
Tentativas Pagamento =
COUNTROWS('bi fact_payments')
~~~

~~~dax
Pagamentos Recusados =
CALCULATE(
    [Tentativas Pagamento],
    'bi fact_payments'[payment_status] = "declined"
)
~~~

~~~dax
Taxa Recusa Tentativas =
DIVIDE([Pagamentos Recusados], [Tentativas Pagamento])
~~~

~~~dax
Entregas Concluídas =
CALCULATE(
    COUNTROWS('bi fact_shipments'),
    'bi fact_shipments'[shipment_status] = "delivered"
)
~~~

~~~dax
Prazo Transporte Médio Dias =
CALCULATE(
    AVERAGE('bi fact_shipments'[transit_days]),
    'bi fact_shipments'[shipment_status] = "delivered"
)
~~~

~~~dax
Produtos Estoque Baixo =
CALCULATE(
    DISTINCTCOUNT('bi fact_inventory'[product_id]),
    'bi fact_inventory'[is_low_stock] = TRUE()
)
~~~

Layout: cartões Pedidos Totais, Taxa Cancelamento, Taxa Recusa Tentativas e Produtos Estoque Baixo. Gráficos de status dos pedidos, métodos de pagamento e status das entregas.

Taxa de recusas é por tentativa, não por cliente ou pedido. Prazo de transporte só considera intervalo entre envio e entrega. Estoque não possui histórico. Não somar todos os pagamentos como faturamento.

## Validação final

O SQL 13 precisa retornar 5.000 clientes, 21.330 tentativas, 17.988 envios e 500 linhas de estoque; a segmentação deve preservar 3.164 recorrentes, 670 em risco e 309 campeões. Confirme que a primeira página continua com 13.190 pedidos entregues e R$ 54.238.147,33 em produtos vendidos.

Depois de criar os visuais, salve o PBIX, faça commit/push e capture as três páginas para documentar o portfólio.
