# Windows — installation et dépannage

Ce guide complète la section « Installation rapide » du [README](README.md). Deux raccourcis suffisent : **JOUER.bat** (installation + lancement) et **INSTALL.bat** (installation seule).

## Démarrage (quick start)

1. Télécharger le ZIP Windows précompilé depuis la page Releases : `https://github.com/elielbarbucovantes-source/paysfictifs-travaux/releases`. À défaut, cloner ce dépôt (`git clone …`).
2. Décompresser l'archive dans un dossier ordinaire. Les accents et les espaces sont acceptés, par exemple `C:\Utilisateurs\Élodie\Mes documents\Pays fictifs`.
3. Double-cliquer sur **JOUER.bat**. La première exécution prépare tout, puis ouvre le jeu.

Pour compiler sans démarrer le jeu : double-cliquer sur **INSTALL.bat**. Les deux scripts sont à lancer depuis le dossier racine du mod (celui qui contient `mod.config`).

## Prérequis (prerequisites)

- Windows 10 ou 11, 64 bits ; connexion Internet pour le premier lancement.
- **SDK .NET 8** : installé automatiquement par winget si absent. Sinon, suivre https://dotnet.microsoft.com/download/dotnet/8.0 puis rouvrir l'invite de commande.
- winget est fourni par « App Installer » (Microsoft Store). Pour le vérifier :

```cmd
winget --version
winget install --id Microsoft.DotNet.SDK.8 --exact --accept-source-agreements --accept-package-agreements
dotnet --list-sdks
```

- Quelques Go d'espace libre : moteur OpenRA, contenu téléchargé, build et logs.
- Aucun droit administrateur n'est nécessaire pour compiler dans son propre dossier. Le pare-feu peut en demander un pour autoriser le jeu (voir ci-dessous).

## Moteur épinglé et format de paquet (package format)

Le mod est construit pour un moteur précis : `ENGINE_VERSION="release-20231010"` dans `mod.config`, et `PackageFormats: Mix` dans `mods/fictifs/mod.yaml`. **Le moteur est épinglé à release-20231010 : pas de mismatch de format de paquet avec un OpenRA plus récent.** Ne pas remplacer le dossier `engine` par un OpenRA plus récent : les sprites/audios ne seraient pas lus et le jeu refuserait de démarrer. Laisser **JOUER.bat** / **INSTALL.bat** (ou `make.cmd`) récupérer la bonne version ; en manuel, vérifier le contenu de `engine\VERSION`.

Si le message « package format » / « format de paquet » apparaît, supprimer le dossier `engine` puis relancer **JOUER.bat** : le bon moteur est téléchargé à nouveau. Les mises à jour du mod ne changent pas l'épinglage du moteur.

## Chemins, accents et espaces (paths with accents or spaces)

Les chemins avec accents (`Élodie`, `Rubénie`) et espaces (`Pays fictifs`) fonctionnent. Éviter toutefois :

- un dossier synchronisé par OneDrive/Dropbox ou un lien symbolique : la compilation peut y être lente ou perdre des fichiers ;
- la racine de disque (`C:\PaysFictifs`) et les chemins très longs, qui peuvent poser des problèmes à .NET/MSBuild ;
- un chemin contenant `&`, `#` ou des guillemets dans les paramètres transmis à la ligne de commande.

Si un script se referme immédiatement, ouvrir une invite de commande (`cmd`) dans le dossier, taper `JOUER.bat` et lire le message d'erreur.

## Premier lancement (first-run content download)

OpenRA n'inclut pas les données du jeu d'origine. Au premier lancement, choisir **Quick Install** : le mod télécharge gratuitement les fichiers de Red Alert (version 2008 de Westwood/EA). Cela ne prend qu'une fois ; les fichiers sont rangés dans le dossier de configuration OpenRA. Sans connexion, le téléchargement échoue et il faut relancer **JOUER.bat** une fois en ligne.

Le pare-feu Windows peut afficher une demande « Autoriser l'accès » : cocher au minimum **Réseaux privés**. Pour le multi-joueur, l'hôte doit aussi ouvrir le port TCP **1235** (partage de cartes et classement Elo). Si la fenêtre a été fermée par erreur : Paramètres → Réseau et Internet → Pare-feu Windows → Autoriser une application, puis autoriser `OpenRA.exe` / le lanceur du mod ; vérifier aussi que ZeroTier est autorisé (voir le README).

## Journaux et diagnostic (logs)

- Journaux du jeu : `Documents\OpenRA\Logs` (soit `%USERPROFILE%\Documents\OpenRA\Logs`).
- Journaux du lanceur : `jouer.log` et `update.log` dans le dossier du mod.
- Pour un rapport de bug, joindre les derniers fichiers `.log` de ces deux emplacements, la version affichée dans le jeu (par exemple `release-20231010+8f4e95b`) et le message d'erreur complet.
- Lancement verbeux : `launch-game.cmd --debug` produit des détails supplémentaires dans les logs.

## FAQ

**« 'winget' n'est pas reconnu »** — Installer « App Installer » depuis le Microsoft Store, redémarrer, ou installer le SDK .NET 8 manuellement avec le lien ci-dessus.

**« dotnet introuvable » après installation** — Redémarrer l'invite de commande (ou Windows) pour rafraîchir le `PATH`, puis vérifier avec `dotnet --list-sdks`.

**« Required engine files not found »** — Le dossier `engine` est absent ou incomplet. Relancer **JOUER.bat** ou **INSTALL.bat** ; en manuel, `make.cmd` puis `launch-game.cmd`.

**« mod.config invalide / fins de ligne »** — `mod.config` doit rester en LF (Unix), jamais en CRLF. Ne pas l'enregistrer avec un éditeur qui convertit les fins de ligne ; le `.gitattributes` du dépôt force LF pour les scripts `.sh`, `.config` et les sources, et CRLF pour `.bat`, `.cmd` et `.ps1`. Après un clonage, ne pas réenregistrer ces fichiers « pour rien ».

**« Erreur de package format / mismatch »** — voir la section « Moteur épinglé » : ne pas utiliser un OpenRA plus récent que `release-20231010`.

**« Le jeu se ferme au premier lancement »** — Vérifier l'espace disque, le téléchargement de **Quick Install** et les journaux dans `Documents\OpenRA\Logs`.

**« Écran noir / pas de son »** — Mettre à jour les pilotes graphiques et audio, puis relancer avec `launch-game.cmd --debug` ; joindre les logs.

**« Comment jouer à deux ? »** — Suivre la section « Jouer en ligne avec un ami (ZeroTier) » du README. Les deux joueurs doivent avoir exactement la même version du mod.

**« Puis-je mettre à jour seulement le moteur ? »** — Non : il est épinglé à `release-20231010` pour garantir la compatibilité du `package format` Mix et des règles du mod.
