# Conventions de codage

## Langage et framework
<!-- Versions de PHP et de Symfony, extensions requises. -->

## Style de code
`declare(strict_types=1)` partout ; PHP-CS-Fixer (`make phpcsfixer-fix`) ; classes concrètes `final` (sauf services mockés) ; `#[\Override]`.

## Nommage — suffixes imposés par couche
`…Controller`, `…Service`, `…Calculator`, `…Repository`, `…QueryOptions`, `…Response`, `…Factory`.

## À faire
- Contrôleurs sans logique métier ; validation des entrées par DTO + `OptionsResolver`.
- Entités sans getter/setter (propriétés publiques + traits).
- DTO de réponse `final readonly` + Factory statique.
- SQL complexe dans `resources/sql/*.sql`.
- Valeurs métier en configuration, jamais en dur.

## À éviter
- `catch (\Exception)` sans re-lancement ni log structuré.
- `@psalm-suppress` / `@codeCoverageIgnore` sans exception documentée : préférer supprimer la branche inatteignable.
- Faux client HTTP en intégration : un serveur de mock rejoue des fixtures (PHP-09).
