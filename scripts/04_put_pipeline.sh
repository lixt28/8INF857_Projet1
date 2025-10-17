#!/usr/bin/env bash
set -euo pipefail

# Déploie le pipeline snort-enrich (version sans Painless)
curl -sSk -u "elastic:MotDePasse" -H 'Content-Type: application/json' \
  -X PUT "https://192.168.1.1:9200/_ingest/pipeline/snort-enrich" \
  --data-binary @- <<'JSON'
{
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

    { "date": { "field": "seconds", "formats": ["UNIX"], "target_field": "@timestamp", "ignore_failure": true } },
    { "remove": { "field": "seconds", "ignore_missing": true } }
  ]
}
JSON

# Vérification (affiche la pipeline)
curl -sSk -u "elastic:MotDePasse" "https://192.168.1.1:9200/_ingest/pipeline/snort-enrich?pretty"

