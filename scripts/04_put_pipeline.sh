sudo tee scripts/04_put_pipeline.sh > /dev/null <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

ES_URL="${ES_URL:-https://127.0.0.1:9200}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ES_PASS:-}"

[[ -z "$ES_PASS" ]] && { echo "ERREUR: ES_PASS est vide"; exit 1; }

CURL_TLS_OPTS=""
[[ "$ES_URL" == https://* ]] && CURL_TLS_OPTS="-k"

curl -sS $CURL_TLS_OPTS -u "${ES_USER}:${ES_PASS}" \
  -H 'Content-Type: application/json' \
  -X PUT "${ES_URL}/_ingest/pipeline/snort-enrich" \
  --data-binary @- <<'JSON'
{
  "processors": [
    { "set":    { "field": "event.module", "value": "snort" } },
    { "rename": { "field": "msg", "target_field": "rule_name", "ignore_missing": true } },
    {
      "script": {
        "lang": "painless",
        "source": "if (ctx.containsKey('rule') && ctx.rule instanceof String) { def p = ctx.rule.split(':'); if (p.length >= 3) { def r = new HashMap(); r.gid = Integer.parseInt(p[0]); r.sid = Integer.parseInt(p[1]); r.rev = Integer.parseInt(p[2]); ctx.rule = r; ctx['rule.id'] = r.sid; } }"
      }
    },
    { "date":   { "field": "seconds", "formats": ["UNIX"], "target_field": "@timestamp", "ignore_failure": true } },
    { "remove": { "field": "seconds", "ignore_missing": true } }
  ]
}
JSON

curl -sS $CURL_TLS_OPTS -u "${ES_USER}:${ES_PASS}" \
  "${ES_URL}/_ingest/pipeline/snort-enrich?pretty"
BASH

sudo chmod +x scripts/04_put_pipeline.sh


