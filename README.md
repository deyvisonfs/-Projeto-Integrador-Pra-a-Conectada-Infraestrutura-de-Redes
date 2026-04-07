🌐 Projeto Integrador: Praça Conectada – Infraestrutura de Redes
📌 Sobre o Projeto
Este repositório documenta o desenvolvimento do meu Projeto Integrador do 1º módulo da graduação em Redes de Computadores. O objetivo central foi projetar e implementar a "Praça Conectada", uma arquitetura de rede robusta simulando um ambiente real de alta disponibilidade para serviços públicos e comunitários.

Neste projeto, implementei uma rede totalmente funcional com foco em escalabilidade, segurança e serviços essenciais.

🛠️ Implementações Técnicas e Topologia
A topologia do projeto foi desenhada no Cisco Packet Tracer e abrange uma rede local comunitária (LAN) conectada a dois provedores de internet (ISP) distintos para redundância.

Visualização da Topologia
![praça](https://github.com/user-attachments/assets/d3fef141-f168-4dbb-ae0e-f8024eec63cc)

Detalhamento das Configurações
Abaixo estão os detalhes técnicos das principais configurações implementadas no núcleo da rede (Roteador e Switch Core):

1. Segmentação da Rede (VLANs e Inter-VLAN Routing)
A rede local foi segmentada em VLANs para otimizar o tráfego e aumentar a segurança. A comunicação entre as VLANs é realizada através da técnica Router-on-a-Stick na interface GigabitEthernet0/0 do roteador principal.

Estrutura de VLANs (Switch ASW):
![Tabela](https://github.com/user-attachments/assets/87c50edc-0982-4b5d-a329-5b4b5fd97fcf)

Configuração Trunk: A porta Gig0/1 do switch está configurada como Trunk (802.1q) para transportar o tráfego de todas as VLANs para o roteador.

2. Endereçamento e Roteamento (L3)
O roteador central gerencia as subinterfaces correspondentes às VLANs e o roteamento para a WAN.

Interfaces do Roteador (IPv4):

Lado LAN (Router-on-a-Stick):

Gi0/0.10: 10.0.0.1 (Gateway VLAN Usuarios)

Gi0/0.20: 10.0.4.1 (Gateway VLAN Servidores)

Gi0/0.30: 10.0.8.1 (Gateway VLAN DMZ)

Gi0/0.99: 10.0.99.1 (Gateway VLAN Gerenciamento)

Lado WAN (Redundância):

Gi0/1: 200.1.1.2 (Conexão com ISP1)

Gi0/1/0: 201.1.1.2 (Conexão com ISP2)

Tabela de Roteamento IPv4:
O roteador possui uma Rota Estática Padrão (0.0.0.0/0) apontando para o gateway do ISP1 (200.1.1.1), garantindo o acesso à internet.

3. Serviços de Rede (DHCP, DNS e Web)
Um servidor dedicado (10.0.4.2 na VLAN de Servidores) foi configurado para prover serviços essenciais.

DHCP: Configurado para distribuir endereços IPv4 dinamicamente para os dispositivos na VLAN de Usuários (Smartphones e Laptops na Praça Central).

DNS:

Servidor: 10.0.4.2

Registro A: O domínio www.praca.com.br foi configurado para resolver para o IP do Servidor Web na DMZ (10.0.8.2).

Serviços Web:

Servidor Web (na DMZ): 10.0.8.2

A imagem abaixo demonstra o sucesso na resolução DNS e no acesso à página web customizada do projeto a partir de um dispositivo da rede.
![DNS](https://github.com/user-attachments/assets/652ee02d-3d70-47ff-9d4e-14c00f8b47a5)


4. NAT (Network Address Translation)
Para permitir que os dispositivos da rede interna (usando IPs privados 10.0.0.0/8) acessem a internet, foi implementado o NAT Overload (PAT).

NAT Inside: Interfaces Gi0/0.10, Gi0/0.20, Gi0/0.30.

NAT Outside: Interface Gi0/1 (ISP1) e Gi0/1/0 (ISP2) para redundância.

🤝 Colaboração e Dual-Stack (IPv6)
Um ponto alto deste projeto foi o trabalho em equipe, destacando a contribuição do colega Daniel Lima, responsável pela implementação completa do Endereçamento IPv6.

A rede opera em Dual-Stack. O roteador central foi configurado com os prefixos globais IPv6 e Link-Local (FE80::) em todas as subinterfaces das VLANs, garantindo que a infraestrutura esteja preparada para o futuro da internet.

Exemplo de Configuração IPv6 (VLAN Usuarios):

Interface: Gi0/0.10

Endereço: 2001:DB8:0:AA10::1/64

Link-Local: FE80::203:E4FF:FEB2:8701
