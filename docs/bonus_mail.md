
# Notifications par e‑mail (syslog‑ng → msmtp/Postfix)

> **But** : envoyer un e‑mail pour certaines alertes Snort lues dans `/var/log/snort/alert_json.txt`, via **syslog‑ng**.  
> **Ce qui est garanti** : si les compteurs syslog‑ng montrent `written > 0` sur la destination mail, **syslog‑ng a bien remis le message au client SMTP**.  
> **Ce qui peut échouer** : la **livraison SMTP** (authentification, blocage réseau, antispam, etc.). Tu trouveras ci‑dessous les preuves à collecter et les causes probables quand ça n’arrive pas en boîte mail.

---

## 0) Vue d’ensemble (pipeline)

```
Snort (alert_json.txt) ──► syslog‑ng (filters) ──► program(mail) ──► SMTP (msmtp ou Postfix) ──► Inbox
```

- **Preuve côté syslog‑ng** : `written` ↑ sur la destination `program()` ⇒ mail **remis** au client SMTP.  
- **Preuve côté SMTP** : logs (`/var/log/msmtp.log` ou `/var/log/mail.log`) ⇒ `sent` (OK) ou `deferred/failed` (problème réseau/auth/antispam).

---

## 1) Option recommandée : **msmtp** (soumission SMTP authentifiée)

### 1.1 Installer & configurer msmtp
```bash
sudo apt-get update
sudo apt-get install -y msmtp-mta ca-certificates

# /etc/msmtprc
sudo tee /etc/msmtprc >/dev/null <<'EOF'
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account gmail
host           smtp.gmail.com
port           587
from           VOTRE_GMAIL@gmail.com
user           VOTRE_GMAIL@gmail.com
password       APP_PASSWORD_16CARSANS_ESPACES

account default : gmail
EOF

sudo chmod 600 /etc/msmtprc
sudo touch /var/log/msmtp.log && sudo chmod 666 /var/log/msmtp.log
```

> ⚠️ **Gmail** : utiliser un **mot de passe d’application** (16 caractères), pas le mot de passe normal.

### 1.2 Test d’envoi direct
```bash
echo "msmtp ok" | msmtp -C /etc/msmtprc -a default VOTRE_GMAIL@gmail.com
tail -n 50 /var/log/msmtp.log
```
- Si OK : on peut brancher syslog‑ng dessus.
- Sinon : l’erreur est explicite (auth/connexion/TLS).

### 1.3 syslog‑ng : filtres + envoi via msmtp
On **réutilise** la source `s_snort_json` (qui lit `/var/log/snort/alert_json.txt`) déjà définie dans `snort-es.conf`.

`/etc/syslog-ng/conf.d/snort-mail.conf` :
```conf
@version: 3.35

# On réutilise la source s_snort_json (déjà déclarée ailleurs)
# On parse le JSON pour cibler le champ "msg"
parser p_snort_json { json-parser(prefix("js.")); };

# Filtres : on matche le champ js.msg (insensible à la casse)
filter f_ssh  { match("SSH_BRUTEFORCE_ATTEMPT" value("js.msg") flags(ignore-case)); };
filter f_scan { match("PORTSCAN_SYN"           value("js.msg") flags(ignore-case)); };
filter f_dns  { match("DNS_EXFIL_SUSPECT"      value("js.msg") flags(ignore-case)); };
filter f_icmp { match("ICMP_FLOOD_ATTEMPT"     value("js.msg") flags(ignore-case)); };
filter f_http { match("HTTP_EXPLOIT_ATTEMPT"   value("js.msg") flags(ignore-case)); };

# Destinations : msmtp (-t lit To/From/Subject depuis l'en-tête)
destination d_mail_scan {
  program("/usr/bin/msmtp -C /etc/msmtprc -a default -t",
          template("From: IDS <VOTRE_GMAIL@gmail.com>\nTo: DESTINATAIRE@gmail.com\nSubject: IDS_SCAN\n\n$MSG\n"),
          template-escape(no));
}
# Duplique pour SSH/DNS/ICMP/HTTP en changeant Subject et To

# Route exemple (scan)
log { source(s_snort_json); parser(p_snort_json); filter(f_scan); destination(d_mail_scan); flags(flow-control); }

# (debug temporaire)
destination d_mail_debug { file("/tmp/snort-mail-debug.log" template("$MSG\n") template-escape(no)); }
log { source(s_snort_json); parser(p_snort_json); filter(f_scan); destination(d_mail_debug); flags(flow-control); }
```

Redémarrer et valider :
```bash
sudo syslog-ng -s -f /etc/syslog-ng/syslog-ng.conf   # vérification syntaxe (silencieux si OK)
sudo systemctl restart syslog-ng
sudo systemctl status syslog-ng --no-pager
```

### 1.4 Preuves — **written** + logs SMTP
1) **Injection d’une fausse alerte** (sans générer de trafic réel) :
```bash
sudo bash -lc 'echo "{ \"seconds\": $(date +%s), \"msg\": \"PORTSCAN_SYN\" }" >> /var/log/snort/alert_json.txt'
```

2) **Compteurs syslog‑ng** (preuve que syslog‑ng a appelé msmtp) :
```bash
sudo syslog-ng-ctl stats | egrep 'd_mail_|processed|written'
# attendu (exemple) :
# dst.program;d_mail_scan#0;/usr/bin/msmtp ...;a;written;1
```

3) **Logs msmtp** (preuve de remise SMTP) :
```bash
tail -n 100 /var/log/msmtp.log
# "sent" attendu ; sinon message d'erreur explicite
```

---

## 2) Option alternative : **Postfix** en relais 587 (Gmail)

### 2.1 Configuration Postfix (IPv4 + relay + SASL)
```bash
sudo apt-get install -y postfix libsasl2-modules ca-certificates

sudo postconf -e 'inet_protocols = ipv4'
sudo postconf -e 'relayhost = [smtp.gmail.com]:587'
sudo postconf -e 'smtp_sasl_auth_enable = yes'
sudo postconf -e 'smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd'
sudo postconf -e 'smtp_sasl_security_options = noanonymous'
sudo postconf -e 'smtp_use_tls = yes'
sudo postconf -e 'smtp_tls_security_level = encrypt'
sudo postconf -e 'smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt'

# Écrire l'identifiant/mot de passe d'application (sans expansion shell)
sudo bash -lc 'cat > /etc/postfix/sasl_passwd <<EOF
[smtp.gmail.com]:587 VOTRE_GMAIL@gmail.com:APP_PASSWORD_16CARSANS_ESPACES
EOF'
sudo postmap /etc/postfix/sasl_passwd
sudo chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db

# (Optionnel mais utile) réécrire l'expéditeur pour coller à Gmail
echo "osboxes@osboxes VOTRE_GMAIL@gmail.com" | sudo tee /etc/postfix/generic
sudo postmap /etc/postfix/generic
sudo postconf -e 'smtp_generic_maps = hash:/etc/postfix/generic'

sudo systemctl restart postfix
```

### 2.2 Test d’envoi
```bash
echo "postfix relay ok" | /usr/bin/mail -s IDS_TEST VOTRE_GMAIL@gmail.com
sudo tail -n 100 /var/log/mail.log | egrep -i 'status=|smtp.gmail|deferred|sent'
postqueue -p
```

### 2.3 syslog‑ng avec `/usr/bin/mail`
Dans `snort-mail.conf`, une destination minimale (quoting simple) :
```conf
destination d_mail_scan {
  program("/usr/bin/mail -s IDS_SCAN DESTINATAIRE@gmail.com"
          template("$MSG\n") template-escape(no));
}
```
*(rester sur msmtp est souvent plus simple et plus fiable en labo)*

---

## 3) Pourquoi ça peut ne **pas** arriver en boîte mail

- **Port 25 sortant bloqué** (si Postfix tente en 25 vers MX) → utiliser **587 + auth** (msmtp ou Postfix relay).  
- **Mauvais secret** : pas de **mot de passe d’application** (Gmail) ⇒ `535 5.7.8 BadCredentials`.  
- **IPv6 non routé** : `Network is unreachable` sur `smtp.gmail.com[IPv6]` ⇒ forcer `inet_protocols = ipv4`.  
- **From/DMARC/SPF** : expéditeur différent du compte utilisé ⇒ rejet/Spam. Utiliser `From:` = même adresse que le compte SMTP (ou `smtp_generic_maps` côté Postfix).  
- **Antispam/ratelimit** : rafale de messages ⇒ Spam/Promotions/limitation temporaire.  
- **Filtre syslog‑ng ne matche pas** : ex. `message("PORTSCAN_SYN")` vs champ JSON `msg` différent. D’où le **json-parser + match(value("js.msg"))**.  
- **Source dupliquée** sur le même fichier `file()` sans `persist-name` distinct ⇒ syslog‑ng ne démarre pas.  
- **Chemin lu** pas le bon (`alert_json.txt` vs `alert.json`), ou absence de droits de lecture.

---

## 4) Dépannage express (check‑list)

1. **syslog‑ng OK ?**
```bash
sudo syslog-ng -s -f /etc/syslog-ng/syslog-ng.conf
sudo systemctl restart syslog-ng && sudo systemctl status syslog-ng --no-pager
```
2. **Injection test** (force un envoi sans attaque) :
```bash
sudo bash -lc 'echo "{ \"seconds\": $(date +%s), \"msg\": \"PORTSCAN_SYN\" }" >> /var/log/snort/alert_json.txt'
```
3. **Compteurs** :
```bash
sudo syslog-ng-ctl stats | egrep 'd_mail_|processed|written'
```
4. **Logs SMTP** :
```bash
# msmtp
tail -n 100 /var/log/msmtp.log

# Postfix
sudo tail -n 100 /var/log/mail.log
postqueue -p
```
5. **Boîte mail** : vérifier **Spam/Promotions**.

---

## 5) Exemples de “preuves” à capturer (screenshots)

- `sudo syslog-ng-ctl stats | egrep 'd_mail_|written'` montrant `written;N` > 0 sur `d_mail_*`.  
- `tail -n 100 /var/log/msmtp.log` affichant `sent` (ou le code d’erreur, à commenter).  
- (Option Postfix) `/var/log/mail.log` avec `status=sent` ou message explicite.

---

## 6) Annexes – Configs complètes

### 6.1 `/etc/msmtprc`
```ini
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account gmail
host           smtp.gmail.com
port           587
from           VOTRE_GMAIL@gmail.com
user           VOTRE_GMAIL@gmail.com
password       APP_PASSWORD_16CARSANS_ESPACES

account default : gmail
```
> Droits : `chmod 600 /etc/msmtprc`

### 6.2 `/etc/syslog-ng/conf.d/snort-mail.conf` (extrait msmtp)
```conf
@version: 3.35
parser p_snort_json { json-parser(prefix("js.")); }
filter f_scan { match("PORTSCAN_SYN" value("js.msg") flags(ignore-case)); }
destination d_mail_scan {
  program("/usr/bin/msmtp -C /etc/msmtprc -a default -t",
          template("From: IDS <VOTRE_GMAIL@gmail.com>\nTo: DESTINATAIRE@gmail.com\nSubject: IDS_SCAN\n\n$MSG\n"),
          template-escape(no));
}
log { source(s_snort_json); parser(p_snort_json); filter(f_scan); destination(d_mail_scan); flags(flow-control); }
```

---

### TL;DR

1) **msmtp** + **mot de passe d’application** = envoi fiable en 587.  
2) **Preuve** syslog‑ng : `written > 0` sur `d_mail_*`.  
3) **Preuve** SMTP : `sent` dans `/var/log/msmtp.log` (ou `mail.log` si Postfix).  
4) Si pas de mail : c’est (presque toujours) côté **SMTP/antispam** (voir §3 causes probables).
