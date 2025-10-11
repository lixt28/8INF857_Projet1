# Scénarios de test — attaques reproduites, scripts, et résultats attendus

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

2. **SSH brute-force (SYN)** — `ssh_bruteforce_syn.sh`  
   - But : envoyer des segments SYN massifs vers le port 22 pour déclencher `SSH_BRUTEFORCE_ATTEMPT`.  
   - Exécution : `sudo ./scripts/test_scenarios/ssh_bruteforce_syn.sh 192.168.1.2 40`

3. **Port scan SYN** — `portscan_syn.sh`  
   - But : scanner plusieurs ports (SYN scan) pour déclencher `PORTSCAN_SYN`.  
   - Exécution : `sudo ./scripts/test_scenarios/portscan_syn.sh 192.168.1.2`

4. **DNS exfil (UDP payload)** — `dns_exfil_udp.sh`  
   - But : envoyer de petits payloads UDP contenant `exfil` vers le port 53 pour déclencher `DNS_EXFIL_SUSPECT`.  
   - Exécution : `./scripts/test_scenarios/dns_exfil_udp.sh 192.168.1.2`

5. **ICMP flood (echo)** — `icmp_flood.sh`  
   - But : envoyer plusieurs requêtes ICMP echo pour déclencher `ICMP_FLOOD_ATTEMPT`.  
   - Exécution : `sudo ./scripts/test_scenarios/icmp_flood.sh 192.168.1.2 50`

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
