# Failover ISP1 ↔ ISP2 — proposta e limitação

**Status: NÃO implementado/testado.** O roteador do Packet Tracer usado no projeto não aceita `route-map` no comando `ip nat inside source`, o que impede configurar um NAT por interface de saída e, portanto, testar o failover automático. Print do erro: [`imagens/nat05_routemap_erro.png`](imagens/nat05_routemap_erro.png).

## Situação atual (validada)
- Rota padrão para o ISP1 (`200.1.1.1`) e NAT Overload pela interface do ISP1 (Gi0/0/0).
- Com um único NAT, só um provedor funciona por vez. O ISP2 (`201.1.1.1`) não é usado como saída.

## Configuração proposta (para roteador real, ex.: Cisco Catalyst C8200)
```
ip route 0.0.0.0 0.0.0.0 200.1.1.1
ip route 0.0.0.0 0.0.0.0 201.1.1.1 5
route-map NAT_ISP1 permit 10
 match ip address 1
 match interface GigabitEthernet0/0/0
route-map NAT_ISP2 permit 10
 match ip address 1
 match interface GigabitEthernet0/1/0
ip nat inside source route-map NAT_ISP1 interface GigabitEthernet0/0/0 overload
ip nat inside source route-map NAT_ISP2 interface GigabitEthernet0/1/0 overload
```
A segunda rota padrão (distância administrativa 5, valor ilustrativo da proposta) é a rota flutuante de reserva.

## Teste de aceite proposto
1. Pingar da VLAN 10 para a Internet (saindo pelo ISP1).
2. `shutdown` na Gi0/0/0.
3. Confirmar que o ping continua, agora pelo ISP2.
4. `no shutdown` e confirmar o retorno ao ISP1.

## Observação
Falhas que não derrubam o link físico (ex.: o provedor para de responder) exigem monitoramento ativo, como **IP SLA + track**, associado à rota padrão.

## Cuidado
No Packet Tracer, o comando `no ip nat inside source list 1 ...` executa antes do erro do `route-map` e **remove o NAT**; é preciso restaurar com `ip nat inside source list 1 interface GigabitEthernet0/0/0 overload`.
