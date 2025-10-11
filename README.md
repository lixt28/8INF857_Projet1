# Projet — Système de détection d'anomalies et de gestion de logs pour la sécurité des réseaux
Groupe : Eliot Droumaguet, Estelle Armandine Tchakouani Noukam, Lîna Janaan Wendtouin SAWADOGO

## But du dépôt
Ce dépôt est un **tutoriel reproductible** pour monter un labo IDS :  
- Snort 3 (alert_json) → `/var/log/snort/alert_json.txt`  
- syslog-ng lit le JSON et envoie vers Elasticsearch (pipeline `snort-enrich`)  
- Kibana pour visualiser et créer des règles/alertes.

Les scripts fournis installent Elasticsearch, Kibana et syslog-ng. Snort 3 est compilé depuis les sources (conformément à la doc officielle).

## Structure du dépôt
Voir l'arborescence dans le README. Les fichiers de configuration sont dans `configs/`. Les scripts d'installation sont dans `scripts/`.

## Pré-requis
- Hôte : Linux (Ubuntu recommandé), VirtualBox installé.
- RAM hôte ≥ 12 GB recommandé (ELK + Snort).
- VMs : osboxes (**victim**, **monitoring**) & Kali (**attacker**).
- Accès Internet depuis la VM monitoring pour `apt` et clonages git.
- Accès Internet temporaire depuis VM victim pour `apt` apache2 (nécessaire pour les tests finaux)

## Installation
- Exécuter les commandes une par une, vérifier la sortie (ok / erreur) avant de passer à la suivante.  
- Pour Snort, remplacer <interface> par le nom réel de l’interface.  
- Si Elasticsearch demande un peu de temps à démarrer, attendre (10–30s) avant de lancer le PUT du pipeline.  

### 1. Préparer l'environnement 
Importer les VMs et configurer le réseau lab (voir [docs/howto_virtualbox.md](docs/howto_virtualbox.md))

### 2. Cloner le dépôt sur la monitoring
```bash
# créer un dossier de travail, cloner le dépôt et vérifier
sudo mkdir ids-project
cd ids-project
git clone https://github.com/lixt28/8INF857_Projet1.git
ls -la
```

### 3. Rendre les scripts exécutables et vérifier
```bash
sudo chmod +x scripts/*.sh
ls -l scripts/
```
Vérifier que les scripts ont le bit `x`.

### 4. Mettre à jour les paquets du système et installer pré-requis
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git build-essential apt-transport-https ca-certificates gnupg
```

### 5. Installer Elasticsearch
```bash
sudo bash scripts/10_install_elasticsearch.sh
# vérifier l'état du cluster (attendre quelques secondes si le service démarre)
curl -s 'http://127.0.0.1:9200/_cluster/health?pretty'
```

### 6. Installer Kibana
```bash
sudo bash scripts/02_install_kibana.sh
# vérifier le statut systemd
sudo systemctl status kibana --no-pager -l | sed -n '1,8p'
```
Kibana écoute par défaut sur http://localhost:5601 (ou http://<monitoring_ip>:5601)

### 7. Déployer le pipeline snort-enrich dans Elasticsearch
```bash
sudo bash scripts/04_put_pipeline.sh
# afficher la réponse
cat /tmp/put_pipeline_resp.json
# vérifier que la pipeline existe
curl -s 'http://127.0.0.1:9200/_ingest/pipeline/snort-enrich?pretty'
```

### 8. Installer Syslog-ng
```bash
sudo bash scripts/03_install_syslogng.sh
# vérifier le service
sudo systemctl status syslog-ng --no-pager -l | sed -n '1,8p'
# tester l'envoi d'un message "fake" pour vérifier la route syslog-ng -> ES :
sudo bash -c 'echo "{ \"seconds\": $(date +%s), \"msg\": \"TEST_PIPELINE\", \"rule\": \"0:0:0\" }" >> /var/log/snort/alert_json.txt'
# puis regarder si ES a ingéré
sleep 2
curl -s 'http://127.0.0.1:9200/snort/_search?size=3&sort=@timestamp:desc&pretty'
```

### 9. Installer snort3 (long, prévoir une dizaine de minute)
```bash
sudo bash scripts/05_install_snort3.sh
# vérifier, afficher la version
/usr/local/snort/bin/snort -V || true
```

### 10. Déployer la config et les règles snort
```bash
sudo bash scripts/06_deploy_snort_rules.sh
# vérifie les fichiers
ls -l /usr/local/etc/snort/
ls -l /usr/local/etc/snort/rules/
```

### 11. Lancer Snort en mode test (console) — commande d'exemple
Avant de lancer, identifie l’interface à utiliser (celle connectée à l'Internal Network) :
```bash
ip a
```
> Noter le nom de l'interface (ex: enp0s3 ou ens33)

Lancer Snort (remplacer <interface> par l'interface réelle) :
```bash
sudo /usr/local/snort/bin/snort -c /usr/local/etc/snort/snort.lua -i <interface> -A alert_json -l /var/log/snort -k none -s 0
```
- `-A alert_json` → écrit JSON dans /var/log/snort/alert_json.txt
- `-s 0` → capture full packet (utile pour HTTP content checks)
Laisser Snort tourner en console le temps d’effectuer un test depuis la VM attacker.

## Configuration de Kibana
1. Importing
2. Go to Stack Management > Saved Objects.
3. Click the Import button.
4. Select the .ndjson file you want to import (configs/kibana/export.ndjson).
5. Choose your import options, such as how to handle conflicts with existing objects.
6. Click Import to complete the process. 

## Tests / Scénarios
Les scénarios de test (HTTP exploit, portscan, brute SSH, DNS exfil, ICMP flood) sont décrits dans [docs/test_scenarios.md](docs/test_scenarios.md) et les scripts des attaques sont proposées `script/test_scenarios/`.

## Preuves
Met dans evidence/ : captures Kibana, sortie curl ES, extrait alert_json.txt, pcap, et screenshots. Voir docs/screenshots/ pour les placeholders.

## Limitations
Les mails d’alerte peuvent dépendre d’un compte SMTP / app password (voir configs/syslog-ng/snort-mail.conf).


   
