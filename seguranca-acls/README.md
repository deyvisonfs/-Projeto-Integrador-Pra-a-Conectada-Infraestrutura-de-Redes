# Segurança entre VLANs (ACLs) e NAT — evidências no Packet Tracer

Implementado e testado em 08/11/2026 no Router0 (borda). Detalhes completos no **Apêndice D** do documento em [`../documentacao/`](../documentacao/).

- Configuração final: [`acls_router0.txt`](acls_router0.txt)
- ACLs nomeadas estendidas, aplicadas **inbound** nas subinterfaces: `USERS_IN` (Gi0/0.10), `SERVERS_IN` (.20), `DMZ_IN` (.30) e `MGMT_IN` (.99).
- Resultado: VLAN 10 acessa Internet, DNS e Web da DMZ; VLAN 99 (gerência) e VLAN 20 ficam protegidas; DMZ não inicia conexão para as VLANs internas.

## Achados durante a implementação
1. **Controlador WLC (10.0.4.5, VLAN 20)** troca tráfego com os clientes da VLAN 10 nos dois sentidos. Sem exceção, os dispositivos perdiam o Wi-Fi. Foram criadas duas exceções (`permit ip host 10.0.4.5 ...` e `permit ip ... host 10.0.4.5`). Os contadores (`show access-lists`) mostraram a causa.
2. **NAT estava ligado à interface do ISP2** (Gi0/1/0) enquanto a rota padrão ia ao ISP1. Corrigido para Gi0/0/0; ping ao ISP1 (200.1.1.1) validado.
3. **Failover ISP1↔ISP2: não implementado.** O roteador do Packet Tracer não aceita `route-map` no NAT. Fica como proposta para roteador real (rota flutuante + route-map + IP SLA/track) — ver D.7.

## Pendências
- Testar HTTP/DNS com as quatro ACLs ativas.
- Identificar a origem de 380 pacotes VLAN 20 → VLAN 10 negados.
- ACLs IPv6 (ipv6 traffic-filter).
- `write memory` e salvar o `.pkt`.

## Prints
| Arquivo | O que mostra |
|---|---|
| `acl01_antes_laptop.png` | Laptop antes das ACLs |
| `acl02_servers_deny_wlc.png` | Contador da regra que nega VLAN 20 → VLAN 10 (WLC) |
| `acl03_wlc_tooltip.png` | Controlador WLC com IP 10.0.4.5 |
| `acl04_users_deny_wlc.png` | USERS_IN bloqueando cliente → WLC |
| `acl05_users_apos_ajuste.png` | USERS_IN após a exceção |
| `acl06_laptop_bloqueado.png` | Ping à gerência bloqueado |
| `acl07_dmz_bloqueado.png` | DMZ sem acesso às VLANs internas |
| `acl08_show_parte1.png`, `acl09_show_parte2.png` | `show access-lists` final |
| `nat01`–`nat04` | Tradução NAT errada, estatísticas, ping ISP1 e ISP2 |
| `nat05_routemap_erro.png` | Erro do `route-map` no Packet Tracer |
