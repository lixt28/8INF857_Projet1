#!/usr/bin/env bash
set -euo pipefail

# Usage: sudo bash suricata/scripts/configure_suricata.sh [interface] [es_url]
IFACE="${1:-${SURICATA_IFACE:-}}"
ES_URL="${2:-${ES_URL:-http://127.0.0.1:9200}}"

# Auto-détection d'interface (sans warnings awk)
if [ -z "${IFACE:-}" ]; then
  filt='^(docker|veth|br-|virbr|vboxnet|tailscale|wg|zt|cali)'
  for pat in '^10\.' '^172\.(1[6-9]|2[0-9]|3[0-1])\.' '^192\.168\.'; do
    cand=$(ip -o -4 addr show up \
           | awk '$2!="lo"{print $2,$4}' \
           | grep -Ev "$filt" \
           | grep -E " $pat" \
           | awk '{print $1; exit}')
    [ -n "$cand" ] && IFACE="$cand" && break
  done
  [ -z "${IFACE:-}" ] && IFACE=$(ip -o link show up | awk -F': ' '$2!="lo"{print $2}' | grep -Ev "$filt" | head -n1 || true)
  [ -z "${IFACE:-}" ] && { echo "Impossible de déterminer l'interface. Indique-la, ex: ens37"; exit 1; }
fi

YAML="/etc/suricata/suricata.yaml"
RULES_DIR="/etc/suricata/rules"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_RULES="${REPO_ROOT}/config/local.rules"

[ -f "$YAML" ] && sudo cp -n "$YAML" "${YAML}.bak.$(date +%s)" || true

if [ -f "$LOCAL_RULES" ]; then
  sudo mkdir -p "$RULES_DIR"
  sudo install -m 0644 -o root -g root "$LOCAL_RULES" "$RULES_DIR/local.rules"
fi

if [ -f "$YAML" ]; then
  sudo sed -i "s/^\(\s*interface:\).*/\1 ${IFACE}/" "$YAML" || true
  sudo sed -i 's/^\(\s*#\s*\)\?enabled: *no/  enabled: yes/' "$YAML" || true
  sudo sed -i 's|^\(\s*file:\).*|\1 /var/log/suricata/eve.json|' "$YAML" || true
  sudo sed -i 's/^\(\s*types:\).*/\1 [ alert, dns, http, tls, ssh, flow, anomaly, stats ]/' "$YAML" || true
  grep -q 'local.rules' "$YAML" || sudo sed -i 's|^rule-files:.*|rule-files:\n  - local.rules|' "$YAML"
fi

# Écrire une conf syslog-ng MINIMALE (pas de @version, @include, template)
SYSLOGNG_DST="/etc/syslog-ng/conf.d/suricata-es.conf"
sudo tee "$SYSLOGNG_DST" >/dev/null <<'CONF'
# Suricata EVE JSON -> Elasticsearch (_bulk)

source s_suricata_eve {
    file("/var/log/suricata/eve.json"
         flags(no-parse)
         program-override("suricata"));
};

destination d_es_suricata {
    http(
        url("http://127.0.0.1:9200/_bulk")
        method("POST")
        headers("Content-Type: application/json")
        body("{\"index\":{\"_index\":\"suricata-eve-${YEAR}.${MONTH}.${DAY}\"}}\n$MSG\n")
        workers(1)
        batch-lines(200)
        batch-timeout(2000)
    );
};

log {
    source(s_suricata_eve);
    destination(d_es_suricata);
    flags(flow-control);
};
CONF

# Garde-fou
if grep -E '^\s*@version|^\s*@include\s+"scl\.conf"|^\s*template\s' "$SYSLOGNG_DST" >/dev/null; then
  echo "Conf syslog-ng invalide (contient @version/include/template)"; exit 1
fi

# Module http requis
dpkg -s syslog-ng-mod-http >/dev/null 2>&1 || { sudo apt update && sudo apt install -y syslog-ng-mod-http; }

# Stopper rsyslog si présent (conflit possible)
systemctl is-active rsyslog >/dev/null 2>&1 && sudo systemctl stop rsyslog || true
systemctl is-enabled rsyslog >/dev/null 2>&1 && sudo systemctl disable rsyslog || true

# Test de conf syslog-ng avant restart
sudo syslog-ng -s

# Redémarrer services
sudo systemctl restart syslog-ng || true
sudo systemctl restart suricata || true
