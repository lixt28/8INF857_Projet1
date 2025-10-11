# Scénarios de test — attaques reproduites, scripts, et résultats attendus

Ce document décrit chaque scénario d'attaque, où trouver les scripts, comment les lancer (depuis la VM **attacker (Kali)**), ce qu'on attend côté Snort/syslog-ng/Elasticsearch/Kibana, et comment collecter les preuves.

---

## Pré-requis avant de lancer les scénarios

1. Être sur la VM **attacker (Kali)** pour lancer les scripts d'attaque.  
2. Vérifier que la VM **victim** a les services nécessaires (ex. Apache pour le test HTTP) :
   ```bash
   # sur victim
   sudo apt update
   sudo apt install -y apache2
   sudo systemctl enable --now apache2
