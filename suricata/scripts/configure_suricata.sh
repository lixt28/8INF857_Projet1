# Écrire la conf syslog-ng minimale (pas de @version, pas de @include, pas de template)
SYSLOGNG_DST="/etc/syslog-ng/conf.d/suricata-es.conf"
sudo tee "$SYSLOGNG_DST" >/dev/null <<'EOF'
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
EOF

# Sanity check: refuser toute conf qui réintroduit @version / include scl.conf / template
if grep -E '^\s*@version|^\s*@include\s+"scl\.conf"|^\s*template\s' "$SYSLOGNG_DST" >/dev/null; then
  printf "Refus: /etc/syslog-ng/conf.d/suricata-es.conf contient des directives interdites.\n" >&2
  exit 1
fi

# S'assurer que le module HTTP est là
if ! dpkg -s syslog-ng-mod-http >/dev/null 2>&1; then
  sudo apt update && sudo apt install -y syslog-ng-mod-http
fi

# Test de syntaxe avant restart
sudo syslog-ng -s

# OK => restart
sudo systemctl restart syslog-ng
