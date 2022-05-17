# BacBackup

## Téléchargement

[Télécharger BacBackup](https://github.com/romoez/BacBackup/releases)

## Principales fonctionnalités
- Surveillance de l'activité sur le PC par des captures d'écran.
- Sauvegarde périodique de toute modification apportée aux [dossiers de travail](#liste-de-dossiers-surveillés-par-bacbackup) des élèves.

![Interface Bacbackup: Dossiers Surveillés](https://github.com/romoez/BacBackup/blob/main/captures_ecran/bb_interface_liste_de_dodssiers_surveilles.png)

## Ce que fait BacBackup

- Il crée un dossier de sauvegarde à chaque démarrage de Windows, le nom de dossier est composé d'un numéro (auto-incrémenté), la date et l'heure de création :

![Un dossier de sauvegarde pour chaque session](https://github.com/romoez/BacBackup/blob/main/captures_ecran/dossier_de_sauvegarde_par_session.png)

- Dans le dossier de sauvegarde de la session encours, BacBackup crée un sous dossier pour y mettre les captures d'écran, et crée des copies compressées des dossiers de travail ayant subi des modifications, on peut y avoir plusieurs versions pour un même dossier de travail:

![Exemple de contenu d'un dossier de sauvegarde d'une session](https://github.com/romoez/BacBackup/blob/main/captures_ecran/exemple_contenu_d_un_dossier_de_sauvegarde.png)


## Paramètres de BacBackup

![Paramètres de BacBackup](https://github.com/romoez/BacBackup/blob/main/captures_ecran/bb_interface_parametres.png)

## Autres informations

- **Shift + Ctrl + Win + F6**: Ouvre l'interface de BacBackup.
- **Shift + Ctrl + Win + F5**: Force BacBackup à prendre une sauvegarde à l'instant s'il est nécessaire.
- L'intervalle de captures d'écran est de 5 secondes *(s'il y a une activité de la souris ou du clavier)*.
- L'intervalle de sauvegardes des dossiers de travail est de 2 minutes *(s'il y a des modifications)*.
- L'installateur de BacBackup, ne crée aucun raccourci, ni au menu démarrer, ni sur le bureau (utilisez le raccourcis clavier pour y accéder **Shift + Ctrl + Win + F6**).
- Les opérations faites par BacBackup, sont transparents à l'utilisateur, et n'affectent pas les performances du PC.
- Le dossier de Sauvegarde de BacBackup est verrouillé, et il n'est accessible qu'à partir de l'interface du logiciel en appuyant sur le lien en bas de la fenêtre.
- Le dossier de Sauvegarde de BacBackup est le même dossier utilisé par [BacCollector](https://github.com/romoez/BacCollector)
- Si le nombre de dossiers de sessions atteint le nombre maximum *(750 par défaut)*, ou la taille du dossier dépasse la taille maximale autorisé *(200Go par défaut)*, BacBackup efface 50% des dossiers de sauvegarde en commençant par les plus anciens.

## Liste de dossiers surveillés par BacBackup:

| Dossiers                                                        | Exemples                                              |
| --------------------------------------------------------------- | ----------------------------------------------------- |
| C:\\Bac\*2\*                                                    | C:\\Bac2022                                           |
| C:\\7\*                                                         | C:\\7b2                                               |
| C:\\8\*                                                         | C:\\8ème B7                                           |
| C:\\9\*                                                         | C:\\9 base 1                                          |
| C:\\1\*                                                         | C:\\1s3                                               |
| C:\\2\*                                                         | C:\\2 TI                                              |
| C:\\3\*                                                         | C:\\3 eco 2                                           |
| C:\\4\*                                                         | C:\\4Lettres1                                         |
| C:\\DC\*                                                        | C:\\dc3                                               |
| C:\\DS\*                                                        | C:\\ds 2                                              |
| C:\\TPW\*                                                       | C:\\tpw 1.5                                           |
| C:\\{ProgramFiles}\\EasyPHP\*\\{dossier d'hébergement d'Apache} | C:\\Program Files (x86)\\EasyPHP-12.1\\www            |
| C:\\{ProgramFiles}\\EasyPHP\*\\{dossier des BD MySql}           | C:\\Program Files (x86)\\EasyPHP-x 2.0b1\\mysql\\data |
| C:\\EasyPHP\*\\{dossier d'hébergement d'Apache}                 | C:\\EasyPHP-12.1\\www                                 |
| C:\\EasyPHP\*\\{dossier des BD MySql}                           | C:\\EasyPHP-x 2.0b1\\mysql\\data                      |
| C:\\xampp\*\\{dossier d'hébergement d'Apache}                   | C:\\xampp7.3.6\\htdocs                                |
| C:\\xampp\*\\{dossier des BD MySql}                             | C:\\xampp7.3.6\\mysql\\data                           |
| C:\\Wamp\*\\{dossier d'hébergement d'Apache}                    | C:\\wamp 2.5x32\\www                                  |
| C:\\Wamp\*\\{dossier des BD MySql}                              | C:\\wamp 2.5x32\\bin\\mysql\\mysql5.6.17\\data        |
| {Bureau}\\Bac\*2\*                                              | C:\\Users\\Eleve\\Desktop\\Bac2022                    |
| {Bureau}\\7\*                                                   | C:\\Users\\Eleve\\Desktop\\7b2                        |
| {Bureau}\\8\*                                                   | C:\\Users\\Eleve\\Desktop\\8ème B7                    |
| {Bureau}\\9\*                                                   | C:\\Users\\Eleve\\Desktop\\9 base 1                   |
| {Bureau}\\1\*                                                   | C:\\Users\\Eleve\\Desktop\\1s3                        |
| {Bureau}\\2\*                                                   | C:\\Users\\Eleve\\Desktop\\2 TI                       |
| {Bureau}\\3\*                                                   | C:\\Users\\Eleve\\Desktop\\3 eco 2                    |
| {Bureau}\\4\*                                                   | C:\\Users\\Eleve\\Desktop\\4Lettres1                  |
| {Bureau}\\DC\*                                                  | C:\\Users\\Eleve\\Desktop\\dc3                        |
| {Bureau}\\DS\*                                                  | C:\\Users\\Eleve\\Desktop\\ds 2                       |
