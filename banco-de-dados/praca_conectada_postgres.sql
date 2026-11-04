-- =====================================================================
-- Praça Conectada – Banco de dados de cadastro de clientes (PostgreSQL)
-- Projeto Integrador II – Senac EAD | Terceira Forma Normal (3FN)
-- Executar no DBeaver (Alt+X) conectado a um banco vazio, ex.: praca_conectada
-- =====================================================================
DROP SCHEMA IF EXISTS praca CASCADE;
CREATE SCHEMA praca;
SET search_path TO praca;

CREATE TABLE vlan (
  id_vlan          INTEGER PRIMARY KEY CHECK (id_vlan BETWEEN 1 AND 4094),
  nome             VARCHAR(30)  NOT NULL UNIQUE,
  finalidade       VARCHAR(120) NOT NULL,
  rede_ipv4        CIDR NOT NULL UNIQUE,
  gateway_ipv4     INET NOT NULL,
  pool_dhcp_inicio INET,
  pool_dhcp_fim    INET,
  prefixo_ipv6     CIDR,
  CHECK (gateway_ipv4 << rede_ipv4)
);

CREATE TABLE perfil_acesso (
  id_perfil           INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nome                VARCHAR(30)  NOT NULL UNIQUE,
  descricao           VARCHAR(120) NOT NULL,
  duracao_max_horas   INTEGER NOT NULL CHECK (duracao_max_horas > 0),
  velocidade_max_mbps INTEGER NOT NULL CHECK (velocidade_max_mbps > 0),
  cota_diaria_mb      INTEGER CHECK (cota_diaria_mb IS NULL OR cota_diaria_mb > 0)
);

CREATE TABLE tipo_dispositivo (
  id_tipo   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  descricao VARCHAR(30) NOT NULL UNIQUE
);

CREATE TABLE termo_uso (
  id_termo        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  versao          VARCHAR(10) NOT NULL UNIQUE,
  vigencia_inicio DATE NOT NULL,
  resumo          VARCHAR(200) NOT NULL
);

CREATE TABLE ponto_acesso (
  id_ap            INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nome             VARCHAR(30) NOT NULL UNIQUE,
  modelo           VARCHAR(30) NOT NULL,
  local_instalacao VARCHAR(80) NOT NULL,
  mac              MACADDR NOT NULL UNIQUE,
  ip_gerencia      INET NOT NULL UNIQUE,
  id_vlan          INTEGER NOT NULL REFERENCES vlan(id_vlan)
);

CREATE TABLE cliente (
  id_cliente    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nome_completo VARCHAR(120) NOT NULL,
  email         VARCHAR(120) NOT NULL UNIQUE,
  telefone      VARCHAR(20),
  id_perfil     INTEGER NOT NULL REFERENCES perfil_acesso(id_perfil),
  data_cadastro DATE NOT NULL DEFAULT CURRENT_DATE,
  status        VARCHAR(10) NOT NULL DEFAULT 'ativo' CHECK (status IN ('ativo','bloqueado','inativo'))
);

CREATE TABLE aceite_termo (
  id_cliente  INTEGER NOT NULL REFERENCES cliente(id_cliente) ON DELETE CASCADE,
  id_termo    INTEGER NOT NULL REFERENCES termo_uso(id_termo),
  data_aceite TIMESTAMP NOT NULL,
  PRIMARY KEY (id_cliente, id_termo)
);

CREATE TABLE dispositivo (
  id_dispositivo  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_cliente      INTEGER NOT NULL REFERENCES cliente(id_cliente) ON DELETE CASCADE,
  id_tipo         INTEGER NOT NULL REFERENCES tipo_dispositivo(id_tipo),
  mac             MACADDR NOT NULL UNIQUE,
  apelido         VARCHAR(60),
  primeiro_acesso TIMESTAMP NOT NULL,
  bloqueado       BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE concessao_dhcp (
  id_concessao   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_dispositivo INTEGER NOT NULL REFERENCES dispositivo(id_dispositivo) ON DELETE CASCADE,
  ip_atribuido   INET NOT NULL,
  id_vlan        INTEGER NOT NULL REFERENCES vlan(id_vlan),
  inicio         TIMESTAMP NOT NULL,
  fim            TIMESTAMP,
  ativa          BOOLEAN NOT NULL DEFAULT TRUE,
  CHECK (fim IS NULL OR fim >= inicio)
);
CREATE UNIQUE INDEX ux_concessao_ip_ativo   ON concessao_dhcp(ip_atribuido)   WHERE ativa;
CREATE UNIQUE INDEX ux_concessao_disp_ativo ON concessao_dhcp(id_dispositivo) WHERE ativa;

-- O IP concedido deve pertencer à rede da VLAN informada
CREATE FUNCTION fn_ip_na_vlan() RETURNS trigger AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vlan v WHERE v.id_vlan = NEW.id_vlan AND NEW.ip_atribuido << v.rede_ipv4) THEN
    RAISE EXCEPTION 'IP % não pertence à rede da VLAN %', NEW.ip_atribuido, NEW.id_vlan;
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql SET search_path = praca;
CREATE TRIGGER tg_ip_na_vlan BEFORE INSERT OR UPDATE ON concessao_dhcp
FOR EACH ROW EXECUTE FUNCTION fn_ip_na_vlan();

CREATE TABLE sessao_wifi (
  id_sessao      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_dispositivo INTEGER NOT NULL REFERENCES dispositivo(id_dispositivo) ON DELETE CASCADE,
  id_ap          INTEGER NOT NULL REFERENCES ponto_acesso(id_ap),
  inicio         TIMESTAMP NOT NULL,
  fim            TIMESTAMP,
  bytes_download BIGINT NOT NULL DEFAULT 0 CHECK (bytes_download >= 0),
  bytes_upload   BIGINT NOT NULL DEFAULT 0 CHECK (bytes_upload   >= 0),
  CHECK (fim IS NULL OR fim >= inicio)
);
CREATE INDEX ix_sessao_disp  ON sessao_wifi(id_dispositivo, inicio);
CREATE INDEX ix_sessao_ap    ON sessao_wifi(id_ap);
CREATE INDEX ix_disp_cliente ON dispositivo(id_cliente);

CREATE TABLE auditoria_cliente (
  id_auditoria  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_cliente    INTEGER NOT NULL,
  status_antigo VARCHAR(10) NOT NULL,
  status_novo   VARCHAR(10) NOT NULL,
  alterado_em   TIMESTAMP NOT NULL DEFAULT now()
);
CREATE FUNCTION fn_cliente_status() RETURNS trigger AS $$
BEGIN
  INSERT INTO auditoria_cliente (id_cliente, status_antigo, status_novo)
  VALUES (OLD.id_cliente, OLD.status, NEW.status);
  IF NEW.status = 'bloqueado' THEN
    UPDATE dispositivo SET bloqueado = TRUE WHERE id_cliente = NEW.id_cliente;
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql SET search_path = praca;
CREATE TRIGGER tg_cliente_status AFTER UPDATE OF status ON cliente
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION fn_cliente_status();

-- =========================== DADOS INICIAIS ===========================
-- VLANs
INSERT INTO vlan (id_vlan, nome, finalidade, rede_ipv4, gateway_ipv4, pool_dhcp_inicio, pool_dhcp_fim, prefixo_ipv6) VALUES (10, 'USERS', 'Usuários da praça (smartphones e notebooks)', '10.0.0.0/22', '10.0.0.1', '10.0.0.100', '10.0.3.250', '2001:DB8:0:AA10::/64');
INSERT INTO vlan (id_vlan, nome, finalidade, rede_ipv4, gateway_ipv4, pool_dhcp_inicio, pool_dhcp_fim, prefixo_ipv6) VALUES (20, 'SERVIDORES', 'Servidores internos (DHCP e DNS)', '10.0.4.0/28', '10.0.4.1', NULL, NULL, '2001:DB8:0:AA11::/64');
INSERT INTO vlan (id_vlan, nome, finalidade, rede_ipv4, gateway_ipv4, pool_dhcp_inicio, pool_dhcp_fim, prefixo_ipv6) VALUES (30, 'DMZ', 'Servidor Web publicado (www.praca.com.br)', '10.0.8.0/24', '10.0.8.1', NULL, NULL, '2001:DB8:0:AA12::/64');
INSERT INTO vlan (id_vlan, nome, finalidade, rede_ipv4, gateway_ipv4, pool_dhcp_inicio, pool_dhcp_fim, prefixo_ipv6) VALUES (99, 'GERENCIAMENTO', 'Administração dos equipamentos', '10.0.99.0/24', '10.0.99.1', NULL, NULL, 'FD00::/64');

-- Perfis de acesso
INSERT INTO perfil_acesso (nome, descricao, duracao_max_horas, velocidade_max_mbps, cota_diaria_mb) VALUES ('Visitante', 'Acesso eventual de visitantes da praça', 2, 5, 500);
INSERT INTO perfil_acesso (nome, descricao, duracao_max_horas, velocidade_max_mbps, cota_diaria_mb) VALUES ('Morador', 'Moradores do entorno da praça', 8, 20, 3000);
INSERT INTO perfil_acesso (nome, descricao, duracao_max_horas, velocidade_max_mbps, cota_diaria_mb) VALUES ('Comerciante', 'Comerciantes e ambulantes cadastrados', 12, 50, 8000);
INSERT INTO perfil_acesso (nome, descricao, duracao_max_horas, velocidade_max_mbps, cota_diaria_mb) VALUES ('Equipe TI', 'Equipe técnica da Praça Conectada', 24, 100, NULL);

-- Tipos de dispositivo
INSERT INTO tipo_dispositivo (descricao) VALUES ('Smartphone');
INSERT INTO tipo_dispositivo (descricao) VALUES ('Notebook');
INSERT INTO tipo_dispositivo (descricao) VALUES ('Tablet');
INSERT INTO tipo_dispositivo (descricao) VALUES ('Smartwatch');

-- Termos de uso (LGPD)
INSERT INTO termo_uso (versao, vigencia_inicio, resumo) VALUES ('1.0', '2026-08-01', 'Termo de uso do Wi-Fi comunitário e tratamento de dados (LGPD) – versão inicial');
INSERT INTO termo_uso (versao, vigencia_inicio, resumo) VALUES ('1.1', '2026-10-01', 'Inclusão do prazo de guarda dos registros de conexão');

-- Pontos de acesso (Cisco Catalyst 9115AXI do orçamento do projeto)
INSERT INTO ponto_acesso (nome, modelo, local_instalacao, mac, ip_gerencia, id_vlan) VALUES ('AP-CENTRAL', 'C9115AXI', 'Coreto (centro da praça)', '02:AA:00:00:00:01', '10.0.99.11', 99);
INSERT INTO ponto_acesso (nome, modelo, local_instalacao, mac, ip_gerencia, id_vlan) VALUES ('AP-NORTE', 'C9115AXI', 'Entrada norte e feira livre', '02:AA:00:00:00:02', '10.0.99.12', 99);
INSERT INTO ponto_acesso (nome, modelo, local_instalacao, mac, ip_gerencia, id_vlan) VALUES ('AP-SUL', 'C9115AXI', 'Playground e quadra', '02:AA:00:00:00:03', '10.0.99.13', 99);
INSERT INTO ponto_acesso (nome, modelo, local_instalacao, mac, ip_gerencia, id_vlan) VALUES ('AP-LESTE', 'C9115AXI', 'Quiosques e área de convivência', '02:AA:00:00:00:04', '10.0.99.14', 99);

-- Clientes (dados fictícios)
INSERT INTO cliente (nome_completo, email, telefone, id_perfil, data_cadastro, status) VALUES ('Maria das Dores Santos', 'maria.santos@exemplo.com.br', '(81) 99001-0001', (SELECT id_perfil FROM perfil_acesso WHERE nome='Morador'), '2026-08-05', 'ativo');
INSERT INTO cliente (nome_completo, email, telefone, id_perfil, data_cadastro, status) VALUES ('João Pedro Almeida', 'joao.almeida@exemplo.com.br', '(81) 99001-0002', (SELECT id_perfil FROM perfil_acesso WHERE nome='Morador'), '2026-08-06', 'ativo');
INSERT INTO cliente (nome_completo, email, telefone, id_perfil, data_cadastro, status) VALUES ('Ana Beatriz Lima', 'ana.lima@exemplo.com.br', '(81) 99001-0003', (SELECT id_perfil FROM perfil_acesso WHERE nome='Visitante'), '2026-08-12', 'ativo');
INSERT INTO cliente (nome_completo, email, telefone, id_perfil, data_cadastro, status) VALUES ('Carlos Eduardo Souza', 'carlos.souza@exemplo.com.br', '(81) 99001-0004', (SELECT id_perfil FROM perfil_acesso WHERE nome='Comerciante'), '2026-08-14', 'ativo');
INSERT INTO cliente (nome_completo, email, telefone, id_perfil, data_cadastro, status) VALUES ('Fernanda Oliveira', 'fernanda.oliveira@exemplo.com.br', '(81) 99001-0005', (SELECT id_perfil FROM perfil_acesso WHERE nome='Comerciante'), '2026-08-20', 'ativo');
INSERT INTO cliente (nome_completo, email, telefone, id_perfil, data_cadastro, status) VALUES ('José Roberto Silva', 'jose.silva@exemplo.com.br', '(81) 99001-0006', (SELECT id_perfil FROM perfil_acesso WHERE nome='Morador'), '2026-09-01', 'ativo');
INSERT INTO cliente (nome_completo, email, telefone, id_perfil, data_cadastro, status) VALUES ('Luciana Barbosa', 'luciana.barbosa@exemplo.com.br', '(81) 99001-0007', (SELECT id_perfil FROM perfil_acesso WHERE nome='Visitante'), '2026-09-03', 'ativo');
INSERT INTO cliente (nome_completo, email, telefone, id_perfil, data_cadastro, status) VALUES ('Rafael Cavalcanti', 'rafael.cavalcanti@exemplo.com.br', '(81) 99001-0008', (SELECT id_perfil FROM perfil_acesso WHERE nome='Morador'), '2026-09-10', 'ativo');
INSERT INTO cliente (nome_completo, email, telefone, id_perfil, data_cadastro, status) VALUES ('Patrícia Gomes', 'patricia.gomes@exemplo.com.br', '(81) 99001-0009', (SELECT id_perfil FROM perfil_acesso WHERE nome='Visitante'), '2026-09-15', 'bloqueado');
INSERT INTO cliente (nome_completo, email, telefone, id_perfil, data_cadastro, status) VALUES ('Marcos Vinícius Rocha', 'marcos.rocha@exemplo.com.br', '(81) 99001-0010', (SELECT id_perfil FROM perfil_acesso WHERE nome='Comerciante'), '2026-09-22', 'ativo');
INSERT INTO cliente (nome_completo, email, telefone, id_perfil, data_cadastro, status) VALUES ('Juliana Pereira', 'juliana.pereira@exemplo.com.br', '(81) 99001-0011', (SELECT id_perfil FROM perfil_acesso WHERE nome='Morador'), '2026-10-02', 'inativo');
INSERT INTO cliente (nome_completo, email, telefone, id_perfil, data_cadastro, status) VALUES ('Thiago Nascimento', 'thiago.nascimento@exemplo.com.br', '(81) 99001-0012', (SELECT id_perfil FROM perfil_acesso WHERE nome='Equipe TI'), '2026-10-05', 'ativo');
INSERT INTO cliente (nome_completo, email, telefone, id_perfil, data_cadastro, status) VALUES ('Beatriz Moura', 'beatriz.moura@exemplo.com.br', '(81) 99001-0013', (SELECT id_perfil FROM perfil_acesso WHERE nome='Visitante'), '2026-10-20', 'ativo');
INSERT INTO cliente (nome_completo, email, telefone, id_perfil, data_cadastro, status) VALUES ('Diego Farias', 'diego.farias@exemplo.com.br', '(81) 99001-0014', (SELECT id_perfil FROM perfil_acesso WHERE nome='Morador'), '2026-10-28', 'ativo');

-- Aceites dos termos (consentimento LGPD)
INSERT INTO aceite_termo (id_cliente, id_termo, data_aceite) VALUES ((SELECT id_cliente FROM cliente WHERE email='maria.santos@exemplo.com.br'), (SELECT id_termo FROM termo_uso WHERE versao='1.0'), '2026-08-05 10:00:00');
INSERT INTO aceite_termo (id_cliente, id_termo, data_aceite) VALUES ((SELECT id_cliente FROM cliente WHERE email='maria.santos@exemplo.com.br'), (SELECT id_termo FROM termo_uso WHERE versao='1.1'), '2026-10-02 10:00:00');
INSERT INTO aceite_termo (id_cliente, id_termo, data_aceite) VALUES ((SELECT id_cliente FROM cliente WHERE email='joao.almeida@exemplo.com.br'), (SELECT id_termo FROM termo_uso WHERE versao='1.0'), '2026-08-06 10:00:00');
INSERT INTO aceite_termo (id_cliente, id_termo, data_aceite) VALUES ((SELECT id_cliente FROM cliente WHERE email='joao.almeida@exemplo.com.br'), (SELECT id_termo FROM termo_uso WHERE versao='1.1'), '2026-10-02 10:00:00');
INSERT INTO aceite_termo (id_cliente, id_termo, data_aceite) VALUES ((SELECT id_cliente FROM cliente WHERE email='ana.lima@exemplo.com.br'), (SELECT id_termo FROM termo_uso WHERE versao='1.0'), '2026-08-12 10:00:00');
INSERT INTO aceite_termo (id_cliente, id_termo, data_aceite) VALUES ((SELECT id_cliente FROM cliente WHERE email='carlos.souza@exemplo.com.br'), (SELECT id_termo FROM termo_uso WHERE versao='1.0'), '2026-08-14 10:00:00');
INSERT INTO aceite_termo (id_cliente, id_termo, data_aceite) VALUES ((SELECT id_cliente FROM cliente WHERE email='carlos.souza@exemplo.com.br'), (SELECT id_termo FROM termo_uso WHERE versao='1.1'), '2026-10-02 10:00:00');
INSERT INTO aceite_termo (id_cliente, id_termo, data_aceite) VALUES ((SELECT id_cliente FROM cliente WHERE email='fernanda.oliveira@exemplo.com.br'), (SELECT id_termo FROM termo_uso WHERE versao='1.0'), '2026-08-20 10:00:00');
INSERT INTO aceite_termo (id_cliente, id_termo, data_aceite) VALUES ((SELECT id_cliente FROM cliente WHERE email='fernanda.oliveira@exemplo.com.br'), (SELECT id_termo FROM termo_uso WHERE versao='1.1'), '2026-10-02 10:00:00');
INSERT INTO aceite_termo (id_cliente, id_termo, data_aceite) VALUES ((SELECT id_cliente FROM cliente WHERE email='jose.silva@exemplo.com.br'), (SELECT id_termo FROM termo_uso WHERE versao='1.0'), '2026-09-01 10:00:00');
INSERT INTO aceite_termo (id_cliente, id_termo, data_aceite) VALUES ((SELECT id_cliente FROM cliente WHERE email='luciana.barbosa@exemplo.com.br'), (SELECT id_termo FROM termo_uso WHERE versao='1.0'), '2026-09-03 10:00:00');
INSERT INTO aceite_termo (id_cliente, id_termo, data_aceite) VALUES ((SELECT id_cliente FROM cliente WHERE email='rafael.cavalcanti@exemplo.com.br'), (SELECT id_termo FROM termo_uso WHERE versao='1.0'), '2026-09-10 10:00:00');
INSERT INTO aceite_termo (id_cliente, id_termo, data_aceite) VALUES ((SELECT id_cliente FROM cliente WHERE email='rafael.cavalcanti@exemplo.com.br'), (SELECT id_termo FROM termo_uso WHERE versao='1.1'), '2026-10-02 10:00:00');
INSERT INTO aceite_termo (id_cliente, id_termo, data_aceite) VALUES ((SELECT id_cliente FROM cliente WHERE email='patricia.gomes@exemplo.com.br'), (SELECT id_termo FROM termo_uso WHERE versao='1.0'), '2026-09-15 10:00:00');
INSERT INTO aceite_termo (id_cliente, id_termo, data_aceite) VALUES ((SELECT id_cliente FROM cliente WHERE email='marcos.rocha@exemplo.com.br'), (SELECT id_termo FROM termo_uso WHERE versao='1.0'), '2026-09-22 10:00:00');
INSERT INTO aceite_termo (id_cliente, id_termo, data_aceite) VALUES ((SELECT id_cliente FROM cliente WHERE email='marcos.rocha@exemplo.com.br'), (SELECT id_termo FROM termo_uso WHERE versao='1.1'), '2026-10-02 10:00:00');
INSERT INTO aceite_termo (id_cliente, id_termo, data_aceite) VALUES ((SELECT id_cliente FROM cliente WHERE email='thiago.nascimento@exemplo.com.br'), (SELECT id_termo FROM termo_uso WHERE versao='1.1'), '2026-10-05 10:00:00');
INSERT INTO aceite_termo (id_cliente, id_termo, data_aceite) VALUES ((SELECT id_cliente FROM cliente WHERE email='beatriz.moura@exemplo.com.br'), (SELECT id_termo FROM termo_uso WHERE versao='1.1'), '2026-10-20 10:00:00');
INSERT INTO aceite_termo (id_cliente, id_termo, data_aceite) VALUES ((SELECT id_cliente FROM cliente WHERE email='diego.farias@exemplo.com.br'), (SELECT id_termo FROM termo_uso WHERE versao='1.1'), '2026-10-28 10:00:00');

-- Dispositivos
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='maria.santos@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Smartphone'), '02:5E:C0:00:00:11', 'Celular da Maria', '2026-08-05 10:00:00', FALSE);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='maria.santos@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Tablet'), '02:5E:C0:00:00:12', 'Tablet', '2026-08-05 10:00:00', FALSE);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='joao.almeida@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Smartphone'), '02:5E:C0:00:00:13', 'Celular do João', '2026-08-06 10:00:00', FALSE);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='joao.almeida@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Notebook'), '02:5E:C0:00:00:14', 'Notebook', '2026-08-06 10:00:00', FALSE);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='ana.lima@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Smartphone'), '02:5E:C0:00:00:15', 'Celular da Ana', '2026-08-12 10:00:00', FALSE);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='carlos.souza@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Smartphone'), '02:5E:C0:00:00:16', 'Celular do Carlos', '2026-08-14 10:00:00', FALSE);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='carlos.souza@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Tablet'), '02:5E:C0:00:00:17', 'Tablet da barraca', '2026-08-14 10:00:00', FALSE);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='fernanda.oliveira@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Smartphone'), '02:5E:C0:00:00:18', 'Celular da Fernanda', '2026-08-20 10:00:00', FALSE);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='fernanda.oliveira@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Notebook'), '02:5E:C0:00:00:19', 'Notebook do quiosque', '2026-08-20 10:00:00', FALSE);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='jose.silva@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Smartphone'), '02:5E:C0:00:00:1A', 'Celular do José', '2026-09-01 10:00:00', FALSE);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='luciana.barbosa@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Smartphone'), '02:5E:C0:00:00:1B', 'Celular da Luciana', '2026-09-03 10:00:00', FALSE);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='luciana.barbosa@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Smartwatch'), '02:5E:C0:00:00:1C', 'Relógio', '2026-09-03 10:00:00', FALSE);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='rafael.cavalcanti@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Notebook'), '02:5E:C0:00:00:1D', 'Notebook do Rafael', '2026-09-10 10:00:00', FALSE);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='rafael.cavalcanti@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Smartphone'), '02:5E:C0:00:00:1E', 'Celular do Rafael', '2026-09-10 10:00:00', FALSE);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='patricia.gomes@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Smartphone'), '02:5E:C0:00:00:1F', 'Celular da Patrícia', '2026-09-15 10:00:00', TRUE);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='marcos.rocha@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Smartphone'), '02:5E:C0:00:00:20', 'Celular do Marcos', '2026-09-22 10:00:00', FALSE);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='juliana.pereira@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Tablet'), '02:5E:C0:00:00:21', 'Tablet da Juliana', '2026-10-02 10:00:00', FALSE);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='thiago.nascimento@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Notebook'), '02:5E:C0:00:00:22', 'Notebook de suporte', '2026-10-05 10:00:00', FALSE);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='thiago.nascimento@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Smartphone'), '02:5E:C0:00:00:23', 'Celular de suporte', '2026-10-05 10:00:00', FALSE);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='beatriz.moura@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Smartphone'), '02:5E:C0:00:00:24', 'Celular da Beatriz', '2026-10-20 10:00:00', FALSE);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='diego.farias@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Smartphone'), '02:5E:C0:00:00:25', 'Celular do Diego', '2026-10-28 10:00:00', FALSE);
INSERT INTO dispositivo (id_cliente, id_tipo, mac, apelido, primeiro_acesso, bloqueado) VALUES ((SELECT id_cliente FROM cliente WHERE email='diego.farias@exemplo.com.br'), (SELECT id_tipo FROM tipo_dispositivo WHERE descricao='Smartwatch'), '02:5E:C0:00:00:26', 'Relógio do Diego', '2026-10-28 10:00:00', FALSE);

-- Concessões DHCP (VLAN 10)
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:11'), '10.0.1.101', 10, '2026-08-05 10:00:00', '2026-08-25 10:00:00', FALSE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:11'), '10.0.0.101', 10, '2026-08-25 10:00:00', NULL, TRUE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:12'), '10.0.0.102', 10, '2026-08-05 10:00:00', NULL, TRUE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:13'), '10.0.0.103', 10, '2026-08-06 10:00:00', NULL, TRUE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:14'), '10.0.0.104', 10, '2026-08-06 10:00:00', NULL, TRUE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:15'), '10.0.0.105', 10, '2026-08-12 10:00:00', NULL, TRUE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:16'), '10.0.1.106', 10, '2026-08-14 10:00:00', '2026-09-03 10:00:00', FALSE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:16'), '10.0.0.106', 10, '2026-09-03 10:00:00', NULL, TRUE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:17'), '10.0.1.107', 10, '2026-08-14 10:00:00', '2026-09-03 10:00:00', FALSE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:17'), '10.0.0.107', 10, '2026-09-03 10:00:00', NULL, TRUE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:18'), '10.0.1.108', 10, '2026-08-20 10:00:00', '2026-09-09 10:00:00', FALSE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:18'), '10.0.0.108', 10, '2026-09-09 10:00:00', NULL, TRUE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:19'), '10.0.1.109', 10, '2026-08-20 10:00:00', '2026-09-09 10:00:00', FALSE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:19'), '10.0.0.109', 10, '2026-09-09 10:00:00', NULL, TRUE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1A'), '10.0.0.110', 10, '2026-09-01 10:00:00', NULL, TRUE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1B'), '10.0.0.111', 10, '2026-09-03 10:00:00', NULL, TRUE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1C'), '10.0.1.112', 10, '2026-09-03 10:00:00', '2026-09-23 10:00:00', FALSE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1C'), '10.0.0.112', 10, '2026-09-23 10:00:00', NULL, TRUE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1D'), '10.0.1.113', 10, '2026-09-10 10:00:00', '2026-09-30 10:00:00', FALSE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1D'), '10.0.0.113', 10, '2026-09-30 10:00:00', NULL, TRUE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1E'), '10.0.1.114', 10, '2026-09-10 10:00:00', '2026-09-30 10:00:00', FALSE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1E'), '10.0.0.114', 10, '2026-09-30 10:00:00', NULL, TRUE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1F'), '10.0.0.115', 10, '2026-09-15 10:00:00', NULL, TRUE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:20'), '10.0.0.116', 10, '2026-09-22 10:00:00', NULL, TRUE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:21'), '10.0.0.117', 10, '2026-10-02 10:00:00', '2026-10-02 18:00:00', FALSE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:22'), '10.0.0.118', 10, '2026-10-05 10:00:00', NULL, TRUE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:23'), '10.0.0.119', 10, '2026-10-05 10:00:00', NULL, TRUE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:24'), '10.0.1.120', 10, '2026-10-20 10:00:00', '2026-11-09 10:00:00', FALSE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:24'), '10.0.0.120', 10, '2026-11-09 10:00:00', NULL, TRUE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:25'), '10.0.1.121', 10, '2026-10-28 10:00:00', '2026-11-17 10:00:00', FALSE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:25'), '10.0.0.121', 10, '2026-11-17 10:00:00', NULL, TRUE);
INSERT INTO concessao_dhcp (id_dispositivo, ip_atribuido, id_vlan, inicio, fim, ativa) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:26'), '10.0.0.122', 10, '2026-10-28 10:00:00', NULL, TRUE);

-- Sessões Wi-Fi
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:12'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-NORTE'), '2026-08-10 17:34:00', '2026-08-10 18:21:00', 82313216, 7483019);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:16'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-08-15 17:30:00', '2026-08-15 18:21:00', 188481536, 23560192);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:15'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-NORTE'), '2026-08-17 09:28:00', '2026-08-17 10:52:00', 151781376, 30356275);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:15'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-CENTRAL'), '2026-08-18 12:47:00', '2026-08-18 13:49:00', 44302336, 4027485);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:11'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-CENTRAL'), '2026-08-20 09:39:00', '2026-08-20 09:59:00', 34865152, 4358144);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:14'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-08-22 16:29:00', '2026-08-22 17:44:00', 211025920, 19184174);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:18'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-08-22 19:34:00', '2026-08-22 19:50:00', 126353408, 18050486);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:15'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-08-27 10:39:00', '2026-08-27 10:54:00', 206831616, 17235968);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:14'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-NORTE'), '2026-09-02 12:18:00', '2026-09-02 13:02:00', 7602176, 1900544);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1A'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-NORTE'), '2026-09-02 14:54:00', '2026-09-02 15:24:00', 99614720, 8301226);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:19'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-09-03 09:05:00', '2026-09-03 10:13:00', 178520064, 19835562);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:14'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-09-03 11:27:00', '2026-09-03 13:10:00', 133693440, 26738688);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:14'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-09-04 10:28:00', '2026-09-04 12:06:00', 197394432, 16449536);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1B'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-09-04 13:07:00', '2026-09-04 13:29:00', 189267968, 15772330);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:19'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-09-05 16:31:00', '2026-09-05 18:20:00', 223870976, 22387097);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:18'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-09-06 15:34:00', '2026-09-06 16:37:00', 26214400, 2621440);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:16'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-CENTRAL'), '2026-09-07 10:03:00', '2026-09-07 10:57:00', 178520064, 19835562);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:16'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-CENTRAL'), '2026-09-07 11:33:00', '2026-09-07 12:08:00', 106168320, 26542080);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1A'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-09-07 15:10:00', '2026-09-07 15:33:00', 188743680, 47185920);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1A'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-09-08 18:45:00', '2026-09-08 19:30:00', 154402816, 22057545);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:13'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-09-10 15:42:00', '2026-09-10 16:31:00', 152305664, 12692138);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:14'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-09-10 19:58:00', '2026-09-10 20:12:00', 228327424, 28540928);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:13'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-CENTRAL'), '2026-09-11 12:49:00', '2026-09-11 13:15:00', 224657408, 56164352);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:17'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-NORTE'), '2026-09-14 16:36:00', '2026-09-14 18:05:00', 221249536, 36874922);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:14'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-NORTE'), '2026-09-16 18:29:00', '2026-09-16 19:45:00', 136577024, 15175224);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:12'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-09-17 14:13:00', '2026-09-17 15:13:00', 72613888, 8068209);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:19'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-CENTRAL'), '2026-09-18 11:20:00', '2026-09-18 12:36:00', 134479872, 12225442);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1D'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-CENTRAL'), '2026-09-18 17:22:00', '2026-09-18 18:48:00', 179044352, 22380544);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:17'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-09-20 17:13:00', '2026-09-20 18:18:00', 172490752, 19165639);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:13'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-NORTE'), '2026-09-20 18:27:00', '2026-09-20 19:37:00', 43253760, 3932160);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:17'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-09-21 12:43:00', '2026-09-21 14:23:00', 23855104, 1987925);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1C'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-CENTRAL'), '2026-09-21 14:03:00', '2026-09-21 15:47:00', 197132288, 19713228);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1B'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-CENTRAL'), '2026-09-21 14:10:00', '2026-09-21 14:53:00', 73924608, 14784921);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1C'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-09-21 14:18:00', '2026-09-21 16:01:00', 211550208, 42310041);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:19'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-NORTE'), '2026-09-22 17:50:00', '2026-09-22 18:35:00', 224133120, 44826624);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1C'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-CENTRAL'), '2026-09-23 18:13:00', '2026-09-23 19:39:00', 129236992, 12923699);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:15'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-09-23 19:22:00', '2026-09-23 19:51:00', 6553600, 728177);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1E'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-09-24 09:01:00', '2026-09-24 09:46:00', 150470656, 13679150);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:11'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-09-24 18:35:00', '2026-09-24 20:18:00', 213647360, 19422487);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:15'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-09-25 11:34:00', '2026-09-25 12:12:00', 132120576, 22020096);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:12'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-09-25 15:47:00', '2026-09-25 17:02:00', 176422912, 35284582);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1E'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-NORTE'), '2026-09-26 14:08:00', '2026-09-26 15:38:00', 164364288, 32872857);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:20'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-NORTE'), '2026-09-27 13:23:00', '2026-09-27 14:42:00', 201326592, 25165824);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:12'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-09-28 14:23:00', '2026-09-28 15:32:00', 118489088, 23697817);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:13'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-09-29 10:40:00', '2026-09-29 12:19:00', 127664128, 11605829);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1B'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-NORTE'), '2026-09-29 13:26:00', '2026-09-29 13:37:00', 20447232, 4089446);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:13'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-CENTRAL'), '2026-09-29 15:36:00', '2026-09-29 16:47:00', 142868480, 11905706);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:11'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-09-30 12:57:00', '2026-09-30 14:23:00', 171966464, 14330538);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:12'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-CENTRAL'), '2026-09-30 19:45:00', '2026-09-30 21:26:00', 160169984, 20021248);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:12'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-10-01 18:35:00', '2026-10-01 19:48:00', 36438016, 3643801);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:20'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-CENTRAL'), '2026-10-04 11:40:00', '2026-10-04 12:42:00', 46399488, 4218135);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:18'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-NORTE'), '2026-10-04 19:56:00', '2026-10-04 20:08:00', 39845888, 3320490);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1A'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-10-07 13:42:00', '2026-10-07 15:03:00', 40632320, 8126464);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1D'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-10-07 18:08:00', '2026-10-07 19:03:00', 116654080, 11665408);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:18'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-10-09 17:57:00', '2026-10-09 18:24:00', 48234496, 8039082);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1C'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-10-11 19:41:00', '2026-10-11 21:22:00', 170131456, 42532864);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:16'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-10-12 11:50:00', '2026-10-12 13:40:00', 162529280, 20316160);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:23'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-10-13 10:20:00', '2026-10-13 11:32:00', 33816576, 6763315);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:20'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-10-14 16:40:00', '2026-10-14 17:48:00', 152305664, 13845969);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1B'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-CENTRAL'), '2026-10-14 19:06:00', '2026-10-14 20:20:00', 89391104, 11173888);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1F'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-10-15 09:14:00', '2026-10-15 10:50:00', 141557760, 23592960);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1E'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-10-15 09:41:00', '2026-10-15 10:56:00', 225181696, 28147712);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1C'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-10-16 14:55:00', '2026-10-16 16:09:00', 187957248, 23494656);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1E'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-CENTRAL'), '2026-10-20 17:48:00', '2026-10-20 19:33:00', 90439680, 22609920);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:23'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-10-21 18:19:00', '2026-10-21 19:51:00', 36700160, 4077795);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1E'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-CENTRAL'), '2026-10-22 12:49:00', '2026-10-22 13:15:00', 54263808, 4521984);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1C'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-10-22 15:20:00', '2026-10-22 16:44:00', 10485760, 873813);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1E'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-NORTE'), '2026-10-22 17:43:00', '2026-10-22 19:04:00', 111673344, 13959168);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:22'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-NORTE'), '2026-10-25 03:00:00', '2026-10-25 04:11:00', 118489088, 13165454);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:20'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-NORTE'), '2026-10-26 03:00:00', '2026-10-26 04:02:00', 218628096, 54657024);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:23'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-10-26 04:00:00', '2026-10-26 04:41:00', 227540992, 25282332);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:22'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-NORTE'), '2026-10-26 06:00:00', '2026-10-26 06:55:00', 41156608, 4115660);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1D'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-CENTRAL'), '2026-10-26 10:10:00', '2026-10-26 11:39:00', 38010880, 7602176);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:22'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-NORTE'), '2026-10-26 17:16:00', '2026-10-26 18:05:00', 16252928, 2321846);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:24'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-10-27 05:00:00', '2026-10-27 05:50:00', 52428800, 7489828);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:25'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-NORTE'), '2026-10-27 06:00:00', '2026-10-27 06:28:00', 151519232, 18939904);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:25'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-10-29 03:00:00', '2026-10-29 04:02:00', 95420416, 19084083);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:26'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-CENTRAL'), '2026-10-29 08:00:00', '2026-10-29 09:01:00', 199491584, 33248597);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:26'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-10-30 07:00:00', '2026-10-30 07:52:00', 160432128, 16043212);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:24'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-10-30 14:27:00', '2026-10-30 15:41:00', 155975680, 17330631);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:1F'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-10-30 14:50:00', '2026-10-30 15:29:00', 155975680, 19496960);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:26'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-CENTRAL'), '2026-10-31 05:00:00', '2026-10-31 06:15:00', 79429632, 8825514);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:22'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-11-01 04:00:00', '2026-11-01 04:23:00', 28049408, 4674901);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:22'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-CENTRAL'), '2026-11-01 06:00:00', '2026-11-01 07:19:00', 44040192, 7340032);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:25'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-11-02 06:00:00', '2026-11-02 06:47:00', 159383552, 14489413);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:23'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-11-02 08:00:00', '2026-11-02 09:49:00', 28573696, 2597608);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:24'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-11-02 11:28:00', '2026-11-02 13:13:00', 157286400, 26214400);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:20'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-CENTRAL'), '2026-11-03 04:00:00', '2026-11-03 04:37:00', 233308160, 29163520);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:22'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-NORTE'), '2026-11-03 06:00:00', '2026-11-03 06:18:00', 103809024, 12976128);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:26'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-SUL'), '2026-11-03 08:00:00', '2026-11-03 09:46:00', 64225280, 12845056);
INSERT INTO sessao_wifi (id_dispositivo, id_ap, inicio, fim, bytes_download, bytes_upload) VALUES ((SELECT id_dispositivo FROM dispositivo WHERE mac='02:5E:C0:00:00:24'), (SELECT id_ap FROM ponto_acesso WHERE nome='AP-LESTE'), '2026-11-03 14:48:00', '2026-11-03 16:38:00', 99090432, 9909043);

-- ============================== VIEWS =================================
CREATE VIEW vw_clientes_ativos AS
SELECT c.id_cliente, c.nome_completo, c.email, p.nome AS perfil,
       COUNT(d.id_dispositivo) AS qtd_dispositivos
FROM cliente c
JOIN perfil_acesso p ON p.id_perfil = c.id_perfil
LEFT JOIN dispositivo d ON d.id_cliente = c.id_cliente
WHERE c.status = 'ativo'
GROUP BY c.id_cliente, c.nome_completo, c.email, p.nome;

CREATE VIEW vw_concessoes_ativas AS
SELECT host(cd.ip_atribuido) AS ip_atribuido, v.id_vlan, v.nome AS vlan, d.mac, td.descricao AS tipo,
       c.nome_completo AS cliente, cd.inicio
FROM concessao_dhcp cd
JOIN vlan v ON v.id_vlan = cd.id_vlan
JOIN dispositivo d ON d.id_dispositivo = cd.id_dispositivo
JOIN tipo_dispositivo td ON td.id_tipo = d.id_tipo
JOIN cliente c ON c.id_cliente = d.id_cliente
WHERE cd.ativa;

CREATE VIEW vw_uso_por_ap AS
SELECT ap.nome AS ponto_acesso, ap.local_instalacao,
       COUNT(s.id_sessao) AS sessoes,
       COUNT(DISTINCT s.id_dispositivo) AS dispositivos_distintos,
       ROUND(SUM(s.bytes_download)/1048576.0, 1) AS download_mb,
       ROUND(SUM(s.bytes_upload)/1048576.0, 1)   AS upload_mb
FROM ponto_acesso ap
LEFT JOIN sessao_wifi s ON s.id_ap = ap.id_ap
GROUP BY ap.id_ap, ap.nome, ap.local_instalacao;
