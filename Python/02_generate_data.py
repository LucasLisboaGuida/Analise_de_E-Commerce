#!/usr/bin/env python3
"""Gera CSVs sinteticos compativeis com Sql/01_create_tables.sql.

Uso: python Python/02_generate_data.py

Requer apenas Python 3.10+ (sem bibliotecas externas).
Os CSVs sao gravados em data/generated/ e nao alteram o PostgreSQL.
"""

import argparse
import calendar
import csv
import random
from bisect import bisect_right
from contextlib import ExitStack
from datetime import datetime, timedelta
from pathlib import Path

COLUNAS = {
    "customers": ["customer_id", "full_name", "email", "phone", "created_at", "customer_status"],
    "addresses": ["address_id", "customer_id", "street", "street_number", "complement", "neighborhood", "city", "state", "postal_code", "country", "is_default"],
    "categories": ["category_id", "category_name", "description"],
    "products": ["product_id", "category_id", "sku", "product_name", "description", "current_price", "is_active", "created_at"],
    "orders": ["order_id", "customer_id", "shipping_address_id", "order_date", "order_status", "shipping_cost", "currency_code", "shipping_street", "shipping_street_number", "shipping_complement", "shipping_neighborhood", "shipping_city", "shipping_state", "shipping_postal_code", "shipping_country"],
    "order_items": ["order_item_id", "order_id", "product_id", "quantity", "unit_price", "discount_amount"],
    "payments": ["payment_id", "order_id", "payment_date", "payment_method", "payment_status", "amount", "transaction_reference"],
    "shipments": ["shipment_id", "order_id", "shipment_status", "carrier", "tracking_code", "shipped_at", "delivered_at"],
    "inventory": ["inventory_id", "product_id", "quantity_on_hand", "reorder_level", "last_updated_at"],
}

CATEGORIAS = [
    ("Celulares", "Smartphone", 70000, 650000),
    ("Informática", "Notebook e acessório", 8000, 850000),
    ("Áudio", "Fone e caixa de som", 3500, 150000),
    ("TVs", "Televisor", 95000, 680000),
    ("Câmeras", "Câmera e lente", 15000, 500000),
    ("Games", "Jogo e acessório gamer", 5000, 400000),
    ("Livros", "Livro", 2000, 18000),
    ("Casa e Cozinha", "Utensílio doméstico", 2000, 90000),
    ("Eletrodomésticos", "Eletrodoméstico", 15000, 450000),
    ("Moda", "Peça de vestuário", 2500, 42000),
    ("Beleza", "Produto de beleza", 1500, 35000),
    ("Esportes", "Artigo esportivo", 3500, 145000),
    ("Papelaria", "Item de papelaria", 500, 18000),
    ("Brinquedos", "Brinquedo", 1500, 65000),
    ("Pet Shop", "Produto para animais", 1500, 45000),
]

LOCALIDADES = [
    ("São Paulo", "SP", 18), ("Campinas", "SP", 5), ("Rio de Janeiro", "RJ", 13),
    ("Belo Horizonte", "MG", 8), ("Curitiba", "PR", 7), ("Porto Alegre", "RS", 5),
    ("Brasília", "DF", 7), ("Salvador", "BA", 6), ("Recife", "PE", 6),
    ("Fortaleza", "CE", 5), ("São Luís", "MA", 4), ("Teresina", "PI", 3),
    ("Belém", "PA", 4), ("Manaus", "AM", 3), ("Goiânia", "GO", 3),
    ("Florianópolis", "SC", 3),
]
NOMES = ["Ana", "Lucas", "Mariana", "João", "Beatriz", "Gabriel", "Camila", "Pedro", "Larissa", "Rafael", "Juliana", "Bruno", "Fernanda", "Thiago", "Isabela", "Mateus", "Paula", "Daniel", "Carolina", "André", "Amanda", "Felipe", "Letícia", "Renata", "Gustavo"]
SOBRENOMES = ["Silva", "Santos", "Oliveira", "Souza", "Costa", "Pereira", "Almeida", "Rodrigues", "Ferreira", "Lima", "Gomes", "Martins", "Ribeiro", "Carvalho", "Araújo", "Barbosa"]
MEIOS_PAGAMENTO = ["pix", "credit_card", "debit_card", "boleto", "wallet"]
STATUS_PEDIDO = ["delivered", "shipped", "processing", "confirmed", "pending", "cancelled", "returned"]
PESOS_STATUS = [66, 8, 7, 6, 4, 6, 3]


def data_texto(valor):
    return valor.strftime("%Y-%m-%d %H:%M:%S") if valor else ""


def reais(centavos):
    return f"{centavos // 100}.{centavos % 100:02d}"


def data_aleatoria(rng, inicio, fim):
    segundos = int((fim - inicio).total_seconds())
    return inicio + timedelta(seconds=rng.randint(0, segundos))


def data_pedido(rng):
    """Distribuicao com picos sazonais em novembro e dezembro de 2025."""
    meses = [(ano, mes) for ano in (2025, 2026) for mes in range(1, 13) if (ano, mes) <= (2026, 10)]
    pesos = [2.0 if mes == 11 else 1.65 if mes == 12 else 1.2 if mes in (5, 7) else 1.0 for _, mes in meses]
    ano, mes = rng.choices(meses, weights=pesos, k=1)[0]
    dia = rng.randint(1, calendar.monthrange(ano, mes)[1])
    return datetime(ano, mes, dia, rng.randint(8, 22), rng.randint(0, 59), rng.randint(0, 59))


def escrever(writer, tabela, registro, contadores):
    writer[tabela].writerow(registro)
    contadores[tabela] += 1


def gerar(destino, quantidade_clientes, quantidade_produtos, quantidade_pedidos, seed):
    if min(quantidade_clientes, quantidade_produtos, quantidade_pedidos) < 1:
        raise ValueError("Clientes, produtos e pedidos devem ser maiores que zero.")
    rng = random.Random(seed)
    destino.mkdir(parents=True, exist_ok=True)
    contadores = dict.fromkeys(COLUNAS, 0)

    with ExitStack() as pilha:
        writers = {}
        for tabela, campos in COLUNAS.items():
            arquivo = pilha.enter_context((destino / f"{tabela}.csv").open("w", encoding="utf-8", newline=""))
            writers[tabela] = csv.DictWriter(arquivo, fieldnames=campos)
            writers[tabela].writeheader()

        # Cadastro de clientes e enderecos: IDs explicitos para respeitar as FKs.
        enderecos = {}  # id_cliente -> lista de enderecos cadastrados
        cadastro_ordenado = []
        id_endereco = 0
        for id_cliente in range(1, quantidade_clientes + 1):
            cadastro = data_aleatoria(rng, datetime(2024, 1, 1), datetime(2026, 9, 30))
            cadastro_ordenado.append((cadastro, id_cliente))
            nome = f"{rng.choice(NOMES)} {rng.choice(SOBRENOMES)} {rng.choice(SOBRENOMES)}"
            escrever(writers, "customers", {
                "customer_id": id_cliente, "full_name": nome,
                "email": f"cliente{id_cliente:05d}@example.com",  # dominio reservado para exemplos
                "phone": "" if rng.random() < 0.25 else f"000000{id_cliente:05d}",
                "created_at": data_texto(cadastro),
                "customer_status": "active" if rng.random() < 0.94 else "inactive",
            }, contadores)

            quantidade_enderecos = 2 if rng.random() < 0.12 else 1
            enderecos[id_cliente] = []
            for numero_endereco in range(quantidade_enderecos):
                id_endereco += 1
                cidade, uf, _ = rng.choices(LOCALIDADES, weights=[x[2] for x in LOCALIDADES], k=1)[0]
                endereco = {
                    "address_id": id_endereco, "customer_id": id_cliente,
                    "street": f"Rua Exemplo {rng.randint(1, 850)}",
                    "street_number": str(rng.randint(1, 2900)),
                    "complement": "Apto " + str(rng.randint(1, 250)) if rng.random() < 0.23 else "",
                    "neighborhood": f"Bairro {rng.randint(1, 80)}",
                    "city": cidade, "state": uf,
                    "postal_code": f"00000-{id_endereco % 1000:03d}",  # CEP ficticio
                    "country": "Brazil", "is_default": numero_endereco == 0,
                }
                enderecos[id_cliente].append(endereco)
                escrever(writers, "addresses", endereco, contadores)

        # Catalogo de produtos e estoque (um unico deposito).
        produtos_ativos = []
        precos = {}
        for id_categoria, (categoria, _, _, _) in enumerate(CATEGORIAS, start=1):
            escrever(writers, "categories", {
                "category_id": id_categoria, "category_name": categoria,
                "description": f"Produtos da categoria {categoria}.",
            }, contadores)

        for id_produto in range(1, quantidade_produtos + 1):
            id_categoria = (id_produto - 1) % len(CATEGORIAS) + 1
            _, descricao, minimo, maximo = CATEGORIAS[id_categoria - 1]
            preco = rng.randint(minimo, maximo)
            precos[id_produto] = preco
            ativo = id_produto == 1 or rng.random() < 0.96
            if ativo:
                produtos_ativos.append(id_produto)
            escrever(writers, "products", {
                "product_id": id_produto, "category_id": id_categoria,
                "sku": f"SKU-{id_produto:05d}",
                "product_name": f"{descricao} Modelo {id_produto:04d}",
                "description": "Produto fictício para análise de e-commerce.",
                "current_price": reais(preco), "is_active": ativo,
                "created_at": "2024-01-01 09:00:00",
            }, contadores)
            escrever(writers, "inventory", {
                "inventory_id": id_produto, "product_id": id_produto,
                "quantity_on_hand": rng.randint(0, 220),
                "reorder_level": rng.randint(5, 25),
                "last_updated_at": "2026-11-01 00:00:00",
            }, contadores)

        cadastro_ordenado.sort()
        datas_cadastro = [par[0] for par in cadastro_ordenado]
        ids_cadastro = [par[1] for par in cadastro_ordenado]
        id_item = id_pagamento = id_envio = 0

        for id_pedido in range(1, quantidade_pedidos + 1):
            data = data_pedido(rng)
            elegiveis = bisect_right(datas_cadastro, data)
            # Um cliente precisa existir antes de realizar um pedido.
            if not elegiveis:
                data = datas_cadastro[0] + timedelta(minutes=1)
                elegiveis = bisect_right(datas_cadastro, data)
            id_cliente = ids_cadastro[rng.randrange(elegiveis)]
            endereco = rng.choice(enderecos[id_cliente])
            status = rng.choices(STATUS_PEDIDO, weights=PESOS_STATUS, k=1)[0]
            frete = rng.choice([0, 0, 990, 1490, 1990, 2990])
            escrever(writers, "orders", {
                "order_id": id_pedido, "customer_id": id_cliente,
                "shipping_address_id": endereco["address_id"],
                "order_date": data_texto(data), "order_status": status,
                "shipping_cost": reais(frete), "currency_code": "BRL",
                "shipping_street": endereco["street"],
                "shipping_street_number": endereco["street_number"],
                "shipping_complement": endereco["complement"],
                "shipping_neighborhood": endereco["neighborhood"],
                "shipping_city": endereco["city"], "shipping_state": endereco["state"],
                "shipping_postal_code": endereco["postal_code"],
                "shipping_country": endereco["country"],
            }, contadores)

            # Sem repeticao de produto dentro do mesmo pedido.
            numero_itens = min(rng.choices([1, 2, 3, 4], weights=[25, 40, 25, 10], k=1)[0], len(produtos_ativos))
            total_centavos = frete
            for id_produto in rng.sample(produtos_ativos, k=numero_itens):
                id_item += 1
                quantidade = rng.choices([1, 2, 3], weights=[78, 18, 4], k=1)[0]
                # Preco historico pode variar ate +/- 5% do preco atual.
                preco_unitario = max(1, precos[id_produto] * rng.randint(95, 105) // 100)
                desconto_pct = rng.choices([0, 5, 10, 15], weights=[65, 18, 12, 5], k=1)[0]
                desconto = quantidade * preco_unitario * desconto_pct // 100
                total_centavos += quantidade * preco_unitario - desconto
                escrever(writers, "order_items", {
                    "order_item_id": id_item, "order_id": id_pedido,
                    "product_id": id_produto, "quantity": quantidade,
                    "unit_price": reais(preco_unitario), "discount_amount": reais(desconto),
                }, contadores)

            metodo = rng.choices(MEIOS_PAGAMENTO, weights=[40, 35, 12, 8, 5], k=1)[0]
            if status == "pending":
                pagamento_final = rng.choice(["pending", "declined"])
            elif status == "cancelled":
                pagamento_final = rng.choice(["cancelled", "declined", "refunded"])
            elif status == "returned":
                pagamento_final = "refunded"
            else:
                pagamento_final = "approved"

            # Pequena parcela com tentativa recusada antes da transacao final.
            if pagamento_final in ("approved", "refunded") and rng.random() < 0.07:
                id_pagamento += 1
                escrever(writers, "payments", {
                    "payment_id": id_pagamento, "order_id": id_pedido,
                    "payment_date": data_texto(data + timedelta(minutes=1)),
                    "payment_method": metodo, "payment_status": "declined",
                    "amount": reais(total_centavos),
                    "transaction_reference": f"TX-{id_pagamento:09d}",
                }, contadores)

            id_pagamento += 1
            escrever(writers, "payments", {
                "payment_id": id_pagamento, "order_id": id_pedido,
                "payment_date": "" if pagamento_final == "pending" else data_texto(data + timedelta(minutes=15)),
                "payment_method": metodo, "payment_status": pagamento_final,
                "amount": reais(total_centavos),
                "transaction_reference": "" if pagamento_final == "pending" else f"TX-{id_pagamento:09d}",
            }, contadores)

            if status not in ("pending", "cancelled"):
                id_envio += 1
                status_envio = {
                    "confirmed": "pending", "processing": "preparing",
                    "shipped": "in_transit", "delivered": "delivered", "returned": "returned",
                }[status]
                expedicao = data + timedelta(days=rng.randint(1, 3)) if status in ("shipped", "delivered", "returned") else None
                entrega = expedicao + timedelta(days=rng.randint(1, 7)) if status in ("delivered", "returned") else None
                escrever(writers, "shipments", {
                    "shipment_id": id_envio, "order_id": id_pedido,
                    "shipment_status": status_envio,
                    "carrier": rng.choice(["Transportadora A", "Transportadora B", "Correios"]) if expedicao else "",
                    "tracking_code": f"TESTE{id_envio:09d}BR" if expedicao else "",
                    "shipped_at": data_texto(expedicao),
                    "delivered_at": data_texto(entrega),
                }, contadores)

    print("Arquivos CSV criados em:", destino.resolve())
    for tabela, quantidade in contadores.items():
        print(f"  {tabela:12} {quantidade:>7} registros")
    print("\nNenhuma alteracao foi feita no PostgreSQL.")


def main():
    parser = argparse.ArgumentParser(description="Gera o dataset sintetico do e-commerce.")
    parser.add_argument("--output", type=Path, default=Path("data/generated"))
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--customers", type=int, default=5000)
    parser.add_argument("--products", type=int, default=500)
    parser.add_argument("--orders", type=int, default=20000)
    args = parser.parse_args()
    gerar(args.output, args.customers, args.products, args.orders, args.seed)


if __name__ == "__main__":
    main()
