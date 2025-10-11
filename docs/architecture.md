# Architecture du labo
Schéma logique :
Attacker (Kali) <--> monitoring (Snort3 + syslog-ng + ES/Kibana) <--> Victim (Ubuntu, services)
- monitoring possède deux interfaces internes (lab_att, lab_vic) plus une interface de management.
- Snort3 écrit des alertes JSON dans /var/log/snort/alert_json.txt
- syslog-ng lit ce fichier (no-parse) et POSTe chaque ligne vers Elasticsearch en utilisant le pipeline `snort-enrich`.
- Kibana lit l'index `snort` et expose dashboards + règles d'alerte.

```mermaid
flowchart LR
  subgraph Internal
    direction TB
    Attacker["Kali - Attacker\n192.168.1.3"]
    Victim["Victim - Server\n192.168.1.2"]
    Monitoring["Monitoring\nSnort3 + syslog-ng + ES/Kibana\n192.168.1.1"]
  end

  Attacker ---|L2| Victim
  Attacker ---|L2| Monitoring
  Victim ---|L2| Monitoring
  Monitoring --- HostMgmt["Host/NAT - Internet"]
  HostMgmt --- Internet["Internet - apt/updates"]

