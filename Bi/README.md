# Power BI | Modelo analítico do e-commerce

**Status:** camada analítica em desenvolvimento; o dashboard ainda não foi criado.

## 1. Objetivo

Transformar as nove tabelas do modelo operacional (\`public\`) em um **modelo dimensional** para o Power BI. Optamos por **views do PostgreSQL**, no schema \`bi\`, sem alterar as tabelas originais. Isso permite reproduzir o preparo analítico com SQL versionado.

Criação das views: [\`Sql/12_create_bi_views.sql\`](../Sql/12_create_bi_views.sql).

## 2. Tabelas e granularidade

| View | Grão | Uso |
| --- | --- | --- |
| \`bi.dim_customer\` | 1 linha por cliente | Filtrar por cliente |
| \`bi.dim_product\` | 1 linha por produto | Produto e categoria |
| \`bi.dim_date\` | 1 linha por dia | Tempo e tendência |
| \`bi.dim_state\` | 1 linha por UF registrada em pedidos | Análise geográfica |
| \`bi.fact_orders\` | **1 linha por pedido** | Contagem de pedidos, status e frete |
| \`bi.fact_order_items\` | **1 linha por item** | Quantidade, descontos e valor vendido por produto |

**Não ligue diretamente as duas tabelas de fatos por \`order_id\`**: elas têm granularidades distintas e podem causar ambiguidades. As dimensões se ligam separadamente às tabelas de fatos.

## 3. Relacionamentos no Power BI

Crie relações **1 para muitos (1:*)**, com **filtro de direção única: dimensão → fato**.

| Lado 1 (dimensão) | Lado muitos (fato) |
| --- | --- |
| \`dim_customer.customer_id\` | \`fact_orders.customer_id\` |
| \`dim_customer.customer_id\` | \`fact_order_items.customer_id\` |
| \`dim_product.product_id\` | \`fact_order_items.product_id\` |
| \`dim_date.date_key\` | \`fact_orders.order_date_key\` |
| \`dim_date.date_key\` | \`fact_order_items.order_date_key\` |
| \`dim_state.state_code\` | \`fact_orders.state_code\` |
| \`dim_state.state_code\` | \`fact_order_items.state_code\` |

Dimensão Produto não se conecta a \`fact_orders\`: nem todo pedido tem apenas um produto. Para analisar pedidos por categoria, usaremos \`DISTINCTCOUNT\` dos pedidos na tabela de itens, com filtros apropriados.

## 4. Preparar as views

Execute [\`Sql/12_create_bi_views.sql\`](../Sql/12_create_bi_views.sql) no banco \`ecommerce\`. O script cria o schema \`bi\`, seis views e executa duas consultas de conferência. As contagens esperadas são:

- \`dim_customer\`: **5.000**
- \`dim_product\`: **500**
- \`fact_orders\`: **20.000**
- \`fact_order_items\`: **43.941**
- \`dim_state\`: número de estados presentes no dataset
- \`dim_date\`: quantidade de dias entre a primeira e a última data de pedidos

A segunda validação deve reproduzir **13.190 pedidos entregues** e **R$ 54.238.147,33** em produtos vendidos após descontos, sem frete, com o gerador padrão.

## 5. Conectar no Power BI Desktop (depois de validar as views)

1. **Página Inicial → Obter dados → Banco de dados PostgreSQL**.
2. Servidor: \`localhost:5432\`; banco de dados: \`ecommerce\`.
3. Use **Importar** para este conjunto pequeno.
4. Quando solicitado, escolha autenticação **Banco de dados**, digite o usuário do PostgreSQL e a senha local. Nunca publique credenciais no GitHub.
5. No navegador, selecione **apenas as seis views** do schema \`bi\` e carregue-as.
6. Na exibição **Modelo**, confirme as relações da tabela acima e a direção de filtro.
7. Confirme que \`date_key\` e \`order_date_key\` aparecem como **Data**, e valores monetários como **Número decimal**.

O Power BI Desktop moderno já inclui o provedor Npgsql para PostgreSQL (sem instalar o \`psycopg\` do Python dentro do Power BI).

## 6. Regras analíticas

- O valor vendido de produtos é \`quantity * unit_price - discount_amount\`, sem frete.
- Para reportar vendas entregues, filtre por \`order_status = 'delivered'\`.
- \`gross_product_value\` e \`net_product_value\` são por **item**; \`shipping_cost\` é por **pedido**.
- As datas são de pedidos, não de entrega.
- O RFM será incorporado em etapa posterior; a data de referência do estudo inicial é 17/11/2026.
- Evite somar pagamentos como receita: a base inclui recusas e reembolsos.
- Todos os registros são sintéticos.

## Próximos passos

Validar essas seis views no PostgreSQL, fazer a primeira importação no Power BI Desktop e só então criar as medidas DAX e visuais.
