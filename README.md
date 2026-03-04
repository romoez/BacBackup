# BacBackup

[![Version](https://img.shields.io/github/v/release/romoez/BacBackup?label=Version)](https://github.com/romoez/BacBackup/releases)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue)](https://github.com/romoez/BacBackup)
[![License](https://img.shields.io/badge/License-GPL--3.0-green.svg)](https://www.gnu.org/licenses/gpl-3.0.html)

[⬇️ Télécharger BacBackup](https://github.com/romoez/BacBackup/releases)

---

## Introduction

**BacBackup** est une solution de surveillance et de sauvegarde automatisée conçue pour sécuriser les travaux des élèves, notamment lors des épreuves pratiques du Baccalauréat. En arrière-plan, le logiciel surveille l'activité (écran, presse-papier, périphériques USB) et sauvegarde automatiquement les dossiers de travail des candidats.

### Interface de BacBackup

![Interface BacBackup](captures_ecran\bb_interface_liste_de_dodssiers_surveilles.png)  
_Interface principale de BacBackup_

---

## Principales Fonctionnalités

- **Capture d'écran intelligente** : Capture toutes les 5 secondes, uniquement si une activité est détectée (souris ou clavier).
- **Surveillance USB** : Détection en temps réel des clés USB insérées et identification des supports non autorisés.
- **Suivi du presse-papier** : Surveillance et journalisation continue du contenu du presse-papier (textes, fichiers et dossiers).
- **Sauvegarde périodique et intelligente** : Archivage automatique des dossiers de travail des candidats toutes les 2 minutes (si une modification est détectée).
- **Sessions horodatées** : Organisation par dossiers indexés (ex: `001___24_5_2026___10h30`) avec incrémentation automatique à chaque redémarrage.
- **Optimisation 7-Zip** : Sauvegardes compressées pour économiser l'espace, incluant les bases de données (MySQL/MariaDB).
- **Auto-nettoyage intelligent** : Gestion automatique de l'espace disque avec suppression des sessions les plus anciennes (seuil par défaut: 100 sessions ou 50 Go).

---

## Sécurité et Auto-protection

Afin de garantir l'intégrité des examens et d'empêcher toute tentative de contournement, BacBackup intègre plusieurs couches de protection :

### a. Sécurisation du stockage

Le répertoire racine des sauvegardes (`C:\Sauvegardes\BacBackup\...`) est verrouillé au niveau du système. Son contenu est protégé contre toute consultation directe ; l'accès aux fichiers n'est autorisé que via l'interface d'administration de BacBackup.

### b. Surveillance du processus

Le logiciel est surveillé en permanence par un service **"Watchdog"**. Ce dispositif assure une disponibilité constante en redémarrant automatiquement le processus principal si celui-ci est interrompu, même en cas d'arrêt forcé via le gestionnaire des tâches.

### c. Immunité contre la suppression

Tous les fichiers du programme, ainsi que les sauvegardes et les captures d'écran, sont protégés. Ils ne peuvent pas être effacés manuellement.

### d. Contrôle de la désinstallation

La suppression du logiciel est strictement encadrée. Elle nécessite obligatoirement la saisie du mot de passe de sécurité défini lors de l'installation initiale, empêchant ainsi toute désactivation non autorisée.

---

## Accès et Commandes Rapides

BacBackup est conçu pour être discret, mais il reste accessible à tout moment grâce à des combinaisons de touches ou via son icône en barre des tâches.

### a. Actions via l'icône de notification

L'icône située dans la zone de notification (près de l'horloge) permet d'interagir rapidement avec le logiciel :

- **Double-clic gauche** : Déclenche une sauvegarde forcée immédiate.
- **Shift + Double-clic gauche** : Ouvre l'interface de BacBackup.

### b. Raccourcis Clavier (Hotkeys)

Ces combinaisons permettent d'agir instantanément, même si l'interface n'est pas ouverte :

| Raccourci             | Action                                                      |
| --------------------- | ----------------------------------------------------------- |
| `⇧ + Ctrl + Win + F6` | Déclenche une sauvegarde forcée immédiate.                  |
| `⇧ + Ctrl + Win + F5` | Ouvre l'interface de BacBackup (nécessite le mot de passe). |

---

## Dossiers Surveillés

| Dossiers                                           | Exemples                              |
| -------------------------------------------------- | ------------------------------------- |
| `C:\Bac\*2\*`                                      | `C:\Bac2026`                          |
| `C:\7\*`                                           | `C:\7b2`                              |
| `C:\8\*`                                           | `C:\8ème B7`                          |
| `C:\9\*`                                           | `C:\9 base 1`                         |
| `C:\1\*`                                           | `C:\1s3`                              |
| `C:\2\*`                                           | `C:\2 TI`                             |
| `C:\3\*`                                           | `C:\3 eco 2`                          |
| `C:\4\*`                                           | `C:\4Lettres1`                        |
| `C:\DC\*`                                          | `C:\dc3`                              |
| `C:\DS\*`                                          | `C:\ds 2`                             |
| `{Bureau}\Bac\*2\*`                                | `C:\Users\Eleve\Desktop\Bac2026`      |
| `{Bureau}\7\*`                                     | `C:\Users\Eleve\Desktop\7b2`          |
| `{Bureau}\8\*`                                     | `C:\Users\Eleve\Desktop\8ème B7`      |
| `{Bureau}\9\*`                                     | `C:\Users\Eleve\Desktop\9 base 1`     |
| `{Bureau}\1\*`                                     | `C:\Users\Eleve\Desktop\1s3`          |
| `{Bureau}\2\*`                                     | `C:\Users\Eleve\Desktop\2 TI`         |
| `{Bureau}\3\*`                                     | `C:\Users\Eleve\Desktop\3 eco 2`      |
| `{Bureau}\4\*`                                     | `C:\Users\Eleve\Desktop\4Lettres1`    |
| `{Bureau}\DC\*`                                    | `C:\Users\Eleve\Desktop\dc3`          |
| `{Bureau}\DS\*`                                    | `C:\Users\Eleve\Desktop\ds 2`         |
| `C:\xampp_lite\*\{dossier d'hébergement d'Apache}` | `C:\xampp_lite_8_5\www`               |
| `C:\xampp_lite\*\{dossier data de MySql/MariaDB}`  | `C:\xampp_lite_8_5\apps\mysql\data`   |
| `C:\xampp\*\{dossier d'hébergement d'Apache}`      | `C:\xampp7.3.6\htdocs`                |
| `C:\xampp\*\{dossier data de MySql/MariaDB}`       | `C:\xampp7.3.6\mysql\data`            |
| `C:\Wamp\*\{dossier d'hébergement d'Apache}`       | `C:\wamp64\www`                       |
| `C:\Wamp\*\{dossier data de MySql/MariaDB}`        | `C:\wamp64\bin\mysql\mysql9.1.0\data` |

**L'astérisque `*`** est utilisé comme joker : il correspond à n'importe quel texte ou chiffre après le préfixe indiqué.

---

## Description des Éléments dans un Dossier de Session BacBackup

![Contenu d'un dossier de session](captures_ecran\dossier_de_sauvegarde_par_session.png)  
_Structure d'un dossier de session BacBackup_

### a. Dossier_CapturesEcran

- **Fonction** : Contient les captures d'écran prises pendant la session
- **Contenu** : Fichiers PNG nommés avec un format séquentiel (ex: `0001_14h30_45.png`)
- **Fréquence** : Une capture toutes les 5 secondes par défaut (paramétrable)
- **Utilité** : Preuve visuelle de l'activité du candidat pendant l'examen

### b. Dossier_UsbWatcher

Ce dossier contient les rapports générés lors de l'insertion de périphériques de stockage non autorisés.

**Contenu** :

- `Fichier_ContenuCléUSB.txt` avec :
  - Marque/Modèle
  - Série Matériel
  - Série Volume
  - Capacité (arrondie)
  - Étiquette
  - Système de fichiers
- Arborescence complète du contenu de la clé (jusqu'à 100 éléments)
- 100 captures d'écran prises à raison d'une toutes les 1,5 secondes
- **Structure** : Sous-dossier nommé avec horodatage + numéro de série (ex: `14_30_45___SN__ABC12345`)

**Déclenchement** : Lorsqu'une clé USB non autorisée est insérée.

### c. Fichier_info_session.txt

Il s'agit de la fiche d'identité de la session de sauvegarde.

**Informations incluses** :

- **Déclencheur** : Démarrage de BacBackup, Sortie de veille/suspend, Reprise après inactivité prolongée, ou Détection de BacCollector
- **Date/Heure de début de session**
- **Numéro de session** (format: `001___18_02_2026___08h30`)
- **Ordinateur** (nom de la machine)
- **Utilisateur connecté**
- **Système d'exploitation** (ex: `WIN_10 X64`)

**Utilité** : Contexte complet de la session pour l'analyse post-examen.

### d. Fichier_journal_presse_papier.log

Ce journal enregistre tout l'historique du presse-papier de Windows.

**Contenu** :

- **Texte** : Jusqu'à 100 Ko (tronqué avec avertissement au-delà)
- **Fichiers** : Chemins complets des fichiers copiés
- **Dossiers** : Chemin racine + arborescence indentée (jusqu'à 20 éléments)
- **Horodatage précis** : Format `[2026-02-18 08:30:45]`
- **Debouncing** : Évite les doublons rapides (500ms minimum entre captures)
- **Rotation automatique** : Nouveau fichier si > 10 Mo

**Utilité** : Détecter les échanges de codes ou de fichiers suspects entre différentes applications.

### e. Fichiers Compressés (Archives)

Ce sont les copies réelles des dossiers de travail de l'élève.

- **Format** : compressé avec 7zip
- **Nommage** : `NomDossier___001.7z`, `NomDossier___002.7z`, etc.
- **Détection des modifications** : Comparaison par empreinte MD5 pour identifier les fichiers modifiés
- **Lien de retour** : Un raccourci `dossier d'origine.lnk` permet de retrouver le chemin source original
- **Utilité** : Permettre la récupération du travail de l'élève en cas de perte ou de corruption, avec historique des versions.

### f. Note de sécurité

Ces fichiers sont stockés dans le répertoire verrouillé `C:\Sauvegardes\BacBackup` avec permissions restrictives :

- Accès refusé à tous les utilisateurs.
- Verrouillage du contenu contre suppression.
- Les fichiers ne sont consultables que par l'enseignant, exclusivement via l'interface sécurisée de BacBackup.

---

## Paramètres

![Paramètres de BacBackup](captures_ecran\bb_interface_parametres.png)  
_Interface des paramètres - Les valeurs sont consultables mais modifiables uniquement via le fichier `BacBackup.ini`_

**Note** : Les options sont configurables uniquement en modifiant manuellement le fichier `BacBackup.ini`. Cette interface permet uniquement de visualiser les valeurs actuelles.

---

## Licence

Ce projet est sous licence [GPL-3.0](LICENSE).

## Liens utiles

- [Téléchargements](https://github.com/romoez/BacBackup/releases)
- [BacCollector](https://github.com/romoez/BacCollector) - Outil de collecte complémentaire
- [Signaler un bug](https://github.com/romoez/BacBackup/issues)
