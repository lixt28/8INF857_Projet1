#!/usr/bin/env bash
set -euo pipefail

# Déploie le pipeline "snort-enrich" dans Elasticsearch.
# Utilise ES_URL / ES_USER / ES_PASS si exportés dans l'environnement.
# Si ES_URL commence par https://, -k est utilisé pour accepter le certificat auto-signé (labo).

ES_URL="${ES_URL:-https://127.0.0.1:9200}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ES_PASS:-}"

if [[ -z "$ES_PASS" ]]; then
  echo "ERREUR: la variable ES_PASS est vide. Exporte ES_PASS et relance." >&2
  exit 1
fi

CURL_TLS_OPTS=""
if [[ "$ES_URL" == https://* ]]; then
  CURL_TLS_OPTS="-k"
fi

# Création / mise à jour du pipeline snort-enrich
curl -sS ${CURL_TLS_OPTS} -u "${ES_USER}:${ES_PASS}" \
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

# Affiche la pipeline pour vérification
curl -sS ${CURL_TLS_OPTS} -u "${ES_USER}:${ES_PASS}" \
  "${ES_URL}/_ingest/pipeline/snort-enrich?pretty"
