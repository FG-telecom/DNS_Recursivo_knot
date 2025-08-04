#!/bin/bash

clear

# ============================
# AUTO INSTALADOR KNOT V5
# BASEADO NO PROJETO https://github.com/padilhafe/video-knot
# DO DESENVOLVEDOR FELIPE PADILHA (@padilhafe)
# ============================================
# CONTATO:
# Felipe Padilha: (43) 92001-7931
# ============================================

# Função para colorir texto
function print_color() {
    COLOR=$1
    TEXT=$2
    case $COLOR in
        "red") echo -e "\e[31m$TEXT\e[0m";;
        "green") echo -e "\e[32m$TEXT\e[0m";;
        "yellow") echo -e "\e[33m$TEXT\e[0m";;
        "blue") echo -e "\e[34m$TEXT\e[0m";;
        *) echo "$TEXT";;
    esac
}

print_color blue "==============================================="
print_color green "        AUTO INSTALADOR KNOT V5"
print_color yellow " Baseado no projeto de Felipe Padilha (@padilhafe)"
print_color yellow "        https://github.com/padilhafe/video-knot"
print_color blue "==============================================="
print_color yellow "Contato:"
print_color yellow "Felipe Padilha: (43) 92001-7931"
print_color blue "==============================================="

# Coleta de informações de hardware
TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
TOTAL_CPU=$(nproc)

RECOM_RAM=$((TOTAL_MEM/2))
RECOM_CPU=$((TOTAL_CPU-1))

print_color green "\nDetectado: ${TOTAL_MEM}MB de RAM e ${TOTAL_CPU} núcleos de CPU"
print_color yellow "Recomendação: Usar até ${RECOM_RAM}MB de RAM para cache e ${RECOM_CPU} núcleos para o DNS"

# Entrada de dados
read -p "Digite o tamanho da RAM para cache em MB [Recomendado: ${RECOM_RAM}]: " RAM_CACHE
RAM_CACHE=${RAM_CACHE:-$RECOM_RAM}

read -p "Digite seu IP público com barramento (ex: 203.0.113.0/24): " IP_PUBLICO

read -p "Digite o número de núcleos da CPU para o Knot [Recomendado: ${RECOM_CPU}]: " NUCLEOS
NUCLEOS=${NUCLEOS:-$RECOM_CPU}

# Criação do usuário do Knot
useradd -r -M -s /usr/sbin/nologin knot-resolver

# Configuração do cache em tmpfs
echo "tmpfs /var/cache/knot-resolver tmpfs rw,size=${RAM_CACHE}M,uid=knot-resolver,gid=knot-resolver,nosuid,nodev,noexec,mode=0700 0 0" | tee -a /etc/fstab
mkdir -p /var/cache/knot-resolver
mount -a

# Desabilita DNS padrão do Ubuntu
systemctl stop systemd-resolved
systemctl disable systemd-resolved
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

# Instalação dos pré-requisitos
apt-get update
apt-get -y install apt-transport-https ca-certificates wget

# Adiciona repositório do Knot
wget -O /usr/share/keyrings/cznic-labs-pkg.gpg https://pkg.labs.nic.cz/gpg
echo "deb [signed-by=/usr/share/keyrings/cznic-labs-pkg.gpg] https://pkg.labs.nic.cz/knot-resolver jammy main" > /etc/apt/sources.list.d/cznic-labs-knot-resolver.list
apt update

# Instalação do Knot
apt-get install -y knot-resolver knot-resolver-module-http knot-dnsutils

# Configura o kresd.conf
cat <<EOF > /etc/knot-resolver/kresd.conf
-- SPDX-License-Identifier: CC0-1.0
-- vim:syntax=lua:set ts=4 sw=4:

modules = {
    'hints > iterate',
    'stats',
    'view',
    'http',
    'daf',
}

net.listen('0.0.0.0', 53, { kind = 'dns' })
net.listen('0.0.0.0', 853, { kind = 'tls' })
net.listen('0.0.0.0', 8453, { kind = 'webmgmt' })

cache.size = cache.fssize() - 10*MB

view:addr('10.0.0.0/8', policy.all(policy.PASS))
view:addr('172.16.0.0/12', policy.all(policy.PASS))
view:addr('192.168.0.0/16', policy.all(policy.PASS))
view:addr('100.64.0.0/10', policy.all(policy.PASS))

view:addr('${IP_PUBLICO}', policy.all(policy.PASS))

view:addr('0.0.0.0/0', policy.all(policy.DROP))
EOF

# Habilita e inicia os serviços do Knot
for i in $(seq 1 $NUCLEOS)
do
    systemctl enable kresd@${i}
    systemctl start kresd@${i}
done

print_color blue "==============================================="
print_color green "Instalação concluída com sucesso!"
print_color yellow "Acesso Web: https://$(hostname -I | awk '{print $1}'):8453"
print_color blue "==============================================="
