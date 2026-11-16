# Inventaire des dépendances

Lu par `scripts/infra-updates.py` : la ligne `php` du tableau suit la version de PHP (UPD-01).

| Composant | Version | Géré par |
|---|---|---|
| `php` | 8.5 | `infra-updates.yml` |
| Symfony | | Dependabot (composer) |

## Outils qualité (`tools/*/composer.json`)
<!-- Un outil par ligne ; chacun a son composer.json, audité et mis à jour séparément (PHP-02, PHP-11). -->

## Commandes de vérification
```sh
make composer c=outdated   # dépendances en retard
make security              # composer audit : application et chaque outil
```
