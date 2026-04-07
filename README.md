Este repositório documenta o desenvolvimento do meu Projeto Integrador do 1º módulo da graduação em Redes de Computadores. O objetivo central foi projetar e implementar a "Praça Conectada", uma arquitetura de rede robusta simulando um ambiente real de alta disponibilidade para serviços públicos e comunitários.

Neste projeto, implementei uma rede totalmente funcional com foco em escalabilidade, segurança e serviços essenciais.

🛠️ Implementações Técnicas e Topologia
A topologia do projeto foi desenhada no Cisco Packet Tracer e abrange uma rede local comunitária (LAN) conectada a dois provedores de internet (ISP) distintos para redundância.

Visualização da Topologia
(Insira aqui a sua imagem image_7.png para dar contexto visual)

Detalhamento das Configurações
Abaixo estão os detalhes técnicos das principais configurações implementadas no núcleo da rede (Roteador e Switch Core):

1. Segmentação da Rede (VLANs e Inter-VLAN Routing)
(Baseado em image_3.png e image_2.png)
A rede local foi segmentada em VLANs para otimizar o tráfego e aumentar a segurança. A comunicação entre as VLANs é realizada através da técnica Router-on-a-Stick na interface GigabitEthernet0/0 do roteador principal.

Estrutura de VLANs (Switch ASW):
O Gemini disse
Este é o momento ideal para enriquecer o seu README do GitHub com o "provar" técnico do que você implementou. Usando as imagens que você forneceu, podemos extrair os dados exatos e criar uma seção de documentação técnica extremamente detalhada e profissional.

Aqui está uma proposta de estrutura completa para o seu README.md, incorporando o seu texto original refinado e uma nova seção de "Detalhamento Técnico" baseada nas capturas de tela.

🌐 Projeto Integrador: Praça Conectada – Infraestrutura de Redes
📌 Sobre o Projeto
Este repositório documenta o desenvolvimento do meu Projeto Integrador do 1º módulo da graduação em Redes de Computadores. O objetivo central foi projetar e implementar a "Praça Conectada", uma arquitetura de rede robusta simulando um ambiente real de alta disponibilidade para serviços públicos e comunitários.

Neste projeto, implementei uma rede totalmente funcional com foco em escalabilidade, segurança e serviços essenciais.

🛠️ Implementações Técnicas e Topologia
A topologia do projeto foi desenhada no Cisco Packet Tracer e abrange uma rede local comunitária (LAN) conectada a dois provedores de internet (ISP) distintos para redundância.

Visualização da Topologia
(Insira aqui a sua imagem image_7.png para dar contexto visual)

Detalhamento das Configurações
Abaixo estão os detalhes técnicos das principais configurações implementadas no núcleo da rede (Roteador e Switch Core):

1. Segmentação da Rede (VLANs e Inter-VLAN Routing)
(Baseado em image_3.png e image_2.png)
A rede local foi segmentada em VLANs para otimizar o tráfego e aumentar a segurança. A comunicação entre as VLANs é realizada através da técnica Router-on-a-Stick na interface GigabitEthernet0/0 do roteador principal.

Estrutura de VLANs (Switch ASW):
ID VLAN	Nome	Portas Associadas	Sub-rede IPv4	Prefixo IPv6
10	USUARIOS	Fa0/1, Fa0/2, Fa0/3	10.0.0.0/22	2001:DB8:0:AA10::/64
20	SERVIDORES	Fa0/5, Fa0/6, Fa0/7	10.0.4.0/28	2001:DB8:0:AA11::/64
30	DMZ	Fa0/4	10.0.8.0/24	2001:DB8:0:AA12::/64
99	GERENCIAMENTO	Fa0/19	10.0.99.0/24	FD00::/64

Configuração Trunk: A porta Gig0/1 do switch está configurada como Trunk (802.1q) para transportar o tráfego de todas as VLANs para o roteador.

2. Endereçamento e Roteamento (L3)
(Baseado em image_5.png e image_6.png)
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
(Baseado em image_0.png e image_7.png)
Um servidor dedicado (10.0.4.2 na VLAN de Servidores) foi configurado para prover serviços essenciais.

DHCP: Configurado para distribuir endereços IPv4 dinamicamente para os dispositivos na VLAN de Usuários (Smartphones e Laptops na Praça Central).

DNS:

Servidor: 10.0.4.2

Registro A: O domínio www.praca.com.br foi configurado para resolver para o IP do Servidor Web na DMZ (10.0.8.2).

Serviços Web:

Servidor Web (na DMZ): 10.0.8.2

A imagem abaixo demonstra o sucesso na resolução DNS e no acesso à página web customizada do projeto a partir de um dispositivo da rede.
(Insira aqui a sua imagem image_0.png para demonstrar o funcionamento)

4. NAT (Network Address Translation)
(Baseado em image_7.png - Esta parte precisa ser inferida, pois não há screenshot da CLI de NAT, mas é essencial para o funcionamento)
Para permitir que os dispositivos da rede interna (usando IPs privados 10.0.0.0/8) acessem a internet, foi implementado o NAT Overload (PAT).

NAT Inside: Interfaces Gi0/0.10, Gi0/0.20, Gi0/0.30.

NAT Outside: Interface Gi0/1 (ISP1) e Gi0/1/0 (ISP2) para redundância.

🤝 Colaboração e Dual-Stack (IPv6)
Um ponto alto deste projeto foi o trabalho em equipe, destacando a contribuição do colega Daniel Lima, responsável pela implementação completa do Endereçamento IPv6.

(Baseado em image_4.png)
A rede opera em Dual-Stack. O roteador central foi configurado com os prefixos globais IPv6 e Link-Local (FE80::) em todas as subinterfaces das VLANs, garantindo que a infraestrutura esteja preparada para o futuro da internet.

Exemplo de Configuração IPv6 (VLAN Usuarios):

Interface: Gi0/0.10

Endereço: 2001:DB8:0:AA10::1/64

Link-Local: FE80::203:E4FF:FEB2:8701

