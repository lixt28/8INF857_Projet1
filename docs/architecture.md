# Architecture du laboratoire
Ce document présente l'architecture logique du laboratoire et les interactions entre les composants.
Dans ce contexte pédagogique, toutes les machines sont sur le même réseau interne (`lab_net`) pour faciliter les tests, mais l'architecture simule le chemin réel des flux d'alerte :

## Vue d'ensemble
Attacker (Kali)  <-->  Monitoring (Snort3 + syslog-ng + Elasticsearch/Kibana)  <-->  Victim (Ubuntu, services)
- Le composant `monitoring` dispose d'une interface sur l'Internal Network `lab_net` et d'une interface NAT pour l'accès Internet.  
- Les machines `victim` et `attacker` sont connectées au même `lab_net` pour faciliter les tests de détection.
> Dans un déploiement réel, l'attaquant n'est généralement pas aussi « proche » du monitoring — ici la simplification aide la reproductibilité.

## Diagramme réseau

```mermaid
flowchart LR
  subgraph LABNET["Internal network: lab_net"]
    direction TB
    Attacker["Kali - Attacker\n192.168.1.3"]
    Victim["Victim - Server\n192.168.1.2"]
    Monitoring["Monitoring\nSnort3 + syslog-ng + ES/Kibana\n192.168.1.1"]
  end

  Attacker --- Victim
  Attacker --- Monitoring
  Victim --- Monitoring

  Monitoring --- HostNAT["Host NAT / Internet"]
  HostNAT --- Internet["Internet - apt updates"]
```

## Diagramme : flux et interactions entre outils & fichiers de configuration

```mermaid
graph TD
  Snort[Snort3 sensor]
  Alerts[Alert file]
  SyslogNg[syslog-ng]
  ES[Elasticsearch index snort]
  Pipeline[Ingest pipeline snort-enrich]
  Kibana[Kibana dashboards and alerts]
  DashboardFile[Dashboard export file]
  Rules[Snort rules file]
  SnortLua[Snort config file]

  Snort --> Alerts
  Alerts --> SyslogNg
  SyslogNg --> ES
  ES --> Kibana
  Kibana --> DashboardFile
  Snort --> Rules
  Snort --> SnortLua
  ES --> Pipeline
```

## Fichiers importants
- `Alert file` → `/var/log/snort/alert_json.txt` (JSONL produit par Snort).  
- `Snort rules file` → `/usr/local/etc/snort/rules/local.rules`.  
- `Snort config file` → `/usr/local/etc/snort/snort.lua`.  
- `ES ingest pipeline` → `snort-enrich` (fichier du dépôt : `configs/elastic/snort-enrich-pipeline.json`).  
- `Kibana dashboard export` → `kibana/dashboards/*.ndjson`.
