#!/usr/bin/env bash
set -e
OUT=../evidence/$(date +%Y%m%d_%H%M)
mkdir -p "$OUT"
curl -s 'http://localhost:9200/_cat/indices?v' > "$OUT/es_indices.txt" || true
curl -s 'http://localhost:9200/snort/_search?size=10&sort=@timestamp:desc' > "$OUT/snort_recent.json" || true
sudo tail -n 200 /var/log/snort/alert_json.txt > "$OUT/alert_json_tail.txt" || true
sudo timeout 5 tcpdump -s 0 -w "$OUT/proof.pcap" -i any || true
echo "Exporte manuellement les captures d'écran Kibana dans docs/screenshots/ et dépose les dans $OUT"
