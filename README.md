# Projet — Système de détection d'anomalies et de gestion de logs pour la sécurité des réseaux (Réalisé sur ubuntu 22.04 et kali Linux)
Groupe : Eliot Droumaguet, Estelle Armandine Tchakouani Noukam, Lîna Janaan Wendtouin Sawadogo


## Objectif
Ce dépôt fournit un guide reproductible pour la mise en place d'un laboratoire IDS + SIEM à des fins pédagogiques. 
L'architecture proposée comprend : Snort 3 (production d'alertes JSON), syslog-ng (lecture et transfert vers Elasticsearch), 
et Kibana pour la visualisation et la création de règles/alertes.

## Contenu principal
-`scripts/` : scripts d'installation et d'aide au déploiement (Elasticsearch, Kibana, syslog-ng, Snort, déploiement du pipeline).
- `configs/` : fichiers de configuration pour Snort, syslog-ng et le pipeline Elasticsearch.
- `scripts/test_scenarios/` : scripts de simulation d'attaques (à lancer depuis la VM attacker/Kali).
- `kibana/dashboards/` : exports de dashboards Kibana (NDJSON) prêts à importer.
- `docs/` : documentation technique et guides d'utilisation.

## Pré-requis
- Hôte : Linux (Ubuntu recommandé) version 22.04 dans le cas d'espèce, VirtualBox installé.
- RAM hôte ≥ 12 GB recommandé (ELK + Snort).
- VMs : osboxes (**victim**, **monitoring**) & Kali (**attacker**).
- Accès Internet depuis la VM monitoring pour `apt` et clonages git.
- Accès Internet temporaire depuis VM victim pour `apt` apache2 (nécessaire pour les tests finaux)

## Préparer l'environnement 
Importer les OVA, configurer le réseau `lab_net` et activer Guest Additions (suivre `docs/howto_virtualbox.md`).

## Installation (sur la VM *monitoring*)
> Exécuter les commandes une par une, vérifier la sortie (ok / erreur) avant de passer à la suivante.
> Pour Snort, remplacer <interface> par le nom réel de l’interface.
> Si Elasticsearch demande un peu de temps à démarrer, attendre (10–30s) avant de lancer le PUT du pipeline.

1. **Cloner le dépôt sur la monitoring :**
   ```bash
   sudo apt install git # si pas déjà installé
   git clone https://github.com/lixt28/8INF857_Projet1.git
   cd 8INF857_Projet1
   ```
2. **Rendre les scripts exécutables et vérifier :**
   ```bash
   sudo chmod +x scripts/*.sh
   sudo chmod +x scripts/test_scenarios/*.sh
   ls -l scripts/
   ```
   Vérifier que les scripts ont le bit `x`.
3. **Mettre à jour les paquets du système et installer pré-requis :**
   ```bash
   sudo apt update && sudo apt upgrade -y
   sudo apt install -y curl wget git build-essential apt-transport-https ca-certificates gnupg jq
   ```
4. **Installer Elasticsearch :**
   ```bash
   sudo bash scripts/01_install_elasticsearch.sh
   # vérifier l'état du cluster (attendre quelques secondes si le service démarre)
   curl -s 'http://127.0.0.1:9200/_cluster/health?pretty'
   ```
5. **Installer Kibana :**
   ```bash
   sudo bash scripts/02_install_kibana.sh
   # vérifier le statut systemd
   sudo systemctl status kibana --no-pager -l | sed -n '1,8p'
   ```
   Kibana écoute par défaut sur http://localhost:5601 (ou http://<monitoring_ip>:5601)
   
7. **Installer Syslog-ng :**
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
8. **Déployer le pipeline snort-enrich dans Elasticsearch :**
   ```bash
   sudo bash scripts/04_put_pipeline.sh
   # afficher la réponse
   cat /tmp/put_pipeline_resp.json
   # vérifier que la pipeline existe
   curl -s 'http://127.0.0.1:9200/_ingest/pipeline/snort-enrich?pretty'
   ```
9. **Installer snort3 (long, prévoir une dizaine de minute) :**
    ```bash
    sudo bash scripts/05_install_snort3.sh
    # vérifier, afficher la version
    /usr/local/snort/bin/snort -V || true
    ```
10. **Déployer la config et les règles snort :**
    ```bash
    sudo bash scripts/06_deploy_snort_rules.sh
    # vérifie les fichiers
    ls -l /usr/local/etc/snort/
    ls -l /usr/local/etc/snort/rules/
    ```
- Lire les logs systemd si un service échoue (`journalctl -u <service>`).
- Vérifier que Elasticsearch répond avant de lancer `04_put_pipeline.sh` (le script attend ES).
10. **Lancer Snort en mode test (console)** — commande d'exemple
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

## Configuration de Kibana (Data Views, Rules, Alerts, Dashboard)
Suivre `docs/kibana_guide.md`, aller directement à la section 5) pour importer.

## Tests & preuves
Les scénarios de test sont fournis dans `scripts/test_scenarios/`. Après l'exécution d'un scénario, 
Snort écrit une alerte au format JSONL dans `/var/log/snort/alert_json.txt`. syslog-ng lit ce fichier et poste chaque ligne
vers Elasticsearch en utilisant le pipeline `snort-enrich`. Kibana indexe les données pour visualisation et création de règles d'alerte.

## Bonus: Emails d'alertes
Suivre `docs/bonus_mail.md`.
Ne pas committer d’identifiants : utiliser configs/msmtp/etc_msmtprc.example comme modèle et remplir /etc/msmtprc localement.  

## Source : 
- https://www.zenarmor.com/docs/linux-tutorials/how-to-install-and-configure-snort-on-ubuntu-linux#:~:text=a%20system%20service.-,Update%20the%20Ubuntu%20Server,and%20installed%20from%20the%20source.
- https://docs.snort.org/start/installation
- https://www.digitalocean.com/community/tutorials/how-to-install-elasticsearch-logstash-and-kibana-elastic-stack-on-ubuntu-22-04
- https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-elasticsearch-on-ubuntu-22-04
