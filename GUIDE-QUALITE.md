# Guide qualité

> Version **3.8** · 17 novembre 2026 · tiré de projets web (Worker + Durable Object, SPA/PWA, JS sans build, site statique), complété par les pratiques d'un backend PHP/Symfony.
> Référence vivante : à faire évoluer ici, puis à rejouer sur les projets (voir [§ 9 Faire évoluer le guide](#9-faire-évoluer-le-guide)).

Ce guide sert à deux choses :

1. **Démarrer un nouveau projet** avec toute la chaîne qualité dès le premier commit ([§ 4](#4-recette-nouveau-projet)).
2. **Mettre un projet existant au standard**, une règle à la fois ([§ 5](#5-adopter-le-standard-sur-un-projet-existant)).

Chaque règle porte un identifiant (`CI-03`, `MUT-02`…) pour pouvoir la citer, la vérifier et suivre qui l'applique ([§ 8](#8-suivi-de-conformité)).

---

## 1. Principes

| # | Principe | Conséquence |
|---|---|---|
| 1 | **Un seul vocabulaire** | Mêmes scripts npm partout ; la CI n'appelle que ces scripts. Ce qui passe en local passe en CI. |
| 2 | **Zéro avertissement** | Le linter bloque (`--deny-warnings`) ; aucun `skip`/`only` dans les tests. |
| 3 | **Logique pure isolée** | La logique métier vit dans des fonctions pures ; les coques (Durable Object, routage, DOM) restent minces. Tout est quand même couvert et muté. |
| 4 | **Les tests sont testés** | 100 % de couverture, puis mutation testing à 100 %. La couverture prouve qu'une ligne a tourné ; Stryker prouve qu'un test échouerait si le comportement changeait. |
| 5 | **Rien ne part en prod sans CI verte** | Déploiement par `workflow_run`, jamais sur un simple push. |
| 6 | **Le dépôt s'explique seul** | `CLAUDE.md` à jour : commandes, architecture, philosophie de test, pièges et leur raison. |
| 7 | **L'architecture s'exécute** | Les règles de dépendance entre dossiers sont vérifiées par un outil dans le linter, pas seulement écrites ([§ 3.10](#310-architecture-exécutable-arch)). |
| 8 | **Ce qui vieillit se met à jour tout seul** | Dependabot, plus des workflows planifiés pour ce qu'il ne sait pas faire ; ces PR ne changent que des numéros de version, la CI dit si c'est sûr ([§ 3.11](#311-mises-à-jour-automatiques-upd)). |

Règle d'or : **on ne baisse jamais un seuil pour avancer**. On étend le périmètre fichier par fichier, ou on simplifie le code.

---

## 2. Choisir selon le type de projet

| Pièce | Worker + Durable Object | SPA Vite + Worker de synchro | JS sans build | Site statique |
|---|---|---|---|---|
| Logique pure | `worker/reducer.ts`, `shared/`, `src/lib/` | `src/lib/`, hooks | modules `js/*.js` | `js/`, `scripts/` |
| Lint / types | oxlint · `tsc` ×2 (worker, client) | oxlint · `tsc -b` | oxlint · `tsc` + `checkJs` | ESLint + Stylelint + html-validate |
| Couverture / mutation | 100 % · matrice | 100 % · matrice | 100 % · matrice, gros fichiers en plages | 100 % · 1 job |
| E2E Playwright | oui, contre `vite dev` (workerd) | oui (+ mobile si PWA) | oui | non |
| Job « Worker de synchronisation » | non | oui | oui | non |
| Déploiement | Cloudflare (+ smoke test, tag `deploy-N`) + Pages | Pages + Worker (si `worker/` a changé) | Pages + Worker | Pages |

**Couches et familles en plus.** Une SPA installable suit en plus [§ 3.12 PWA](#312-application-installable-pwa). Un backend PHP/Symfony est une famille à part ([§ 3.13](#313-backend-phpsymfony-php)) : mêmes principes et mêmes noms de checks (CI-03, CI-05, CI-06), outils PHP à la place des outils npm.

Ce qui est **commun à toutes les familles** : noms de jobs, ruleset, audit, CodeQL, Dependabot, seuil 100 %, job de synthèse de mutation.

---

## 3. Le standard

### 3.1 Scripts npm (`SCR-*`)

| ID | Règle |
|---|---|
| SCR-01 | `package.json` expose : `lint`, `typecheck`, `test`, `test:coverage`, `test:mutation`, `test:e2e`, `build` (sans `typecheck`/`test:e2e` si non applicable). |
| SCR-02 | Node 24 ; `package-lock.json` généré avec **npm 11** (`npx --yes npm@11 install`, puis `npm@11 ci` pour vérifier). npm 10 peut omettre des binaires optionnels et casser `npm ci`. |
| SCR-03 | *Optionnelle, projets multi-langages ou multi-services.* Point d'entrée unique : un `Makefile` dont `help` (cible par défaut) liste les cibles à partir des `## commentaires`, avec les mêmes noms que les scripts ci-dessus (`make lint`, `make test`…) ; la CI appelle ces mêmes cibles. Outils et services dans Docker, pour qu'un poste neuf démarre par `make start`. Vérifier : `make help` sort en 0. Un projet npm seul garde les scripts npm. |

### 3.2 Lint et types (`LINT-*`)

| ID | Règle |
|---|---|
| LINT-01 | `oxlint --deny-warnings`, plugins `typescript` et `oxc`. (Site statique : ESLint + Stylelint + html-validate.) |
| LINT-02 | TypeScript strict. Worker + client : **deux** `tsc` (`tsconfig.worker.json` pour `worker/`+`shared/`, `tsconfig.client.json` pour `src/`+`shared/`), car les types Cloudflare et le DOM déclarent des globaux incompatibles. JS pur : `allowJs` + `checkJs`, globaux dans `types/globals.d.ts`. |

### 3.3 Couverture (`COV-*`)

| ID | Règle |
|---|---|
| COV-01 | Seuils `lines/branches/functions/statements = 100`. |
| COV-02 | Périmètre = **tout le code applicatif**, interface comprise, en **glob** (`src/**/*.ts`), pas en liste de fichiers : un nouveau fichier est couvert d'office. |
| COV-03 | Chaque exclusion est écrite et commentée. Exclusions légitimes : types seuls (`shared/types.ts`), coque Durable Object, `worker/test/**`, points d'entrée et `*.d.ts`. |
| COV-04 | jsdom activé **par fichier** (`// @vitest-environment jsdom`), pas globalement, pour garder les tests purs rapides (une SPA dont tout le `src/` est du DOM peut l'activer globalement). |
| COV-05 | Une branche défensive devenue morte se **supprime** ; on ne la couvre pas avec un test factice. |

### 3.4 Mutation testing (`MUT-*`)

| ID | Règle |
|---|---|
| MUT-01 | Stryker avec `testRunner: "command"` (`npx vitest run <tests ciblés>`), `coverageAnalysis: "off"`. Le plugin Vitest de Stryker exécute 0 à 1 test par mutant : tous les mutants « survivent ». |
| MUT-02 | Seuils `high`, `low`, `break` = **100**. |
| MUT-03 | `tsconfigFile` vers un fichier **inexistant** (contournement TypeScript 7 : `parseConfigFileTextToJson` supprimée). |
| MUT-04 | Table `targets` : module → fichiers de test qui tuent ses mutants. Chaque mutant ne relance que ceux-là. `MUTATE` restreint le run ; un module inconnu fait échouer la config. |
| MUT-05 | Périmètre = tout le code applicatif. Un gros fichier se découpe en **plages de lignes** (`src/App.tsx:1-75`), un job par plage. Taille de départ ~75 lignes ; mesurer chaque job en CI et redécouper ceux qui dépassent ~8 min. |
| MUT-06 | Un mutant équivalent se traite en **simplifiant le code** (garde redondante, `??=`, copie défensive jamais mutée, `return` final d'un `else if`). `// Stryker disable next-line` seulement avec la raison écrite à côté, en dernier recours. |
| MUT-07 | Les tests vérifient **quelle** erreur est levée (`rejects.toBe(err)`, message exact) et, côté interface, la **structure exacte** (`outerHTML`, `getAttributeNames()`, `defaultPrevented`). |
| MUT-08 | `.github/scripts/mutation-matrix.mjs` : **même fichier dans tous les dépôts** (voir [§ 7](#7-fichiers-de-référence)). |
| MUT-09 | Trois jobs CI : `plan` → `module` (matrice, `fail-fast: false`, artefact `mutation-report-<nom>`) → **synthèse « Mutation testing (logique pure) »**, seul check requis. Le nom de la synthèse ne change jamais, même si le périmètre s'élargit. |
| MUT-10 | **La mutation complète tourne la nuit, pas à chaque PR.** `ci.yml` a un déclencheur `schedule` (une fois par nuit) et `workflow_dispatch` ; [`mutation-select.mjs`](templates/.github/scripts/mutation-select.mjs) filtre la matrice de MUT-09. *PR* : seuls les modules dont le fichier source ou de test est dans le diff, et **tous** si la PR touche autre chose (config, workflow, dépendances, fichier de `src/` non muté). *Nuit ou lancement manuel* : tous. *Push sur `main`* : aucun. Le check « Mutation testing (logique pure) » reste requis : il passe quand aucun module n'est concerné et échoue si la planification échoue. Raison : la mutation fait l'essentiel du calcul de la CI et les runners gratuits sont partagés entre dépôts ([§ 6](#6-pièges-connus)) ; relancer des dizaines de modules à chaque PR et à chaque push fait attendre tout le monde. **Limite assumée** : une PR qui modifie le module A peut tuer ou laisser survivre des mutants du module B qui l'importe ; seul le contrôle de nuit le détecte, le lendemain (GIT-04). **Objectif de durée** : 10 minutes sur les PR et les pushes ; le contrôle de nuit n'est pas borné (personne n'attend son résultat), donc inutile de découper ses modules pour le raccourcir. **Projet à un seul job de mutation (sans matrice, ex. site statique)** : même règle, sans sélection par module. Le job porte `if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'` : il tourne la nuit et à la demande, il est **sauté** sur PR et sur push (un check sauté compte comme réussi pour le ruleset), et `build` garde `if: ${{ !failure() && !cancelled() }}`. La durée du job ne change rien à la règle : un job court s'y plie aussi, pour que tous les dépôts se comportent pareil. Limite assumée : aucune mutation avant la fusion, seul le contrôle de nuit détecte une régression (GIT-04). Vérifier : `schedule` dans `ci.yml` (et `mutation-select.mjs` identique au modèle si le projet a une matrice). |

### 3.5 CI (`CI-*`)

`ci.yml`, workflow nommé **CI**, sur `pull_request` et `push` sur `main`. `permissions: contents: read`, `concurrency` annulante.

| ID | Identifiant | Nom affiché (check requis) | Présent dans |
|---|---|---|---|
| CI-01 | `lint` | Linter | tous |
| CI-02 | `typecheck` | Vérification des types | tous sauf site statique |
| CI-03 | `unit-tests` | Tests unitaires + couverture | tous |
| CI-04 | `e2e-tests` | Tests fonctionnels (Playwright) | tous sauf site statique |
| CI-05 | `mutation-testing` | Mutation testing (logique pure) | tous |
| CI-06 | `audit` | Audit des dépendances | tous |
| CI-07 | `worker-tests` | Worker de synchronisation | SPA et JS sans build avec Worker de synchro |
| CI-08 | `build` | Build de production | tous ; `needs` = tous les jobs ci-dessus |
| CI-09 | `analyze` (`codeql.yml`) | Analyse | tous |

> Les noms affichés sont ceux que le **ruleset exige** : les changer sans mettre le ruleset à jour bloque toutes les PR.

| ID | Règle |
|---|---|
| CI-10 | Audit en deux commandes dans le même job : `npm audit --omit=dev --audit-level=moderate` (production), puis l'audit complet au niveau `high` par `node .github/scripts/audit-check.mjs --level=high` (tout, CI-13). Un avis de production sans correctif se documente à côté de la commande ; un avis de développement sans correctif passe par CI-13. |
| CI-11 | Artefacts conservés 14 jours ; sur PR, upload de `pr-build-preview` (7 jours). |
| CI-12 | Playwright : `webServer` = `vite dev --port 5173 --strictPort --host 127.0.0.1` (`localhost` se résout en IPv6 seul sur les runners), timeout 120 s, `retries: 1` et `forbidOnly` en CI, `trace: "on-first-retry"`. |
| CI-13 | **Un avis sans correctif ne se contourne pas en baissant le seuil, il s'exempte par écrit.** [`audit-check.mjs`](templates/.github/scripts/audit-check.mjs) (identique dans tous les dépôts) remplace `npm audit --audit-level=high` dans `ci.yml` et `audit.yml` : il échoue sur tout avis de gravité `high` ou plus, sauf ceux de [`.github/audit-exceptions.json`](templates/.github/audit-exceptions.json) (`{ "id": "GHSA-…", "reason": "…", "expires": "AAAA-MM-JJ" }`, `[]` par défaut). Une exception a une **raison** et une **date d'expiration** (30 jours au plus, à renouveler après vérification qu'aucun correctif n'est sorti) ; expirée, elle ne protège plus et l'audit repasse au rouge ; sans effet (l'avis a disparu), elle est signalée pour être retirée. Réservé aux dépendances de **développement** : l'audit de production (CI-10) n'a pas d'exception. Raison : un avis publié sans version corrigée (cas du § 6) laisse l'audit rouge sur toutes les PR sans aucune action possible ; baisser le seuil masquerait aussi tous les futurs avis, alors qu'une exception nomme un seul avis et expire. Vérifier : `audit-check.mjs` identique au modèle et appelé par `ci.yml`. |

### 3.6 Sécurité (`SEC-*`)

| ID | Règle |
|---|---|
| SEC-01 | **Toutes les actions sont épinglées par SHA** : `uses: actions/checkout@<sha 40 car.> # v7`, jamais `@v7`. Un tag peut être déplacé vers du code malveillant (cas réel : `tj-actions/changed-files`, 2025). Retrouver le SHA : `gh api repos/<action>/git/ref/tags/<tag>` (si l'objet est de type `tag`, suivre `git/tags/<sha>`). |
| SEC-02 | `dependabot.yml` : `npm` (devDependencies groupées) et `github-actions` (toutes groupées en **une** PR), hebdomadaire, 10 PR maximum. Il met à jour SHA et commentaire. |
| SEC-03 | `codeql.yml` (push, PR, lundi 3 h UTC). **Ne pas activer le « default setup »** tant que ce workflow existe : GitHub refuse alors ses envois. Dépôt privé : exige GitHub Advanced Security. |
| SEC-04 | `audit.yml` planifié (lundi 4 h UTC + `workflow_dispatch`) avec les mêmes niveaux que CI-10. |
| SEC-05 | Toute valeur qui finit dans un attribut HTML est revalidée côté serveur (longueurs, formats) **et** échappée au rendu. Jamais l'un sans l'autre. |
| SEC-06 | Rate limiting Cloudflare sur chaque route d'écriture sans authentification. |
| SEC-07 | Ne jamais promettre plus que le modèle d'accès ; l'interface le dit. |

### 3.7 Ruleset et workflow de contribution (`GIT-*`)

| ID | Règle |
|---|---|
| GIT-01 | `.github/rulesets/main.json` versionné dans chaque dépôt, appliqué avec `apply-rulesets.sh`. Tous les checks de CI-01…CI-09 requis, branche à jour avant fusion. |
| GIT-02 | PR obligatoire, conversations résolues, 0 approbation exigée, historique linéaire, pas de force-push ni de suppression, fusion par **rebase** uniquement, aucun contournement. |
| GIT-03 | **Ordre** : si une PR renomme un check requis, appliquer d'abord le ruleset (la PR produit déjà le nouveau nom) ; sinon fusionner puis appliquer. Après un changement de checks, `@dependabot rebase` sur les PR Dependabot ouvertes. |
| GIT-04 | Une CI rouge se corrige et se repousse ; un check rouge sur `main` (nouvel avis d'audit) se corrige dans la PR suivante, sans traîner. Le contrôle de mutation de nuit (MUT-10) suit la même règle : s'il échoue, le module en cause se corrige dans la PR suivante. |
| GIT-05 | *Choix du propriétaire, à adapter :* messages de commit et commentaires en français. Les préfixes suivent GIT-07. |
| GIT-06 | Avec un assistant : il ouvre les PR et surveille la CI ; **le propriétaire fusionne** et déclenche lui-même les déploiements. |
| GIT-07 | Commits **atomiques**, au format conventionnel `type(portée): sujet` (`feat`, `fix`, `refactor`, `test`, `ci`, `build(deps)`, `docs`, `chore`), à l'impératif, qui disent le *pourquoi*. Une refonte imposée par une contrainte de qualité (longueur, complexité) est un commit `refactor` à part. Les commits des bots suivent le même format (`build(deps): bump …`). Raison : un historique lisible et filtrable, qui alimente le versionnement automatique ([§ 3.14](#314-versionnement-ver)). Appliqué par les checks « Titre de PR conventionnel » et « Commits conventionnels » (VER-04). Vérifier : `check-conformity.sh` affiche la part de commits conformes sur les 100 derniers. |

### 3.8 Déploiement (`CD-*`)

| ID | Règle |
|---|---|
| CD-01 | `on: workflow_run: workflows: [CI], types: [completed], branches: [main]` + `workflow_dispatch`, avec `if: … conclusion == 'success'`. Un push direct ne déploie jamais un commit rouge. Ne renommer **CI** qu'en changeant aussi les workflows de déploiement. |
| CD-02 | Checkout du **commit testé** : `ref: ${{ github.event.workflow_run.head_sha \|\| github.sha }}`. `concurrency` **sans** `cancel-in-progress`. |
| CD-03 | Test de fumée après déploiement : accueil en 200 et une route d'API en 404 (le Durable Object répond, sans rien créer). Sauté si `vars.DEPLOY_URL` est vide. |
| CD-04 | Cloudflare : tag `deploy-N` après chaque déploiement (`contents: write` limité à ce workflow). Worker de synchro : `worker-deploy-*`, redéployé seulement si `worker/` a changé. |
| CD-05 | Double origine Cloudflare + Pages : `VITE_SYNC_WORKER_URL`, `VITE_BASE_PATH`, `cp index.html 404.html` (repli SPA), CORS explicite sur chaque méthode HTTP utilisée (jamais sur la route WebSocket). |
| CD-06 | `wrangler r2 bucket create` (idempotent) avant `wrangler deploy` : un bucket R2 n'est pas provisionné tout seul. |
| CD-07 | **Ne jamais** relancer un déploiement Pages avec `gh run rerun --failed` (second artefact `github-pages`, « Multiple artifacts … count is 2 ») : lancer un nouveau run en `workflow_dispatch`. |

### 3.9 Documentation (`DOC-*`)

| ID | Règle |
|---|---|
| DOC-01 | `CLAUDE.md` : Commandes (dont « lancer un seul test »), Architecture, Philosophie de test (unitaire vs e2e, pourquoi), CI/CD, Modèle de confidentialité/sécurité, Pièges locaux. |
| DOC-02 | Les décisions coûteuses (runner Stryker, périmètre de couverture, bug CORS passé en prod) y sont écrites **avec leur raison**. |
| DOC-03 | Les règles propres à un module (ex. plages de lignes d'un gros `app.js`) sont décrites dans son `CLAUDE.md`, avec la commande pour les relancer. |
| DOC-04 | `doc/` = vérité stable, écrite pour un humain **et** un agent : `architecture.md`, `codage.md` (conventions, « À faire / À éviter »), et un backlog priorisé impact/effort (`improvement.md`). Raison : `CLAUDE.md` reste court et renvoie ici pour le détail. Vérifier : le dossier existe et `CLAUDE.md` le référence. |
| DOC-05 | `docs/` = travail daté, un **spec puis un plan** par chantier (`YYYY-MM-DD-sujet.md`, [modèle](templates/docs/YYYY-MM-DD-sujet.md)). Les plans citent les fichiers (`fichier:ligne`) ; un plan réussi sert de modèle au suivant. Raison : la décision et son contexte survivent à la PR. |

### 3.10 Architecture exécutable (`ARCH-*`)

| ID | Règle |
|---|---|
| ARCH-01 | `.dependency-cruiser.cjs` versionné ([modèle](templates/.dependency-cruiser.cjs)) : pas de cycle, pas de fichier orphelin (code mort, voir COV-05), sens des dépendances entre `shared/`, `worker/`, `src/`, et `src/lib/` (pur) sans import de l'interface. Raison : une règle écrite dans `CLAUDE.md` seule se viole en silence. Équivalents : Deptrac (PHP), import-linter (Python), `depguard` (Go). |
| ARCH-02 | Le contrôle est **dans `npm run lint`** (`oxlint … && depcruise src worker shared`) : il tourne dans le check requis « Linter », sans ajouter de job ni toucher au ruleset. Avec TypeScript ≥ 7, `dependency-cruiser` ne lit plus les sources : ajouter `@swc/core` en devDependency, sinon il annonce « 0 modules » et ne bloque rien (piège du § 6). |
| ARCH-03 | Une exception à une règle se **documente à côté** (`pathNot` ou commentaire avec la raison), jamais un assouplissement global. Même esprit que MUT-06. |
| ARCH-04 | **Sans modules ES, pas de graphe à vérifier.** Un projet de scripts classiques (`<script src>`, espace de noms global) n'a aucun `import` : `dependency-cruiser` y voit tous les fichiers orphelins. ARCH-01 et ARCH-02 ne s'appliquent alors pas ; l'architecture est l'**ordre des balises `<script>`** (un fichier n'utilise que les espaces de noms chargés avant lui), décrit dans `doc/architecture.md`. L'écart se déclare dans `CLAUDE.md`, section « Écarts au guide », en citant `ARCH-01`. Raison : une règle qu'aucun outil ne peut vérifier s'écrit, elle ne se simule pas. Vérifier : `check-conformity.sh` accepte l'absence de `.dependency-cruiser` seulement si l'écart est déclaré. |

### 3.11 Mises à jour automatiques (`UPD-*`)

| ID | Règle |
|---|---|
| UPD-01 | `node-updates.yml` planifié ([modèle](templates/.github/workflows/node-updates.yml)) : monte la version LTS de Node dans les workflows, `.nvmrc` et `engines`, branche stable `bump-node-version` réutilisée si une PR est ouverte. Raison : Dependabot ne sait pas le faire. |
| UPD-02 | Ces workflows ouvrent leurs PR avec un **jeton dédié** (secret `UPDATE_TOKEN`), pas `GITHUB_TOKEN` : une PR ouverte avec ce dernier ne déclenche pas la CI. |
| UPD-03 | Ces PR **ne changent que des numéros de version**, et le disent dans leur description : une CI rouge signale un travail manuel. La CI trie, pas l'humain. |
| UPD-04 | `major-updates.yml` planifié ([modèle](templates/.github/workflows/major-updates.yml)) : **une PR par paquet** en retard d'une version majeure, pour qu'une montée qui casse n'en bloque pas d'autres. |

### 3.12 Application installable (`PWA-*`)

S'applique aux projets qui se servent d'un service worker (`vite-plugin-pwa`). Aucun nouveau check requis : les contrôles tournent dans « Tests unitaires + couverture » et « Tests fonctionnels (Playwright) ».

| ID | Règle |
|---|---|
| PWA-01 | Manifeste complet : `name`, `short_name`, `display`, icônes 192 et 512 dont une `maskable`, `theme_color`. `start_url` et `scope` suivent `VITE_BASE_PATH` (déploiement Pages sous un sous-chemin). Raison : sans cela l'installation échoue ou ouvre une page 404. Vérifier : un test lit `dist/manifest.webmanifest` après `build` et contrôle ces champs. |
| PWA-02 | `generateSW` par défaut : le service worker est produit, pas écrit. Un service worker écrit à la main (`injectManifest`) entre dans le périmètre de couverture et de mutation (COV-02, MUT-05) ; à ne choisir qu'avec un besoin documenté. |
| PWA-03 | Le service worker ne met jamais en cache l'API ni le WebSocket : `navigateFallbackDenylist` couvre les routes d'API et de synchro. Raison : une réponse d'API servie depuis le cache masque les données à jour et casse la synchronisation. Vérifier : un e2e vérifie qu'une route d'API répond depuis le réseau. |
| PWA-04 | Mise à jour **annoncée**, jamais silencieuse : `registerType: "prompt"` (pas `autoUpdate`), l'application affiche « nouvelle version disponible » (`onNeedRefresh`) et l'utilisateur recharge quand il veut. La logique (état, rechargement) est dans une fonction pure, couverte et mutée. Raison : avec `autoUpdate`, la page se recharge d'elle-même au déploiement et une saisie en cours est perdue. Vérifier : `registerType: "prompt"` dans `vite.config`, et un test du composant de mise à jour. |
| PWA-05 | Test e2e **hors ligne** : après un premier chargement, `context.setOffline(true)` puis rechargement ; l'interface s'affiche et dit qu'elle est hors ligne. Raison : c'est la promesse de la PWA, et jsdom ne la teste pas. Le test tourne sur le **build de production** (le service worker n'existe pas sous `vite dev`) : un second `webServer` `build` + `preview` ou un projet Playwright dédié. Avec `registerType: "prompt"` le service worker ne prend le contrôle qu'au chargement suivant : recharger une fois avant de couper le réseau. Vérifier : `context.setOffline` dans `e2e/` (un simple mock nommé `setOffline` ne compte pas). |
| PWA-06 | *(abandonnée, version 2.0)* Cache de `sw.js` par `_headers` : aucun projet ne le fait et GitHub Pages ne permet pas de régler ces en-têtes. |
| PWA-07 | `vite-plugin-pwa` et workbox sont des dépendances de **développement**. L'audit de production (CI-10) ne doit rien remonter à leur sujet ; un avis transitif sans correctif se documente comme exception datée, à côté de la commande d'audit. |
| PWA-08 | *(abandonnée, version 2.0)* Règle sans équivalent dans les projets. |

### 3.13 Backend PHP/Symfony (`PHP-*`)

Famille à part : les noms de checks de CI-03, CI-05 et CI-06 restent identiques ; les règles de § 3.1 à 3.5 sont remplacées par leurs équivalents PHP ci-dessous. SEC, GIT, UPD, DOC et ARCH (avec Deptrac) s'appliquent tels quels. Modèles : dossier [`templates/php/`](templates/php/), qui reprend l'arborescence d'un dépôt PHP (`Makefile`, configs, `tools/`, `.github/`).

**Checks requis (ruleset PHP, [`templates/php/.github/rulesets/main.json`](templates/php/.github/rulesets/main.json))** : un job par outil, pour qu'un échec se lise seul. Pas de CodeQL (PHP non pris en charge) : SEC-03 ne s'applique pas.

| Workflow | Checks |
|---|---|
| `ci_codequality.yml` | EditorConfig · Format (PHP-CS-Fixer) · Complexité (PHPMD) · Analyse statique (Psalm) · Analyse statique (PHPStan) · Architecture (Deptrac) |
| `ci_infraquality.yml` | Linter Docker Compose · Linter Dockerfile · Linter DotEnv · Références des mocks |
| `conventional_commits.yml` | Titre de PR conventionnel · Commits conventionnels (GIT-07) |
| `ci_tests.yml` | Tests unitaires · Tests d'intégration · **Tests unitaires + couverture** (CI-03) · **Mutation testing (logique pure)** (CI-05, `needs` la couverture, qui lui passe `build/coverage` en artefact) |
| `security.yml` | **Audit des dépendances** (CI-06), aussi planifié le lundi (SEC-04) |

**Squelette Symfony minimal** (`composer.json`, `src/Kernel.php`, `config/`, `public/`, `bin/console`, un `HealthController` + `HealthService` avec leurs tests unitaire et d'intégration) : le projet démarre et **toutes les cibles sont vertes à vide** (`make code-quality infra-quality tests measures security`, couverture et MSI à 100 %). On y ajoute ses classes en gardant le vert ; les dossiers vides (`src/Calculator/`, `src/Repository/`, `src/DTO/Response/`, `src/Entity/`) portent un `.gitkeep` parce que `psalm.xml` et `deptrac.yaml` les citent. Les migrations passent avec `--allow-no-migration` tant qu'il n'y en a pas. `composer.json` vide le cache à chaque `install`/`update` (script `post-install-cmd`), ce que la cible `php_prod` du `Dockerfile` appelle pour compiler le cache de production.

**Image de production vérifiée** (`php_prod`) : construite, lancée derrière nginx, `/health` répond `up`, un autre `.php` répond 404, aucun paquet de dev dans `vendor/`, cache `prod` compilé, `opcache.validate_timestamps` coupé, `RUN_MIGRATIONS=true` passe sans migration. Le compose fourni déclare un healthcheck sur la base (`pg_isready`) et `depends_on: condition: service_healthy` sur le service PHP ; une pile de production doit faire de même, car `RUN_MIGRATIONS` s'arrête à la première connexion refusée.

**Base Docker** : `.docker/php/Dockerfile` (cibles `php_base`, `php_dev`, `php_prod`), `docker-compose.yaml` (PostgreSQL, PHP, nginx liés à `127.0.0.1`, serveur de mock en exemple commenté), `.docker/nginx/`, `docker-compose.override.yaml.dist`, `.dockerignore`, `.env.ci` et `.env.dev` (valeurs de test, aucun secret). À adapter : extensions PHP, base de données, mocks, noms de services.

**Montée de PHP et des images épinglées (UPD-01)** : [`templates/php/scripts/infra-updates.py`](templates/php/scripts/infra-updates.py) et son workflow `infra-updates.yml` (une PR par cible, `php` et `pins`) modifient l'image du `Dockerfile`, la contrainte `php` de chaque `composer.json`, les hashes des lockfiles, `setup-php` et les images des linters épinglées dans le Makefile et les workflows. Dependabot ignore `php` dans son bloc `docker`.

**Release et déploiement (GIT-07, PHP-13)** : `release.yml` (semantic-release, `.releaserc.json`) crée une prerelease à chaque push sur `main` ; `push.yml` construit l'image arm64 + amd64, le manifest multi-arch, puis ouvre la PR de bump sur le dépôt d'infra (secrets `RELEASE_TOKEN`, `INFRA_TOKEN`, variables `INFRA_REPOSITORY` et `INFRA_STACK_PATH`). Hook local : `.githooks/commit-msg` (`make hooks`). **Documentation** : `CLAUDE.md` et `doc/` types (`architecture`, `codage`, `improvement`, `update`).

| ID | Règle |
|---|---|
| PHP-01 | **Tout dans Docker, tout par `make`** (SCR-03 devient obligatoire) : `make start` met un poste neuf en route, `make help` documente les cibles, des alias courts (`t`, `q`, `a`). La CI appelle les mêmes cibles. L'hôte n'a aucune toolchain PHP. |
| PHP-02 | Chaque outil qualité a **son propre `composer.json`** dans `tools/<outil>/`, installé à la demande par une règle Make. Raison : pas de conflit de dépendances avec l'application, mise à jour indépendante. |
| PHP-03 | Format : PHP-CS-Fixer (`@PER-CS`, `@Symfony`), `check --diff` en CI, `fix` en local. `declare(strict_types=1)` partout (imposé par le fixer). |
| PHP-04 | Analyse statique : PHPStan **niveau max**, sur `src` **et** `tests` ; Psalm strict en complément avec `--find-unused-psalm-suppress`. PHPMD (complexité, taille, nommage) sur `src` et `tests`. Un `@psalm-suppress` ou `@codeCoverageIgnore` est une exception documentée. Une baseline sert à *entrer* dans un projet existant, avec la commande de mise à jour dans `CLAUDE.md` et l'objectif de la vider. |
| PHP-05 | Architecture : **Deptrac** `--report-uncovered --fail-on-uncovered` ; couches `Controller → Service → Calculator → Repository`, sans saut de couche. Une classe hors couche fait échouer la CI (ARCH-01). |
| PHP-06 | Règles de fond vérifiables par les outils ci-dessus : classes concrètes `final` (sauf celles qu'on mocke), `#[\Override]`, contrôleurs sans logique métier, validation des entrées par DTO, SQL complexe dans des fichiers `.sql`, valeurs métier en configuration, aucun `catch (\Exception)` sans re-lancement ni log. |
| PHP-07 | Couverture de lignes **100 %** (script qui échoue sous le seuil et génère le HTML en cas d'échec). Chaque classe de test porte `/** @internal */` et `#[CoversClass(Cible::class)]` : sans cela la couverture ne compte pas la classe. |
| PHP-08 | Mutation **Infection**, MSI et covered MSI à **100** (`--min-msi=100 --min-covered-msi=100` dans le Makefile et la CI), `--filter=src`, réutilise la couverture déjà produite (équivalent de MUT-02). Un mutant équivalent se traite en simplifiant le code (MUT-06). |
| PHP-09 | Deux niveaux : **unitaire** (dépendances mockées, aucune base) et **intégration** (vraie base, un serveur de mock HTTP (Moco, [`templates/php/.docker/moco/`](templates/php/.docker/moco/Dockerfile)) qui rejoue des fixtures JSON). **Jamais de faux client HTTP en intégration** : on teste le vrai client. |
| PHP-10 | Hygiène des mocks vérifiée en CI (`make check-moco-refs`, scripts de `tools/`) : aucune référence cassée, aucun fichier de mock orphelin ; `make clean-unused-files` et `make clean-moco-routes` retirent les mocks que plus aucun test n'utilise. Validation JSON des fixtures : `make jsonlint`. `doctrine:schema:validate --skip-sync` avant les tests : la CI échoue si entités et migrations divergent. |
| PHP-11 | `composer audit` sur l'application **et sur chaque outil** de `tools/`, dans **un seul job** « Audit des dépendances » (`composer audit --locked` lit `composer.lock` sans rien installer ; sans `--locked`, Composer exige un `vendor/`), à chaque PR et en tâche planifiée (CI-10, SEC-04). |
| PHP-12 | Mises à jour : Dependabot pour `composer` (application et chaque `tools/*`), `docker`, `docker-compose` et `github-actions` (quotidien, groupés). La version de PHP elle-même (image Docker, contrainte `php` de **tous** les `composer.json`, `setup-php`, doc) et les majeures Composer (une PR par projet composer) passent par des workflows maison (UPD-01, UPD-04). |
| PHP-13 | *Optionnelle.* Déploiement conteneurisé ([`push.yml`](templates/php/.github/workflows/push.yml), [`release.yml`](templates/php/.github/workflows/release.yml)) : une release publiée construit l'image **arm64 et amd64 en parallèle** (runners natifs), pousse un manifest multi-arch versionné, écrit la version dans un fichier lu par l'application, puis ouvre une PR sur le dépôt d'infrastructure qui bump la version. Rollback = revert de PR. Jeton dédié (UPD-02). Remplace CD-01 pour ce type de projet. Variante de VER-03 : la release est créée en *prerelease* (staging) et sa publication la promeut en production. |
| PHP-14 | *Projets avec interface.* Tests navigateur **Chrome et Firefox en parallèle** (Panther + Selenium), dans leur propre suite `Browser Test Suite`, exclue de la couverture et de la mutation. Raison : un comportement qui diffère selon le navigateur ne se voit pas avec un seul. Checks « Tests navigateur (Chrome) » et « Tests navigateur (Firefox) ». Modèles : [`templates/php-ui/`](templates/php-ui/). |
| PHP-15 | *Projets avec interface.* **Validation W3C** du HTML (validateur `vnu`) des pages listées dans `tools/w3c-validate/w3c_validate.sh`, récupérées sur le vhost de test ; deux URLs distinctes au contenu identique, ou une page qui ne répond pas le code attendu, échouent. Raison : une page de connexion ou d'erreur servie à la place de la vraie page serait validée sans que personne le voie. Check « Validation W3C ». |


### 3.14 Versionnement (`VER-*`)

Le numéro de version n'est jamais choisi par une personne : il se **déduit des commits**. Une release = un tag `vX.Y.Z` + une release GitHub aux notes générées.

| ID | Règle |
|---|---|
| VER-01 | [Semantic Versioning](https://semver.org/lang/fr/) `MAJEURE.MINEURE.CORRECTIF`, tag `vX.Y.Z` sur `main`, **source de vérité unique**. Aucun numéro écrit à la main : le champ `version` de `package.json` (ou de `composer.json`) n'est pas tenu à jour, et aucun `CHANGELOG.md` n'est maintenu à la main (les notes sont générées, VER-03). Raison : un numéro saisi diverge du tag, un changelog manuel s'oublie. |
| VER-02 | **Correspondance commit → version** (GIT-07), appliquée par [`.releaserc.json`](templates/.releaserc.json) : `feat` → mineure ; `fix`, `perf`, `build(deps)` → correctif ; `!` après le type ou pied `BREAKING CHANGE:` → majeure ; `docs`, `style`, `refactor`, `test`, `ci`, `chore`, `revert`, et `build` sans portée `deps` → **aucune release**. Raison : un refactor ou une montée d'outil de développement ne change rien pour l'utilisateur. Vérifier : `.releaserc.json` présent et ses règles identiques au modèle. |
| VER-03 | `release.yml` ([modèle](templates/.github/workflows/release.yml)) : à chaque push sur `main`, `semantic-release` calcule la version, crée le tag, puis la release GitHub (`gh release create --generate-notes`). Pas de condition sur la CI : le ruleset (GIT-01) ne laisse arriver sur `main` qu'un commit dont les checks sont verts. `concurrency` sans `cancel-in-progress`, `fetch-depth: 0` (il lit l'historique depuis le dernier tag). Famille PHP conteneurisée : la release est une *prerelease* qu'on promeut en la publiant (PHP-13). |
| VER-04 | **Les messages sont contrôlés avant la fusion** : `conventional_commits.yml` ([modèle](templates/.github/workflows/conventional_commits.yml), identique dans toutes les familles) avec les checks requis « Titre de PR conventionnel » et « Commits conventionnels » (règles : [`.commitlintrc.json`](templates/.commitlintrc.json)), plus le hook local [`.githooks/commit-msg`](templates/.githooks/commit-msg) (`git config core.hooksPath .githooks`, ou `make hooks` en PHP). Raison : la fusion est un *rebase* (GIT-02), donc chaque commit de la PR devient un commit de `main` et se lit tel quel : un seul message non conforme fausse le numéro. |
| VER-05 | **Aucun commit de release sur `main`** : pas de plugin `@semantic-release/git` ni `@semantic-release/changelog`, pas de `[skip ci]`. Raison : le ruleset interdit les poussées directes (GIT-02), et un commit de release relancerait la CI en boucle. |
| VER-06 | **Dependabot parle conventionnel** : `commit-message` avec `prefix: build` (dépendances de production), `prefix-development: chore`, `include: scope` pour npm/Composer, `prefix: ci` pour les actions. Raison : une montée de dépendance de production donne `build(deps)` → version correctif ; une montée d'outil de développement ne publie rien. **Chaque** entrée `npm`, `composer` et `github-actions` porte son propre `commit-message` : Dependabot ne l'hérite pas d'une entrée à l'autre, et une entrée sans lui garde « Bump … », que VER-04 refuse. Vérifier : autant de `commit-message` que d'entrées `package-ecosystem` dans `dependabot.yml`. |
| VER-07 | Le jeton qui crée la release doit être **adapté à ce qui doit la suivre** : `GITHUB_TOKEN` suffit si rien ne réagit à la release ; si un workflow doit démarrer sur la release (déploiement de PHP-13, `on: release`), utiliser le jeton dédié `RELEASE_TOKEN` (UPD-02), car les événements créés avec `GITHUB_TOKEN` ne déclenchent aucun workflow. |
| VER-08 | Les tags de déploiement de CD-04 (`deploy-N`, `worker-deploy-*`) restent **distincts** des tags de version `v*` : les premiers numérotent des déploiements, les seconds des versions. `tagFormat` de semantic-release ne reconnaît que `v*`. |

**Première version** : sans tag existant, `semantic-release` publie `v1.0.0`. Pour démarrer plus bas, poser à la main un tag `v0.1.0` sur le commit voulu avant la première exécution. **Rejouer sur un dépôt existant** : fusionner d'abord `conventional_commits.yml` et son ruleset (GIT-03) ; les anciens commits non conformes sont ignorés par `semantic-release`, qui ne regarde que ceux d'après le dernier tag.

**Modèles** : [`.releaserc.json`](templates/.releaserc.json), [`release.yml`](templates/.github/workflows/release.yml), [`conventional_commits.yml`](templates/.github/workflows/conventional_commits.yml), [`.commitlintrc.json`](templates/.commitlintrc.json), [`.githooks/commit-msg`](templates/.githooks/commit-msg), préfixes de commit dans [`dependabot.yml`](templates/.github/dependabot.yml).

---

## 4. Recette nouveau projet

Chaque étape est vérifiable avant la suivante. Les seuils sont posés **avant** le premier vrai code.

1. **Scripts et Node 24** — SCR-01, SCR-02. Vérifier : `npm@11 ci` passe.
2. **Lint, architecture et types** — LINT-01, LINT-02, ARCH-01…03. Vérifier : `npm run lint && npm run typecheck`.
3. **Découpage** — `shared/`, `worker/` (réducteur pur + coque), `src/`. Décider ce qui est unitaire et ce qui est e2e ; l'écrire dans `CLAUDE.md` (DOC-01).
4. **Vitest à 100 %** — COV-01…COV-05 ([§ 7](#7-fichiers-de-référence)). Vérifier : `npm run test:coverage`.
5. **Playwright** — CI-12 ([§ 7](#7-fichiers-de-référence)). Vérifier : `npm run test:e2e`.
6. **Stryker + matrice** — MUT-01…MUT-09 ([§ 7](#7-fichiers-de-référence)). Vérifier : `MUTATE=<module> npx stryker run`, puis `node .github/scripts/mutation-matrix.mjs`.
7. **`ci.yml`** aux noms du standard — CI-01…CI-11 ([§ 7](#7-fichiers-de-référence)).
8. **`codeql.yml`, `audit.yml`, `dependabot.yml`, `node-updates.yml`, `major-updates.yml`** — SEC-01…SEC-04, UPD-01…04, actions épinglées dès le départ ; créer le secret `UPDATE_TOKEN`.
9. **Versionnement** — VER-01…VER-08 : `.commitlintrc.json`, `conventional_commits.yml`, hook, `.releaserc.json`, `release.yml`.
10. **Ruleset** — GIT-01…GIT-03 ([§ 7](#7-fichiers-de-référence)). Vérifier en ouvrant une PR : les 10 checks apparaissent requis.
11. **Déploiement** — CD-01…CD-07, environnement GitHub nommé, variable `DEPLOY_URL`.
12. **Documentation** — `CLAUDE.md` (DOC-01…DOC-03), `doc/` (DOC-04) ; `docs/` dès le premier chantier (DOC-05).

---

## 5. Adopter le standard sur un projet existant

Principe : **une règle ou une famille de règles par PR**, CI verte entre chaque, jamais de seuil abaissé. Ordre conseillé, du moins risqué au plus coûteux :

| Étape | Règles | Coût | Remarque |
|---|---|---|---|
| 1 | SCR-01/02, LINT-*, DOC-*, GIT-07 | faible | À faire en premier : tout le reste s'appuie dessus. |
| 2 | SEC-01…SEC-04 (SHA, Dependabot, CodeQL, audit planifié), UPD-01…04 | faible | Une PR mécanique, sans changement de code. Créer `UPDATE_TOKEN` avant de fusionner UPD. |
| 2 bis | ARCH-01…04 | moyen | Commencer avec les seules règles que le code respecte déjà (cycles, `shared/`), puis resserrer. Fichiers orphelins : les supprimer (COV-05). |
| 3 | CI-01…CI-11 aux noms du standard | moyen | **Avant** de fusionner : appliquer le ruleset si des noms changent (GIT-03). |
| 4 | GIT-01…GIT-03 (ruleset) | faible | Le ruleset exige des checks qui doivent exister, donc après l'étape 3. |
| 5 | CD-01…CD-07 | moyen | Remplacer un déploiement sur push par `workflow_run`. |
| 6 | COV-* (couverture 100 %) | **élevé** | Étendre le périmètre fichier par fichier (voir § 5.1). |
| 7 | MUT-* (mutation 100 %) | **élevé** | Un module à la fois (voir § 5.2). |

### 5.1 Atteindre 100 % de couverture sur du code existant

1. Poser le seuil à 100 avec un `include` **limité** aux fichiers déjà couverts ; chaque PR ajoute des fichiers **et** leurs tests, donc le seuil ne passe jamais sous 100.
2. Une fois tout couvert, remplacer la liste par un glob (COV-02).
3. Branche défensive morte : la supprimer (COV-05).

### 5.2 Atteindre 100 % de mutation sur du code existant

1. **Un dépôt à la fois, un module à la fois, un seul Stryker à la fois** (sinon des mutants expirent et sont comptés tués : un dépôt a annoncé 96 % pour 89 % réel).
2. **État de référence** : lancer Stryker module par module, en séquence ; noter durée, score et survivants. Un petit script qui imprime un survivant par ligne (`fichier:ligne  mutateur  remplacement`) évite de lire le rapport HTML.
3. **Classer chaque survivant** :
   - *test trop faible* → renforcer l'assertion (structure exacte, message d'erreur, attributs, `defaultPrevented`) ;
   - *mutant équivalent* → simplifier le code (MUT-06) ;
   - *test vide de sens* → le réécrire (voir § 6).
4. **Ne pas croire un test neuf** : appliquer la mutation à la main dans le source, vérifier que le test échoue, restaurer.
5. Relancer le strict nécessaire (`MUTATE=module` ou `MUTATE=fichier:début-fin`). Si le source change, les numéros de ligne bougent : recalculer les plages.
6. Machine sans Node : conteneur `node:24 --cpus=4`, `npm ci` d'abord, `chown` du dépôt à la fin.
7. En CI : mesurer chaque job, redécouper ceux qui dépassent ~8 min (sur un gros fichier JS, des plages de 150 lignes allaient de 6 à 19 min ; les zones denses sont descendues à 35-50 lignes).

**Résultat attendu** : un run complet de 5 à 10 min (job le plus long : de 3 min 25 à 9 min selon le dépôt).

---

## 6. Pièges connus

### CI et dépendances
- **Lockfile et npm 10** : voir SCR-02.
- **Architecture exécutable muette** : avec TypeScript 7, `depcruise` sans `@swc/core` annonce « 0 modules cruised » et réussit. Vérifier que le nombre de modules analysés n'est pas nul (ARCH-02). Découvert au rejeu sur une application.
- **Renommer un check requis** : toutes les PR attendent indéfiniment ; appliquer le ruleset avant de fusionner (GIT-03).
- **Serveur de dev invisible en CI** : sans `--host 127.0.0.1`, Playwright attend en vain (CI-12).
- **Dependabot sans préfixe sur une entrée** : `commit-message` se règle par entrée `package-ecosystem`, sans héritage. Une entrée oubliée (typiquement `npm` à la racine, quand `/worker` et `github-actions` l'avaient) ouvre des PR « Bump … » qui échouent à « Titre de PR conventionnel » et « Commits conventionnels » (VER-04). Corriger l'entrée, puis `@dependabot rebase` sur les PR ouvertes (le titre est régénéré). Découvert sur trois dépôts dont seules les entrées secondaires étaient configurées (VER-06).
- **PR de bot sans CI** : une PR ouverte par un workflow avec `GITHUB_TOKEN` ne déclenche aucun workflow, donc les checks requis n'arrivent jamais et la PR reste bloquée. Jeton dédié (UPD-02). Un projet PHP l'évite avec un secret propre à sa PR de déploiement.
- **Exemple de clé dans la doc** : un README de backend PHP contenait un exemple de clé d'API qui ressemblait à une vraie. Toujours un placeholder (`<votre-clé>`) ; révoquer si c'était une vraie.

- **Avis d'audit sans version corrigée** : un avis `high` sur une dépendance de développement transitive (ReDoS dans `picomatch`, toutes versions jusqu'à la dernière, 19 octobre 2026) a fait échouer « Audit des dépendances » sur tous les dépôts le jour de sa publication. `npm audit fix` n'y change rien et sa suggestion `--force` est un retour en arrière (ancienne majeure d'un outil). Ne pas baisser le seuil : poser une exception datée (CI-13), puis la retirer quand un correctif sort.

### Mutation testing
- **CI longue à cause de la file d'attente, pas du calcul** : un push qui lance la CI de plusieurs dépôts en même temps (quatre dépôts à 40-60 jobs) se partage vraisemblablement le quota de jobs simultanés du compte (hypothèse non vérifiée : le plan n'était pas lisible par l'API) ; des jobs de 5 min attendaient 23 min un runner (durée réelle 25-33 min contre 12-18 min pour un dépôt seul). Mesurer la somme des durées de jobs, la durée du plus long et la concurrence atteinte avant de redécouper ; réduire le calcul total (MUT-10) plutôt que multiplier les jobs. Mesuré sur les dépôts de référence.
- **Job « skipped » en amont qui saute le build** : un job sans `if` porte un `success()` implicite qui exige que *tous* ses ancêtres aient réussi, y compris ceux de plus haut dans la chaîne `needs`. Avec MUT-10, les modules de mutation sont *skipped* sur un push ou une PR sans module concerné, et `build` l'était aussi alors que ses `needs` directs étaient verts. Ajouter `if: ${{ !failure() && !cancelled() }}` au job final. Découvert sur le premier push après le passage à la mutation de nuit.
- **Mutation en parallèle** : plusieurs runs saturent la machine, des mutants expirent et sont comptés tués. Mesurer un dépôt à la fois.
- **Toute la suite par mutant** : 22 à 37 min sur une SPA, 17 à 33 min par lot sur une autre. Mesure sur 166 mutants : 342 s avec 10 fichiers, 117 s avec un seul. Ne lancer que les tests du module muté (MUT-04).

### Écrire des tests fiables
- **Test d'interface vide de sens** : un test jsdom peut passer sans rien vérifier (élément déjà focalisé, sélecteur qui ne correspond à rien, `flyTo` qui se comporte comme `setView`, `moveend` toujours émis même sans déplacement, `focus()` qui marche sur un élément caché, pas de `blur` à la suppression d'un nœud). Casser le code à la main avant de s'y fier.
- **Test aléatoire** : un nom tiré au hasard comparé à une valeur fixe échoue une fois sur N (1 échec sur 144 constaté). Choisir des valeurs que le générateur ne peut pas produire.
- **jsdom partout ralentit tout** : l'activer par fichier (COV-04).
- **Mises à jour pendant la frappe** : sans optimistic update, la diffusion de l'état peut écraser un champ en cours d'édition ; geler la carte qui a le focus.
- **Bibliothèques qui modifient leurs arguments** : Leaflet enrichit l'objet d'options passé à `setView` ; asserter avec `expect.objectContaining`. `L.DomEvent.stop` pose `originalEvent._stopped`, pas `defaultPrevented`.

### Déploiement et exécution
- **Relancer un déploiement Pages échoué** : voir CD-07.
- **CORS en local trompeur** : Vite répond lui-même aux `OPTIONS` et les e2e sont en même origine ; un `PUT`/`DELETE` absent de `Access-Control-Allow-Methods` n'échoue qu'en production.
- **Rate limiters persistants** : leur état survit aux redémarrages de `vite dev` dans `.wrangler/state` ; faux 429 en e2e. `rm -rf .wrangler/state/v3/ratelimit` avant un run local.

---

## 7. Fichiers de référence

Les modèles sont de **vrais fichiers** dans ce dépôt, à copier puis adapter. `@<sha> # vN` dans le guide signifie : épingler l'action par son SHA de 40 caractères, tag en commentaire (SEC-01) ; les modèles ont déjà des SHA valides, que Dependabot maintient.

| Règle | Fichier modèle | À adapter |
|---|---|---|
| COV-01…05 | [`templates/vitest.config.ts`](templates/vitest.config.ts) | listes `include`/`exclude`, exclusions commentées |
| MUT-01…07 | [`templates/stryker.config.mjs`](templates/stryker.config.mjs) | table `targets` (modules, plages de lignes) |
| MUT-08 | [`templates/.github/scripts/mutation-matrix.mjs`](templates/.github/scripts/mutation-matrix.mjs) | **rien** : identique dans tous les dépôts |
| MUT-10 | [`templates/.github/scripts/mutation-select.mjs`](templates/.github/scripts/mutation-select.mjs) | **rien** : identique dans tous les dépôts (lit `targets` de `stryker.config.mjs`) |
| CI-01…11, MUT-09 | [`templates/.github/workflows/ci.yml`](templates/.github/workflows/ci.yml) | retirer les jobs sans objet ; chemin de l'aperçu de build (`dist/client`) ; `worker-tests` si Worker de synchro |
| CI-12 | [`templates/playwright.config.ts`](templates/playwright.config.ts) | `testDir`, projets |
| SEC-03 | [`templates/.github/workflows/codeql.yml`](templates/.github/workflows/codeql.yml) | langages |
| SEC-04, CI-10 | [`templates/.github/workflows/audit.yml`](templates/.github/workflows/audit.yml) | — |
| CI-13 | [`templates/.github/scripts/audit-check.mjs`](templates/.github/scripts/audit-check.mjs), [`templates/.github/audit-exceptions.json`](templates/.github/audit-exceptions.json) | **rien** pour le script (identique partout) ; les exceptions du projet |
| SEC-02 | [`templates/.github/dependabot.yml`](templates/.github/dependabot.yml) | — |
| GIT-01/02 | [`templates/.github/rulesets/main.json`](templates/.github/rulesets/main.json) | ajouter « Worker de synchronisation » (CI-07) si applicable |
| GIT-03 | [`scripts/apply-rulesets.sh`](scripts/apply-rulesets.sh) | — |
| CD-01…04, CD-06 | [`templates/.github/workflows/deploy-cloudflare.yml`](templates/.github/workflows/deploy-cloudflare.yml) | route de test de fumée, secrets, environnement |
| CD-05, CD-07 | [`templates/.github/workflows/pages.yml`](templates/.github/workflows/pages.yml) | `VITE_*`, dossier de build |
| DOC-01…03 | [`templates/CLAUDE.md`](templates/CLAUDE.md) | tout le contenu |
| PHP-01…12 | [`templates/php/`](templates/php/) (Makefile, Docker, configs, `scripts/`, `tools/`, composites, workflows, Dependabot, ruleset) | namespaces et couches (`deptrac.yaml`, `psalm*.xml`), extensions PHP (`local-php`), fichiers de clé de cache (`docker-compose`), secret `UPDATE_TOKEN` ; extensions et base du `Dockerfile`, services du compose |
| PHP-14, PHP-15 | [`templates/php-ui/`](templates/php-ui/) (`docker-compose.ui.yaml`, vhost de test nginx, `Makefile.ui`, `ci_ui.yml`, `phpunit.snippet.xml`, tests navigateur, `tools/w3c-validate/`) | pages à valider, rôles authentifiés ; ajouter les 3 checks au ruleset ; `COMPOSE_FILE` dans `.env.ci` et `.env.dev` ; `composer require --dev symfony/panther` |
| PHP-03 | [`templates/php/.php-cs-fixer.dist.php`](templates/php/.php-cs-fixer.dist.php) | dossiers |
| VER-01…08, GIT-07 | [`templates/.releaserc.json`](templates/.releaserc.json), [`.github/workflows/release.yml`](templates/.github/workflows/release.yml), [`conventional_commits.yml`](templates/.github/workflows/conventional_commits.yml), [`.commitlintrc.json`](templates/.commitlintrc.json), [`.githooks/commit-msg`](templates/.githooks/commit-msg) ; ajouter les 2 checks au ruleset | `RELEASE_TOKEN` si un workflow doit suivre la release (VER-07) ; rien d'autre |
| PHP-13 | [`templates/php/.github/workflows/`](templates/php/.github/workflows/) (`push.yml`, `release.yml` en prerelease), `.releaserc.json` | variables `INFRA_*`, secrets `RELEASE_TOKEN`, `INFRA_TOKEN` |
| DOC-01…05 (PHP) | [`templates/php/CLAUDE.md`](templates/php/CLAUDE.md), [`templates/php/doc/`](templates/php/doc/) | tout le contenu |
| PWA-01…08 | *pas encore de modèle* | à extraire d'un projet qui les applique (`vite.config` PWA, test e2e hors ligne) |
| ARCH-01…03 | [`templates/.dependency-cruiser.cjs`](templates/.dependency-cruiser.cjs) | dossiers et sens des dépendances ; ajouter `depcruise …` au script `lint` |
| UPD-01…03 | [`templates/.github/workflows/node-updates.yml`](templates/.github/workflows/node-updates.yml) | secret `UPDATE_TOKEN` |
| UPD-04 | [`templates/.github/workflows/major-updates.yml`](templates/.github/workflows/major-updates.yml) | secret `UPDATE_TOKEN` |
| DOC-05 | [`templates/docs/YYYY-MM-DD-sujet.md`](templates/docs/YYYY-MM-DD-sujet.md) | tout le contenu |
| MUT-07 | [`examples/ui-test.example.test.ts`](examples/ui-test.example.test.ts) | exemple générique de test d'interface |

**Exemples réels** (pour voir un fichier rempli) : [`examples/worker-do/`](examples/worker-do/) (stryker + vitest d'un Worker, ~50 modules, un gros fichier en plages) et [`examples/js-sans-build/stryker.config.mjs`](examples/js-sans-build/stryker.config.mjs) (JS sans build, un gros `app.js` en 26 plages).

> **Règle d'évolution.** Un modèle change dans ce dépôt d'abord, puis est rejoué sur les projets (§ 9). Les exemples réels sont des instantanés : ils ne sont pas tenus à jour.

---

## 8. Suivi de conformité

Ce dépôt ne contient **aucun état par projet** : chaque projet suit son propre écart au standard (par exemple dans son `CLAUDE.md`, section « Écarts au guide »). Ce qui se mesure se mesure avec le script ; le reste est un écart déclaré avec sa raison.

| Règle | Vérifié par `check-conformity.sh` |
|---|---|
| SEC-01 | aucune action référencée par tag |
| SEC-02…04, GIT-01 | présence de `dependabot.yml`, `codeql.yml`, `audit.yml`, `rulesets/main.json` |
| COV-01, MUT-02 | seuils à 100 dans les configs |
| MUT-08 | empreinte de `mutation-matrix.mjs` identique au modèle |
| CI-13 | `audit-check.mjs` identique au modèle et appelé par `ci.yml` |
| MUT-10 | `mutation-select.mjs` identique au modèle et déclencheur `schedule` dans `ci.yml` (famille à matrice de mutation) ; `schedule` seul pour un projet à un seul job |
| ARCH-01/02 | `.dependency-cruiser.*` présent et `depcruise` dans `package.json` |
| UPD-01/04 | `node-updates.yml` et `major-updates.yml` présents |
| DOC-04 | `doc/` présent et cité dans `CLAUDE.md` |
| PWA-03/05/07 | si `vite-plugin-pwa` est utilisé : `navigateFallbackDenylist` (information si absent), test e2e hors ligne, dépendance de développement |
| VER-02/03/04/06 | `.releaserc.json` identique au modèle (hors `--prerelease` en PHP), `release.yml`, `conventional_commits.yml` identique au modèle, `.commitlintrc.json` identique, un `commit-message` par entrée de `dependabot.yml`, aucun plugin `git`/`changelog` (VER-05) |
| PHP-01…08, GIT-07, UPD-01 | si `composer.json` sans `package.json` : workflows PHP présents, `make help`, `tools/`, niveau PHPStan, Deptrac, MSI 100, commitlint, montée de PHP |
| SEC-01 | toute action externe référencée par un SHA de 40 caractères (les deux familles) |
| informatif | nombre de `Stryker disable` (MUT-06) ; part de commits conventionnels (GIT-07) |

**Vérifier des dépôts** : `scripts/check-conformity.sh chemin/dépôt [chemin/dépôt …]`. Une ligne par vérification (`ok` / `KO`, `--` pour une information), code de sortie 1 s'il y a un `KO`. Après l'ajout d'une règle au guide, les dépôts non rejoués affichent `KO` jusqu'à leur PR d'alignement. Le ruleset en ligne se compare à part : `gh api repos/<proprio>/<dépôt>/rulesets`.

---

## 9. Faire évoluer le guide

1. **Une règle = un identifiant stable.** Ne jamais réutiliser un identifiant ; une règle retirée est marquée *(abandonnée, version X)* plutôt que supprimée.
2. **Modifier le guide d'abord, les dépôts ensuite.** Incrémenter la version (mineure : règle ajoutée ou précisée ; majeure : règle qui oblige à toucher le ruleset ou les noms de checks), puis ajouter l'entrée au journal ci-dessous.
3. **Rejouer sur l'existant** : ajouter la vérification au tableau de [§ 8](#8-suivi-de-conformité), puis une PR par dépôt (§ 5). Si la règle change un nom de check, suivre GIT-03.
4. **Une règle n'entre dans le guide que si elle est vérifiable** (commande, fichier, check) et que sa **raison** est écrite.
5. Les pièges nouveaux s'ajoutent à [§ 6](#6-pièges-connus), sous le bon thème, avec l'incident qui les a révélés.
6. Les modèles de [§ 7](#7-fichiers-de-référence) sont des fichiers de `templates/` ; pour une nouvelle vérification, ajouter la ligne correspondante à `scripts/check-conformity.sh`.

### Journal des versions

| Version | Date | Changement |
|---|---|---|
| 1.0 | 2026-11-16 | Première version : standard CI/CD, 100 % couverture et mutation sur tout le code, matrice de mutation à script commun, actions épinglées par SHA, ruleset, déploiement par `workflow_run`. Tiré des 8 dépôts. |
| 1.1 | 2026-11-16 | Pratiques d'un backend PHP/Symfony généralisées : architecture exécutable (ARCH-01…03, dependency-cruiser dans `lint`), mises à jour automatiques maison (UPD-01…04), `doc/` et `docs/` (DOC-04/05), commits conventionnels (GIT-07), point d'entrée Make optionnel (SCR-03), groupement Dependabot des actions (SEC-02), deux pièges. Aucun nom de check ni ruleset modifié. |
| 1.2 | 2026-11-16 | Règles PWA (PWA-01…08) et backend PHP/Symfony (PHP-01…13) avec leurs modèles : `templates/php/` couvre Makefile, Docker, configs et outils qualité, workflows (qualité, tests, audit, mises à jour, release, déploiement), commits conventionnels et documentation. Suivi de conformité rendu générique : plus d'état ni de nom de projet dans ce dépôt ; exemples renommés `worker-do` et `js-sans-build`. |
| 2.0 | 2026-11-16 | Majeure : la famille PHP impose ses noms de checks (ruleset PHP, § 3.13), que les projets PHP existants devront adopter (GIT-03). Ajout de PHP-14 (tests navigateur Chrome + Firefox) et PHP-15 (validation W3C) avec `templates/php-ui/`. PWA-06 et PWA-08 abandonnées. SEC-01 vérifié sur les deux familles. `check-conformity.sh` distingue les familles npm et PHP. |
| 3.0 | 2026-11-16 | Majeure : versionnement automatique (§ 3.14, VER-01…08) étendu à toutes les familles : SemVer déduit des Conventional Commits par semantic-release, release GitHub aux notes générées, aucun commit de release. Le ruleset npm exige désormais « Titre de PR conventionnel » et « Commits conventionnels » (GIT-03). Dependabot préfixe ses commits. Modèles ajoutés à `templates/` ; `check-conformity.sh` vérifie VER-02…06. |
| 3.1 | 2026-11-16 | Mineure, tirée du rejeu sur les applications : `dependency-cruiser` exige `@swc/core` avec TypeScript 7 (sinon 0 module analysé, ARCH-02 et piège du § 6) ; le modèle `.dependency-cruiser.cjs` couvre `src/views/` et documente l'exception des helpers de test. |
| 3.2 | 2026-11-16 | Mineure, tirée du rejeu PWA : PWA-05 précise que le test hors ligne tourne sur le build de production et exige `context.setOffline` (un mock du même nom ne suffisait pas) ; `check-conformity.sh` durci en conséquence. |
| 3.3 | 2026-11-16 | Mineure, tirée du rejeu sur un projet de scripts classiques : ARCH-04 (pas de modules ES, pas de graphe d'import : écart déclaré dans `CLAUDE.md`, ordre des balises `<script>` documenté) ; `check-conformity.sh` accepte l'écart déclaré. |
| 3.4 | 2026-11-17 | Mineure, tirée d'un incident : VER-06 précise que `commit-message` se pose sur **chaque** entrée de `dependabot.yml` (sans héritage) ; nouveau piège au § 6 ; `check-conformity.sh` compare le nombre de `commit-message` au nombre d'entrées. |
| 3.5 | 2026-11-17 | Mineure, tirée de la mesure des temps de CI : MUT-10 (mutation complète la nuit, modules touchés sur les PR, aucune sur `main`) avec `mutation-select.mjs` et `ci.yml` à jour ; piège « CI longue à cause de la file d'attente » (§ 6). Aucun nom de check modifié. |
| 3.6 | 2026-11-17 | Mineure, tirée du premier push après MUT-10 : le modèle `ci.yml` ajoute `if: ${{ !failure() && !cancelled() }}` au job `build` (sinon sauté quand les modules de mutation sont *skipped*) et piège correspondant au § 6 ; MUT-10 précise que l'objectif de 10 minutes ne vaut pas pour le contrôle de nuit. Aucun nom de check modifié. |
| 3.7 | 2026-11-17 | Mineure : MUT-10 s'applique aussi aux projets à un seul job de mutation (nuit et lancement manuel seulement, sauté sur PR et push), quelle que soit la durée du job ; `check-conformity.sh` exige `schedule` dans `ci.yml` (famille npm). Aucun nom de check modifié. |
| 3.8 | 2026-11-17 | Mineure, tirée d'un avis d'audit `high` sans correctif publié (`picomatch`) qui a rougi l'audit de tous les dépôts : CI-13 (`audit-check.mjs`, exceptions datées pour les dépendances de développement, seuil inchangé), `ci.yml` et `audit.yml` l'appellent, piège au § 6, `check-conformity.sh` vérifie l'empreinte du script. Aucun nom de check modifié. |
