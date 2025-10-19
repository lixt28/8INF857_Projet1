# Kibana – Data Views, Dashboards & Alerts (Snort → Elasticsearch)

Ce guide résume la configuration **Kibana** réalisée pour visualiser les événements **Snort** indexés dans **Elasticsearch**, créer des **tableaux de bord**, et générer des **alertes** (règles) qui écrivent dans un index d’alertes dédié. Pour directement importer, aller à la section **5) Export & Import (Save Objects, `*.ndjson`)**.

---

## 0) Pré-requis (côté données)

- Les événements Snort arrivent dans l’index **`snort`** avec un pipeline d’ingestion (ex. `snort-enrich`) qui :
  - Convertit `seconds` → **`@timestamp`**
  - Renomme `msg` → **`rule_name`**
  - Décompose `rule` → **`rule.gid/sid/rev`**
  - Ajoute `event.module: "snort"`
- Les champs utiles visibles dans Discover : `@timestamp`, `rule_name`, `proto`, `src_addr`, `dst_addr`, etc.

> **Test rapide** (facultatif) :  
> ```bash
> curl -s 'http://192.168.1.1:9200/snort/_search?size=1&sort=@timestamp:desc&pretty'
> ```

---

## 1) connexion a Elasticsearch-Kibana
   a) Connexion à Kibana
   - Dans la barre de recherche du navigateur de notre kali, entrer http://192.168.1.1:5601
   - Entrer dans la barre au milieu de l'écran https://192.168.1.1:9200
   - Cliquer sur "se connecter manuellement" puis entrer le nom d'utilisateur Kibana_System puis le mot de passe (MotDePasse dans notre cas)
   - Aller dans le PC monitoring et entrer la commande sudo /usr/share/kibana/bin/kibana-verification-code pour obtenir le code de verification demandé par kibana et le rentrer dans le PC Attaker (kali).
     
NB: la connexion à Kibana peut également se faire automatiquement grâce à un token pouvant être généré.
Pour se faire, aller dans le pc monitoring et entrer la commande sudo /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana, copier le token généré et le coller dans la page d'acceuil de kibana dans kali

   b) Connexion à élastic
   
Après s'être connecté à Kibana, la page de connexion a Élastic s'ouvrira. Entrer le nom d'utilisateur: "Elastic" dans notre cas et le mot de passe "MotDePasse".


## 2) Data views (index patterns)

### 2.1 Créer la data view **snort**
1. *Kibana* → **Stack Management** → **Data views** → **Create data view**  
2. **Name** : `snort`  
   **Index pattern** : `snort`  
   **Time field** : **`@timestamp`**  
3. **Save data view**.

### 2.2 Créer la data view **alerts-snort** (pour les alertes Kibana)
1. *Kibana* → **Stack Management** → **Data views** → **Create data view**
2. **Name** : `alerts-snort`  
   **Index pattern** : `alerts-snort`  
   **Time field** : **`@timestamp`**
3. **Save data view**.

> **Sanity check** : *Discover* → sélectionner la data view `snort` → *Time range* « Last 15 minutes » → KQL `event.module:"snort"` ⇒ des lignes doivent apparaître.

---

## 3) Dashboard (Lens)

Créer un tableau de bord **“Snort – Overview”** et y ajouter des visualisations **Lens**.

1. *Kibana* → **Dashboard** → **Create dashboard** → **Create visualization** → **Lens**, data view **`snort`**.
2. **Panneaux recommandés :**
   - **Alerts over time**  
     - *Metric* : **Count**  
     - *X-axis* : **Date histogram** sur **`@timestamp`**  
     - (Option) Filtre KQL : `event.module:"snort"`
   - **Top rules (rule_name)**  
     - *Break down by* : **Top values of `rule_name`** (Tops 10)
   - **Top source IPs** : Top values de **`src_addr`**
   - **Top destination IPs** : Top values de **`dst_addr`**
   - **Protocol breakdown** : Top values de **`proto`**
3. **Save** chaque visualisation puis **Save** le dashboard.

> **Astuce** : tu peux dupliquer ces panneaux pour la data view **`alerts-snort`** si tu veux analyser les **alertes générées par Kibana** (index `alerts-snort`) séparément des événements bruts (index `snort`).

---

## 4) Règles (Alerts) – écrire dans `alerts-snort`

### 4.1 Créer un connecteur **Index**
1. *Kibana* → **Stack Management** → **Connectors** → **Create connector** → **Index**  
2. **Connector name** : `Index: alerts-snort`  
   **Index** : `alerts-snort`  
3. **Save**.

### 4.2 Créer une règle **Elasticsearch query** (ex. Port scan SYN)
1. *Kibana* → **Stack Management** → **Rules** → **Create rule**  
2. **Rule type** : **Elasticsearch query**  
3. **Name** : `Snort – Portscan SYN (1m)`  
4. **Data view** : `snort`  
   **Time field** : **`@timestamp`**  
5. **Schedule** : **Every 1 minute** ; **Time window** : **1 minute**
6. **Query (KQL)** :
   ```kql
   event.module:"snort" and rule_name:"PORTSCAN_SYN"
   ```
7. **Actions** : ajouter **Index: alerts-snort**  
   - **Action frequency** : **Summary of alerts**  
   - **On check intervals** ✅  
   - **Run when** : **Query matched** ✅  
   - **Message** (**JSON valide**) :
     ```json
     {
       "@timestamp": "{{date}}",
       "alert.type": "PORTSCAN_SYN",
       "rule.name": "PORTSCAN_SYN",
       "message": "Rule matched at {{date}}",
       "kql": "event.module:\"snort\" and rule_name:\"PORTSCAN_SYN\"",
       "source": "kibana-rule"
     }
     ```
8. **Save** la règle.

> Répéter pour d’autres règles en changeant **`rule_name`** et **`alert.type`** :  
> `SSH_BRUTEFORCE_ATTEMPT`, `DNS_EXFIL_SUSPECT`, `ICMP_FLOOD_ATTEMPT`, `HTTP_EXPLOIT_ATTEMPT`.

#### Variante : **Log threshold**
- Même data view et champs.  
- Condition : `WHEN count() IS ABOVE 0 FOR THE LAST 1 minute`  
- Action : **Index: alerts-snort** + **Summary of alerts / On check intervals / Query matched**  
- Message JSON similaire (tu peux ajouter des champs fixes).

### 4.3 Vérifier l’exécution des règles
- Dans la page de la règle → **History / Execution log** :  
  - **Search count** : nombre de documents qui matchent la requête dans la fenêtre.  
  - **Actions executed** : doit être **≥ 1** quand ça matche.
- Contrôler l’index :
  ```bash
  curl -s 'http://127.0.0.1:9200/_cat/indices/alerts-snort?v'
  curl -s 'http://127.0.0.1:9200/alerts-snort/_search?size=3&sort=@timestamp:desc&pretty'
  ```

---

## 5) Bonnes pratiques & dépannage rapide

- **Fenêtre de temps** : pour tester, mets **1 minute** (schedule) / **1 minute** (time window).  
- **Action frequency** : *Summary of alerts* + *On check intervals* + *Run when: Query matched* → 1 doc par exécution si la requête matche.  
- **Tester le KQL dans Discover** avec la **même période** que la règle.  
- **Data view** : assure-toi que **`@timestamp`** est bien le *Time field*.  
- **Index connector** : le **Message** doit être **un JSON valide** (objet) ; évite les chaînes seules.

---

## 6) Export & Import (Save Objects, `*.ndjson`)

### 6.1 Exporter
1. *Kibana* → **Stack Management** → **Saved Objects** → **Export**  
2. **Sélectionne** :  
   - **Data views** : `snort`, `alerts-snort`  
   - **Dashboards** : `Sécurité Informatique - Projet 1 (Eliot, Estelle, Lina)`  
   - **Visualizations** liées  
3. Coche **“Include related objects”**, puis **Export** → télécharger le fichier `kibana-saved-objects.ndjson`.

> **Export des règles** : *Stack Management* → **Rules and Connectors** → sélectionner tes règles → **Export** (génère aussi un `*.ndjson`).  
> Les **connecteurs** (ex. Index) s’exportent, mais **les secrets** (pour e-mail, etc.) ne sont **pas** inclus et doivent être reconfigurés après import.

### 6.2 Importer
> Avant l'importation, il faut copier les clefs d'encryption dans la config `/etc/kibana/kibana.yml`, elle peuvent être générer avec `sudo /usr/share/kibana/bin/kibana-encryption-keys generate` (copier les résultats `xpack..` directement dans kibana.yml)

1. *Kibana* → **Stack Management** → **Saved Objects** → **Import**  
2. Glisser-déposer le `kibana-saved-objects.ndjson` → cocher **“Automatically overwrite conflicts”** → **Import**.  
3. Pour les **règles**, aller dans **Rules and Connectors** → **Import** le fichier `*.ndjson` des règles.  
4. Vérifier que les **data views** et le **dashboard** sont présents ; ouvrir **Rules** et confirmer que l’**Index connector** pointe bien vers `alerts-snort`.

---

## 7) Résumé express

- **Data views** : `snort` & `alerts-snort`, Time field = `@timestamp`  
- **Dashboard Lens** : timeline, top rules, top IP src/dst, protocol breakdown  
- **Règles (Elasticsearch query)** : KQL par `rule_name`, **Summary of alerts / On check intervals / Query matched**, **Index connector** vers `alerts-snort` avec **Message JSON**  
- **Export/Import** : *Saved Objects* pour data views/dashboards/visualizations, **Rules and Connectors** pour les règles

