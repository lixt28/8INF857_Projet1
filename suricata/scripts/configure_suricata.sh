
#!/usr/bin/env bash
# Usage:

set -euo pipefail


IFACE_RAW="${1:-${SURICATA_IFACE:-}}"
ES_URL="${2:-${ES_URL:-http://127.0.0.1:9200}}"

YAML="/etc/suricata/suricata.yaml"
RULES_DIR="/etc/suricata/rules"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_RULES="${REPO_ROOT}/config/local.rules"         
SYSLOGNG_SRC="${REPO_ROOT}/config/suricata-es.conf"
SYSLOGNG_DST="/etc/syslog-ng/conf.d/suricata-es.conf"

echo "[+] Configure Suricata + pipeline syslog-ng -> Elasticsearch"


if [ -z "${IFACE_RAW}" ]; then
  filt='^(lo|docker|veth|br-|virbr|vboxnet|tailscale|wg|zt|cali)$'
  IFACE_RAW=$(ip -o -4 addr show up \
    | awk '{print $2,$4}' \
    | grep -Ev "$filt" \
    | awk '$2 ~ /^10\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.|^192\.168\./ {print $1}' \
    | head -n1 || true)
  [ -z "${IFACE_RAW}" ] && { echo "Impossible de déterminer l'interface. Relance avec: sudo bash ... configure_suricata.sh <iface>"; exit 1; }
fi


IF_LIST=$(echo "$IFACE_RAW" | tr ',' ' ')
SURI_I_OPTS=""
for dev in $IF_LIST; do SURI_I_OPTS="$SURI_I_OPTS -i $dev"; done
echo "[+] Interfaces retenues: $IF_LIST"


sudo mkdir -p "$RULES_DIR"
if [ -f "$LOCAL_RULES" ]; then
  sudo install -m 0644 -o root -g root "$LOCAL_RULES" "$RULES_DIR/local.rules"
  echo "[+] local.rules déployé -> $RULES_DIR/local.rules"
else
  sudo touch "$RULES_DIR/local.rules"
  sudo chmod 0644 "$RULES_DIR/local.rules"
  echo "[!] local.rules absent dans le repo (créé vide)."
fi


if [ -f "$YAML" ]; then
  
  sudo sed -i 's/^\(\s*#\s*\)\?enabled:\s*no/ enabled: yes/' "$YAML" || true
  sudo sed -i 's|^\(\s*file:\).*|\1 /var/log/suricata/eve.json|' "$YAML" || true
  sudo sed -i 's/^\(\s*types:\).*/\1 [ alert, flow, dns, http, tls, ssh, anomaly, stats ]/' "$YAML" || true
  
  grep -q 'local.rules' "$YAML" || sudo sed -i 's|^rule-files:.*|rule-files:\n - local.rules|' "$YAML"
else
  echo "[!] Attention: $YAML introuvable. Suricata peut ne pas être installé."
fi


if [ -f "$SYSLOGNG_SRC" ]; then
  sudo install -m 0644 -o root -g root "$SYSLOGNG_SRC" "$SYSLOGNG_DST"
else
  echo "[!] $SYSLOGNG_SRC introuvable. Le pipeline syslog-ng->ES ne sera pas écrit."
fi


if ! dpkg -s syslog-ng-mod-http >/dev/null 2>&1; then
  echo "[+] Installation syslog-ng-mod-http"
  sudo apt update && sudo apt install -y syslog-ng-mod-http
fi


sudo syslog-ng -s


[ -f /etc/default/suricata ] && sudo cp -n /etc/default/suricata /etc/default/suricata.bak.$(date +%s)
sudo tee /etc/default/suricata >/dev/null <<EOF
RUN=yes
LISTENMODE=pcap
IFACE=${IFACE_RAW}
SURICATA_OPTIONS="${SURI_I_OPTS} -c /etc/suricata/suricata.yaml"
EOF
echo "[+] /etc/default/suricata écrit."


sudo mkdir -p /var/log/suricata
sudo chown suricata:suricata /var/log/suricata || true


echo "[+] Test suricata -T"
sudo suricata -T -c "$YAML" ${SURI_I_OPTS}

echo "[+] Restart services"
sudo systemctl daemon-reload
sudo systemctl restart syslog-ng
sudo systemctl restart suricata


echo "[+] Test lecture EVE (si trafic vu)"
sudo head -n1 /var/log/suricata/eve.json || true

echo "[+] Indices Elasticsearch (si ES up & trafic)"
curl -s "${ES_URL}/_cat/indices/suricata-eve-*?h=index,docs.count,health" || true

echo "[✓] Terminé. Dans Kibana: Data View = 'suricata-eve-*' (time field: 'timestamp')."



