# Análise exploratória: metodologia e achados

**Projeto:** Análise de E-Commerce | **Situação:** EDA inicial concluída, Power BI pendente.

## Escopo e origem

O estudo utiliza registros sintéticos gerados com o script `Python/02_generate_data.py` (semente padrão: `42`) e importados para PostgreSQL. O conjunto contém 5.000 clientes, 500 produtos, 15 categorias, 20.000 pedidos e 43.941 itens de pedidos (114.821 registros distribuídos em nove tabelas).

O período de pedidos simulados é **janeiro/2025 a outubro/2026**. Uma auditoria de oito regras selecionadas não encontrou inconsistências; isso **não garante ausência de todos os problemas**.

## Definições que devem permanecer consistentes

- **Pedido entregue:** `orders.order_status = 'delivered'`.
- **Valor vendido dos produtos:** soma de `order_items.quantity * order_items.unit_price - order_items.discount_amount`, apenas em pedidos entregues.
- **Frete:** não incluído no valor vendido dos produtos.
- **Mês de venda:** agrupado pela data do pedido (`orders.order_date`), **não** pela data efetiva de entrega.
- **Ticket médio de produtos:** valor vendido dos produtos dividido pelo número de pedidos entregues.
- **Cliente recorrente:** possui **dois ou mais** pedidos entregues; o denominador da taxa de recorrência considera clientes com ao menos um pedido entregue.
- **Recência RFM:** dias desde a data do último pedido entregue até **17/11/2026** (data fixa para reprodutibilidade).

Estas definições são analíticas, **não** equivalem à receita reconhecida contabilmente, caixa recebido ou previsão de inadimplência.

## Resultados observados

| Métrica / comparação | Observação |
| --- | --- |
| Pedidos entregues | 13.190 (dos 20.000 gerados) |
| Valor dos produtos em pedidos entregues | R$ 54.238.147,33 |
| Novembro/2025 | 1.071 pedidos entregues; R$ 4.478.409,73 em produtos |
| São Paulo | 3.075 pedidos entregues; R$ 12.674.109,91 em produtos |
| Compradores com ao menos uma compra entregue | 4.049 de 5.000 clientes |
| Clientes recorrentes | 3.164; 78,14% dos compradores com pedidos entregues |
| Clientes com 4 ou mais pedidos entregues | 1.610; 64,48% do valor vendido de produtos |
| RFM: Campeões | 309 clientes; 16,31% do valor vendido |
| RFM: Em risco | 670 clientes; 27,07% do valor vendido |

## Interpretação e limites

1. **Sazonalidade:** o pico de novembro foi introduzido por probabilidades no gerador de pedidos. Não demonstra, por si, uma tendência do mercado real.
2. **Geografia:** o gerador atribui probabilidades diferentes a determinadas cidades; São Paulo tem mais localidades no conjunto. O resultado não é uma medição da participação real do varejo paulista.
3. **Recorrência:** é alta no dataset, em parte por conta da distribuição dos pedidos sintetizados. Recorrência não é retenção medida por coortes.
4. **Valor e frequência:** clientes frequentes somam mais compras, mas isso não prova que seus itens individuais sejam mais caros.
5. **Segmentação RFM:** as faixas são **critérios descritivos definidos para este projeto**. `Em risco` não significa probabilidade estimada de abandono. A pontuação monetária usa quintis entre compradores, enquanto recência e frequência usam limites fixos.
6. **Qualidade:** a aprovação em oito testes é um marco inicial, não uma certificação de perfeição do banco.

## Fontes internas

- [Consultas SQL principais](../Sql/README.md)
- [Modelo relacional](../Diagram/diagrams_01_operational_model.png)
- [Gerador de dados](../Python/02_generate_data.py)
- [Auditoria de qualidade](../Sql/02_data_quality_checks.sql)

## Próximos passos

Construir um modelo dimensional para BI, validar as medidas no Power BI Desktop e adicionar capturas do dashboard final. As consultas atuais fornecem uma base, mas não substituem o desenho de fatos, dimensões e medidas.
