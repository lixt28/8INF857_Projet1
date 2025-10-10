# Récupérer et configurer les VMs (VirtualBox)

## Installer VirtualBox
Se rendre sur le site officiel de VirtualBox et récupérer la dernière version disponible pour le bon système d'exploitation :
-> https://www.virtualbox.org/wiki/Downloads <-

## Où récupérer les VMs (osboxes)
Utilise OSBoxes (https://www.osboxes.org/) pour télécharger les images (OVA) :
- Ubuntu LTS (pour `monitoring` et/ou `victim`)
- Kali Linux (pour `attacker`)

Ne pousse jamais les OVA dans le repo — indiquer le lien et la version suffira.

## Importer une OVA dans VirtualBox
1. VirtualBox → Fichier → Importer un appareil virtuel… → sélectionne l’OVA → Suivant.  
2. Modifie le nom de la VM (ex. `victim-ubuntu`, `attacker-kali`, `monitoring-ubuntu`).

## Réseau VirtualBox recommandé (topologie fiable)
But : monitoring voit le trafic (soit via mode promisc, soit en tant que gateway). La façon la plus simple et reproductible pour un labo :
- Crée deux Internal Networks : `lab_att` (`attacker`) et `lab_vic` (`victim`).
- `attacker` : attache l’adaptateur 1 à Internal Network `lab_att`.
- `victim` : attache l’adaptateur 1 à Internal Network `lab_vic`.
- `monitoring` : attache 3 adaptateurs :
  - Adapter1 : Host-only/NAT pour management/Internet (ex: `vboxnet0`),
  - Adapter2 : Internal Network `lab_att`,
  - Adapter3 : Internal Network `lab_vic`.
- Active (optionnel) **Promiscuous Mode = Allow All** sur les adaptateurs monitoring si tu veux sniff L2, mais la topologie “2 internal networks + monitoring routeur” ne nécessite pas promisc.

## Activer le copier/coller bidirectionnel (clipboard)
Pour chaque VM :
1. Arrête la VM si elle est en marche.
2. Dans VirtualBox Manager → Paramètres de la VM → Général → Avancé → **Presse-papiers partagé** : choisissez *Bidirectionnel*.
3. Installe les *Guest Additions* dans la VM :
   - Démarre la VM.
   - VirtualBox → Périphériques → Insérer l'image CD des Additions invité… puis exécute `VBoxLinuxAdditions.run` (souvent via `sudo sh /media/cdrom/VBoxLinuxAdditions.run`).
   - Redémarre la VM.
4. Vérifie : copier du host → coller dans VM, et inversement.

## Raccourci : réseaux & IPs conseillés
- monitoring lab_att IP : `10.10.10.1/24`
- attacker IP : `10.10.10.20/24` (gateway `10.10.10.1`)
- monitoring lab_vic IP : `10.10.20.1/24`
- victim IP : `10.10.20.10/24` (gateway `10.10.20.1`)

La doc fournit aussi des alternatives (promisc mode vs gateway). Pour ton labo, choisis la topologie qui te convient.  
