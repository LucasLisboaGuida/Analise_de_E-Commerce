# Dataset sintético do e-commerce

O script `02_generate_data.py` gera **nove arquivos CSV** compatíveis com `Sql/01_create_tables.sql`. Não conecta nem modifica o banco de dados.

## Requisitos

Python 3.10 ou superior. Não precisa instalar bibliotecas adicionais.

## Execução

Abra o terminal do VS Code **na pasta principal do repositório** e execute:

```powershell
py Python/02_generate_data.py
```

Se `py` não funcionar, tente `python Python/02_generate_data.py`.

Os arquivos aparecem em `data/generated/`: `customers.csv`, `addresses.csv`, `categories.csv`, `products.csv`, `orders.csv`, `order_items.csv`, `payments.csv`, `shipments.csv`, `inventory.csv`.

Para testar com menos dados:

```powershell
py Python/02_generate_data.py --customers 50 --products 30 --orders 100 --output data/teste
```

## Dataset padrão

- 5.000 clientes, com um ou dois endereços;
- 15 categorias e 500 produtos com estoque;
- 20.000 pedidos, geralmente com 1 a 4 produtos distintos por pedido;
- aproximadamente 44 mil itens, 21 mil pagamentos e 18 mil registros de entrega;
- datas de vendas entre janeiro/2025 e outubro/2026, com sazonalidade simulada;
- pedidos cancelados ou devolvidos, tentativas recusadas e clientes recorrentes.

Todos os dados são fictícios; os e-mails usam `example.com`, e CEPs e telefones são marcadores de teste. Um pedido pode ter mais de uma tentativa de pagamento. **Não some todos os pagamentos para calcular faturamento**: existem recusas e reembolsos.

A semente padrão (`--seed 42`) torna os dados reproduzíveis. Rodar novamente com a mesma configuração sobrescreve os CSVs. Os arquivos não são importados automaticamente para o PostgreSQL.

## Próxima etapa

Verificar os arquivos gerados e preparar a importação na ordem correta das chaves estrangeiras.


## Importação dos CSVs para PostgreSQL

Depois de gerar os CSVs, instale o driver PostgreSQL no mesmo Python do VS Code:

```powershell
py -m pip install "psycopg[binary]"
```

No terminal, na pasta raiz do projeto:

```powershell
py Python/03_import_data.py
```

O script conecta em `localhost:5432`, banco `ecommerce` e usuário `postgres` por padrão. Ele pede a senha do usuário PostgreSQL (a mesma usada na conexão do VS Code) sem exibi-la na tela. Se o usuário/porta forem diferentes, use `--user outro_usuario` ou `--port 5433`.

**Proteções:** exige que as nove tabelas estejam vazias, verifica os cabeçalhos dos nove arquivos, solicita a palavra `IMPORTAR` e usa uma transação única. Se algo falhar, a carga é revertida. A inserção segue as dependências entre as tabelas e ajusta as sequências `IDENTITY` para futuros cadastros.

Confira no banco depois da importação:

```sql
SELECT COUNT(*) AS total_clientes FROM customers;
SELECT COUNT(*) AS total_pedidos FROM orders;
SELECT COUNT(*) AS total_itens FROM order_items;
```

Resultados esperados para o dataset padrão: 5.000 clientes, 20.000 pedidos e 43.941 itens. **Não execute o importador novamente após a carga**, porque ele foi criado para uma base vazia. Não coloque senhas em arquivos versionados ou no GitHub.
