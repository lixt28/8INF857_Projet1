#!/usr/bin/env bash
curl -X PUT "http://127.0.0.1:9200/_ingest/pipeline/snort-enrich" \
  -H 'Content-Type: application/json' -d '{
  "processors": [
    { "set":  { "field": "@timestamp", "value": "{{_ingest.timestamp}}" } },
    { "date": { "field": "seconds", "formats": ["UNIX"], "target_field": "@timestamp",
                "ignore_failure": true }},

    { "set":  { "field": "event.module",   "value": "snort" }},
    { "set":  { "field": "event.kind",     "value": "alert" }},
    { "set":  { "field": "event.category", "value": "network" }},
    { "set":  { "field": "event.type",     "value": "info" }},

    { "rename": { "field": "msg", "target_field": "rule_name", "ignore_failure": true }},

    { "rename": { "field": "rule", "target_field": "rule_text",
                  "ignore_missing": true, "ignore_failure": true }},
    { "dissect": { "field": "rule_text", "pattern": "%{rule_gid}:%{rule_sid}:%{rule_rev}",
                   "ignore_missing": true, "ignore_failure": true }},
    { "convert": { "field": "rule_gid", "type": "long", "ignore_missing": true, "ignore_failure": true }},
    { "convert": { "field": "rule_sid", "type": "long", "ignore_missing": true, "ignore_failure": true }},
    { "convert": { "field": "rule_rev", "type": "long", "ignore_missing": true, "ignore_failure": true }},
    { "set":     { "field": "rule_id",  "copy_from": "rule_sid", "ignore_empty_value": true, "override": true }},
    { "remove":  { "field": "rule_text", "ignore_missing": true, "ignore_failure": true }},

    { "rename":  { "field": "src_addr", "target_field": "source.ip",        "ignore_failure": true }},
    { "rename":  { "field": "dst_addr", "target_field": "destination.ip",   "ignore_failure": true }},
    { "rename":  { "field": "src_port", "target_field": "source.port",      "ignore_failure": true }},
    { "rename":  { "field": "dst_port", "target_field": "destination.port", "ignore_failure": true }}
  ],
  "on_failure": [
    { "set": { "field": "event.ingest_error", "value": "{{ _ingest.on_failure_message }}" } }
  ]
}'
