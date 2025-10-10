# Récupérer et configurer les VMs (VirtualBox)

## 1. Installer VirtualBox
Télécharger et installer VirtualBox depuis le site officiel :  
https://www.virtualbox.org/wiki/Downloads

---

## 2. Où récupérer des VMs (osboxes / Kali)
- **OSBoxes** (Ubuntu, autres distros préconfigurées) — pratique pour `monitoring` et `victim` :  
  https://www.osboxes.org/virtualbox-images/   
  *Mot de passe par défaut souvent indiqué sur la page de l’OVA (ex. "osboxes.org").*
  
> **Important** : Récupérer version `OVA`

- **Kali Linux (VM)** — distribution pour tests d’intrusion, idéal pour `attacker` :  
  https://www.kali.org/get-kali/#kali-virtual-machines

> **Important** : Prendre version `VirtualBox`

---

## 3. Importer les VM dans VirtualBox
1. VirtualBox → **Fichier → Importer un appareil virtuel…** → sélectionner l’OVA → **Suivant**.  
2. Après import, *astuce pratique* : cloner la VM (clic droit → **Cloner…**) → choisir **Clone complet** et **Réinitialiser les adresses MAC** pour éviter les conflits réseau.  
3. Renommer les VMs logiquement (ex. `victim-ubuntu`, `attacker-kali`, `monitoring-ubuntu`).

**Conseil** : prendre un snapshot après l’import et avant toute grosse modification (`Machine → Snapshots (Instantanés) → Prendre un instantané`).

---

## 4. Paramètres recommandés (ressources)
Ajuster selon les ressources de l'hôte :

- **Monitoring (ELK + Kibana + syslog-ng + Snort)**  
  - CPU : 4 vCPU  
  - RAM : 8–12 GB (10 GB recommandé si possible)  
  - Disk : 40–80 GB

- **Victim (serveur web)**  
  - CPU : 2 vCPU  
  - RAM : 2–4 GB  
  - Disk : 20 GB

- **Attacker (Kali)**  
  - CPU : 2 vCPU  
  - RAM : 4 GB  
  - Disk : 20 GB

---

## 5. Réseau VirtualBox recommandé (topologie fiable)
Objectif : que la **monitoring** voie le trafic entre `attacker` et `victim`.

### Topologie simple (recommandée)
- Créer un **Internal Network** (ex. `labnet`).
- **monitoring** :
  - Adapter 1 → *Internal Network* `labnet`  (interface interne pour sniffing / monitoring)  
  - Adapter 2 → *NAT* pour accès Internet / `apt`  
  - **Activer Promiscuous Mode = Allow All** :
    - GUI : VirtualBox → Paramètres VM → Réseau → Avancé → *Promiscuous Mode*: **Allow All**
    - Dans la VM :  
      ```bash
      # remplacer <interface> par le nom de l'interface pour labnet (voir **6. Nom d'interface et vérifications**)
      sudo ip link set dev <interface> promisc on
      ```
- **victim** :
  - Adapter 1 → *Internal Network* `lab_net`  
  - Adapter 2 → *NAT* (pour apt / Internet si nécessaire)
- **attacker** (Kali) :
  - Adapter 1 → *Internal Network* `lab_net`

> **Remarque** : Normalement cette configuration dervait suffir à ce que **monitoring** puisse lire le trafic. Toute fois, une précaution supplémentaire consiste à ce que **victim** et **attacker** aient **monitoring** en passerelle par défaut. Détails dans **8. Exemples : config IP statique (persistant)**

---

## 6. Nom d'interface et vérifications
Les noms d’interface peuvent varier (`eth0`, `enp0s3`, `ens33`, ...). Toujours vérifier avec :
```bash
ip a
```
> **Pour Monitoring** : Repèrer l’interface correspondant à l’Internal Network (ex. celle qui a l’IP 192.168.1.x). C’est sur celle-ci que tu activeras le promisc et où Snort écoutera.

---

## 7. IPs & exemples (valeurs utilisées pour les tests)
Exemple cohérent :
- **Monitoring** (interface interne) : `192.168.1.1/24`
- **Victim** (serveur web) : `192.168.1.2/24`
- **Attacker** (Kali) : `192.168.1.3/24`
> **A savoir** : L’interface NAT obtient une IP par VirtualBox ; les IP ci-dessus concernent l’Internal Network.

---

## 8. Exemples : config IP statique (persistant)
### Ubuntu (victim) — netplan
Fichier `/etc/netplan/01-lab.yaml` :
```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      addresses: [192.168.1.2/24]
      gateway4: 192.168.1.1
```
Appliquer :
```bash
sudo netplan apply
```

### Kali (attacker) — nmcli (NetworkManager)
```bash
# adapter ifname=eth0 si différent
nmcli con add type ethernet ifname eth0 con-name lab_att \
  ipv4.addresses 192.168.1.3/24 ipv4.gateway 192.168.1.1 \
  ipv4.method manual
nmcli con up lab_att
```

### Méthode temporaire (tous OS)
```bash
sudo ip addr add 192.168.1.3/24 dev <iface>
sudo ip link set dev <iface> up
sudo ip route add default via 192.168.1.1
```
(Cela n’est pas persistant au reboot.)

---

## 9. Activer la capture / test promisc & sniff

Pour vérifier que la monitoring voit le trafic :
1. Sur la monitoring VM, trouve l’interface :
```bash
ip a
```
2. Activer le mode promisc (si pas déjà fait via GUI) :
```bash
sudo ip link set dev <interface> promisc on
```
3. Lancer une capture `tcpdump` :
```bash
sudo tcpdump -n -i <interface> host 192.168.1.3 and host 192.168.1.2
```
4. Depuis attacker (Kali) :
```bash
curl -v --noproxy "*" http://192.168.1.2/
```
Si SYN / GET / 200 dans `tcpdump` sur la monitoring → sniff OK.

---

## 10. NAT / accès Internet et apt
- Le second adaptateur en NAT permet aux VMs d’accéder à Internet pour apt sans exposer le réseau interne.
- Pour installer `Apache` sur la victim (étape nécessaire pour tester les scénarios finaux) :
```bash
sudo apt update && sudo apt install -y apache2
sudo systemctl status apache2 # doit être Actif
```

---

## 11. Copier/Coller bidirectionnel & Guest Additions
1. Arrêter la VM.
2. **VirtualBox Manager → VM → Paramètres → Général → Avancé → Presse-papiers partagé** : *Bidirectionnel*.
3. Démarrer la VM → **VirtualBox → Périphériques → Insérer l’image CD des Additions invité...**
4. Dans la VM (Debian/Ubuntu) :
```bash
sudo apt update
sudo apt install -y build-essential dkms linux-headers-$(uname -r)
sudo sh /media/cdrom/VBoxLinuxAdditions.run
sudo reboot
```
5. Vérifier le copier/coller entre hôte ↔ VM.

---

## 12. Checklist minimal après setup
```text
1) ip a -> vérifier interfaces et IPs (monitoring: 192.168.1.1)
2) sudo ip link set dev <iface_monitor> promisc on
3) sudo tcpdump -n -i <iface_monitor> host 192.168.1.3 and host 192.168.1.2
4) depuis Kali: curl -v --noproxy "*" http://192.168.1.2/
5) vérifier logs/captures sur monitoring
6) snapshot (post-setup)
```
