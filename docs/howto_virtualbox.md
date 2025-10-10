# Récupérer et configurer les VMs (VirtualBox)

## Installer VirtualBox
Se rendre sur le site officiel de VirtualBox et installer la version :
https://www.virtualbox.org/wiki/Downloads

## Où récupérer des VMs (osboxes)
- Les images OSBoxes sont des images pré-configurer et gratuites, à privilégier pour les machines `monitoring` et `victim` : https://www.osboxes.org/virtualbox-images/
- Kali Linux est la distribution idéale pour les tests d'intrusion en raison de la variété des outils utilisable pour les tentative d'intrusion, à privilegier pour la machine `attacker` : https://www.kali.org/get-kali/#kali-virtual-machines

## Importer une OVA dans VirtualBox
1. VirtualBox → Fichier → Importer un appareil virtuel… → sélectionner l’OVA → Suivant.  
2. Modifie le nom de la VM (ex. `victim-ubuntu`, `attacker-kali`, `monitoring-ubuntu`).

## Réseau VirtualBox recommandé (topologie fiable)
L'objectif est que monitoring voit le trafic :
- Crée un Internal Network : `lab_net`
- `monitoring` : Attacher l’adaptateur 1 à Internal Network `lab_att`, attacher l'adaptateur 2 à NAT (nécessaire pour installer les outils). Activer **Promiscuous Mode = Allow All** sur l'adaptateur 1 +
  '''bash
  sudo ip link set dev <interface> promisc on
- `victim` : Attacher l’adaptateur 1 à Internal Network `lab_net`, attacher l'adaptateur 2 à NAT (pour `apt` pour installer apache2 - nécessaire pour réaliser l'un des tests d'attaque)
- `attacker` : Attacher l’adaptateur 1 à Internal Network `lab_net`
  

## Activer le copier/coller bidirectionnel (clipboard)
Pour chaque VM :
1. Arrêter la VM si elle est en marche.
2. Dans VirtualBox Manager → Paramètres de la VM → Général → Avancé → **Presse-papiers partagé** : choisissez *Bidirectionnel*.
3. Installer les *Guest Additions* dans la VM :
   - Démarrer la VM.
   - VirtualBox → Périphériques → Insérer l'image CD des Additions invité… puis exécuter `VBoxLinuxAdditions.run` (souvent via `sudo sh /media/cdrom/VBoxLinuxAdditions.run`).
   - Redémarrer la VM.
4. Vérifier : copier du host → coller dans VM, et inversement.

## Réseau & IPs utilisés pendant les tests (changer en fonction des préferences
- monitoring IP (labnet : enp0s3) : `192.168.1.1/24`
- monitoring IP (labnet : enp0s3) : `192.168.1.2/24`
- attacker IP (labnet : eth0) : `192.168.1.3/24`



