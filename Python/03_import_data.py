#!/usr/bin/env python3
"""Importa os 9 CSVs sinteticos para o PostgreSQL de forma transacional.

Execute na raiz do projeto:
    py Python/03_import_data.py

Dependencia:
    py -m pip install "psycopg[binary]"

Seguranca:
- Somente importa no banco "ecommerce", no schema "public".
- Exige todas as nove tabelas vazias (nao sobrescreve dados).
- Confere os cabecalhos dos CSVs com as colunas reais do banco.
- Pede confirmacao antes da carga.
- Um erro em qualquer tabela faz rollback da transacao inteira.
- Ajusta as sequencias IDENTITY apos importar os IDs explicitos.
"""

import argparse
import csv
import getpass
import os
import sys
from pathlib import Path

try:
    import psycopg
    from psycopg import sql
except ImportError:
    sys.exit(
        'Biblioteca psycopg nao encontrada. Execute: py -m pip install "psycopg[binary]"'
    )

# Pais precisam ser importados antes dos filhos por causa das FOREIGN KEYs.
TABELAS = (
    ("customers", "customer_id"),
    ("addresses", "address_id"),
    ("categories", "category_id"),
    ("products", "product_id"),
    ("orders", "order_id"),
    ("order_items", "order_item_id"),
    ("payments", "payment_id"),
    ("shipments", "shipment_id"),
    ("inventory", "inventory_id"),
)

PASTA_PADRAO = Path(__file__).resolve().parent.parent / "data" / "generated"


def verificar_arquivos(pasta):
    """Valida cabecalhos e conta registros sem guardar os arquivos na memoria."""
    if not pasta.is_dir():
        raise ValueError(f"Pasta com CSVs nao encontrada: {pasta}")

    metadados = {}
    for tabela, _ in TABELAS:
        caminho = pasta / f"{tabela}.csv"
        if not caminho.is_file():
            raise ValueError(f"Arquivo nao encontrado: {caminho}")
        with caminho.open("r", encoding="utf-8-sig", newline="") as arquivo:
            leitor = csv.reader(arquivo)
            cabecalho = next(leitor, None)
            if not cabecalho or len(set(cabecalho)) != len(cabecalho):
                raise ValueError(f"Cabecalho ausente ou duplicado: {caminho}")
            total = 0
            for numero_linha, registro in enumerate(leitor, start=2):
                if len(registro) != len(cabecalho):
                    raise ValueError(
                        f"{caminho.name}, linha {numero_linha}: quantidade de colunas incorreta."
                    )
                total += 1
        if total == 0:
            raise ValueError(f"Arquivo sem registros: {caminho}")
        metadados[tabela] = (caminho, cabecalho, total)
    return metadados


def validar_banco(cursor, metadados):
    """Exige banco certo, tabelas vazias e mesma estrutura de colunas."""
    cursor.execute("SELECT current_database()")
    nome_banco = cursor.fetchone()[0]
    if nome_banco != "ecommerce":
        raise RuntimeError(
            f"Conexao apontando para '{nome_banco}'. Importacao permitida apenas em 'ecommerce'."
        )

    for tabela, _ in TABELAS:
        cursor.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = %s
            ORDER BY ordinal_position
            """,
            (tabela,),
        )
        colunas_banco = [linha[0] for linha in cursor.fetchall()]
        if not colunas_banco:
            raise RuntimeError(f"Tabela public.{tabela} nao encontrada.")
        colunas_csv = metadados[tabela][1]
        if colunas_csv != colunas_banco:
            raise RuntimeError(
                f"Colunas diferentes em public.{tabela}.\n"
                f"CSV:   {colunas_csv}\n"
                f"Banco: {colunas_banco}"
            )
        cursor.execute(
            sql.SQL("SELECT COUNT(*) FROM {}").format(sql.Identifier("public", tabela))
        )
        quantidade = cursor.fetchone()[0]
        if quantidade != 0:
            raise RuntimeError(
                f"public.{tabela} ja tem {quantidade} registros. "
                "Carga cancelada para evitar duplicacoes. Nao exclua os dados automaticamente."
            )


def importar(cursor, metadados):
    """COPY em blocos; tudo dentro de uma unica transacao."""
    for tabela, chave_primaria in TABELAS:
        caminho, colunas, esperado = metadados[tabela]
        comando = sql.SQL(
            "COPY {} ({}) FROM STDIN WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8')"
        ).format(
            sql.Identifier("public", tabela),
            sql.SQL(", ").join(map(sql.Identifier, colunas)),
        )

        with caminho.open("rb") as arquivo:
            with cursor.copy(comando) as copia:
                while bloco := arquivo.read(64 * 1024):
                    copia.write(bloco)

        cursor.execute(
            sql.SQL("SELECT COUNT(*) FROM {}").format(sql.Identifier("public", tabela))
        )
        atual = cursor.fetchone()[0]
        if atual != esperado:
            raise RuntimeError(
                f"{tabela}: esperados {esperado} registros, mas foram lidos {atual}."
            )

        # As PKs foram importadas com numeros explicitos. Avanca o IDENTITY
        # para que um INSERT futuro sem ID nao tente reutilizar o numero 1.
        cursor.execute(
            sql.SQL("SELECT COALESCE(MAX({}), 0) FROM {}").format(
                sql.Identifier(chave_primaria),
                sql.Identifier("public", tabela),
            )
        )
        proximo_id = cursor.fetchone()[0] + 1
        cursor.execute(
            sql.SQL("ALTER TABLE {} ALTER COLUMN {} RESTART WITH {}").format(
                sql.Identifier("public", tabela),
                sql.Identifier(chave_primaria),
                sql.Literal(proximo_id),
            )
        )
        print(f"  OK {tabela:12} {atual:>7} registros")


def main():
    parser = argparse.ArgumentParser(description="Carrega CSVs no banco ecommerce.")
    parser.add_argument("--data-dir", type=Path, default=PASTA_PADRAO)
    parser.add_argument("--host", default="localhost")
    parser.add_argument("--port", type=int, default=5432)
    parser.add_argument("--user", default="postgres")
    args = parser.parse_args()

    print("Etapa 1/3: verificando os 9 arquivos CSV...")
    metadados = verificar_arquivos(args.data_dir)
    total = sum(info[2] for info in metadados.values())
    print(f"Arquivos encontrados em: {args.data_dir.resolve()}")
    print(f"Total de linhas de dados: {total:,}".replace(",", "."))

    print("\nEtapa 2/3: conectando ao PostgreSQL...")
    senha = os.getenv("PGPASSWORD")
    if senha is None:
        senha = getpass.getpass(f"Senha do PostgreSQL (usuario {args.user}): ")
    with psycopg.connect(
        host=args.host,
        port=args.port,
        dbname="ecommerce",
        user=args.user,
        password=senha,
        connect_timeout=10,
    ) as conexao:
        with conexao.cursor() as cursor:
            validar_banco(cursor, metadados)
            print("Banco ecommerce confirmado. As 9 tabelas estao vazias.")
            confirmacao = input("Digite IMPORTAR para iniciar a carga: ").strip()
            if confirmacao != "IMPORTAR":
                raise RuntimeError("Importacao cancelada pelo usuario; nenhuma tabela foi alterada.")

            print("\nEtapa 3/3: importando em uma transacao...")
            importar(cursor, metadados)
        # Saida normal do contexto da conexao confirma a transacao.
        # Qualquer excecao faz ROLLBACK antes de fechar a conexao.

    print("\nImportacao concluida! As 9 tabelas foram preenchidas com sucesso.")
    print("Consulte os totais no VS Code com SELECT COUNT(*) FROM public.orders;")


if __name__ == "__main__":
    try:
        main()
    except (Exception, KeyboardInterrupt) as erro:
        print(f"\nERRO: {erro}", file=sys.stderr)
        print(
            "Importacao nao concluida. Se a transacao foi iniciada, "
            "suas insercoes foram desfeitas.",
            file=sys.stderr,
        )
        sys.exit(1)
