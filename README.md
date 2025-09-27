# 🛠 Auto Instalador Knot V5

Script de instalação automatizada do **Knot Resolver 5** no **Ubuntu 22.04 LTS**.
Baseado no projeto de [@padilhafe](https://github.com/padilhafe/video-knot).

---

## 🚀 Funcionalidades
- Detecta automaticamente **RAM** e **núcleos de CPU**.
- Cria usuário seguro `knot-resolver` (se não existir).
- Configura **cache em RAM (tmpfs)** para performance.
- Desabilita o **systemd-resolved** do Ubuntu.
- Instala pacotes oficiais do repositório **NIC.CZ**.
- Configura **DNS (53/UDP/TCP)**, **DNS-over-TLS (853)** e **painel web (8453)**.
- Regras de segurança com `view` para restringir acesso.
- Inicia automaticamente o serviço `kresd`.

---

## 📋 Pré-requisitos
- Servidor rodando **Ubuntu 22.04 LTS** (recomendado recém-instalado).
- Acesso **root** ou `sudo`.
- IP público válido.

---

## 📦 Instalação

Clone o repositório e rode o instalador:

```bash

git clone https://github.com/FG-telecom/DNS_Recursivo_knot/blob/main/install.sh

chmod +x install.sh

sudo ./install.sh


