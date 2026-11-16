# CLAUDE.md

## Commandes
```sh
make start                      # tout : images, vendors, cache, données
make sh                         # shell dans le conteneur PHP
make composer c="req paquet"    # composer
make tests | tests-unit | tests-integration     # t · tu · ti
make coverage | infection | measures            # m
make quality | code-quality | infra-quality | security | all    # a
```
- Un seul test : `make sh` puis `php vendor/bin/phpunit tests/src/Unit/Chemin/MonTest.php --filter testVerbeComportement`.
- Les outils qualité s'installent à la demande (`tools/<outil>/`, un `composer.json` chacun).

## Architecture
<!-- Schéma des couches Controller → Service → Calculator → Repository et sens des dépendances ; détail dans doc/architecture.md. -->

## Exigences qualité
- Couverture 100 % (`make coverage`), MSI 100 % et covered MSI 100 % (`make infection`).
- PHPStan niveau max, Psalm strict, PHPMD, Deptrac sans violation.
- `declare(strict_types=1)`, classes concrètes `final`, `#[\Override]`.
- Chaque classe de test : `/** @internal */` + `#[CoversClass(Cible::class)]`.
- Une exception (`@psalm-suppress`, `@codeCoverageIgnore`, mutant ignoré) s'écrit avec sa raison ; préférer supprimer la branche inatteignable.
- Baselines : seulement pour entrer dans un projet existant ; commande de mise à jour : <!-- à écrire -->.

## Environnements de test
- **Unitaire** (`tests/src/Unit/`) : dépendances mockées, aucune base.
- **Intégration** (`tests/src/Integration/`) : vraie base, serveur de mock HTTP (`tests/resources/moco/`) à la place des API externes. Jamais de faux client HTTP.
- Hygiène des mocks : `make check-moco-refs` (en CI), `make clean-unused-files`, `make clean-moco-routes`.

## Variables d'environnement
| Variable | Rôle |
|---|---|
| `DATABASE_URL` | DSN de la base (une par environnement) |

## Astuce de debug
```php
file_put_contents('tests/last.html', $client->getCrawler()->html());   // HTML d'un échec d'intégration
```

## Commits et releases
- Conventional Commits (`type(portée): sujet`), règles dans `.commitlintrc.json`, vérifiées par la CI et, en local, par `make hooks` (GIT-07).
- PR fusionnées par rebase : chaque commit doit être conventionnel.
- À chaque push sur `main`, `release.yml` (semantic-release) crée une **prerelease** → image de staging (`push.yml`) → PR de bump sur le dépôt d'infra. Publier la prerelease la promeut en prod.
- Secrets : `RELEASE_TOKEN`, `UPDATE_TOKEN`, `INFRA_TOKEN` ; variables : `INFRA_REPOSITORY`, `INFRA_STACK_PATH`.
