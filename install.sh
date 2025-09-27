#!/bin/bash

clear

# ============================
# AUTO INSTALADOR KNOT V5
# DESENVOLVIDO POR FG TELECOM LTDA E CARLOS.M
# BASEADO NO PROJETO https://github.com/padilhafe/video-knot
# DO DESENVOLVEDOR FELIPE PADILHA (@padilhafe)
# ============================================
# CONTATOS:
# FG TELECOM LTDA: http://fgtelecom.psi.br
# Carlos.M: (47) 9 9205-4508
# Felipe Padilha: (43) 92001-7931
# ============================================

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
print_color green " Desenvolvido por FG Telecom LTDA e Carlos.M"
print_color yellow " Baseado no projeto de Felipe Padilha (@padilhafe)"
print_color yellow "        https://github.com/padilhafe/video-knot"
print_color blue "==============================================="
print_color yellow "Contatos:"
print_color yellow "FG Telecom LTDA: http://fgtelecom.psi.br"
print_color yellow "Carlos.M: (47) 9 9205-4508"
print_color yellow "Felipe Padilha: (43) 92001-7931"
print_color blue "==============================================="

TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
TOTAL_CPU=$(nproc)
RECOM_RAM=$((TOTAL_MEM/2))
RECOM_CPU=$((TOTAL_CPU-1))

print_color green "\nDetectado: ${TOTAL_MEM}MB de RAM e ${TOTAL_CPU} núcleos de CPU"
print_color yellow "Recomendação: Usar até ${RECOM_RAM}MB de RAM para cache e ${RECOM_CPU} núcleos para o DNS"

read -p "Digite o tamanho da RAM para cache em MB [Recomendado: ${RECOM_RAM}]: " RAM_CACHE
RAM_CACHE=${RAM_CACHE:-$RECOM_RAM}
read -p "Digite seu IP público com barramento (ex: 203.0.113.0/24): " IP_PUBLICO
read -p "Digite o número de núcleos da CPU para o Knot [Recomendado: ${RECOM_CPU}]: " NUCLEOS
NUCLEOS=${NUCLEOS:-$RECOM_CPU}

useradd -r -M -s /usr/sbin/nologin knot-resolver || true

echo "tmpfs /var/cache/knot-resolver tmpfs rw,size=${RAM_CACHE}M,uid=knot-resolver,gid=knot-resolver,nosuid,nodev,noexec,mode=0700 0 0" | tee -a /etc/fstab
mkdir -p /var/cache/knot-resolver
mount -a || { print_color red "Erro ao montar tmpfs"; exit 1; }

systemctl stop systemd-resolved || true
systemctl disable systemd-resolved || true
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

apt-get update
apt --fix-broken install -y
apt-get -y install apt-transport-https ca-certificates wget

wget -O /usr/share/keyrings/cznic-labs-pkg.gpg https://pkg.labs.nic.cz/gpg
echo "deb [signed-by=/usr/share/keyrings/cznic-labs-pkg.gpg] https://pkg.labs.nic.cz/knot-resolver jammy main" > /etc/apt/sources.list.d/cznic-labs-knot-resolver.list
apt update

if ! apt-get install -y knot-resolver knot-resolver-module-http knot-dnsutils; then
    print_color red "Falha na instalação do Knot Resolver. Verifique pacotes ou dependências."
    print_color yellow "Se estiver em uma versão antiga do Ubuntu, considere atualizar para 22.04."
    exit 1
fi

mkdir -p /etc/knot-resolver/

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

if systemctl list-unit-files | grep -q '^kresd@.service'; then
    for i in $(seq 1 $NUCLEOS)
    do
        systemctl enable kresd@${i}
        if ! systemctl start kresd@${i}; then
            print_color red "Falha ao iniciar kresd@${i}. Verifique com: journalctl -xeu kresd@${i}.service"
            print_color yellow "Tentando fallback para kresd.service..."
            systemctl enable kresd
            systemctl restart kresd
            break
        fi
    done
elif systemctl list-unit-files | grep -q '^kresd.service'; then
    systemctl enable kresd
    systemctl restart kresd
    print_color yellow "Aviso: Apenas o serviço principal kresd.service está disponível, usando ele."
else
    print_color red "Serviço do Knot não encontrado. Verifique se o pacote foi instalado corretamente."
fi

print_color blue "==============================================="
print_color green "Instalação concluída com sucesso!"
print_color yellow "Os serviços do Knot foram reiniciados com sucesso."
print_color yellow "Acesso Web: https://$(hostname -I | awk '{print $1}'):8453"
print_color blue "==============================================="
