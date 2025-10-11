# Scénarios de test — attaques reproduites, scripts, et résultats attendus

Ce document décrit chaque scénario d'attaque, où trouver les scripts, comment les lancer (depuis la VM **attacker (Kali)**), ce qu'on attend côté Snort/syslog-ng/Elasticsearch/Kibana, et comment collecter les preuves.

## Pré-requis avant de lancer les scénarios

1. Être sur la VM **attacker (Kali)** pour lancer les scripts d'attaque.  
2. Vérifier que la VM **victim** a les services nécessaires (ex. Apache pour le test HTTP) :
   ```bash
   # sur victim
   sudo apt update
   sudo apt install -y apache2
   sudo systemctl enable --now apache2
   ```
3. Sur la VM monitoring :
   - Snort doit être installé et en mesure d'écouter l'interface interne (ex: enp0s3).
   - syslog-ng doit être installé et configurer pour lire /var/log/snort/alert_json.txt et poster vers ES.
   - Elasticsearch et Kibana doivent être démarrés et accessibles.
5. Rendre les scripts exécutables :
   ```bash
   sudo chmod +x scripts/test_scenarios/*.sh
   sudo chmod +x scripts/20_collect_proofs.sh
   ```
6. (Optionnel) Si tu veux tester sans provoquer d'attaque réseau, tu peux injecter une fausse alerte dans /var/log/snort/alert_json.txt :
   ```bash
   sudo bash -lc 'echo "{ \"seconds\": $(date +%s), \"msg\": \"PORTSCAN_SYN\", \"rule\": \"122:23:1\" }" >> /var/log/snort/alert_json.txt'
   ```

## Emplacement des scripts
- `scripts/test_scenarios/http_exploit.sh`
- `scripts/test_scenarios/ssh_bruteforce_syn.sh`
- `scripts/test_scenarios/portscan_syn.sh`
- `scripts/test_scenarios/dns_exfil_udp.sh`
- `scripts/test_scenarios/icmp_flood.sh`

## Vue d'ensemble des scénarios
> Chaque scénario déclenche une règle Snort définie dans configs/snort/local.rules (msg/exemple : HTTP_EXPLOIT_ATTEMPT, SSH_BRUTEFORCE_ATTEMPT, PORTSCAN_SYN, DNS_EXFIL_SUSPECT, ICMP_FLOOD_ATTEMPT).
> Après détection Snort écrit une ligne JSON dans /var/log/snort/alert_json.txt → syslog-ng lit ce fichier et POSTe chaque ligne vers ES → pipeline snort-enrich enrichit / convertit → Kibana indexe / visualise.

### 1) HTTP exploit — http_exploit.sh

But : déclencher la règle HTTP_EXPLOIT_ATTEMPT (détection d’un param exploit=1 dans l’URI).

Script :
```bash
#!/usr/bin/env bash
TARGET=${1:-192.168.1.2}
for i in {1..5}; do
  curl -s -o /dev/null "http://${TARGET}/?exploit=1"
  sleep 0.5
done
```

Exécution (sur Kali) :
```bash
./scripts/test_scenarios/http_exploit.sh 192.168.1.2
```

Pré-requis victim : Apache (voir plus haut).

Résultat attendu :
- Une ligne JSON apparaîtra dans `/var/log/snort/alert_json.txt` contenant `msg`: `"HTTP_EXPLOIT_ATTEMPT"` (ou `rule_name` après pipeline).
- Vérifier localement (monitoring) :
  ```bash
  sudo tail -n 50 /var/log/snort/alert_json.txt
  ```
- Vérifier ingestion ES :
  ```bash
  curl -s 'http://127.0.0.1:9200/snort/_search?size=5&sort=@timestamp:desc&pretty'
  ```
- Vérifier dans Kibana : index pattern `snort` → voir les nouveaux documents / Dashboards.

### 2) SSH brute-force (SYN) — ssh_bruteforce_syn.sh

But : envoyer des SYN massifs vers le port 22 pour déclencher SSH_BRUTEFORCE_ATTEMPT (règle basée sur flags SYN + detection_filter).

Script :
```bash
#!/usr/bin/env bash
# usage: sudo ./ssh_bruteforce_syn.sh 192.168.1.2 40
TARGET=${1:-192.168.1.2}
COUNT=${2:-40}
sudo hping3 -S -p 22 -c "$COUNT" --faster "$TARGET"
```

Exécution (sur Kali) :
```bash
sudo ./scripts/test_scenarios/ssh_bruteforce_syn.sh 192.168.1.2 40
```

Résultat attendu :
- Plusieurs entrées d'alerte ou une alerte agrégée SSH_BRUTEFORCE_ATTEMPT.
- Vérification via tail du fichier et via ES (même commandes que ci-dessus).

### 3) Port scan SYN — portscan_syn.sh

But : déclencher PORTSCAN_SYN (detection_filter sur SYN vers de multiples ports).

Script / commande (utilise nmap) :
```bash
sudo nmap -sS -Pn -p1-1024 --min-rate 200 192.168.1.2
```

ou script wrapper portscan_syn.sh qui lance la commande.

Exécution (sur Kali) :
```bash
sudo ./scripts/test_scenarios/portscan_syn.sh 192.168.1.2
```

Résultat attendu :
- Règle PORTSCAN_SYN déclenchée.
- Vérifications via tail, ES, et dashboard Kibana.

### 4) DNS exfil (UDP payload) — dns_exfil_udp.sh

But : simuler exfiltration via DNS/UDP contenant la chaîne exfil, déclenche DNS_EXFIL_SUSPECT.

Script :
```bash
#!/usr/bin/env bash
TARGET=${1:-192.168.1.2}
for i in {1..5}; do
  printf 'exfil' | nc -u -w1 "$TARGET" 53
  sleep 0.2
done
```

Exécution :
```bash
./scripts/test_scenarios/dns_exfil_udp.sh 192.168.1.2
```

Résultat attendu :
- Alert DNS_EXFIL_SUSPECT visible dans /var/log/snort/alert_json.txt puis ES/Kibana.

### 5) ICMP flood (echo) — icmp_flood.sh

But : générer plusieurs Echo Request pour déclencher ICMP_FLOOD_ATTEMPT.

Script :
```bash
#!/usr/bin/env bash
TARGET=${1:-192.168.1.2}
COUNT=${2:-50}
sudo hping3 -1 -c "$COUNT" -i u1000 "$TARGET"
```

Exécution :
```bash
sudo ./scripts/test_scenarios/icmp_flood.sh 192.168.1.2 50
```

Résultat attendu :
- Alert ICMP_FLOOD_ATTEMPT.
- ATTENTION : un flood peut rendre la VM victim instable — garde les counts bas en labo.

## Vérifications / commandes utiles après chaque scénario

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

Afficher une alerte type (après pipeline)
Exemple d'entrée brute (avant pipeline) :
```bash
{ "seconds": 1759726797, "msg": "PORTSCAN_SYN", "rule": "122:23:1" }
```

Après ingestion avec snort-enrich tu devrais voir un document avec champs @timestamp, rule_name, rule.gid/sid/rev, event.module: "snort".

Vérifier dans Kibana
- Ouvre Kibana → Discover → sélectionne index snort et la time field @timestamp.
- Filtre KQL par event.module:"snort" ou rule_name:"PORTSCAN_SYN" etc.
