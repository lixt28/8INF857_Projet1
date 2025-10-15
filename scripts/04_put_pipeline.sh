curl -sSk -u "elastic:$ES_PASS" -H 'Content-Type: application/json' \
  -X PUT 'https://127.0.0.1:9200/_ingest/pipeline/snort-enrich' \
  -d '{
    "processors": [
      { "set":    { "field": "event.module", "value": "snort" } },
      { "rename": { "field": "msg", "target_field": "rule_name", "ignore_missing": true } },
      { "script": { "lang":"painless",
        "source":"if (ctx.containsKey(\"rule\") && ctx.rule instanceof String) { def p = ctx.rule.split(\":\"); if (p.length >= 3) { def r = new HashMap(); r.gid = Integer.parseInt(p[0]); r.sid = Integer.parseInt(p[1]); r.rev = Integer.parseInt(p[2]); ctx.rule = r; ctx[\"rule.id\"] = r.sid; } }"
      }},
      { "date":   { "field":"seconds", "formats":["UNIX"], "target_field":"@timestamp", "ignore_failure":true } },
      { "remove": { "field":"seconds", "ignore_missing":true } }
    ]
  }'

# Vérifier
curl -sSk -u "elastic:$ES_PASS" 'https://127.0.0.1:9200/_ingest/pipeline/snort-enrich?pretty'
