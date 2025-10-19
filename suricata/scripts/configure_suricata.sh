#!/usr/bin/env bash

set -euo pipefail

IFACE="${1:-}"
HOME_NET="${2:-192.168.1.0/24}"
[[ -z "$IFACE" ]] && { echo "Usage: sudo bash suricata/scripts/configure.sh <INTERFACE> [HOME_NET]"; exit 1; }


SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../configs"

echo "[configure] Interface=$IFACE  HOME_NET=$HOME_NET"

SYSCONF="/etc/suricata"
YAML="$SYSCONF/suricata.yaml"
RULEDIR="$SYSCONF/rules"
LOGDIR="/var/log/suricata"

sudo mkdir -p "$RULEDIR"


[[ -f "$YAML" ]] && sudo cp "$YAML" "$YAML.bak_$(date +%Y%m%d_%H%M%S)"


sudo sed -i "s#^ *HOME_NET:.*#HOME_NET: \"[$HOME_NET]\"#g" "$YAML" || true


if ! grep -q "filename: $LOGDIR/eve.json" "$YAML" 2>/dev/null; then
  sudo tee -a "$YAML" >/dev/null <<YAML_APPEND

# EVE JSON minimal pour ingestion par syslog-ng
outputs:
  - eve-log:
      enabled: yes
      filetype: regular
      filename: $LOGDIR/eve.json
      community-id: true
      types: [alert, flow, dns, http, tls, ssh, fileinfo, anomaly]
YAML_APPEND
fi


if ! grep -q "^af-packet:" "$YAML" 2>/dev/null; then
  sudo tee -a "$YAML" >/dev/null <<AFPK

af-packet:
  - interface: $IFACE
    cluster-id: 99
    cluster-type: cluster_flow
    defrag: yes
    use-mmap: yes
AFPK
else
  sudo sed -i "0,/interface: .*/s//interface: $IFACE/" "$YAML" || true
fi


if [[ -f "$CONFIG_DIR/suricata/local.rules" ]]; then
  echo "[configure] Déploie local.rules"
  sudo cp "$CONFIG_DIR/suricata/local.rules" "$RULEDIR/local.rules"
else
  echo "[configure] local.rules non trouvé — création d'une règle de test"
  sudo tee "$RULEDIR/local.rules" >/dev/null <<LR
# Test ICMP (ping) vers HOME_NET
alert icmp any any -> $HOME_NET any (msg:"LOCAL ICMP test"; itype:8; sid:1000001; rev:1;)
LR
fi


if grep -q "^default-rule-path:" "$YAML" 2>/dev/null; then
  sudo sed -i "s#^default-rule-path:.*#default-rule-path: $RULEDIR#g" "$YAML"
else
  echo "default-rule-path: $RULEDIR" | sudo tee -a "$YAML" >/dev/null
fi

if ! grep -q "^rule-files:" "$YAML" 2>/dev/null; then
  sudo tee -a "$YAML" >/dev/null <<RF
rule-files:
  - suricata.rules
  - local.rules
RF
else
  grep -q "suricata.rules" "$YAML" || sudo sed -i "/^rule-files:/a\  - suricata.rules" "$YAML"
  grep -q "local.rules"    "$YAML" || sudo sed -i "/^rule-files:/a\  - local.rules" "$YAML"
fi


echo "[configure] Test suricata -T"
sudo suricata -T -c "$YAML" -i "$IFACE"


if [[ -f "$CONFIG_DIR/syslog-ng/suricata-es.conf" ]]; then
  echo "[configure] Déploie suricata-es.conf pour syslog-ng"
  sudo mkdir -p /etc/syslog-ng/conf.d
  sudo cp "$CONFIG_DIR/syslog-ng/suricata-es.conf" /etc/syslog-ng/conf.d/suricata-es.conf
  sudo syslog-ng -s -f /etc/syslog-ng/syslog-ng.conf || true
  sudo systemctl restart syslog-ng || true
else
  echo "[configure] Avertissement: suricata-es.conf introuvable dans le repo"
fi


sudo systemctl enable --now suricata || true
sudo systemctl restart suricata || true


sudo systemctl --no-pager -l status suricata | sed -n '1,10p' || true
sudo systemctl --no-pager -l status syslog-ng | sed -n '1,10p' || true



