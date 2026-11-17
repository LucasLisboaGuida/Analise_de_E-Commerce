# Estudo de caso exploratório: padrões de compra

> **Análise opcional, com clientes e produtos inteiramente fictícios.** Este estudo documenta um raciocínio investigativo em SQL e não integra as métricas oficiais do dashboard.

## Pergunta e hipótese

Ao observar o ranking RFM, dois clientes sintéticos se destacaram: **cliente 1853** e **cliente 3986**. O cliente 3986 tinha maior **frequência** de compras entregues, enquanto o cliente 1853 apresentava maior **valor monetário acumulado**.

**Hipótese:** a diferença no gasto ocorre porque o cliente 1853 compra unidades de maior valor, e não apenas um volume maior de produtos.

## Investigação

O estudo avançou do agregado para o detalhe:

1. Comparação de **frequência, valor e recência**: [RFM básico](../Sql/07_eda_rfm_basics.sql).
2. Cálculo de **ticket médio, unidades por pedido e preço líquido por unidade**: [consulta 08](../Sql/estudos_de_caso/08_eda_ticket_vs_quantity.sql).
3. Identificação das **categorias de maior gasto**: [consulta 09](../Sql/estudos_de_caso/09_eda_customer_categories.sql).
4. Inspeção dos **pedidos e itens individuais**: [consulta 10](../Sql/estudos_de_caso/10_eda_customer_basket.sql).

## Resultado observado

| Métrica | Cliente 1853 | Cliente 3986 |
| --- | ---: | ---: |
| Pedidos entregues | 8 | 10 |
| Valor total em produtos (R$) | 81.974,81 | 70.299,14 |
| Unidades compradas | 24 | 31 |
| Unidades por pedido | 3,00 | 3,10 |
| Ticket médio de produtos (R$) | 10.246,85 | 7.029,91 |
| Preço médio líquido por unidade (R$) | 3.415,62 | 2.267,71 |

O cliente **1853 comprou menos unidades**, mas a um **preço médio líquido por unidade mais alto**; portanto, o maior ticket não foi explicado por maior quantidade de unidades por pedido.

A inspeção das categorias de maior gasto revelou concentração em eletrônicos, especialmente **celulares e televisores**.

## Limitações e conclusão

Compras múltiplas de eletrônicos levantam **hipóteses**, como aquisição para terceiros, compras empresariais ou revenda. **Os dados não permitem identificar a finalidade das compras.** Não há informações externas ou verificação de perfil empresarial, e o conjunto é artificial.

A contribuição deste estudo ao portfólio é mostrar a sequência: **identificar um comportamento → formular hipótese → aprofundar consultas SQL → comunicar o que foi confirmado e o que permanece incerto**.

Para resultados gerais do projeto, veja a [análise exploratória principal](analise_exploratoria.md).
