# Prints do DBeaver

Já publicados: 01, 03, 04, 05, 06, 07 e 08. Pendente: 02 (diagrama ER do DBeaver).

Salve aqui os prints do banco de dados rodando no DBeaver, com os nomes abaixo. Depois, no `README.md` da raiz, descomente as linhas de imagem na seção **Evidências no DBeaver**.

| Arquivo | O que mostrar | Como obter no DBeaver |
|---|---|---|
| `01-conexao-visoes.png` | Conexão criada e visões listadas | Navegador de banco de dados, expandir *Tables* e *Views* |
| `02-diagrama-dbeaver.png` | Diagrama ER gerado pelo DBeaver | Botão direito em *Tables* > *View Diagram* |
| `03-dados-clientes-ativos.png` | Dados da visão `vw_clientes_ativos` | Duplo clique na visão > aba *Dados* |
| `04-concessoes-ativas.png` | Concessões DHCP ativas | `SELECT * FROM vw_concessoes_ativas;` |
| `05-uso-por-ap.png` | Uso por ponto de acesso | `SELECT * FROM vw_uso_por_ap;` |
| `06-teste-integridade.png` | Erro ao inserir MAC inválido | `INSERT INTO dispositivo (id_cliente, id_tipo, mac, primeiro_acesso) VALUES (1, 1, 'zz', '2026-01-01');` |
| `07-auditoria.png` e `08-dispositivo-bloqueado.png` | Auditoria do bloqueio e dispositivo bloqueado | `UPDATE cliente SET status='bloqueado' WHERE id_cliente=3;` e `SELECT * FROM auditoria_cliente;` |

Dica: no PostgreSQL, execute `SET search_path TO praca;` antes das consultas. Evite mostrar dados reais nos prints; os dados do projeto são fictícios.
