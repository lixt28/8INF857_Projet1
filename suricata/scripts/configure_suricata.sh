#!/usr/bin/env bash
set -euo pipefail



IFACE="${1:-${SURICATA_IFACE:-}}"
ES_URL="${2:-${ES_URL:-http://127.0.0.1:9200}}"


if [ -z "${IFACE}" ]; then
  filt='!($1 ~ /^(docker|veth|br-|virbr|vboxnet|tailscale|wg|zt|cali)/)'

  
  for pat in '^10\.' '^172\.(1[6-9]|2[0-9]|3[0-1])\.' '^192\.168\.'; do
    cand=$(ip -o -4 addr show up | awk '$2!="lo"{print $2,$4}' \
           | awk "$filt" | awk -v P="$pat" '$2 ~ P {print $1; exit}')
    if [ -n "$cand" ]; then
      IFACE="$cand"
      break
    fi
  done

  
  if [ -z "${IFACE}" ]; then
    IFACE=$(ip -o link show up | awk -F': ' '$2!="lo"{print $2}' \
            | awk "$filt" | head -n1)
  fi
fi

if [ -z "${IFACE}" ]; then
  printf "ERROR: Impossible de déterminer l'interface. Spécifie-la: sudo bash ... enp0s3\n" >&2
  exit 1
fi


YAML="/etc/suricata/suricata.yaml"
RULES_DIR="/etc/suricata/rules"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_RULES="${REPO_ROOT}/config/local.rules"
SYSLOGNG_SRC="${REPO_ROOT}/config/suricata-es.conf"
SYSLOGNG_DST="/etc/syslog-ng/conf.d/suricata-es.conf"


if [ -f "$YAML" ]; then
  sudo cp -n "$YAML" "${YAML}.bak.$(date +%s)" || true
fi


sudo mkdir -p "$RULES_DIR"
sudo cp -f "$LOCAL_RULES" "$RULES_DIR/local.rules"
sudo chown root:root "$RULES_DIR/local.rules"
sudo chmod 0644 "$RULES_DIR/local.rules"


if [ -f "$YAML" ]; then
  
  sudo sed -i "s/^\(\s*interface:\).*/\1 ${IFACE}/" "$YAML" || true

 
  sudo sed -i 's/^\(\s*#\s*\)\?enabled: *no/  enabled: yes/' "$YAML" || true
  sudo sed -i 's|^\(\s*file:\).*|\1 /var/log/suricata/eve.json|' "$YAML" || true
  sudo sed -i 's/^\(\s*types:\).*/\1 [ alert, dns, http, tls, ssh, flow, anomaly, stats ]/' "$YAML" || true

  
  if ! grep -q 'local.rules' "$YAML"; then
    sudo sed -i 's|^rule-files:.*|rule-files:\n  - local.rules|' "$YAML"
  fi
fi


sudo cp -f "$SYSLOGNG_SRC" "$SYSLOGNG_DST"
sudo chown root:root "$SYSLOGNG_DST"
sudo chmod 0644 "$SYSLOGNG_DST"

# Redémarrer services
sudo systemctl restart syslog-ng || true
sudo systemctl restart suricata || true




