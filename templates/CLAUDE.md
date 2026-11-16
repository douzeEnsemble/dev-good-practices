# CLAUDE.md

## Commandes
- `npm run lint` · `npm run typecheck` · `npm run test` · `npm run test:coverage`
- `npm run test:e2e` · `npm run build`
- `npm run test:mutation` (tout) · `MUTATE=<module ou fichier:début-fin> npm run test:mutation` (un module)
- Lancer un seul test : `npx vitest run <fichier> -t "<nom du test>"`

## Architecture
<!-- Dossiers, rôle de chacun, ce qui est pur (réducteur, src/lib) et ce qui est coque (Durable Object, routage, DOM). -->

## Architecture exécutable
- `.dependency-cruiser.cjs` (lancé par `npm run lint`) : sens des dépendances, pas de cycle ni d'orphelin. Détail dans `doc/architecture.md`.

## Philosophie de test
- Ce qui est unitaire : …
- Ce qui est e2e (Playwright) : …
- Couverture 100 % sur tout le code applicatif ; mutation 100 % (Stryker, runner `command`).
- Les tests d'interface comparent la structure exacte (`outerHTML`, `getAttributeNames()`).
- Un mutant équivalent se traite en simplifiant le code, pas en baissant le seuil.

## Versionnement
- Commits au format conventionnel (`type(portée): sujet`) ; activer le hook : `git config core.hooksPath .githooks`.
- La version se déduit des commits (semantic-release, `release.yml`) : ne jamais éditer un numéro de version ni un changelog à la main.

## CI/CD
<!-- Noms des checks requis (ruleset), workflows de déploiement, variables (DEPLOY_URL), tags. -->

## Modèle de confidentialité / sécurité
<!-- Ce qui est promis, ce qui ne l'est pas, validation côté serveur + échappement au rendu. -->

## Pièges locaux
<!-- Une entrée par piège : symptôme, cause, contournement, raison. -->
