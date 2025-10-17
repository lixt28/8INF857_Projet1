#!/usr/bin/env bash
set -euo pipefail

# Configuration
ES_URL="https://192.168.1.1:9200"
ES_USER="elastic"
ES_PASS="MotDePasse"

echo "[i] Test de la connexion à Elasticsearch..."
curl -sSk --http1.1 -u "$ES_USER:$ES_PASS" "$ES_URL/" >/dev/null \
  || { echo "[!] Elasticsearch injoignable sur $ES_URL"; exit 1; }

echo "[i] (Ré)création du pipeline snort-enrich..."
curl -sSk --http1.1 -u "$ES_USER:$ES_PASS" -X DELETE "$ES_URL/_ingest/pipeline/snort-enrich" >/dev/null || true

curl -sSk --http1.1 -u "$ES_USER:$ES_PASS" -H 'Content-Type: application/json' \
  -X PUT "$ES_URL/_ingest/pipeline/snort-enrich" \
  --data-binary @- <<'JSON'
{
  "description": "Pipeline d'enrichissement Snort sans Painless",
  "processors": [
    { "set": { "field": "event.module", "value": "snort" } },
    { "rename": { "field": "msg", "target_field": "rule_name", "ignore_missing": true } },

    { "dissect": {
        "field": "rule",
        "pattern": "%{rule.gid}:%{rule.sid}:%{rule.rev}",
        "ignore_failure": true
    }},

    { "convert": { "field": "rule.gid", "type": "integer", "ignore_missing": true } },
    { "convert": { "field": "rule.sid", "type": "integer", "ignore_missing": true } },
    { "convert": { "field": "rule.rev", "type": "integer", "ignore_missing": true } },

    { "set": { "field": "rule.id", "copy_from": "rule.sid", "ignore_empty_value": true } },

    { "date": {
        "field": "seconds",
        "formats": ["UNIX"],
        "target_field": "@timestamp",
        "ignore_failure": true
    }},
    { "remove": { "field": "seconds", "ignore_missing": true } }
  ]
}
JSON

echo "[i] Vérification de la pipeline :"
curl -sSkf --http1.1 -u "$ES_USER:$ES_PASS" "$ES_URL/_ingest/pipeline/snort-enrich?pretty"
echo
echo "[✓] Pipeline snort-enrich installée avec succès."


