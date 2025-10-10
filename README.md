# Projet — Système de détection d'anomalies & gestion de logs (Snort 3 + ELK + syslog-ng)

Eliot Droumaguet, Estelle, Lîna

## But du dépôt
Ce dépôt est un **tutoriel reproductible** pour monter un labo IDS + SIEM :  
- Snort 3 (alert_json) → `/var/log/snort/alert_json.txt`  
- syslog-ng lit le JSON et envoie vers Elasticsearch (pipeline `snort-enrich`)  
- Kibana pour visualiser et créer des règles/alertes.

Les scripts fournis installent Elasticsearch, Kibana et syslog-ng. Snort 3 est compilé depuis les sources (conformément à la doc officielle).

## Structure du dépôt
Voir l'arborescence dans le README (ou `tree` au besoin). Les fichiers de configuration sont dans `configs/`. Les scripts d'installation sont dans `scripts/`.

## Pré-requis
- Hôte : Linux (Ubuntu recommandé), VirtualBox installé.
- RAM hôte ≥ 12 GB recommandé (ELK + Snort).
- VMs : osboxes (victim, monitoring) & Kali (attacker).
- Accès Internet depuis la VM monitoring pour `apt` et clonages git.
- Accès Internet temporaire depuis VM victim pour `apt` apache2 (nécessaire pour les tests finaux)

## Installation (résumé)
1. Importer VMs (voir `docs/howto_virtualbox.md`) et config réseau.  
2. Sur la VM **monitoring**, exécuter dans l’ordre :
   ```bash
   sudo bash scripts/01_install_elasticsearch.sh
   sudo bash scripts/02_install_kibana.sh
   sudo bash scripts/03_install_syslogng.sh
   sudo bash scripts/04_install_snort3.sh
   sudo bash scripts/05_deploy_snort_rules.sh
3. Vérifier la génération d’alertes : sudo tail -f /var/log/snort/alert_json.txt
4. Vérifier ingestion ES : curl 'http://localhost:9200/snort/_search?size=3&pretty'

## Tests / Scénarios
Les scénarios de test (HTTP exploit, portscan, brute SSH, DNS exfil, ICMP flood) sont décrits dans docs/architecture.md et les commandes proposées dans la section « Scénarios ».

## Preuves
Met dans evidence/ : captures Kibana, sortie curl ES, extrait alert_json.txt, pcap, et screenshots. Voir docs/screenshots/ pour les placeholders.

## Limitations
Les mails d’alerte peuvent dépendre d’un compte SMTP / app password (voir configs/syslog-ng/snort-mail.conf).


   
