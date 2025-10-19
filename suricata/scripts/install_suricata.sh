#!/usr/bin/env bash

set -euo pipefail

echo "[install] Installation Suricata (ppa: oisf/suricata-stable)"

sudo apt update
sudo apt install -y software-properties-common curl jq

# PPA officiel OISF (paquets stables Suricata)
sudo add-apt-repository -y ppa:oisf/suricata-stable
sudo apt update

# Suricata + gestionnaire de règles
sudo apt install -y suricata suricata-update

# Chemins règles & logs
sudo mkdir -p /etc/suricata/rules /var/lib/suricata/rules /var/log/suricata
sudo chown -R suricata:suricata /var/log/suricata || true

# Téléchargement des règles communautaires 
echo "[install] suricata-update initial (ok si warning non bloquant)"
sudo suricata-update || true

# Lier le bundle principal s'il existe
if [[ -f /var/lib/suricata/rules/suricata.rules ]]; then
  sudo ln -sf /var/lib/suricata/rules/suricata.rules /etc/suricata/rules/suricata.rules
fi


