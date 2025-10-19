#!/usr/bin/env bash
set -euo pipefail


sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:oisf/suricata-stable
sudo apt update
sudo apt install -y suricata jq


sudo systemctl enable suricata
sudo systemctl stop suricata || true
