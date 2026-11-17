# Análise de E-Commerce | SQL, Python e Business Intelligence

Projeto de portfólio **end-to-end**: da modelagem de um banco de dados relacional à geração de dados sintéticos, carga no PostgreSQL, testes de qualidade, análises exploratórias e segmentação de clientes. O **dashboard em Power BI está em desenvolvimento**.

> **Aviso:** esta é uma empresa fictícia. Todos os clientes, endereços, produtos e pedidos foram gerados por código. Os resultados não representam o varejo brasileiro real.

## Visão geral

| Indicador do dataset | Resultado |
| --- | ---: |
| Clientes cadastrados | **5.000** |
| Produtos | **500** |
| Categorias | **15** |
| Pedidos | **20.000** |
| Itens de pedidos | **43.941** |
| Registros nas 9 tabelas | **114.821** |
| Verificações de qualidade selecionadas | **8/8 sem inconsistências** |

**Período simulado de pedidos:** janeiro de 2025 a outubro de 2026.

**Ferramentas:** PostgreSQL, SQL, Python 3.10+, Git/GitHub e VS Code. **Power BI Desktop:** próxima fase.

## Objetivos

- Desenhar um **modelo operacional relacional** com chaves primárias, estrangeiras e regras de integridade.
- Construir um processo **reproduzível** de geração e importação de dados, sem depender de arquivos privados.
- Avaliar qualidade e consistência antes de utilizar os dados.
- Explorar desempenho comercial, distribuição geográfica, recorrência, valor por cliente e **segmentação RFM**.
- Evoluir o projeto para **modelo dimensional e dashboard em Power BI**.

## Modelo de dados

![Diagrama entidade-relacionamento do e-commerce](Diagram/diagrams_01_operational_model.png)

O modelo operacional possui 9 tabelas: `customers`, `addresses`, `categories`, `products`, `orders`, `order_items`, `payments`, `shipments` e `inventory`. O pedido preserva um retrato do endereço de entrega e os itens mantêm o preço praticado no momento da compra.

## Principais achados da exploração inicial

Os resultados abaixo usam **pedidos com status `delivered`** e **valor dos produtos após descontos, sem frete**; não equivalem a faturamento contábil nem a recebimentos.

| Pergunta | Resultado observado |
| --- | --- |
| Mês de maior valor vendido em 2025 | **Novembro/2025:** aproximadamente **R$ 4,48 milhões** |
| Estado com maior valor vendido | **SP:** aproximadamente **R$ 12,67 milhões** |
| Quantos compradores são recorrentes? | **3.164 de 4.049** compradores com pedidos entregues (**78,14%**) |
| Participação dos clientes com 4 ou mais pedidos entregues | **64,48%** do valor vendido |
| Segmento RFM `Em risco` | **670 clientes**, responsáveis por **27,07%** do valor vendido no período |

**Limitações:** sazonalidade, preços, composição geográfica e comportamento dos clientes foram definidos no gerador sintético. A análise RFM aplica faixas descritivas e não prevê abandono real.

[Leia a metodologia e os resultados completos](docs/analise_exploratoria.md).

## Como reproduzir o projeto

**Pré-requisitos:** PostgreSQL local, Python 3.10+ e um cliente SQL (VS Code/pgAdmin). Os comandos abaixo partem da **raiz do repositório**.

1. No PostgreSQL, crie um banco chamado `ecommerce`. Conecte-se a ele e execute [`Sql/01_create_tables.sql`](Sql/01_create_tables.sql) **uma única vez**, em banco vazio.
2. Gere os CSVs sintéticos:

   ```powershell
   py Python/02_generate_data.py
   ```

3. Instale o driver e importe os CSVs (o script solicita a senha e confirmação):

   ```powershell
   py -m pip install "psycopg[binary]"
   py Python/03_import_data.py
   ```

4. Rode [`Sql/02_data_quality_checks.sql`](Sql/02_data_quality_checks.sql) e explore as consultas descritas no [índice de SQL](Sql/README.md).

> O importador exige as **9 tabelas vazias** e não sobrescreve uma base já preenchida. Os arquivos `data/generated/` são recriados localmente e ignorados pelo Git.

Instruções e parâmetros adicionais: [`Python/README.md`](Python/README.md).

## Organização do repositório

```text
.
├── Diagram/
│   └── diagrams_01_operational_model.png
├── Python/
│   ├── 02_generate_data.py       # Geração reproduzível de CSVs
│   ├── 03_import_data.py         # Carga transacional no PostgreSQL
│   └── README.md
├── Sql/
│   ├── 01_create_tables.sql      # Modelo relacional
│   ├── 02_data_quality_checks.sql
│   ├── 03_eda_sales.sql
│   ├── 04_eda_geography_customers.sql
│   ├── 05_eda_customer_frequency.sql
│   ├── 06_eda_customer_value.sql
│   ├── 07_eda_rfm_basics.sql
│   ├── 11_customer_rfm_segments.sql
│   ├── estudos_de_caso/          # Investigações opcionais
│   │   ├── 08_eda_ticket_vs_quantity.sql
│   │   ├── 09_eda_customer_categories.sql
│   │   └── 10_eda_customer_basket.sql
│   └── README.md
├── docs/
│   ├── analise_exploratoria.md
│   └── estudo_de_caso_clientes.md
└── README.md
```

A investigação de dois clientes sintéticos foi mantida como **estudo de caso complementar**, separado das análises centrais: [leia o estudo](docs/estudo_de_caso_clientes.md).

## Andamento

- [x] Modelagem relacional e implementação do banco
- [x] Geração determinística do dataset sintético
- [x] Importação e auditoria inicial de qualidade
- [x] Análise exploratória e segmentação RFM
- [ ] Modelagem dimensional (fatos e dimensões)
- [ ] Dashboard interativo no Power BI
- [ ] Publicação das evidências visuais e documentação final

O versionamento guarda os **scripts e a documentação**, não uma cópia do banco local ou os CSVs gerados. Uma execução nova do gerador com a mesma semente produz o mesmo dataset.
