# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Dépôt de documentation et de modèles : bonnes pratiques de développement tirées de projets web (Worker, SPA/PWA, JS sans build, site statique) et d'un backend PHP/Symfony. Ce n'est pas une application : il n'y a ni `package.json`, ni build, ni test à lancer.

## Contenu

- `GUIDE-QUALITE.md` : le guide. Principes (§ 1), choix selon le type de projet (§ 2), le standard = les règles à identifiant stable (`CI-03`, `MUT-06`, `A11Y-02`…) (§ 3), recette nouveau projet (§ 4), adoption sur un projet existant (§ 5), pièges (§ 6), tableau modèles (§ 7), suivi de conformité (§ 8), règles d'évolution et journal des versions (§ 9).
- `templates/` : fichiers à copier tels quels dans un projet (workflows, ruleset, `mutation-matrix.mjs`, configs Vitest/Stryker/Playwright, `CLAUDE.md` type). Ils tournent en production dans les dépôts de référence.
- `examples/` : fichiers réels remplis (`worker-do/`, `js-sans-build/`) et un exemple générique de test d'interface. Ce sont des **instantanés**, non tenus à jour.
- `scripts/apply-rulesets.sh propriétaire/dépôt …` : applique `.github/rulesets/main.json` d'un dépôt à son ruleset GitHub (agit sur GitHub : ne le lancer qu'à la demande). `scripts/check-conformity.sh chemin/dépôt …` : vérifie des dépôts clonés contre le guide (lecture seule ; sortie `ok`/`KO`, code 1 si un KO).

## Règles de travail

- **Le guide et les modèles évoluent ensemble.** Modifier une règle sans mettre à jour le modèle correspondant (ou l'inverse) crée une dérive : le tableau du § 7 relie chaque règle à son fichier.
- **Un identifiant de règle ne se réutilise jamais.** Une règle retirée est marquée *(abandonnée, version X)*, pas supprimée.
- **Une règle n'entre que si elle est vérifiable** (commande, fichier ou check) **et que sa raison est écrite.** Un nouveau piège s'ajoute au § 6 avec l'incident qui l'a révélé.
- **Toute évolution** : incrémenter la version du guide (mineure : règle ajoutée ou précisée ; majeure : elle oblige à toucher le ruleset ou les noms de checks), ajouter une ligne au journal (§ 9), mettre à jour le suivi de conformité (§ 8), puis rejouer sur les projets à raison d'une PR par dépôt.
- **Nouvelle vérification automatisable** : ajouter la ligne correspondante à `scripts/check-conformity.sh` et la relancer sur les dépôts suivis.
- `templates/.github/scripts/mutation-matrix.mjs` doit rester **identique** dans tous les dépôts à matrice ; `check-conformity.sh` compare son empreinte. Même règle pour `audit-check.mjs` (tous les dépôts npm). Toute modification ici se rejoue partout.
- Les actions des workflows sont épinglées par SHA (`@<sha> # vN`) : ne jamais les remplacer par un tag. Pour en ajouter une, retrouver le SHA avec `gh api repos/<action>/git/ref/tags/<tag>` (si l'objet est de type `tag`, suivre `git/tags/<sha>`).

## Vérifier avant de livrer une modification

```sh
# Depuis le dossier qui contient les dépôts à vérifier
../dev-good-practices/scripts/check-conformity.sh dépôt1 dépôt2 …
```

Aucun `KO` attendu, sauf sur les règles de la version courante tant qu'elles ne sont pas rejouées (§ 8 du guide). Vérifier aussi que les liens relatifs du guide (`templates/…`, `scripts/…`, `examples/…`) pointent vers des fichiers existants.

## Conventions

- **Ne nommer aucun projet** dans ce dépôt (guide, modèles, exemples, scripts, README) : ni nom, ni chemin, ni état par projet. Le suivi par projet vit dans chaque projet.
- Rédaction en français (guide, commentaires, messages de commit). Code et noms de fichiers en anglais ou comme dans les dépôts d'origine.
- Rien de propre à une machine ou à un compte dans `templates/` : pas de chemin absolu, d'identifiant de compte, d'URL personnelle ni de secret. Les valeurs à adapter sont signalées dans la colonne « À adapter » du § 7.
- Un fichier de `examples/` ne contient rien de secret non plus ; en cas de doute, ne pas le copier ici.

## État

Version 3.16 du guide (18 novembre 2026). Remote : `douzeEnsemble/dev-good-practices`. Premier commit fait à la demande du propriétaire ; ne pousser qu'à sa demande explicite.
