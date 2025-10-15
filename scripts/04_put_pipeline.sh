sudo cp scripts/04_put_pipeline.sh scripts/04_put_pipeline.sh.bak
sudo tee scripts/04_put_pipeline.sh > /dev/null <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

ES_URL="${ES_URL:-http://127.0.0.1:9200}"
ES_USER="${ES_USER:-}"
ES_PASS="${ES_PASS:-}"

CURL_TLS_OPTS=""
if [[ "$ES_URL" == https://* ]]; then
  # Cert autosigné en labo → on ignore la vérif cert
  CURL_TLS_OPTS="-k"
fi

CURL_AUTH_OPTS=()
if [[ -n "$ES_USER" && -n "$ES_PASS" ]]; then
  CURL_AUTH_OPTS=(-u "${ES_USER}:${ES_PASS}")
fi

# Déploie le pipeline snort-enrich (version minimale)
curl -sS ${CURL_TLS_OPTS} "${CURL_AUTH_OPTS[@]}" \
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

# Vérification : afficher la pipeline
curl -sS ${CURL_TLS_OPTS} "${CURL_AUTH_OPTS[@]}" \
  "${ES_URL}/_ingest/pipeline/snort-enrich?pretty"
BASH

sudo chmod +x scripts/04_put_pipeline.sh

