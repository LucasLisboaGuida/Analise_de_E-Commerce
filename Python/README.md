# Geração e importação do dataset sintético

Esta pasta reúne os dois scripts Python que tornam o estudo reproduzível.

## Pré-requisitos

- Python 3.10 ou superior.
- PostgreSQL com um banco chamado `ecommerce` e tabelas criadas a partir de [`Sql/01_create_tables.sql`](../Sql/01_create_tables.sql).

Os exemplos abaixo são executados no **terminal da pasta raiz** do repositório.

## 1. Gerar CSVs

```powershell
py Python/02_generate_data.py
```

O gerador usa apenas a biblioteca padrão do Python. Os nove arquivos ficam em `data/generated/` e cobrem `customers`, `addresses`, `categories`, `products`, `orders`, `order_items`, `payments`, `shipments` e `inventory`.

O conjunto padrão tem 5.000 clientes, 500 produtos, 15 categorias, 20.000 pedidos, 43.941 itens, 21.330 pagamentos e 17.988 registros de envio, além de endereços e estoque.

Para testar uma carga menor sem sobrescrever a saída padrão:

```powershell
py Python/02_generate_data.py --customers 50 --products 30 --orders 100 --output data/teste
```

A semente padrão é `--seed 42`, que possibilita reproduzir o mesmo dataset. Executar novamente na mesma pasta **sobrescreve os CSVs**. O gerador **não altera** o banco PostgreSQL.

## 2. Importar para o PostgreSQL

Instale a dependência e execute o importador:

```powershell
py -m pip install "psycopg[binary]"
py Python/03_import_data.py
```

Por padrão, o importador usa `localhost:5432`, banco `ecommerce`, usuário `postgres`. Também aceita `--user`, `--host`, `--port` e `--data-dir`.

O programa:

- Pede a senha do PostgreSQL (sem exibir) e uma confirmação digitada.
- Verifica o nome do banco, os CSVs, seus cabeçalhos e se **todas as nove tabelas estão vazias**.
- Importa os registros na ordem das dependências usando uma **transação única**.
- Ajusta as sequências de IDs para futuras inserções.
- Desfaz as inserções se a carga falhar antes de ser concluída.

**Não execute o importador numa base já preenchida:** ele interrompe a operação para evitar duplicações. Nunca publique senhas no GitHub.

## 3. Validar

Com a conexão aberta no banco `ecommerce`, rode [`Sql/02_data_quality_checks.sql`](../Sql/02_data_quality_checks.sql).

## Observações de modelagem

Os dados são **sintéticos**: e-mails usam `example.com`, enquanto os demais dados cadastrais são fictícios. Há sazonalidade, preços de faixas definidas, tentativas recusadas, estornos e pedidos de múltiplos itens.

**Não some todos os pagamentos como receita:** `payments` guarda tentativas e resultados, inclusive recusas e reembolsos. A métrica exploratória de **valor vendido de produtos** usa os itens dos pedidos entregues, com descontos e sem frete.
