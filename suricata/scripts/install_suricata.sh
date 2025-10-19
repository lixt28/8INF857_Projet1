#!/usr/bin/env bash

set -euo pipefail

echo "[install] Installation Suricata (ppa: oisf/suricata-stable)"

sudo apt update
sudo apt install -y software-properties-common curl jq

sudo add-apt-repository -y ppa:oisf/suricata-stable
sudo apt update

sudo apt install -y suricata suricata-update

sudo mkdir -p /etc/suricata/rules /var/lib/suricata/rules /var/log/suricata
sudo chown -R suricata:suricata /var/log/suricata || true
 
echo "[install] suricata-update initial (ok si warning non bloquant)"
sudo suricata-update || true

if [[ -f /var/lib/suricata/rules/suricata.rules ]]; then
  sudo ln -sf /var/lib/suricata/rules/suricata.rules /etc/suricata/rules/suricata.rules
fi


