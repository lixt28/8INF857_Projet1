# Scénarios de test — attaques reproduites, scripts, et résultats attendus

<img src="docs/images/http exploit(suricata).jpg" alt="Suricata - HTTP exploit" width="600">

Ce document décrit chaque scénario d'attaque, où trouver les scripts, comment les lancer (depuis la VM **attacker (Kali)**), ce qu'on attend côté Snort/syslog-ng/Elasticsearch/Kibana, et comment collecter les preuves. Les scripts se trouvent dans `scripts/test_scenarios/` et doivent être exécutés depuis la VM **attacker (Kali)**.`

## Pré-requis
- La VM `victim` doit disposer des services nécessaires (ex : Apache pour le test HTTP).  
- Les composants `monitoring` doivent être opérationnels : Snort en écoute, syslog-ng configuré, Elasticsearch et Kibana démarrés.  
- Les scripts doivent être rendus exécutables : `chmod +x scripts/test_scenarios/*.sh`.

## Emplacement des scripts
- `scripts/test_scenarios/http_exploit.sh`
- `scripts/test_scenarios/ssh_bruteforce_syn.sh`
- `scripts/test_scenarios/portscan_syn.sh`
- `scripts/test_scenarios/dns_exfil_udp.sh`
- `scripts/test_scenarios/icmp_flood.sh`

## Rappel du fonctionnement
> Chaque scénario déclenche une règle Snort définie dans configs/snort/local.rules (ex: HTTP_EXPLOIT_ATTEMPT).
> Une alerte JSON est écrite dans `/var/log/snort/alert_json.txt`.
> syslog-ng poste la ligne vers Elasticsearch en utilisant le pipeline `snort-enrich`.
> Les documents sont indexés dans l'index `snort` et deviennent visibles dans Kibana (Discover / Dashboards).


## Liste des scénarios
1. **HTTP exploit** — `http_exploit.sh`  
   - But : générer des requêtes HTTP avec le paramètre `?exploit=1` pour déclencher la règle `HTTP_EXPLOIT_ATTEMPT`.  
   - Exécution : `./scripts/test_scenarios/http_exploit.sh 192.168.1.2`
   - Description :Un attaquant tente d’exploiter une vulnérabilité dans une application web en envoyant des requêtes HTTP spécialement conçues, contenant le paramètre exploit=1. Ce type de comportement est typique des attaques par injection ou des tests automatisés de failles.
   - Justification : Les attaques web sont parmi les plus fréquentes dans les environnements connectés. Ce test permet de vérifier si le système de détection est capable d’identifier des requêtes HTTP anormales, souvent utilisées pour compromettre des applications web.

2. **SSH brute-force (SYN)** — `ssh_bruteforce_syn.sh`  
   - But : envoyer des segments SYN massifs vers le port 22 pour déclencher `SSH_BRUTEFORCE_ATTEMPT`.  
   - Exécution : `sudo ./scripts/test_scenarios/ssh_bruteforce_syn.sh 192.168.1.2 40`
   - Description :Un attaquant cherche à deviner les identifiants SSH en envoyant de nombreuses tentatives de connexion vers le port 22. Ce comportement génère une série de paquets SYN, typiques d’une attaque par force brute. Le système doit détecter cette activité excessive et la classer comme une tentative d’intrusion.
   - Justification : Les attaques par force brute sur SSH sont courantes pour obtenir un accès non autorisé. Ce test est essentiel pour s’assurer que le système peut détecter une activité anormale sur les ports critiques.

3. **Port scan SYN** — `portscan_syn.sh`  
   - But : scanner plusieurs ports (SYN scan) pour déclencher `PORTSCAN_SYN`.  
   - Exécution : `sudo ./scripts/test_scenarios/portscan_syn.sh 192.168.1.2`
   - Description : Un attaquant réalise une reconnaissance du réseau en scannant les ports ouverts d’une machine cible. Il utilise des paquets SYN pour identifier les services actifs. Ce type de scan est souvent le prélude à une attaque plus ciblée. Le système doit détecter cette activité comme une tentative de cartographie malveillante.
   - Justification : La détection de scans de ports est cruciale pour prévenir les intrusions. Ce scénario permet de tester la capacité du système à repérer une reconnaissance réseau préalable à une attaque.

4. **DNS exfil (UDP payload)** — `dns_exfil_udp.sh`  
   - But : envoyer de petits payloads UDP contenant `exfil` vers le port 53 pour déclencher `DNS_EXFIL_SUSPECT`.  
   - Exécution : `./scripts/test_scenarios/dns_exfil_udp.sh 192.168.1.2`
   - Description : Un attaquant tente d’exfiltrer des données sensibles en les dissimulant dans des requêtes DNS. Il envoie des paquets UDP vers le port 53 contenant des fragments de données, ici simulés par le mot-clé exfil. Cette méthode est discrète et difficile à détecter sans une surveillance fine du trafic DNS.
   - Justification : L’exfiltration via DNS est difficile à détecter car elle utilise un protocole légitime. Ce scénario permet de tester la finesse du système de détection face à des techniques furtives.

5. **ICMP flood (echo)** — `icmp_flood.sh`  
   - But : envoyer plusieurs requêtes ICMP echo pour déclencher `ICMP_FLOOD_ATTEMPT`.  
   - Exécution : `sudo ./scripts/test_scenarios/icmp_flood.sh 192.168.1.2 50`
   - Description : Un attaquant lance une attaque par déni de service (DoS) en saturant la cible avec des requêtes ICMP echo (ping). Cette surcharge peut ralentir ou paralyser le système. Le système de détection doit identifier cette anomalie comme une tentative de flood ICMP.
   - Justification : Les attaques ICMP flood peuvent paralyser un système. Ce test permet de vérifier que le système de détection peut réagir rapidement à une surcharge réseau.

## Vérifications / commandes utiles après chaque scénario ou au besoin

Vérifier le fichier d'alerte Snort (monitoring) :
```bash
sudo tail -n 100 /var/log/snort/alert_json.txt
```

Vérifier que syslog-ng a posté vers ES :
```bash
sudo syslog-ng-ctl stats | egrep 'snort|http|processed|written' || true
```
processed augmente = lu ; written augmente = envoyé.

Rechercher les derniers documents ingestionnés dans ES :
```bash
curl -s 'http://127.0.0.1:9200/snort/_search?size=10&sort=@timestamp:desc&pretty'
```

## Vérifier dans Kibana
- Ouvre Kibana → Discover → sélectionne index snort et la time field @timestamp.
- Filtre KQL par event.module:"snort" ou rule_name:"PORTSCAN_SYN" etc.
