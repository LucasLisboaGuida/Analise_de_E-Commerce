# Índice de consultas SQL

As consultas estão divididas entre **estrutura/carga e análises principais** e **investigações exploratórias opcionais**.

## Scripts principais

| Arquivo | Finalidade |
| --- | --- |
| [01_create_tables.sql](01_create_tables.sql) | Estrutura das nove tabelas e integridade |
| [02_data_quality_checks.sql](02_data_quality_checks.sql) | Contagens de carga e oito verificações de qualidade |
| [03_eda_sales.sql](03_eda_sales.sql) | Vendas mensais e ticket médio |
| [04_eda_geography_customers.sql](04_eda_geography_customers.sql) | Distribuição por estado e taxa de recorrência |
| [05_eda_customer_frequency.sql](05_eda_customer_frequency.sql) | Distribuição de frequência de compras |
| [06_eda_customer_value.sql](06_eda_customer_value.sql) | Valor vendido por faixa de frequência |
| [07_eda_rfm_basics.sql](07_eda_rfm_basics.sql) | Recência, frequência e valor por cliente |
| [11_customer_rfm_segments.sql](11_customer_rfm_segments.sql) | Segmentação RFM da carteira completa |

A numeração foi preservada para manter a ordem histórica de criação dos scripts. Os números 08, 09 e 10 foram movidos para `estudos_de_caso/`, pois são análises de aprofundamento e não etapas obrigatórias.

## Estudo de caso (opcional)

| Arquivo | Pergunta investigada |
| --- | --- |
| [08_eda_ticket_vs_quantity.sql](estudos_de_caso/08_eda_ticket_vs_quantity.sql) | Diferença entre ticket médio e preço por unidade |
| [09_eda_customer_categories.sql](estudos_de_caso/09_eda_customer_categories.sql) | Categorias de maior gasto por cliente |
| [10_eda_customer_basket.sql](estudos_de_caso/10_eda_customer_basket.sql) | Itens, quantidades e datas de compras selecionadas |

Leia o [resumo do estudo de caso](../docs/estudo_de_caso_clientes.md) para entender a hipótese e as limitações.

## Convenções

- Consultas de análise usam apenas pedidos `delivered`, salvo indicação explícita em contrário.
- **Valor vendido de produtos**: `SUM(quantity * unit_price - discount_amount)`, sem frete.
- Não some todas as linhas de `payments` como faturamento: a tabela inclui tentativas recusadas e reembolsos.
- Todas as análises exploratórias aqui são somente leitura. A criação do banco ocorre no `01_create_tables.sql`.
- O dataset é inteiramente **sintético**, não representando comportamento real de consumidores.
