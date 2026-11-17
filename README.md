# dev-good-practices

Bonnes pratiques de développement (qualité, CI/CD, tests, sécurité), les **modèles** à copier et des **exemples** réels. Tiré de projets web (Worker, SPA/PWA, JS sans build, site statique) et d'un backend PHP/Symfony.

| Je veux… | Aller à |
|---|---|
| Démarrer un projet | [`GUIDE-QUALITE.md`](GUIDE-QUALITE.md) § 4 (recette), puis copier `templates/` |
| Mettre un projet existant au standard | [`GUIDE-QUALITE.md`](GUIDE-QUALITE.md) § 5 (une famille de règles par PR) |
| Savoir ce qui se vérifie | [`GUIDE-QUALITE.md`](GUIDE-QUALITE.md) § 8 (suivi de conformité) |
| Vérifier un projet | `scripts/check-conformity.sh chemin/dépôt …` |
| Appliquer le ruleset de `main` | `scripts/apply-rulesets.sh propriétaire/dépôt …` |

## Contenu

```
GUIDE-QUALITE.md      le guide : principes, règles à identifiant (CI-03, MUT-06…), recette, adoption, pièges
templates/            fichiers à copier, tels qu'ils tournent en production
  .github/workflows/  ci, codeql, audit, deploy-cloudflare, pages, node-updates, major-updates
  .github/scripts/    mutation-matrix.mjs, mutation-select.mjs, audit-check.mjs (identiques dans tous les dépôts)
  .github/audit-exceptions.json  exceptions d'audit datées (CI-13)
  .github/rulesets/   main.json
  .github/dependabot.yml
  vitest.config.ts · stryker.config.mjs · playwright.config.ts · .dependency-cruiser.cjs · CLAUDE.md
  docs/               modèle de spec/plan daté
  php/                famille backend PHP/Symfony (squelette qui démarre et passe tout au vert) : Makefile, Docker, configs qualité, tools/, workflows (qualité, release, déploiement, mises à jour), CLAUDE.md et doc/
  php-ui/             en plus pour un backend PHP avec interface : tests navigateur Chrome + Firefox, validation W3C
scripts/              apply-rulesets.sh · check-conformity.sh
examples/             fichiers réels remplis (`worker-do/`, `js-sans-build/`) et un exemple de test d'interface
```

## Utiliser un modèle

1. Copier le fichier dans le projet, au même chemin relatif.
2. Adapter ce que le guide indique (§ 7, colonne « À adapter »).
3. Lancer `scripts/check-conformity.sh` sur le projet.

Les workflows ont déjà des actions **épinglées par SHA** ; Dependabot (`github-actions`) les met à jour.

## Faire évoluer

Modifier le guide **et** les modèles ici d'abord, incrémenter la version et ajouter une ligne au journal (§ 9 du guide), puis rejouer sur les projets, une PR par dépôt. Les `examples/` sont des instantanés, pas des références tenues à jour.
