-- Consultas de apresentação – Praça Conectada (SQLite; no PostgreSQL use: SET search_path TO praca;)

-- 1) Clientes ativos por perfil, com quantidade de dispositivos
SELECT perfil, COUNT(*) AS clientes, SUM(qtd_dispositivos) AS dispositivos
FROM vw_clientes_ativos GROUP BY perfil;

-- 2) IPs concedidos na VLAN 10 (concessões ativas)
SELECT ip_atribuido, tipo, cliente FROM vw_concessoes_ativas ORDER BY ip_atribuido;

-- 3) Uso por ponto de acesso
SELECT * FROM vw_uso_por_ap;

-- 4) Histórico de IPs de um cliente
SELECT c.nome_completo, d.apelido, cd.ip_atribuido, cd.inicio, cd.fim, cd.ativa
FROM concessao_dhcp cd
JOIN dispositivo d ON d.id_dispositivo = cd.id_dispositivo
JOIN cliente c ON c.id_cliente = d.id_cliente
WHERE c.email = 'joao.almeida@exemplo.com.br'
ORDER BY cd.inicio;

-- 5) Clientes que ainda não aceitaram a versão mais recente do termo
SELECT c.nome_completo, c.email
FROM cliente c
WHERE NOT EXISTS (SELECT 1 FROM aceite_termo a JOIN termo_uso t ON t.id_termo = a.id_termo
                  WHERE a.id_cliente = c.id_cliente
                    AND t.vigencia_inicio = (SELECT MAX(vigencia_inicio) FROM termo_uso));

-- 6) Cadastro de um novo cliente com aceite do termo e um dispositivo
INSERT INTO cliente (nome_completo, email, telefone, id_perfil)
VALUES ('Novo Cliente', 'novo@exemplo.com.br', '(81) 99999-0000',
        (SELECT id_perfil FROM perfil_acesso WHERE nome = 'Visitante'));
INSERT INTO aceite_termo (id_cliente, id_termo, data_aceite)
VALUES ((SELECT id_cliente FROM cliente WHERE email = 'novo@exemplo.com.br'),
        (SELECT id_termo FROM termo_uso WHERE versao = '1.1'), CURRENT_TIMESTAMP);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso)
VALUES ((SELECT id_cliente FROM cliente WHERE email = 'novo@exemplo.com.br'),
        (SELECT id_tipo FROM tipo_dispositivo WHERE descricao = 'Smartphone'),
        '02:5E:C0:00:99:01', 'Celular do novo cliente', CURRENT_TIMESTAMP);

-- 7) Bloqueio (gatilho grava auditoria e bloqueia os dispositivos)
UPDATE cliente SET status = 'bloqueado' WHERE email = 'novo@exemplo.com.br';
SELECT * FROM auditoria_cliente;

-- 8) Testes de integridade (devem falhar)
-- INSERT INTO dispositivo (id_cliente, id_tipo, mac, primeiro_acesso) VALUES (1, 1, 'zz', '2026-01-01');
-- INSERT INTO cliente (nome_completo, email, id_perfil, status) VALUES ('X','x@exemplo.com.br',1,'qualquer');
