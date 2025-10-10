# Projet — Système de détection d'anomalies & gestion de logs (Snort 3 + ELK + syslog-ng)

Eliot Droumaguet, Estelle Armandine Tchakouani Noukam, Lîna Janaan Wendtouin SAWADOGO

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
- VMs : osboxes (**victim**, **monitoring**) & Kali (**attacker**).
- Accès Internet depuis la VM monitoring pour `apt` et clonages git.
- Accès Internet temporaire depuis VM victim pour `apt` apache2 (nécessaire pour les tests finaux)

## Installation
- Exécuter les commandes une par une, vérifie la sortie (ok / erreur) avant de passer à la suivante.  
- Pour Snort, remplacer <interface> par le nom réel de l’interface.  
- Si Elasticsearch demande un peu de temps à démarrer, attendre (10–30s) avant de lancer le PUT du pipeline.  

1. Importer VMs (voir `docs/howto_virtualbox.md`) et config réseau.  
2. Sur la VM **monitoring**, exécuter dans l’ordre :
   ```bash
   # créer un dossier de travail, cloner le dépôt et vérifier
   sudo mkdir ids-project
   cd ids-project
   git clone https://github.com/lixt28/8INF857_Projet1.git
   ls -la

   # rendre les scripts exécutables et vérifier
   sudo chmod +x scripts/*.sh
   ls -l scripts/ # le bit 'x' doit apparaître

   # mettre à jour les paquets du système et installer pré-requis
   sudo apt update && sudo apt upgrade -y
   sudo apt install -y curl wget git build-essential apt-transport-https ca-certificates gnupg

   # installer elasticsearch
   sudo bash scripts/10_install_elasticsearch.sh
   # vérifier l'état du cluster (attendre quelques secondes si le service démarre)
   curl -s 'http://127.0.0.1:9200/_cluster/health?pretty'

   # installer kibana
   sudo bash scripts/02_install_kibana.sh
   # vérifier le statut systemd
   sudo systemctl status kibana --no-pager -l | sed -n '1,8p'
   # Kibana écoute par défaut sur http://localhost:5601 (ou http://<monitoring_ip>:5601)

   # déployer le pipeline snort-enrich dans elasticsearch
   sudo bash scripts/04_put_pipeline.sh
   # afficher la réponse
   cat /tmp/put_pipeline_resp.json
   # vérifier que la pipeline existe
   curl -s 'http://127.0.0.1:9200/_ingest/pipeline/snort-enrich?pretty'

   sudo bash scripts/03_install_syslogng.sh
   # vérifier le service
   sudo systemctl status syslog-ng --no-pager -l | sed -n '1,8p'
   # tester l'envoi d'un message "fake" pour vérifier la route syslog-ng -> ES :
   sudo bash -c 'echo "{ \"seconds\": $(date +%s), \"msg\": \"TEST_PIPELINE\", \"rule\": \"0:0:0\" }" >> /var/log/snort/alert_json.txt'
   # puis regarder si ES a ingéré
   sleep 2
   curl -s 'http://127.0.0.1:9200/snort/_search?size=3&sort=@timestamp:desc&pretty'

   #installer snort3 (long, prévoir une dizaine de minute)
   sudo bash scripts/05_install_snort3.sh
   # vérifier, afficher la version
   /usr/local/snort/bin/snort -V || true

   # déployer la config et les règles snort
   sudo bash scripts/06_deploy_snort_rules.sh
   # vérifie les fichiers
   ls -l /usr/local/etc/snort/
   ls -l /usr/local/etc/snort/rules/
   
   Lancer Snort en mode test (console) — commande d'exemple

Avant de lancer, identifie l’interface à utiliser (celle connectée à l'Internal Network) :

ip a
# note le nom de l'interface (ex: enp0s3 ou ens33)


Lancer Snort (remplace <interface> par ton interface réelle) :

sudo /usr/local/snort/bin/snort -c /usr/local/etc/snort/snort.lua -i <interface> -A alert_json -l /var/log/snort -k none -s 0


-A alert_json → écrit JSON dans /var/log/snort/alert_json.txt

-s 0 → capture full packet (utile pour HTTP content checks)

Laisse Snort tourner en console le temps d’effectuer un test depuis la VM attacker.
   sudo bash scripts/07_collect_proofs.sh
   ```


## Tests / Scénarios
Les scénarios de test (HTTP exploit, portscan, brute SSH, DNS exfil, ICMP flood) sont décrits dans docs/architecture.md et les commandes proposées dans la section « Scénarios ».

## Preuves
Met dans evidence/ : captures Kibana, sortie curl ES, extrait alert_json.txt, pcap, et screenshots. Voir docs/screenshots/ pour les placeholders.

## Limitations
Les mails d’alerte peuvent dépendre d’un compte SMTP / app password (voir configs/syslog-ng/snort-mail.conf).


   
